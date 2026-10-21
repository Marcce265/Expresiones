import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
    required this.onContact,
    required this.onPrivacy,
    required this.onAdminLogin,
  });

  final VoidCallback onContact;
  final VoidCallback onPrivacy;
  final VoidCallback onAdminLogin;

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
        maxWidth: 1040,
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
            const SizedBox(height: 20),
            const InfoBanner(
              title: 'La cotización es libre y sin registro',
              message: 'Puedes revisar productos, calcular cantidades y preparar tu solicitud sin crear una cuenta.',
              icon: Icons.lock_open_rounded,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [for (final item in items) _FaqCard(item: item)],
                  );
                }
                final left = <({IconData icon, String title, String body})>[];
                final right = <({IconData icon, String title, String body})>[];
                for (var index = 0; index < items.length; index++) {
                  (index.isEven ? left : right).add(items[index]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          for (final item in left) _FaqCard(item: item),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          for (final item in right) _FaqCard(item: item),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => _HelpActions(
                horizontal: constraints.maxWidth >= 620,
                onPrivacy: onPrivacy,
                onContact: onContact,
                onAdminLogin: onAdminLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final ({IconData icon, String title, String body}) item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.pinkSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 21),
          ),
          title: Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(item.body)),
          ],
        ),
      ),
    );
  }
}

class _HelpActions extends StatelessWidget {
  const _HelpActions({
    required this.horizontal,
    required this.onPrivacy,
    required this.onContact,
    required this.onAdminLogin,
  });

  final bool horizontal;
  final VoidCallback onPrivacy;
  final VoidCallback onContact;
  final VoidCallback onAdminLogin;

  @override
  Widget build(BuildContext context) {
    final privacy = OutlinedButton.icon(
      onPressed: onPrivacy,
      icon: const Icon(Icons.privacy_tip_outlined),
      label: const Text('Privacidad y mis datos'),
    );
    final contact = FilledButton.icon(
      onPressed: onContact,
      style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
      icon: const Icon(Icons.chat_outlined),
      label: const Text('Hablar con Expresiones'),
    );
    final primaryActions = horizontal
        ? Row(
            children: [
              Expanded(child: privacy),
              const SizedBox(width: 12),
              Expanded(child: contact),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [privacy, const SizedBox(height: 10), contact],
          );

    return Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        primaryActions,
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Acceso exclusivo para la administración de Expresiones',
          child: TextButton.icon(
            key: const ValueKey('admin-login-button'),
            onPressed: onAdminLogin,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.muted,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Iniciar sesión administrativa'),
          ),
        ),
      ],
    );
  }
}
