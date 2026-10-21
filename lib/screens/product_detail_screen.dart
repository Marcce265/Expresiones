import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_visual.dart';
import '../widgets/quantity_input.dart';

typedef AddProductCallback = void Function({
  required int quantity,
  String? variantId,
  required String customization,
});

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.onAdd,
    this.initialVariantId,
  });

  final CatalogProduct product;
  final String? initialVariantId;
  final AddProductCallback onAdd;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late String? _variantId =
      widget.initialVariantId ??
      (widget.product.variants.isEmpty
          ? null
          : widget.product.variants.first.id);
  int _quantity = 1;

  CatalogProduct get product => widget.product;
  ProductVariant? get variant => product.variantById(_variantId);
  double get unitPrice =>
      product.unitPriceFor(_quantity, variantId: _variantId);
  List<PriceTier> get tiers => variant != null && variant!.priceTiers.isNotEmpty
      ? variant!.priceTiers
      : product.priceTiers;

  @override
  Widget build(BuildContext context) {
    final image =
        variant?.imageUrl ??
        variant?.thumbnailUrl ??
        product.imageUrl ??
        product.thumbnailUrl;
    final title = variant?.name ?? product.name;
    final sku = variant?.sku ?? product.sku;
    final total = product.totalFor(_quantity, variantId: _variantId);
    final canAdd = product.canRequest(_quantity, variantId: _variantId);
    final imageFit = productImageFit(product, variant: variant);

    return Column(
      children: [
        ResponsivePage(
          maxWidth: 1180,
          padding: const EdgeInsets.fromLTRB(14, 12, 20, 4),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                IconButton.outlined(
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Eyebrow('Detalle del producto')),
                if (constraints.maxWidth >= 600)
                  TextButton.icon(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                    label: const Text('Volver al catálogo'),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: ResponsivePage(
              maxWidth: 1180,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mobile = constraints.maxWidth < 760;
                  final squareVisual = product.id == 'limpiapipas-premium-8mm';
                  final visual = Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: ProductVisual(
                      label: title,
                      imageAsset: image,
                      colorHex: variant?.colorHex,
                      categoryKey: product.category.key,
                      fit: imageFit,
                      cropBottomFraction: productImageCropBottom(
                        product,
                        variant: variant,
                      ),
                      alignment: productImageAlignment(product),
                    ),
                  );
                  final information = Container(
                    padding: EdgeInsets.all(mobile ? 20 : 28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _ProductInformation(
                      product: product,
                      variant: variant,
                      title: title,
                      sku: sku,
                      quantity: _quantity,
                      unitPrice: unitPrice,
                      tiers: tiers,
                      variantId: _variantId,
                      onVariant: (id) => setState(() {
                        _variantId = id;
                        _quantity = 1;
                      }),
                      onDecrease: _quantity == 1
                          ? null
                          : () => setState(() => _quantity--),
                      onQuantityEntered: (value) {
                        if (product.canRequest(value, variantId: _variantId)) {
                          setState(() => _quantity = value);
                        }
                      },
                      onIncrease:
                          product.canRequest(
                            _quantity + 1,
                            variantId: _variantId,
                          )
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                  );

                  if (mobile) {
                    return Column(
                      children: [
                        AspectRatio(
                          aspectRatio: squareVisual ? 1 : 1.18,
                          child: visual,
                        ),
                        const SizedBox(height: 20),
                        information,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: squareVisual
                            ? AspectRatio(aspectRatio: 1, child: visual)
                            : SizedBox(height: 560, child: visual),
                      ),
                      const SizedBox(width: 32),
                      Expanded(flex: 5, child: information),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: ResponsivePage(
            maxWidth: 1180,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: constraints.maxWidth >= 760
                    ? Alignment.centerRight
                    : Alignment.center,
                child: SizedBox(
                  width: constraints.maxWidth >= 760 ? 480 : double.infinity,
                  child: FilledButton.icon(
                    onPressed: canAdd
                        ? () => widget.onAdd(
                            quantity: _quantity,
                            variantId: _variantId,
                            customization: '',
                          )
                        : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
                    label: Text(
                      canAdd
                          ? 'Agregar a mi cotización · S/ ${total.toStringAsFixed(2)}'
                          : 'No disponible por ahora',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductInformation extends StatelessWidget {
  const _ProductInformation({
    required this.product,
    required this.variant,
    required this.title,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.tiers,
    required this.variantId,
    required this.onVariant,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityEntered,
  });

  final CatalogProduct product;
  final ProductVariant? variant;
  final String title;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final List<PriceTier> tiers;
  final String? variantId;
  final ValueChanged<String> onVariant;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final ValueChanged<int> onQuantityEntered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('${product.category.label} · ${product.name}'),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(16) >= 21;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 5),
                  PriceText(
                    unitPrice,
                    prefix: product.startingAt ? 'Desde' : '',
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(width: 12),
                PriceText(unitPrice, prefix: product.startingAt ? 'Desde' : ''),
              ],
            );
          },
        ),
        const SizedBox(height: 5),
        Text(
          [if (sku != null) 'Código $sku', product.description].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _AvailabilityPill(
          status: product.stockStatusFor(variantId),
          stock: variant?.stock ?? product.stock,
          unitLabel: product.unitLabel,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final quantityPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Cantidad'),
                const SizedBox(height: 8),
                _QuantitySelector(
                  value: quantity,
                  onDecrease: onDecrease,
                  onIncrease: onIncrease,
                  onQuantityEntered: onQuantityEntered,
                ),
              ],
            );
            final pricePanel = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Precio'),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Por ${product.unitLabel} · S/ ${unitPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            );
            final stacked =
                constraints.maxWidth < 390 ||
                MediaQuery.textScalerOf(context).scale(16) >= 21;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  quantityPanel,
                  const SizedBox(height: 14),
                  pricePanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: quantityPanel),
                const SizedBox(width: 12),
                Expanded(child: pricePanel),
              ],
            );
          },
        ),
        if (tiers.isNotEmpty) ...[
          const SizedBox(height: 16),
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
                  'Ahorra comprando más',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  tiers
                      .map(
                        (tier) =>
                            '${tier.minQuantity} ${product.unitLabel}${product.unitLabel == 'unidad' ? 'es' : 's'}: '
                            'S/ ${tier.unitPrice.toStringAsFixed(2)} por ${product.unitLabel}',
                      )
                      .join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
        if (product.variants.length > 1) ...[
          const SizedBox(height: 17),
          Text(
            'Otros colores y modelos',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final options = [
                for (final option in product.variants.where(
                  (item) => item.isActive,
                ))
                  ChoiceChip(
                    avatar: option.colorHex == null
                        ? null
                        : CircleAvatar(
                            backgroundColor: _color(option.colorHex!),
                          ),
                    label: Text(option.name),
                    selected: variantId == option.id,
                    onSelected: (_) => onVariant(option.id),
                  ),
              ];
              if (constraints.maxWidth >= 520) {
                return Wrap(spacing: 8, runSpacing: 8, children: options);
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    for (var index = 0; index < options.length; index++) ...[
                      options[index],
                      if (index != options.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
        if (product.priceIsEstimate) ...[
          const SizedBox(height: 16),
          const InfoBanner(
            title: 'Precio referencial',
            message: 'Expresiones confirmará el acabado y la disponibilidad por WhatsApp.',
          ),
        ],
      ],
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityEntered,
  });

  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final ValueChanged<int> onQuantityEntered;

  @override
  Widget build(BuildContext context) {
    return QuantityInput(
      value: value,
      onChanged: onQuantityEntered,
      onDecrease: onDecrease,
      onIncrease: onIncrease,
      backgroundColor: AppColors.surface,
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({
    required this.status,
    required this.stock,
    required this.unitLabel,
  });

  final StockStatus status;
  final int? stock;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final units = stock == 1
        ? unitLabel
        : unitLabel == 'unidad'
        ? 'unidades'
        : '${unitLabel}s';
    final label = stock != null && status != StockStatus.outOfStock
        ? '${status.label} · $stock $units'
        : status.label;
    final emphasized = status == StockStatus.lowStock;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? AppColors.pinkSoft : AppColors.canvas,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == StockStatus.outOfStock
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
              size: 16,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _color(String value) {
  final normalized = value.replaceAll('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null
      ? AppColors.border
      : Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
}
