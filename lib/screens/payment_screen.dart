import 'package:flutter/material.dart';

import '../models/coordination_details.dart';
import '../models/quote_line.dart';
import '../models/simulated_payment.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

typedef SimulatedPaymentProcessor = Future<SimulatedPayment> Function(
  SimulatedPaymentMethod method,
);
typedef SimulatedPaymentApproved = Future<void> Function(
  SimulatedPayment payment,
);

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.lines,
    required this.details,
    required this.onBack,
    required this.onProcessPayment,
    required this.onApproved,
    this.settings = const StorefrontSettings(),
  });

  final List<ResolvedQuoteLine> lines;
  final CoordinationDetails details;
  final VoidCallback onBack;
  final SimulatedPaymentProcessor onProcessPayment;
  final SimulatedPaymentApproved onApproved;
  final StorefrontSettings settings;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  SimulatedPaymentMethod _method = SimulatedPaymentMethod.demoCard;
  bool _processing = false;
  bool _rejected = false;

  double get _subtotal =>
      widget.lines.fold(0, (total, line) => total + line.total);

  Future<void> _submit() async {
    if (_processing || widget.lines.isEmpty || _subtotal <= 0) return;
    setState(() {
      _processing = true;
      _rejected = false;
    });
    try {
      final payment = await widget.onProcessPayment(_method);
      if (!payment.isApproved) {
        if (mounted) setState(() => _rejected = true);
        return;
      }
      await widget.onApproved(payment.withMethodLabel(_methodLabel));
    } catch (_) {
      if (mounted) setState(() => _rejected = true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _selectMethod(SimulatedPaymentMethod method) {
    if (_processing) return;
    setState(() {
      _method = method;
      _rejected = false;
    });
  }

  String get _methodLabel => widget.settings.text(
    _method == SimulatedPaymentMethod.demoCard
        ? StorefrontText.paymentCardMethod
        : StorefrontText.paymentYapeMethod,
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_processing,
      child: SingleChildScrollView(
        child: ResponsivePage(
          maxWidth: 1280,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeading(
                eyebrow: widget.settings.text(StorefrontText.paymentEyebrow),
                title: widget.settings.text(StorefrontText.paymentTitle),
                body: widget.settings.text(StorefrontText.paymentBody),
                onBack: _processing ? null : widget.onBack,
              ),
              const SizedBox(height: 20),
              _StepBadge(current: 4, total: 5, label: 'Pago'),
              const SizedBox(height: 18),
              InfoBanner(
                title: widget.settings.text(StorefrontText.paymentDemoBadge),
                message: widget.settings.text(StorefrontText.paymentDisclaimer),
                icon: Icons.science_outlined,
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final summary = _OrderSummary(
                    lines: widget.lines,
                    details: widget.details,
                    subtotal: _subtotal,
                    shippingPendingLabel: widget.settings.text(
                      StorefrontText.paymentShippingPending,
                    ),
                  );
                  final payment = _PaymentPanel(
                    selectedMethod: _method,
                    subtotal: _subtotal,
                    processing: _processing,
                    rejected: _rejected,
                    settings: widget.settings,
                    onSelect: _selectMethod,
                    onSubmit: _submit,
                  );

                  if (!wide) {
                    return Column(
                      children: [summary, const SizedBox(height: 18), payment],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: summary),
                      const SizedBox(width: 28),
                      Expanded(flex: 7, child: payment),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.onBack,
  });

  final String eyebrow;
  final String title;
  final String body;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Volver a la revisión',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 5),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.current,
    required this.total,
    required this.label,
  });

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso $current de $total: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          'PASO $current DE $total · ${label.toUpperCase()}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.lines,
    required this.details,
    required this.subtotal,
    required this.shippingPendingLabel,
  });

  final List<ResolvedQuoteLine> lines;
  final CoordinationDetails details;
  final double subtotal;
  final String shippingPendingLabel;

  @override
  Widget build(BuildContext context) {
    final quantity = lines.fold(
      0,
      (total, resolved) => total + resolved.line.quantity,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _RoundIcon(Icons.shopping_bag_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen del pedido',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '$quantity ${quantity == 1 ? 'unidad' : 'unidades'} en ${lines.length} ${lines.length == 1 ? 'producto' : 'productos'}',
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
                'Tu carrito está vacío.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (var index = 0; index < lines.length; index++) ...[
                _SummaryLine(line: lines[index]),
                if (index != lines.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 11),
                    child: Divider(),
                  ),
              ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            _AmountRow(label: 'Productos', value: subtotal),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    details.deliveryMethod == DeliveryMethod.shalom
                        ? 'Envío por Shalom'
                        : 'Recojo en Huancayo',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
                Text(
                  details.deliveryMethod == DeliveryMethod.shalom
                      ? shippingPendingLabel
                      : 'Sin costo de envío',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            _AmountRow(
              label: 'Total simulado',
              value: subtotal,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.line});

  final ResolvedQuoteLine line;

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
            '${line.line.quantity}×',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.displayName,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (line.code != null)
                Text(line.code!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'S/ ${line.total.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
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

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({
    required this.selectedMethod,
    required this.subtotal,
    required this.processing,
    required this.rejected,
    required this.settings,
    required this.onSelect,
    required this.onSubmit,
  });

  final SimulatedPaymentMethod selectedMethod;
  final double subtotal;
  final bool processing;
  final bool rejected;
  final StorefrontSettings settings;
  final ValueChanged<SimulatedPaymentMethod> onSelect;
  final VoidCallback onSubmit;

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
                const _RoundIcon(Icons.lock_outline_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elige cómo simular el pago',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'No solicitaremos datos financieros.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _MethodTile(
              icon: Icons.credit_card_rounded,
              title: settings.text(StorefrontText.paymentCardMethod),
              description: settings.text(StorefrontText.paymentCardDescription),
              selected: selectedMethod == SimulatedPaymentMethod.demoCard,
              enabled: !processing,
              onTap: () => onSelect(SimulatedPaymentMethod.demoCard),
            ),
            const SizedBox(height: 12),
            _MethodTile(
              icon: Icons.phone_android_rounded,
              title: settings.text(StorefrontText.paymentYapeMethod),
              description: settings.text(StorefrontText.paymentYapeDescription),
              selected: selectedMethod == SimulatedPaymentMethod.demoYape,
              enabled: !processing,
              onTap: () => onSelect(SimulatedPaymentMethod.demoYape),
            ),
            if (rejected) ...[
              const SizedBox(height: 16),
              _RejectedMessage(settings: settings, onRetry: onSubmit),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: processing || subtotal <= 0 ? null : onSubmit,
                icon: processing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  processing
                      ? settings.text(StorefrontText.paymentProcessing)
                      : '${settings.text(StorefrontText.paymentSubmitButton)} · S/ ${subtotal.toStringAsFixed(2)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.text(StorefrontText.paymentDisclaimer),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$title. $description',
      child: Material(
        color: selected ? AppColors.pinkSoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.ink : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.ink : AppColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RejectedMessage extends StatelessWidget {
  const _RejectedMessage({required this.settings, required this.onRetry});

  final StorefrontSettings settings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .07),
        border: Border.all(color: AppColors.error.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.text(StorefrontText.paymentRejectedTitle),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 4),
                Text(
                  settings.text(StorefrontText.paymentRejectedBody),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 5),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: Text(settings.text(StorefrontText.paymentRetryButton)),
                ),
              ],
            ),
          ),
        ],
      ),
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
