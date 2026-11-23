import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/customer_account_repository.dart';
import '../screens/order_success_screen.dart';
import '../widgets/app_components.dart';

class AdminPickupVerificationScreen extends StatefulWidget {
  const AdminPickupVerificationScreen({super.key, required this.repository});

  final CustomerAccountRepository repository;

  @override
  State<AdminPickupVerificationScreen> createState() =>
      _AdminPickupVerificationScreenState();
}

class _AdminPickupVerificationScreenState
    extends State<AdminPickupVerificationScreen> {
  StoredCustomerOrder? _entry;
  String? _message;
  bool _checking = false;
  int _cameraAttempt = 0;

  void _retry() => setState(() {
    _entry = null;
    _message = null;
    _cameraAttempt++;
  });

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted || _checking || _entry != null || _message != null) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (barcode.format != BarcodeFormat.qrCode || value == null) continue;
      setState(() => _checking = true);
      try {
        final entry = await widget.repository.verifyPickupQr(value);
        if (!mounted) return;
        setState(() {
          _entry = entry;
          if (entry == null) {
            _message = 'No encontramos un pedido de recojo con ese código.';
          }
        });
      } on FormatException catch (error) {
        if (mounted) setState(() => _message = error.message);
      } catch (_) {
        if (mounted) {
          setState(
            () => _message =
                'No se pudo consultar el pedido. Inténtalo de nuevo.',
          );
        }
      } finally {
        if (mounted) setState(() => _checking = false);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar recojo')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsivePage(
            maxWidth: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_checking)
                  const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Consultando pedido',
                    ),
                  )
                else if (entry != null) ...[
                  InfoBanner(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Pedido encontrado',
                    message: '${entry.order.id} · ${entry.customerName}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirma el nombre del cliente antes de entregar el pedido.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Escanear otro QR'),
                  ),
                  OrderDeliveryCard(details: entry.order.details),
                  OrderReceiptCard(order: entry.order),
                ] else if (_message != null)
                  Text(_message!)
                else ...[
                  const Text('Enfoca el QR que te muestra el cliente.'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: MobileScanner(
                        key: ValueKey(_cameraAttempt),
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => EmptyState(
                          icon: Icons.no_photography_outlined,
                          title: 'Cámara no disponible',
                          message:
                              error.errorCode ==
                                  MobileScannerErrorCode.permissionDenied
                              ? 'Permite el acceso a la cámara en los ajustes de Android.'
                              : 'Revisa que la cámara esté disponible e inténtalo de nuevo.',
                          action: TextButton(
                            onPressed: _retry,
                            child: const Text('Reintentar'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Escanear otro QR'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
