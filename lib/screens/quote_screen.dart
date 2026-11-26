import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../models/coordination_details.dart';
import '../models/quote_line.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/product_visual.dart';
import '../widgets/quantity_input.dart';
import '../widgets/store_footer.dart';

typedef QuantityChanged = void Function(QuoteLine line, int quantity);

class QuoteScreen extends StatelessWidget {
  const QuoteScreen({
    super.key,
    required this.lines,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onContinue,
    required this.onBrowse,
    this.showOrderSummary = false,
    this.onBack,
    this.onSelectCategory,
    this.onOpenHelp,
    this.settings = const StorefrontSettings(),
  });

  final List<ResolvedQuoteLine> lines;
  final QuantityChanged onQuantityChanged;
  final ValueChanged<QuoteLine> onRemove;
  final VoidCallback onContinue;
  final VoidCallback onBrowse;
  final bool showOrderSummary;
  final VoidCallback? onBack;
  final ValueChanged<ProductCategory>? onSelectCategory;
  final VoidCallback? onOpenHelp;
  final StorefrontSettings settings;

  @override
  Widget build(BuildContext context) {
    final hasItems = lines.isNotEmpty;
    final footer = StoreFooter(
      settings: settings,
      onSelectCategory: onSelectCategory,
      onOpenHelp: onOpenHelp,
      whatsappNumber: settings.whatsappNumber,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ResponsivePage.storefront(
            top: 12,
            bottom: hasItems ? 40 : 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeading(itemCount: lines.length, onBack: onBack),
                const SizedBox(height: 16),
                if (!hasItems)
                  EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: settings.text(StorefrontText.quoteEmptyTitle),
                    message: settings.text(StorefrontText.quoteEmptyBody),
                    action: FilledButton.icon(
                      onPressed: onBrowse,
                      icon: const Icon(Icons.grid_view_rounded),
                      label: const Text('Explorar catálogo'),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final items = showOrderSummary
                          ? CheckoutOrderSummary(
                              lines: lines,
                              onQuantityChanged: onQuantityChanged,
                              onRemove: onRemove,
                            )
                          : _QuoteItemsSection(
                              lines: lines,
                              onQuantityChanged: onQuantityChanged,
                              onRemove: onRemove,
                            );
                      final nextStep = _QuoteNextStep(
                        onContinue: onContinue,
                        onBrowse: onBrowse,
                      );
                      if (constraints.maxWidth < 940) {
                        return Column(
                          children: [
                            items,
                            const SizedBox(height: 18),
                            nextStep,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: items),
                          const SizedBox(width: 28),
                          Expanded(flex: 3, child: nextStep),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final remaining =
                constraints.viewportMainAxisExtent -
                constraints.precedingScrollExtent;
            return SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: remaining.clamp(0.0, double.infinity),
                ),
                child: Align(alignment: Alignment.bottomCenter, child: footer),
              ),
            );
          },
        ),
      ],
    );
  }
}

class CheckoutOrderSummary extends StatelessWidget {
  const CheckoutOrderSummary({
    super.key,
    required this.lines,
    this.onQuantityChanged,
    this.onRemove,
    this.deliveryMethod,
  });

  final List<ResolvedQuoteLine> lines;
  final QuantityChanged? onQuantityChanged;
  final ValueChanged<QuoteLine>? onRemove;
  final DeliveryMethod? deliveryMethod;

