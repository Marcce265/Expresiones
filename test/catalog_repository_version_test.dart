import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:expresiones/data/catalog_repository.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('usa la caché cuando catalog_metadata conserva la versión', () async {
    const cacheKey = 'catalog.version-test';
    const cachedProduct = CatalogProduct(
      id: 'cinta',
      name: 'Cinta satinada',
      category: ProductCategory.materials,
      basePrice: 29,
      unitLabel: 'rollo',
    );
    SharedPreferences.setMockInitialValues({
      cacheKey: jsonEncode([cachedProduct.toMap()]),
      '$cacheKey.version': 7,
    });
    final server = await _FakeSupabaseServer.start(version: 7);
    final client = _client(server.url);
    addTearDown(() async {
      await client.removeAllChannels();
      await client.dispose();
      await server.close();
    });

    final repository = CatalogRepository(client: client, cacheKey: cacheKey);
    final products = await repository.watchProducts().first.timeout(
      const Duration(seconds: 5),
    );

    expect(products.single.id, cachedProduct.id);
    expect(repository.lastSource, CatalogDataSource.cache);
    expect(server.restTables, ['catalog_metadata']);
  });

  test('refresca y guarda la versión cuando la caché quedó atrás', () async {
    const cacheKey = 'catalog.version-refresh-test';
    SharedPreferences.setMockInitialValues({
      cacheKey: '[]',
      '$cacheKey.version': 6,
    });
    final server = await _FakeSupabaseServer.start(version: 7);
    final client = _client(server.url);
    addTearDown(() async {
      await client.removeAllChannels();
      await client.dispose();
      await server.close();
    });

    final repository = CatalogRepository(client: client, cacheKey: cacheKey);
    final products = await repository.watchProducts().first.timeout(
      const Duration(seconds: 5),
    );

    expect(products, isEmpty);
    expect(repository.lastSource, CatalogDataSource.supabase);
    expect(
      server.restTables,
      containsAll(<String>[
        'catalog_metadata',
        'families',
        'variants',
        'family_price_tiers',
        'variant_price_tiers',
      ]),
    );
    expect(server.restTables.length, 5);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('$cacheKey.version'), 7);
  });

  test('agrupa varios cambios seguidos en una sola recarga', () async {
    const cacheKey = 'catalog.version-debounce-test';
    const cachedProduct = CatalogProduct(
      id: 'limpiapipas',
      name: 'Limpiapipas',
      category: ProductCategory.materials,
      basePrice: 5,
      unitLabel: 'paquete',
    );
    SharedPreferences.setMockInitialValues({
      cacheKey: jsonEncode([cachedProduct.toMap()]),
      '$cacheKey.version': 7,
    });
    final server = await _FakeSupabaseServer.start(version: 7);
    final client = _client(server.url);
    final repository = CatalogRepository(client: client, cacheKey: cacheKey);
    final emissionsFuture = repository
        .watchProducts()
        .take(2)
        .toList()
        .timeout(const Duration(seconds: 5));
    addTearDown(() async {
      await client.removeAllChannels();
      await client.dispose();
      await server.close();
    });

    await _eventually(() => server.restTables.contains('catalog_metadata'));
    await server.emitVersion(8);
    await server.emitVersion(9);
    final emissions = await emissionsFuture;

    expect(emissions.first.single.id, cachedProduct.id);
    expect(emissions.last, isEmpty);
    expect(
      server.restTables.where((table) => table == 'families'),
      hasLength(1),
    );
    expect(server.restTables, hasLength(5));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('$cacheKey.version'), 9);
  });
}

SupabaseClient _client(String url) => SupabaseClient(
  url,
  'test-publishable-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeSupabaseServer {
  _FakeSupabaseServer._(this._server, this.version);

  final HttpServer _server;
  final int version;
  final restTables = <String>[];
  final _sockets = <WebSocket>[];
  final _joined = Completer<void>();
  WebSocket? _realtimeSocket;
  String? _realtimeTopic;

  String get url =>
      'http://${InternetAddress.loopbackIPv4.address}:${_server.port}';

  static Future<_FakeSupabaseServer> start({required int version}) async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _FakeSupabaseServer._(httpServer, version);
    httpServer.listen(server._handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _sockets.add(socket);
      socket.listen((message) => _replyToRealtime(socket, message));
      return;
    }

    final table = request.uri.pathSegments.last;
    restTables.add(table);
    final body = table == 'catalog_metadata'
        ? jsonEncode([
            {'id': 'public', 'version': version},
          ])
        : '[]';
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(body);
    await request.response.close();
  }

  void _replyToRealtime(WebSocket socket, dynamic message) {
    final frame = jsonDecode(message as String) as List<dynamic>;
    if (frame[3] == 'phx_leave' || frame[3] == 'heartbeat') {
      try {
        socket.add(
          jsonEncode([
            frame[0],
            frame[1],
            frame[2],
            'phx_reply',
            {'status': 'ok', 'response': <String, dynamic>{}},
          ]),
        );
      } on StateError {
        // A canceled `.first` listener can close before the reply is written.
      }
      return;
    }
    if (frame[3] != 'phx_join') return;
    final config = (frame[4] as Map<String, dynamic>)['config'];
    final changes =
        (config as Map<String, dynamic>)['postgres_changes'] as List;
    _realtimeSocket = socket;
    _realtimeTopic = frame[2] as String;
    try {
      socket.add(
        jsonEncode([
          frame[0],
          frame[1],
          frame[2],
          'phx_reply',
          {
            'status': 'ok',
            'response': {
              'postgres_changes': [
                for (final entry in changes.indexed)
                  {...entry.$2 as Map<String, dynamic>, 'id': entry.$1},
              ],
            },
          },
        ]),
      );
    } on StateError {
      // The `.first` subscriber may close immediately after the REST snapshot.
    }
    if (!_joined.isCompleted) _joined.complete();
  }

  Future<void> emitVersion(int nextVersion) async {
    await _joined.future.timeout(const Duration(seconds: 5));
    _realtimeSocket!.add(
      jsonEncode([
        null,
        null,
        _realtimeTopic,
        'postgres_changes',
        {
          'ids': [0],
          'data': {
            'columns': [
              {'name': 'id', 'type': 'text', 'type_modifier': 4294967295},
              {'name': 'version', 'type': 'int8', 'type_modifier': 4294967295},
            ],
            'commit_timestamp': '2026-10-26T00:00:00Z',
            'errors': null,
            'old_record': {'id': 'public'},
            'record': {'id': 'public', 'version': nextVersion},
            'schema': 'public',
            'table': 'catalog_metadata',
            'type': 'UPDATE',
          },
        },
      ]),
    );
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }
}

Future<void> _eventually(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('La condición no se cumplió a tiempo.');
}
