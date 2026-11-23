import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/checkout_order.dart';
import '../models/coordination_details.dart';
import '../models/pickup_order_qr.dart';

class PickupOrderQrCard extends StatelessWidget {
  const PickupOrderQrCard({super.key, required this.order});

  final CheckoutOrder order;

  @override
  Widget build(BuildContext context) {
    final data = PickupOrderQr.encode(order.id);
    if (data == null ||
        order.details.deliveryMethod != DeliveryMethod.pickup ||
        !order.payment.isApproved) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('QR de recojo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Muéstralo al personal cuando recojas tu pedido.'),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: data,
                size: 184,
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.white,
                semanticsLabel: 'Código QR de recojo del pedido ${order.id}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
