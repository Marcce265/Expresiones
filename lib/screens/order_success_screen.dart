import 'package:flutter/material.dart';

import '../models/checkout_order.dart';
import '../models/coordination_details.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/order_export_buttons.dart';

typedef OrderSuccessAction = Future<void> Function();

class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    super.key,
    required this.order,
    required this.onSendWhatsapp,
    required this.onCopySummary,
    required this.onHome,
    required this.onNewOrder,
    this.settings = const StorefrontSettings(),
  });

  final CheckoutOrder order;
  final OrderSuccessAction onSendWhatsapp;
  final OrderSuccessAction onCopySummary;
  final VoidCallback onHome;
  final VoidCallback onNewOrder;
  final StorefrontSettings settings;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  bool _sending = false;
  bool _copying = false;

  Future<void> _sendWhatsapp() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSendWhatsapp();
    } catch (_) {
      if (mounted) {
        showAppNotice(
          context,
          'No pudimos abrir WhatsApp. Inténtalo nuevamente.',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copySummary() async {
    if (_copying) return;
    setState(() => _copying = true);
    try {
      await widget.onCopySummary();
      if (mounted) showAppNotice(context, 'Resumen del pedido copiado.');
    } catch (_) {
      if (mounted) {
        showAppNotice(
          context,
          'No se pudo copiar el resumen.',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1280,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SuccessHero(order: order, settings: widget.settings),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final details = Column(
                  children: [
                    _OrderReceiptCard(order: order),
                    const SizedBox(height: 18),
                    _DeliveryCard(details: order.details),
                  ],
                );
                final actions = _ActionsCard(
                  order: order,
                  settings: widget.settings,
                  sending: _sending,
                  copying: _copying,
                  onSendWhatsapp: _sendWhatsapp,
                  onCopySummary: _copySummary,
                  onHome: widget.onHome,
                  onNewOrder: widget.onNewOrder,
                );
                if (!wide) {
                  return Column(
                    children: [details, const SizedBox(height: 18), actions],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: details),
                    const SizedBox(width: 28),
                    Expanded(flex: 5, child: actions),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({required this.order, required this.settings});

  final CheckoutOrder order;
  final StorefrontSettings settings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final icon = Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: AppColors.whatsapp,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 34,
              ),
            );
            final copy = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Eyebrow(settings.text(StorefrontText.successEyebrow)),
                const SizedBox(height: 6),
                Text(
                  settings.text(StorefrontText.successTitle),
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 7),
                Text(
                  settings.text(StorefrontText.successBody),
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            );
            final step = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.pinkSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'PASO 5 DE 5 · LISTO',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            );

            if (compact) {
              return Column(
                children: [
                  step,
                  const SizedBox(height: 18),
                  icon,
                  const SizedBox(height: 16),
                  copy,
                ],
              );
            }
            return Row(
              children: [
                icon,
                const SizedBox(width: 18),
                Expanded(child: copy),
                const SizedBox(width: 18),
                step,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderReceiptCard extends StatelessWidget {
  const _OrderReceiptCard({required this.order});

  final CheckoutOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _RoundIcon(Icons.receipt_long_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprobante del pedido',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${order.totalQuantity} ${order.totalQuantity == 1 ? 'unidad' : 'unidades'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pinkSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'SIMULACIÓN',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            if (order.items.isEmpty)
              Text(
                'No hay productos en este comprobante.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (var index = 0; index < order.items.length; index++) ...[
                _ReceiptLine(item: order.items[index]),
                if (index != order.items.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
              ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            _ReceiptAmountRow(
              label: 'Productos',
              value: order.productsSubtotal,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Envío',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
                Text(
                  order.shippingPending ? 'Por confirmar' : 'Sin envío',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            _ReceiptAmountRow(
              label: 'Total simulado',
              value: order.simulatedTotal,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.item});

  final CheckoutOrderItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${item.quantity}×',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (item.sku != null)
                Text(item.sku!, style: Theme.of(context).textTheme.bodySmall),
              if (item.customization.isNotEmpty)
                Text(
                  item.customization,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'S/ ${item.lineTotal.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _ReceiptAmountRow extends StatelessWidget {
  const _ReceiptAmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasized
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
          ),
        ),
        Text(
          'S/ ${value.toStringAsFixed(2)}',
          style: emphasized
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.details});

  final CoordinationDetails details;

  @override
  Widget build(BuildContext context) {
    final agency = details.shalomAgencyName.trim();
    final desiredDate = details.desiredDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _RoundIcon(Icons.local_shipping_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Datos de coordinación',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            _DetailRow(icon: Icons.person_outline_rounded, text: details.name),
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.phone_outlined, text: details.phone),
            const SizedBox(height: 12),
            _DetailRow(
              icon: details.deliveryMethod == DeliveryMethod.shalom
                  ? Icons.local_shipping_outlined
                  : Icons.storefront_outlined,
              text: details.deliveryLabel,
            ),
            if (agency.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.location_on_outlined,
                text:
                    '$agency${details.shalomAgencyLocality.trim().isEmpty ? '' : ' · ${details.shalomAgencyLocality.trim()}'}',
              ),
            ],
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              text: desiredDate == null
                  ? 'Fecha por coordinar'
                  : 'Fecha deseada: ${_formatDate(desiredDate)}',
            ),
            for (final entry in details.customFields.entries)
              if (entry.value.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.assignment_outlined,
                  text: '${entry.key}: ${entry.value.trim()}',
                ),
              ],
            if (details.note.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailRow(icon: Icons.notes_outlined, text: details.note.trim()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.order,
    required this.settings,
    required this.sending,
    required this.copying,
    required this.onSendWhatsapp,
    required this.onCopySummary,
    required this.onHome,
    required this.onNewOrder,
  });

  final CheckoutOrder order;
  final StorefrontSettings settings;
  final bool sending;
  final bool copying;
  final VoidCallback onSendWhatsapp;
  final VoidCallback onCopySummary;
  final VoidCallback onHome;
  final VoidCallback onNewOrder;

  @override
  Widget build(BuildContext context) {
    final payment = order.payment;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.text(StorefrontText.successPaymentLabel),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REFERENCIA',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectionArea(
                    child: Text(
                      payment.reference,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MetaRow(label: 'Método', value: payment.methodLabel),
                  const SizedBox(height: 8),
                  _MetaRow(
                    label: 'Fecha',
                    value: _formatDateTime(payment.processedAt),
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(
                    label: 'Importe',
                    value: 'S/ ${payment.amount.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoBanner(
              title: 'No se realizó ningún cobro',
              message: settings.text(StorefrontText.successNoCharge),
              icon: Icons.shield_outlined,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sending ? null : onSendWhatsapp,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                  foregroundColor: Colors.white,
                ),
                icon: sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.chat_outlined),
                label: Text(
                  sending
                      ? 'Abriendo WhatsApp…'
                      : settings.text(StorefrontText.successWhatsappButton),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: copying ? null : onCopySummary,
                icon: copying
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.copy_rounded, size: 18),
                label: Text(copying ? 'Copiando…' : 'Copiar resumen'),
              ),
            ),
            const SizedBox(height: 10),
            OrderExportButtons(order: order),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 370;
                final home = OutlinedButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: Text(settings.text(StorefrontText.successHomeButton)),
                );
                final again = TextButton.icon(
                  onPressed: onNewOrder,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    settings.text(StorefrontText.successNewOrderButton),
                  ),
                );
                if (stack) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: home),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: again),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: home),
                    const SizedBox(width: 8),
                    Expanded(child: again),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.pinkSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 21),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${value.day} de ${months[value.month - 1]} de ${value.year}';
}

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} · '
      '${two(value.hour)}:${two(value.minute)}';
}
