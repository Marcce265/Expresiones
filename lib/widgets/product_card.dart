import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import 'product_visual.dart';

typedef ProductSelected = void Function(
  CatalogProduct product,
  String? variantId,
);

typedef CatalogTile = ({CatalogProduct product, ProductVariant? variant});

List<CatalogTile> expandCatalogTiles(Iterable<CatalogProduct> products) {
  return [
    for (final product in products)
      if (product.variants.where((variant) => variant.isActive).isEmpty)
        (product: product, variant: null)
      else
        for (final variant in product.variants.where(
          (variant) => variant.isActive,
        ))
          (product: product, variant: variant),
  ];
}

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.variant,
    this.imageAsset,
    this.compact = false,
    this.showCategory = false,
    this.showPrice = true,
    this.showUnavailableOverlay = true,
  });

  final CatalogProduct product;
  final ProductVariant? variant;
  final String? imageAsset;
  final VoidCallback onTap;
  final bool compact;
  final bool showCategory;
  final bool showPrice;
  final bool showUnavailableOverlay;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final variantId = widget.variant?.id;
    final status = widget.product.stockStatusFor(variantId);
    final unavailable =
        !widget.product.isActive || status == StockStatus.outOfStock;
    final title = widget.variant == null
        ? widget.product.name
        : variantDisplayName(widget.variant!);
    final hideInternalPaletteCode =
        widget.variant?.attributes.containsKey('paletteNumber') ?? false;
    final sku = hideInternalPaletteCode
        ? null
        : widget.variant?.sku ?? widget.product.sku;
    final image =
        widget.imageAsset ??
        widget.variant?.previewImageUrl ??
        productFamilyCoverImage(widget.product);
    final price = widget.product.unitPriceFor(1, variantId: variantId);
    final pricePrefix = widget.product.startingAt ? 'Desde ' : '';
    final imageFit = productImageFit(widget.product, variant: widget.variant);

    return Semantics(
      button: true,
      enabled: !unavailable,
      label: [
        title,
        if (widget.showPrice) _priceLabel(price),
        if (unavailable) 'Agotado',
      ].join(', '),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered && !unavailable ? 1.012 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hovered ? AppColors.border : const Color(0xFFF0EDE8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _hovered && !unavailable ? .11 : .055,
                  ),
                  blurRadius: _hovered ? 22 : 12,
                  offset: Offset(0, _hovered ? 9 : 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: unavailable ? null : widget.onTap,
                overlayColor: WidgetStatePropertyAll(
                  AppColors.ink.withValues(alpha: .045),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: Colors.white,
                            child: ProductVisual(
                              label: title,
                              imageAsset: image,
                              colorHex: widget.variant?.colorHex,
                              categoryKey: _visualCategory(
                                widget.product.category,
                              ),
                              fit: imageFit,
                              cropBottomFraction: productImageCropBottom(
                                widget.product,
                                variant: widget.variant,
                              ),
                              alignment: productImageAlignment(widget.product),
                            ),
                          ),
                          if (unavailable && widget.showUnavailableOverlay)
                            Positioned.fill(
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: .78),
                                child: const Center(child: _UnavailableBadge()),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.compact ? 12 : 15,
                        widget.compact ? 10 : 12,
                        widget.compact ? 12 : 15,
                        widget.compact ? 12 : 15,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.showCategory) ...[
                            Text(
                              (widget.variant == null
                                      ? widget
                                                .product
                                                .attributes['catalogGroup'] ??
                                            widget.product.category.label
                                      : widget.product.name)
                                  .toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: AppColors.muted,
                                    fontSize: 9,
                                    letterSpacing: .75,
                                  ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontSize: widget.compact ? 13 : 14,
                                  height: 1.22,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sku == null
                                ? 'Por ${widget.product.unitLabel}'
                                : 'Código $sku · por ${widget.product.unitLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: widget.compact ? 10 : 11),
                          ),
                          if (widget.showPrice) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$pricePrefix${_priceLabel(price)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontSize: widget.compact ? 16 : 17,
                                        ),
                                  ),
                                ),
                                if (!widget.compact) ...[
                                  const SizedBox(width: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _hovered
                                          ? AppColors.ink
                                          : AppColors.canvas,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15,
                                      color: _hovered
                                          ? Colors.white
                                          : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableBadge extends StatelessWidget {
  const _UnavailableBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text('Agotado'),
      ),
    );
  }
}

String _visualCategory(ProductCategory category) => switch (category) {
  ProductCategory.bouquets => 'bouquets',
  ProductCategory.personalizedGifts => 'gifts',
  ProductCategory.materials => 'materials',
};

String _priceLabel(double value) => 'S/ ${value.toStringAsFixed(2)}';
