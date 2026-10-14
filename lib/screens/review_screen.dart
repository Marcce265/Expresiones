import 'package:flutter/material.dart';

import '../models/coordination_details.dart';
import '../models/quote_line.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

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
  });

  final List<ResolvedQuoteLine> lines;
  final CoordinationDetails details;
  final String quoteId;
  final String message;
  final Future<void> Function() onSendWhatsapp;
  final VoidCallback onCopyMessage;
  final VoidCallback onEditQuote;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos abrir WhatsApp. Copia el mensaje e inténtalo nuevamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _copy() {
    widget.onCopyMessage();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Mensaje copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1040,
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
                    'Revisa antes de enviar',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const StepProgress(current: 3),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 780;
                final overview = Column(
                  children: [
                    _RequestCard(lines: widget.lines, subtotal: _subtotal),
                    const SizedBox(height: 14),
                    _CoordinationCard(details: widget.details),
                  ],
                );
                final sendPanel = _SendPanel(
                  quoteId: widget.quoteId,
                  message: widget.message,
                  sending: _sending,
                  onSend: _send,
                  onCopy: _copy,
                  onEdit: widget.onEditQuote,
                );

                if (!wide) {
                  return Column(
                    children: [overview, const SizedBox(height: 18), sendPanel],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: overview),
                    const SizedBox(width: 22),
                    Expanded(flex: 4, child: sendPanel),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Tu solicitud'),
            const SizedBox(height: 16),
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
                    'Subtotal referencial',
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
  const _CoordinationCard({required this.details});

  final CoordinationDetails details;

  @override
  Widget build(BuildContext context) {
    final desiredDate = details.desiredDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Coordinación'),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: desiredDate == null
                  ? 'Fecha deseada: por coordinar'
                  : 'Fecha deseada: ${_formatDate(desiredDate)}',
            ),
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
    required this.sending,
    required this.onSend,
    required this.onCopy,
    required this.onEdit,
  });

  final String quoteId;
  final String message;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onCopy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('Así llegará a WhatsApp')),
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copiar mensaje'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sending ? null : onSend,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                  foregroundColor: Colors.white,
                ),
                icon: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.chat_outlined),
                label: Text(
                  sending
                      ? 'Abriendo WhatsApp…'
                      : 'Enviar cotización por WhatsApp',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'No se realiza ningún pago dentro de la aplicación.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEdit,
                child: const Text('Editar cotización'),
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
