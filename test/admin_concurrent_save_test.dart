import 'dart:convert';
import 'dart:io';

import 'package:expresiones/admin/admin_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'dos administradores reintentan y guardan ante contención transitoria',
    () async {
      final server = await _ConcurrentSaveServer.start();
      addTearDown(server.close);

      SupabaseClient client() => SupabaseClient(
        server.url,
        'public-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final first = AdminCatalogRepository(client: client());
      final second = AdminCatalogRepository(client: client());

      await Future.wait([
        first.updateProduct('producto-compartido', {'name': 'Edición A'}),
        second.updateProduct('producto-compartido', {'name': 'Edición B'}),
      ]);

      expect(server.attempts['Edición A'], 2);
      expect(server.attempts['Edición B'], 2);
      expect(server.successfulSaves, 2);
    },
  );

  test(
    'un SKU duplicado no se reintenta y muestra una explicación útil',
    () async {
      final server = await _ConcurrentSaveServer.start();
      addTearDown(server.close);
      final client = SupabaseClient(
        server.url,
        'public-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final repository = AdminCatalogRepository(client: client);

      await expectLater(
        repository.updateProduct('producto-compartido', {
          'name': 'SKU duplicado',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'mensaje',
            contains('El código xs-1 ya está usado'),
          ),
        ),
      );
      expect(server.attempts['SKU duplicado'], 1);
    },
  );
}

class _ConcurrentSaveServer {
  _ConcurrentSaveServer._(this._server);

  final HttpServer _server;
  final attempts = <String, int>{};
  var successfulSaves = 0;

  String get url => 'http://${_server.address.host}:${_server.port}';

  static Future<_ConcurrentSaveServer> start() async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _ConcurrentSaveServer._(httpServer);
    httpServer.listen(server._handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path != '/rest/v1/rpc/admin_save_catalog_family') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
    final payload = body['payload'] as Map;
    final name = '${payload['name']}';
    final attempt = (attempts[name] ?? 0) + 1;
    attempts[name] = attempt;
    request.response.headers.contentType = ContentType.json;

    if (name == 'SKU duplicado') {
      request.response.statusCode = HttpStatus.conflict;
      request.response.write(
        jsonEncode({
          'code': '23505',
          'message': 'duplicate key value violates unique constraint "variants_sku_unique"',
          'details': 'Key (lower(sku))=(xs-1) already exists.',
          'hint': null,
        }),
      );
      await request.response.close();
      return;
    }

    if (attempt == 1) {
      request.response.statusCode = HttpStatus.conflict;
      request.response.write(
        jsonEncode({
          'code': '40P01',
          'message': 'deadlock detected',
          'details': null,
          'hint': null,
        }),
      );
    } else {
      successfulSaves++;
      request.response.statusCode = HttpStatus.ok;
      request.response.write('[]');
    }
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}
