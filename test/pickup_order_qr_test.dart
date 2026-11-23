import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:expresiones/admin/admin_pickup_verification_screen.dart';
import 'package:expresiones/admin/admin_portal.dart';
import 'package:expresiones/data/customer_account_repository.dart';
import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/pickup_order_qr.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/widgets/pickup_order_qr_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = 'PED-20261123-100000-001';
const _payload = 'expresiones:recojo:1:$_id';

void main() {
  group('acceso del personal', () {
    late SupabaseClient staffClient;
    setUp(() {
      staffClient = SupabaseClient(
        'https://example.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
    });
    tearDown(() => staffClient.dispose());
    testWidgets('una sesión sin guardar abre el formulario enseguida', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminPortal(client: staffClient, pickupVerificationOnly: true),
        ),
      );
      await tester.pump();
      expect(find.text('Correo administrativo'), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
    });
  });

  test('el QR contiene solo el identificador y rechaza entradas ajenas', () {
    expect(PickupOrderQr.encode(_id), _payload);
    expect(PickupOrderQr.decode(_payload), _id);
    expect(PickupOrderQr.decode('https://example.com/$_id'), isNull);
    expect(PickupOrderQr.decode('$_payload?extra=1'), isNull);
    expect(PickupOrderQr.decode('$_payload\n'), isNull);
    expect(PickupOrderQr.encode('otro-formato'), isNull);
  });

  testWidgets('solo un pedido aprobado de recojo tiene un QR', (tester) async {
    Future<void> show(CheckoutOrder order) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PickupOrderQrCard(order: order)),
      ),
    );
    await show(_order());
    expect(find.byType(QrImageView), findsOneWidget);
    await show(_order(delivery: DeliveryMethod.shalom));
    expect(find.byType(QrImageView), findsNothing);
    await show(_order(status: SimulatedPaymentStatus.declined));
    expect(find.byType(QrImageView), findsNothing);
  });

  test(
    'la consulta exige acceso administrativo y filtra pedidos de recojo',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var allowed = false;
      var lookups = 0;
      var result = <Object>[];
      final queries = <Map<String, String>>[];
      server.listen((request) async {
        final Object response;
        if (request.uri.path.endsWith('/rpc/can_admin_write')) {
          response = allowed;
        } else {
          lookups++;
          queries.add(request.uri.queryParameters);
          response = result;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final repo = CustomerAccountRepository(client: client);
      await expectLater(repo.verifyPickupQr(_payload), throwsFormatException);

      final claims = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'exp':
                    DateTime.now()
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }),
            ),
          )
          .replaceAll('=', '');
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.test',
          'refresh_token': 'test',
          'token_type': 'bearer',
          'user': {'id': 'test', 'aud': 'authenticated'},
        }),
      );
      await expectLater(repo.verifyPickupQr(_payload), throwsFormatException);
      expect(lookups, 0);

      allowed = true;
      expect(await repo.verifyPickupQr(_payload), isNull);
      result = [_row(_order())];
      expect((await repo.verifyPickupQr(_payload))?.order.id, _id);
      expect(queries.last['id'], 'eq.$_id');
      expect(queries.last['delivery_method'], 'eq.pickup');
      expect(queries.last['status'], 'eq.paid_simulated');
      result = [_row(_order(delivery: DeliveryMethod.shalom))];
      expect(await repo.verifyPickupQr(_payload), isNull);
    }, _LoopbackHttpOverrides()),
  );

  testWidgets('el lector ignora duplicados y permite volver a escanear', (
    tester,
  ) async {
    final originalPlatform = MobileScannerPlatform.instance;
    final camera = _TestCamera();
    MobileScannerController.resetPlatformSessionOwner();
    MobileScannerPlatform.instance = camera;
    addTearDown(() {
      MobileScannerController.resetPlatformSessionOwner();
      MobileScannerPlatform.instance = originalPlatform;
      return camera.events.close();
    });
    final repo = _ScanRepository();
    await tester.pumpWidget(
      MaterialApp(home: AdminPickupVerificationScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    void scan(String data) => camera.events.add(
      BarcodeCapture(
        barcodes: [Barcode(rawValue: data, format: BarcodeFormat.qrCode)],
      ),
    );
    scan('código externo');
    await tester.pumpAndSettle();
    expect(find.text('QR inválido'), findsOneWidget);
    await tester.tap(find.text('Escanear otro QR'));
    await tester.pumpAndSettle();
    scan(_payload);
    scan(_payload);
    await tester.pump();
    expect(repo.count, 2);
    repo.result.complete(
      StoredCustomerOrder(
        order: _order(),
        customerName: 'Cliente de prueba',
        customerPhone: '',
        status: 'paid_simulated',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pedido encontrado'), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);
    scan(_payload);
    await tester.pump();
    expect(repo.count, 2);
  });
}

CheckoutOrder _order({
  DeliveryMethod delivery = DeliveryMethod.pickup,
  SimulatedPaymentStatus status = SimulatedPaymentStatus.approved,
}) {
  final date = DateTime(2026, 11, 23);
  return CheckoutOrder(
    id: _id,
    items: const [],
    details: CoordinationDetails(deliveryMethod: delivery),
    productsSubtotal: 25,
    payment: SimulatedPayment(
      reference: 'SIM-20261123-100000-000',
      method: SimulatedPaymentMethod.demoYape,
      status: status,
      amount: 25,
      processedAt: date,
    ),
    createdAt: date,
  );
}

Map<String, Object?> _row(CheckoutOrder order) => {
  'snapshot': order.toJson(),
  'customer_name': 'Cliente de prueba',
  'customer_phone': '',
  'status': 'paid_simulated',
};

class _ScanRepository implements CustomerAccountRepository {
  final result = Completer<StoredCustomerOrder?>();
  int count = 0;

  @override
  Future<StoredCustomerOrder?> verifyPickupQr(String payload) async {
    count++;
    if (PickupOrderQr.decode(payload) == null) {
      throw const FormatException('QR inválido');
    }
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCamera extends MobileScannerPlatform {
  final events = StreamController<BarcodeCapture?>.broadcast();

  @override
  Stream<BarcodeCapture?> get barcodesStream => events.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(320, 240),
      );
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _LoopbackHttpOverrides extends HttpOverrides {}
