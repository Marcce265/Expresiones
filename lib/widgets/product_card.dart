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

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.variant,
    this.imageAsset,
    this.compact = false,
    this.showCategory = false,
    this.showPrice = true,
  });

  final CatalogProduct product;
  final ProductVariant? variant;
  final String? imageAsset;
  final VoidCallback onTap;
  final bool compact;
  final bool showCategory;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final variantId = variant?.id;
    final status = product.stockStatusFor(variantId);
    final unavailable = !product.isActive || status == StockStatus.outOfStock;
    final title = variant?.name ?? product.name;
    final sku = variant?.sku ?? product.sku;
    final image =
        imageAsset ??
        variant?.previewImageUrl ??
        productFamilyHeroAsset(product) ??
        product.previewImageUrl;
    final price = product.unitPriceFor(1, variantId: variantId);
    final pricePrefix = product.startingAt ? 'Desde ' : '';
    final imageFit = productImageFit(product, variant: variant);

    return Semantics(
      button: true,
      enabled: !unavailable,
      label: [
        title,
        if (showPrice) _priceLabel(price),
        if (unavailable) 'Agotado',
      ].join(', '),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1.2,
        shadowColor: Colors.black.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFF0EDE8)),
        ),
        child: InkWell(
          onTap: unavailable ? null : onTap,
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
                        colorHex: variant?.colorHex,
                        categoryKey: _visualCategory(product.category),
                        fit: imageFit,
                        cropBottomFraction: productImageCropBottom(
                          product,
                          variant: variant,
                        ),
                        alignment: productImageAlignment(product),
                      ),
                    ),
                    if (unavailable)
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
                  compact ? 12 : 15,
                  compact ? 10 : 12,
                  compact ? 12 : 15,
                  compact ? 12 : 15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showCategory) ...[
                      Text(
                        (variant == null
                                ? product.attributes['catalogGroup'] ??
                                      product.category.label
                                : product.name)
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: compact ? 13 : 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sku == null
                          ? 'Por ${product.unitLabel}'
                          : 'Código $sku · por ${product.unitLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: compact ? 10 : 11),
                    ),
                    if (showPrice) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$pricePrefix${_priceLabel(price)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: compact ? 16 : 17),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
