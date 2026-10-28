import 'package:flutter/material.dart';

import '../models/coordination_details.dart';
import '../models/quote_line.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/quote_export_buttons.dart';
import '../widgets/shalom_embedded_map.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.lines,
    required this.details,
    required this.quoteId,
    required this.message,
    required this.onSendWhatsapp,
    required this.onCopyMessage,
    required this.onEditQuote,
    this.onContinueToPayment,
    this.settings = const StorefrontSettings(),
  });

  final List<ResolvedQuoteLine> lines;
  final CoordinationDetails details;
  final String quoteId;
  final String message;
  final Future<void> Function() onSendWhatsapp;
  final VoidCallback onCopyMessage;
  final VoidCallback onEditQuote;
  final VoidCallback? onContinueToPayment;
  final StorefrontSettings settings;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _sending = false;

  double get _subtotal =>
      widget.lines.fold(0, (sum, resolved) => sum + resolved.total);

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSendWhatsapp();
    } catch (_) {
      if (mounted) {
        _showNotice(
          'No pudimos abrir WhatsApp. Copia el mensaje e inténtalo nuevamente.',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _copy() {
    widget.onCopyMessage();
    _showNotice('Mensaje copiado.');
  }

  void _showNotice(
    String message, {
    AppNoticeTone tone = AppNoticeTone.success,
  }) {
    showAppNotice(context, message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1380,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onEditQuote,
                  tooltip: 'Volver a la cotización',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.settings.text(StorefrontText.reviewTitle),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(
                widget.settings.text(StorefrontText.reviewBody),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 18),
            const StepProgress(current: 3),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final overview = Column(
                  children: [
                    _RequestCard(lines: widget.lines, subtotal: _subtotal),
                    const SizedBox(height: 14),
                    _CoordinationCard(
                      details: widget.details,
                      settings: widget.settings,
                    ),
                  ],
                );
                final sendPanel = _SendPanel(
                  quoteId: widget.quoteId,
                  message: widget.message,
                  lines: widget.lines,
                  details: widget.details,
                  sending: _sending,
                  onSend: _send,
                  onCopy: _copy,
                  onEdit: widget.onEditQuote,
                  onContinueToPayment: widget.onContinueToPayment,
                  settings: widget.settings,
                );

                if (!wide) {
                  return Column(
                    children: [overview, const SizedBox(height: 18), sendPanel],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: overview),
                    const SizedBox(width: 28),
                    Expanded(flex: 5, child: sendPanel),
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.lines, required this.subtotal});

  final List<ResolvedQuoteLine> lines;
  final double subtotal;

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.pinkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Productos y subtotal',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${lines.length} ${lines.length == 1 ? 'producto seleccionado' : 'productos seleccionados'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            if (lines.isEmpty)
              Text(
                'No hay productos en la cotización.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (var index = 0; index < lines.length; index++) ...[
                _ReviewLine(resolved: lines[index]),
                if (index != lines.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
              ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subtotal de productos',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
                PriceText(subtotal),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Envío y disponibilidad por confirmar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.resolved});

  final ResolvedQuoteLine resolved;

  @override
  Widget build(BuildContext context) {
    final code = resolved.code;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${resolved.line.quantity}×',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resolved.displayName,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (code != null)
                Text(code, style: Theme.of(context).textTheme.bodySmall),
              if (resolved.line.customization.trim().isNotEmpty)
                Text(
                  resolved.line.customization.trim(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'S/ ${resolved.total.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _CoordinationCard extends StatelessWidget {
  const _CoordinationCard({required this.details, required this.settings});

  final CoordinationDetails details;
  final StorefrontSettings settings;

  @override
  Widget build(BuildContext context) {
    final desiredDate = details.desiredDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.pinkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_pin_circle_outlined, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.text(StorefrontText.reviewContactTitle),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        settings.text(StorefrontText.reviewContactBody),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            _DetailRow(icon: Icons.person_outline_rounded, label: details.name),
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.phone_outlined, label: details.phone),
            const SizedBox(height: 12),
            _DetailRow(
              icon: details.deliveryMethod == DeliveryMethod.pickup
                  ? Icons.storefront_outlined
                  : Icons.local_shipping_outlined,
              label: details.deliveryLabel,
            ),
            if (details.deliveryMethod == DeliveryMethod.shalom &&
                details.shalomAgencyId.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label:
                    '${details.shalomAgencyName} · ${details.shalomAgencyLocality}\n${details.shalomAgencyAddress}',
              ),
              if (details.shalomAgencyLatitude != null &&
                  details.shalomAgencyLongitude != null) ...[
                const SizedBox(height: 16),
                ShalomEmbeddedMap(
                  selectedAgencyId: details.shalomAgencyId,
                  selectedAgencyName: details.shalomAgencyName,
                  selectedAgencyLocality: details.shalomAgencyLocality,
                  latitude: details.shalomAgencyLatitude,
                  longitude: details.shalomAgencyLongitude,
                  showOtherAgencies: false,
                  height: 250,
                ),
              ],
            ],
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: desiredDate == null
                  ? 'Fecha deseada: por coordinar'
                  : 'Fecha deseada: ${_formatDate(desiredDate)}',
            ),
            for (final entry in details.customFields.entries)
              if (entry.value.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.assignment_outlined,
                  label: '${entry.key}: ${entry.value.trim()}',
                ),
              ],
            if (details.note.trim().isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(),
              ),
              Text('Nota', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 5),
              Text(details.note.trim()),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _SendPanel extends StatelessWidget {
  const _SendPanel({
    required this.quoteId,
    required this.message,
    required this.lines,
    required this.details,
    required this.sending,
    required this.onSend,
    required this.onCopy,
    required this.onEdit,
    this.onContinueToPayment,
    required this.settings,
  });

  final String quoteId;
  final String message;
  final List<ResolvedQuoteLine> lines;
  final CoordinationDetails details;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback? onContinueToPayment;
  final StorefrontSettings settings;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.text(StorefrontText.reviewMessageTitle),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        settings.text(StorefrontText.reviewMessageBody),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (quoteId.trim().isNotEmpty)
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
                      '#${quoteId.trim()}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 320),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (onContinueToPayment != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onContinueToPayment,
                  icon: const Icon(Icons.lock_outline_rounded, size: 19),
                  label: const Text('Continuar al pago de prueba'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: sending ? null : onSend,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.whatsapp,
                  side: const BorderSide(color: AppColors.whatsapp),
                ),
                icon: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.whatsapp,
                        ),
                      )
                    : const Icon(Icons.chat_outlined),
                label: Text(
                  sending
                      ? 'Abriendo WhatsApp…'
                      : 'Enviar por WhatsApp sin pagar',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                settings.text(StorefrontText.reviewPaymentNote),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            Text(
              'También puedes guardar o copiar la cotización',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar mensaje'),
              ),
            ),
            const SizedBox(height: 8),
            QuoteExportButtons(
              quoteId: quoteId,
              lines: lines,
              details: details,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar carrito'),
              ),
            ),
          ],
        ),
      ),
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
