import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../models/catalog_models.dart';
import '../models/coordination_details.dart';
import '../models/quote_line.dart';
import '../models/storefront_settings.dart';
import '../services/quote_pdf_share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/quote_export_buttons.dart';
import '../widgets/shalom_embedded_map.dart';
import '../widgets/store_footer.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.lines,
    required this.details,
    required this.quoteId,
    required this.message,
    this.onSharePdf,
    this.onSendWhatsapp,
    required this.onCopyMessage,
    required this.onEditQuote,
    this.onContinueToPayment,
    this.onSelectCategory,
    this.onOpenHelp,
    this.settings = const StorefrontSettings(),
  });

  final List<ResolvedQuoteLine> lines;
  final CoordinationDetails details;
  final String quoteId;
  final String message;
  final Future<QuotePdfShareOutcome> Function(Rect sharePositionOrigin)?
  onSharePdf;
  final Future<void> Function()? onSendWhatsapp;
  final VoidCallback onCopyMessage;
  final VoidCallback onEditQuote;
  final VoidCallback? onContinueToPayment;
  final ValueChanged<ProductCategory>? onSelectCategory;
  final VoidCallback? onOpenHelp;
  final StorefrontSettings settings;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _sharing = false;
  bool _sending = false;

  double get _subtotal =>
      widget.lines.fold(0, (sum, resolved) => sum + resolved.total);

  Future<void> _send() async {
    final send = widget.onSendWhatsapp;
    if (_sending || send == null) return;
    setState(() => _sending = true);
    try {
      await send();
    } catch (_) {
      if (mounted) {
        _showNotice(
          'No pudimos abrir WhatsApp. Puedes compartir o guardar el PDF.',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sharePdf(BuildContext buttonContext) async {
    final share = widget.onSharePdf;
    if (_sharing || share == null) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? Rect.zero
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      final outcome = await share(origin);
      if (!mounted || outcome == QuotePdfShareOutcome.dismissed) return;
      _showNotice(
        outcome == QuotePdfShareOutcome.shared
            ? 'Cotización PDF compartida.'
            : 'Tu navegador descargó la cotización PDF.',
      );
    } catch (_) {
      if (mounted) {
        _showNotice(
          'No pudimos compartir el PDF. Usa Guardar PDF e inténtalo nuevamente.',
          tone: AppNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
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
      child: Column(
        children: [
          ResponsivePage.storefront(
            bottom: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBreadcrumbBar(
                  onBack: () => Navigator.maybePop(context),
                  items: [
                    BreadcrumbItem(label: 'Carrito', onTap: widget.onEditQuote),
                    BreadcrumbItem(
                      label: 'Datos',
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const BreadcrumbItem(label: 'Revisión'),
                  ],
                ),
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
                      sharing: _sharing,
                      sending: _sending,
                      onSharePdf: widget.onSharePdf == null ? null : _sharePdf,
                      onSend: widget.onSendWhatsapp == null ? null : _send,
                      onCopy: _copy,
                      onEdit: widget.onEditQuote,
                      onContinueToPayment: widget.onContinueToPayment,
                      settings: widget.settings,
                    );

                    if (!wide) {
                      return Column(
                        children: [
                          overview,
                          const SizedBox(height: 18),
                          sendPanel,
                        ],
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
          StoreFooter(
            settings: widget.settings,
            onSelectCategory: widget.onSelectCategory,
            onOpenQuote: widget.onEditQuote,
            onOpenHelp: widget.onOpenHelp,
            whatsappNumber: widget.settings.whatsappNumber,
          ),
        ],
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
          style: AppTheme.priceStyle(fontSize: 15.5),
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
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Nombres y apellidos: ${details.name}',
            ),
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
              const SizedBox(height: 12),
              const _DetailRow(
                icon: Icons.payments_outlined,
                label:
                    'Envío desde S/ 5.00. El monto final depende del tamaño '
                    'y peso del pedido y se confirma por WhatsApp.',
              ),
            ],
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: desiredDate == null
                  ? 'Fecha deseada: no registrada'
                  : 'Fecha deseada: ${_formatDate(desiredDate)}',
            ),
            for (final entry in details.customFields.entries)
              if (entry.value.trim().isNotEmpty &&
                  !isLegacyNameCustomField(entry.key)) ...[
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
    required this.sharing,
    required this.sending,
    required this.onSharePdf,
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
  final bool sharing;
  final bool sending;
  final Future<void> Function(BuildContext buttonContext)? onSharePdf;
  final VoidCallback? onSend;
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
                        FeatureFlags.customerAccounts
                            ? settings.text(StorefrontText.reviewMessageBody)
                            : 'Detalle listo para guardar, copiar o exportar',
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
                  label: const Text('Continuar al pago simulado'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (onSharePdf != null)
              Builder(
                builder: (buttonContext) => SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: sharing || sending
                        ? null
                        : () => onSharePdf!(buttonContext),
                    icon: sharing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(
                      sharing ? 'Preparando PDF…' : 'Compartir cotización PDF',
                    ),
                  ),
                ),
              ),
            if (onSharePdf != null && onSend != null)
              const SizedBox(height: 10),
            if (onSend != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: sharing || sending ? null : onSend,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Enviar mensaje por WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.whatsapp,
                  ),
                ),
              ),
            if (onContinueToPayment != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  settings.text(StorefrontText.reviewPaymentNote),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
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