  @override
  Widget build(BuildContext context) {
    final amounts = quoteAmounts(lines, deliveryMethod);
    final reviewing = deliveryMethod != null;
    final text = Theme.of(context).textTheme;
    Widget amount(String label, String value, {bool emphasized = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: (emphasized ? text.titleSmall : text.bodySmall)
                      ?.copyWith(fontSize: reviewing ? 12 : null),
                ),
              ),
              Text(
                value,
                style: emphasized
                    ? AppTheme.priceStyle(fontSize: reviewing ? 14 : 21)
                    : text.bodySmall,
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              reviewing ? 'Productos y subtotal' : 'Tu pedido',
              style: text.titleMedium?.copyWith(
                fontSize: reviewing ? 14 : null,
              ),
            ),
            const SizedBox(height: 4),
            for (final family in groupQuoteLines(lines)) ...[
              _OrderFamily(
                lines: family,
                onQuantityChanged: onQuantityChanged,
                onRemove: onRemove,
              ),
              const Divider(height: 1),
            ],
            const SizedBox(height: 8),
            amount(
              reviewing ? 'Subtotal de productos' : 'Subtotal',
              'S/ ${amounts.subtotal.toStringAsFixed(2)}',
              emphasized: !reviewing,
            ),
            if (reviewing) ...[
              if (deliveryMethod == DeliveryMethod.shalom)
                amount(
                  'Transporte y embalaje',
                  'S/ ${amounts.transportAndPacking.toStringAsFixed(2)}',
                )
              else
                amount('Entrega', 'Recojo gratis'),
              const Divider(height: 12),
              amount(
                'Total',
                'S/ ${amounts.total.toStringAsFixed(2)}',
                emphasized: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderFamily extends StatelessWidget {
  const _OrderFamily({
    required this.lines,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final List<ResolvedQuoteLine> lines;
  final QuantityChanged? onQuantityChanged;
  final ValueChanged<QuoteLine>? onRemove;

  @override
  Widget build(BuildContext context) {
    final first = lines.first;
    final grouped = lines.length > 1;
    final sharedPrice = grouped && sharesQuoteUnitPrice(lines);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped) ...[
          const SizedBox(height: 10),
          Text(
            first.product.name,
            style: text.titleSmall?.copyWith(
              fontSize: onQuantityChanged == null ? 12 : null,
            ),
          ),
          if (sharedPrice) Text(_unitPriceText(first), style: text.bodySmall),
          const SizedBox(height: 4),
        ],
        for (final item in lines)
          _QuoteLineCard(
            key: ValueKey(item.line.key),
            resolved: item,
            onQuantityChanged: onQuantityChanged,
            onRemove: onRemove,
            summary: true,
            summaryName: grouped
                ? item.variant?.name ?? 'Presentación estándar'
                : item.displayName,
            showUnitPrice: !sharedPrice,
          ),
      ],
    );
  }
}

String _unitPriceText(ResolvedQuoteLine line) {
  final unit = line.product.unitLabel.toLowerCase();
  final tier = line.appliedPriceTierLabel?.toLowerCase();
  final price = 'S/ ${line.unitPrice.toStringAsFixed(2)} por $unit';
  return tier == null ? price : '$price · $tier';
}

class _QuoteItemsSection extends StatelessWidget {
  const _QuoteItemsSection({
    required this.lines,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final List<ResolvedQuoteLine> lines;
  final QuantityChanged onQuantityChanged;
  final ValueChanged<QuoteLine> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Productos seleccionados',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Revisa cantidades, variantes y precios referenciales.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(),
            ),
            _LineList(
              lines: lines,
              onQuantityChanged: onQuantityChanged,
              onRemove: onRemove,
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
    return AppBreadcrumbBar(
      onBack: onBack ?? () => Navigator.maybePop(context),
      items: const [BreadcrumbItem(label: 'Carrito')],
      trailing: itemCount == 0
          ? null
          : Container(
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
            key: ValueKey(lines[index].line.key),
            resolved: lines[index],
            onQuantityChanged: onQuantityChanged,
            onRemove: onRemove,
          ),
          if (index != lines.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _QuoteLineCard extends StatelessWidget {
  const _QuoteLineCard({
    super.key,
    this.summary = false,
    this.summaryName,
    this.showUnitPrice = true,
    required this.resolved,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final bool summary;
  final String? summaryName;
  final bool showUnitPrice;
  final ResolvedQuoteLine resolved;
  final QuantityChanged? onQuantityChanged;
  final ValueChanged<QuoteLine>? onRemove;

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
      onRemove: () => onRemove?.call(line),
    );
    final quantityControl = _QuantityControl(
      compact: summary,
      value: line.quantity,
      canIncrease: canIncrease,
      onQuantityEntered: (value) {
        if (product.canRequest(value, variantId: line.variantId)) {
          onQuantityChanged?.call(line, value);
        }
      },
      onDecrease: () {
        if (line.quantity > 1) {
          onQuantityChanged?.call(line, line.quantity - 1);
        } else {
          onRemove?.call(line);
        }
      },
      onIncrease: canIncrease
          ? () => onQuantityChanged?.call(line, line.quantity + 1)
          : null,
    );

    Widget thumbnail(double size) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: size,
        child: ProductVisual(
          label: resolved.displayName,
          imageAsset: image,
          colorHex: variant?.colorHex,
          categoryKey: product.category.key,
          fit: productImageFit(product, variant: variant),
          cropBottomFraction: productImageCropBottom(product, variant: variant),
          alignment: productImageAlignment(product),
          decodeToLayout: true,
        ),
      ),
    );

    if (summary) {
      final text = Theme.of(context).textTheme;
      final readOnly = onQuantityChanged == null;
      final note = line.customization.trim();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            thumbnail(readOnly ? 40 : 52),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summaryName ?? resolved.displayName,
                    style: text.labelLarge?.copyWith(
                      fontSize: readOnly ? 12 : null,
                    ),
                  ),
                  if (showUnitPrice) ...[
                    const SizedBox(height: 3),
                    Text(_unitPriceText(resolved), style: text.bodySmall),
                  ],
                  if (note.isNotEmpty) Text(note, style: text.bodySmall),
                  const SizedBox(height: 4),
                  if (readOnly)
                    Text('Cantidad: ${line.quantity}', style: text.bodySmall)
                  else
                    quantityControl,
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/ ${resolved.total.toStringAsFixed(2)}',
                  style: AppTheme.priceStyle(fontSize: readOnly ? 12 : 17),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Quitar ${resolved.displayName}',
                    onPressed: () => onRemove?.call(line),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final priceAndQuantity = _PriceAndQuantity(
      resolved: resolved,
      quantityControl: quantityControl,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth < 500 ? 56.0 : 76.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                thumbnail(size),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [identity, priceAndQuantity],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resolved.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resolved.priceTierLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'S/ ${resolved.total.toStringAsFixed(2)}',
              style: AppTheme.priceStyle(fontSize: 17),
            ),
            if (resolved.line.quantity > 1)
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
    this.compact = false,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityEntered,
  });

  final int value;
  final bool compact;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;
  final ValueChanged<int> onQuantityEntered;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 84 : 126,
      child: QuantityInput(
        value: value,
        compact: compact,
        onChanged: onQuantityEntered,
        onDecrease: onDecrease,
        onIncrease: canIncrease ? onIncrease : null,
        backgroundColor: AppColors.canvas,
      ),
    );
  }
}

class _QuoteNextStep extends StatelessWidget {
  const _QuoteNextStep({required this.onContinue, required this.onBrowse});

  final VoidCallback onContinue;
  final VoidCallback onBrowse;

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
                  child: const Icon(Icons.arrow_forward_rounded, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Siguiente: datos para coordinar',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Elige cómo recibir tu cotización y la fecha que prefieres.',
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
            const _NextStepItem(
              icon: Icons.person_outline_rounded,
              text: 'Datos de contacto',
            ),
            const SizedBox(height: 12),
            const _NextStepItem(
              icon: Icons.local_shipping_outlined,
              text: 'Recojo o envío por Shalom',
            ),
            const SizedBox(height: 12),
            const _NextStepItem(
              icon: Icons.calendar_today_outlined,
              text: 'Fecha disponible',
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                child: const Text(
                  'Continuar con la cotización',
                  textAlign: TextAlign.center,
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

class _NextStepItem extends StatelessWidget {
  const _NextStepItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
