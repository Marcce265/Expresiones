import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
    required this.onContact,
    required this.onPrivacy,
  });

  final VoidCallback onContact;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, String title, String body})>[
      (
        icon: Icons.receipt_long_outlined,
        title: '¿Cómo funciona la cotización?',
        body: 'Elige productos y cantidades. La app calcula un subtotal de productos y prepara el mensaje para WhatsApp. No necesitas crear una cuenta.',
      ),
      (
        icon: Icons.inventory_2_outlined,
        title: 'Stock y precio final',
        body: 'Expresiones confirma disponibilidad y precio antes de cualquier pago. Agregar productos no reserva stock.',
      ),
      (
        icon: Icons.storefront_outlined,
        title: 'Recojo en Huancayo',
        body: 'La dirección y el horario se coordinan al confirmar el pedido por WhatsApp.',
      ),
      (
        icon: Icons.local_shipping_outlined,
        title: 'Envíos nacionales',
        body: 'Los envíos se coordinan mediante Shalom. La tarifa se confirma según destino, tamaño y peso.',
      ),
      (
        icon: Icons.event_available_outlined,
        title: 'Fechas y capacidad',
        body: 'Los ramos y regalos son artesanales. La fecha solicitada depende de la carga de producción y queda confirmada por WhatsApp.',
      ),
      (
        icon: Icons.payments_outlined,
        title: 'Pago',
        body: 'No se cobra dentro de esta app. El pago se coordina únicamente después de confirmar todos los detalles.',
      ),
    ];

    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Estamos para ayudarte'),
            const SizedBox(height: 8),
            Text(
              'Preguntas frecuentes',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Cotiza con calma. La conversación final siempre continúa con una persona de Expresiones.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ExpansionTile(
                    leading: Icon(item.icon),
                    title: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(item.body),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPrivacy,
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Privacidad y mis datos'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContact,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                ),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Hablar con Expresiones'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
