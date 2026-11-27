import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import 'product_visual.dart';

export '../models/catalog_models.dart' show CatalogTile;

typedef ProductSelected = void Function(
  CatalogProduct product,
  String? variantId,
);

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
    this.onAdd,
    this.variant,
    this.imageAsset,
    this.compact = false,
    this.showCategory = false,
    this.showPrice = true,
    this.showUnavailableOverlay = true,
    this.homePresentation = false,
    this.trailingIcon = Icons.arrow_forward_rounded,
  });

  final CatalogProduct product;
  final ProductVariant? variant;
  final String? imageAsset;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final bool compact;
  final bool showCategory;
  final bool showPrice;
  final bool showUnavailableOverlay;
  final bool homePresentation;
  final IconData trailingIcon;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  static const _actionSize = 39.0;
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
    final image =
        widget.imageAsset ??
        widget.variant?.previewImageUrl ??
        productFamilyCoverImage(widget.product);
    final price = widget.product.unitPriceFor(1, variantId: variantId);
    final pricePrefix = widget.product.startingAt ? 'Desde ' : '';
    final imageFit = productImageFit(widget.product, variant: widget.variant);
    final content = widget.product.attributes['contenido']?.trim();
    final detailLine = widget.homePresentation
        ? 'Por ${widget.product.unitLabel}${content == null || content.isEmpty ? '' : ' ($content)'}'
        : 'Por ${widget.product.unitLabel}';
    final cardRadius = widget.homePresentation ? 14.0 : 18.0;
    final actionButton = unavailable
        ? const SizedBox.square(dimension: _actionSize)
        : IconButton(
            onPressed: widget.onAdd ?? widget.onTap,
            tooltip: widget.onAdd == null
                ? 'Ver $title'
                : 'Añadir $title al carrito',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.pinkSoft,
              foregroundColor: AppColors.roseDeep,
              minimumSize: const Size.square(_actionSize),
              fixedSize: const Size.square(_actionSize),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: widget.onAdd == null
                ? Icon(
                    widget.trailingIcon,
                    size: 17,
                    color: AppColors.roseDeep,
                  )
                : const Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 17,
                    color: AppColors.roseDeep,
                  ),
          );

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
          scale: _hovered && !unavailable
              ? widget.homePresentation
                    ? 1.008
                    : 1.012
              : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: widget.homePresentation
                    ? _hovered
                          ? AppColors.pinkStrong.withValues(alpha: .45)
                          : AppColors.border
                    : _hovered
                    ? AppColors.border
                    : const Color(0xFFF0EDE8),
              ),
              boxShadow: widget.homePresentation
                  ? const <BoxShadow>[]
                  : [
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
                              decodeToLayout: true,
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
                        widget.homePresentation
                            ? 10
                            : widget.compact
                            ? 12
                            : 15,
                        widget.homePresentation
                            ? 9
                            : widget.compact
                            ? 10
                            : 12,
                        widget.homePresentation
                            ? 10
                            : widget.compact
                            ? 12
                            : 15,
                        widget.homePresentation
                            ? 9
                            : widget.compact
                            ? 12
                            : 15,
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
                          _buildTitleAndDetail(
                            context,
                            title,
                            detailLine,
                            trailing: !widget.showPrice && widget.onAdd != null
                                ? actionButton
                                : null,
                          ),
                          if (widget.showPrice) ...[
                            SizedBox(height: widget.homePresentation ? 7 : 5),
                            if (widget.homePresentation) ...[
                              const Divider(),
                              const SizedBox(height: 7),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$pricePrefix${_priceLabel(price)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.priceStyle(
                                      fontSize: widget.homePresentation
                                          ? 13.5
                                          : widget.compact
                                          ? 16
                                          : 17,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                actionButton,
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

  Widget _buildTitleAndDetail(
    BuildContext context,
    String title,
    String detail, {
    Widget? trailing,
  }) {
    final theme = Theme.of(context).textTheme;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.labelLarge?.copyWith(
            fontSize: widget.homePresentation
                ? 11.5
                : widget.compact
                ? 13
                : 14,
            height: 1.22,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.bodySmall?.copyWith(
            fontSize: widget.homePresentation
                ? 9
                : widget.compact
                ? 10
                : 11,
          ),
        ),
      ],
    );
    return trailing == null
        ? text
        : Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 8),
              trailing,
            ],
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
  ProductCategory.koreanPaper => 'materials',
  ProductCategory.crowns => 'materials',
};

String _priceLabel(double value) => 'S/ ${value.toStringAsFixed(2)}';
