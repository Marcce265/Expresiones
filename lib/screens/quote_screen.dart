import 'package:flutter/material.dart';

import '../models/quote_line.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_visual.dart';
import '../widgets/quantity_input.dart';

typedef QuantityChanged = void Function(QuoteLine line, int quantity);

class QuoteScreen extends StatelessWidget {
  const QuoteScreen({
    super.key,
    required this.lines,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onContinue,
    required this.onBrowse,
    this.onBack,
  });

  final List<ResolvedQuoteLine> lines;
  final QuantityChanged onQuantityChanged;
  final ValueChanged<QuoteLine> onRemove;
  final VoidCallback onContinue;
  final VoidCallback onBrowse;
  final VoidCallback? onBack;

  double get subtotal => lines.fold(0, (sum, item) => sum + item.total);

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return SingleChildScrollView(
        child: ResponsivePage(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeading(itemCount: 0, onBack: onBack),
              EmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'Tu cotización está vacía',
                message: 'Explora el catálogo y agrega los materiales que quieras consultar.',
                action: FilledButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Explorar catálogo'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1040,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(itemCount: lines.length, onBack: onBack),
            const SizedBox(height: 18),
            const StepProgress(current: 1),
            const SizedBox(height: 22),
            const InfoBanner(
              title: 'Aún no es un pedido',
              message: 'Expresiones confirmará disponibilidad, precio final, fecha y envío por WhatsApp.',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 780;
                final items = _LineList(
                  lines: lines,
                  onQuantityChanged: onQuantityChanged,
                  onRemove: onRemove,
                );
                final summary = _QuoteSummary(
                  subtotal: subtotal,
                  onContinue: onContinue,
                  onBrowse: onBrowse,
                );

                if (!wide) {
                  return Column(
                    children: [items, const SizedBox(height: 22), summary],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: items),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: summary),
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

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.itemCount, this.onBack});

  final int itemCount;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack ?? () => Navigator.maybePop(context),
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Mi cotización',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '$itemCount ${itemCount == 1 ? 'producto' : 'productos'}',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _LineList extends StatelessWidget {
  const _LineList({
    required this.lines,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final List<ResolvedQuoteLine> lines;
  final QuantityChanged onQuantityChanged;
  final ValueChanged<QuoteLine> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          _QuoteLineCard(
            resolved: lines[index],
            onQuantityChanged: onQuantityChanged,
            onRemove: onRemove,
          ),
          if (index != lines.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuoteLineCard extends StatelessWidget {
  const _QuoteLineCard({
    required this.resolved,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final ResolvedQuoteLine resolved;
  final QuantityChanged onQuantityChanged;
  final ValueChanged<QuoteLine> onRemove;

  @override
  Widget build(BuildContext context) {
    final line = resolved.line;
    final product = resolved.product;
    final variant = resolved.variant;
    final canIncrease = product.canRequest(
      line.quantity + 1,
      variantId: line.variantId,
    );
    final image = variant?.previewImageUrl ?? product.previewImageUrl;

    final identity = _QuoteLineIdentity(
      resolved: resolved,
      onRemove: () => onRemove(line),
    );
    final priceAndQuantity = _PriceAndQuantity(
      resolved: resolved,
      quantityControl: _QuantityControl(
        value: line.quantity,
        canIncrease: canIncrease,
        onQuantityEntered: (value) {
          if (product.canRequest(value, variantId: line.variantId)) {
            onQuantityChanged(line, value);
          }
        },
        onDecrease: () {
          if (line.quantity > 1) {
            onQuantityChanged(line, line.quantity - 1);
          } else {
            onRemove(line);
          }
        },
        onIncrease: canIncrease
            ? () => onQuantityChanged(line, line.quantity + 1)
            : null,
      ),
    );

    Widget visual({required double width, required double height}) => ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: ProductVisual(
          label: resolved.displayName,
          imageAsset: image,
          colorHex: variant?.colorHex,
          categoryKey: product.category.key,
          fit: productImageFit(product, variant: variant),
          cropBottomFraction: productImageCropBottom(product, variant: variant),
          alignment: productImageAlignment(product),
        ),
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      visual(width: 82, height: 88),
                      const SizedBox(width: 14),
                      Expanded(child: identity),
                    ],
                  ),
                  const SizedBox(height: 16),
                  priceAndQuantity,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                visual(width: 104, height: 116),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 16),
                      priceAndQuantity,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuoteLineIdentity extends StatelessWidget {
  const _QuoteLineIdentity({required this.resolved, required this.onRemove});

  final ResolvedQuoteLine resolved;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final customization = resolved.line.customization.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                resolved.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Quitar ${resolved.displayName}',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
        if (resolved.code case final code?)
          Text(
            'Código $code · ${resolved.priceTierLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Text(
            resolved.priceTierLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (customization.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            customization,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.ink),
          ),
        ],
      ],
    );
  }
}

class _PriceAndQuantity extends StatelessWidget {
  const _PriceAndQuantity({
    required this.resolved,
    required this.quantityControl,
  });

  final ResolvedQuoteLine resolved;
  final Widget quantityControl;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'S/ ${resolved.total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'S/ ${resolved.unitPrice.toStringAsFixed(2)} por ${resolved.product.unitLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        quantityControl,
      ],
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.value,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityEntered,
  });

  final int value;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;
  final ValueChanged<int> onQuantityEntered;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: QuantityInput(
        value: value,
        onChanged: onQuantityEntered,
        onDecrease: onDecrease,
        onIncrease: canIncrease ? onIncrease : null,
        backgroundColor: AppColors.canvas,
      ),
    );
  }
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({
    required this.subtotal,
    required this.onContinue,
    required this.onBrowse,
  });

  final double subtotal;
  final VoidCallback onContinue;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Resumen'),
            const SizedBox(height: 18),
            _SummaryRow(
              label: 'Productos',
              value: 'S/ ${subtotal.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            const _SummaryRow(label: 'Envío', value: 'Por confirmar'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Subtotal de productos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                PriceText(subtotal),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Los precios pueden variar según disponibilidad y personalización.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continuar con mis datos'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onBrowse,
                child: const Text('Agregar más productos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
