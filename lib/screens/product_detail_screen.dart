import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_visual.dart';
import '../widgets/quantity_input.dart';
import '../widgets/store_footer.dart';

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
    this.onHelp,
    this.relatedProducts = const [],
    this.onSelectRelated,
    this.onNavigateCategory,
    this.onNavigateHome,
    this.onBuyNow,
    this.settings,
  });

  final CatalogProduct product;
  final String? initialVariantId;
  final AddProductCallback onAdd;
  final VoidCallback? onHelp;
  final List<CatalogProduct> relatedProducts;
  final ValueChanged<CatalogProduct>? onSelectRelated;
  final ValueChanged<ProductCategory>? onNavigateCategory;
  final VoidCallback? onNavigateHome;
  final AddProductCallback? onBuyNow;
  final StorefrontSettings? settings;

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
  bool _isFavorite = false;

  CatalogProduct get product => widget.product;
  ProductVariant? get variant => product.variantById(_variantId);
  double get unitPrice =>
      product.unitPriceFor(_quantity, variantId: _variantId);
  List<PriceTier> get tiers => variant != null && variant!.priceTiers.isNotEmpty
      ? variant!.priceTiers
      : product.priceTiers;

  void _handleAdd() {
    widget.onAdd(
      quantity: _quantity,
      variantId: _variantId,
      customization: '',
    );
  }

  void _handleBuyNow() {
    if (widget.onBuyNow != null) {
      widget.onBuyNow!(
        quantity: _quantity,
        variantId: _variantId,
        customization: '',
      );
    } else {
      _handleAdd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final image =
        variant?.imageUrl ??
        variant?.thumbnailUrl ??
        product.imageUrl ??
        product.thumbnailUrl;
    final title = variant == null ? product.name : variantDisplayName(variant!);
    final hideInternalPaletteCode =
        variant?.attributes.containsKey('paletteNumber') ?? false;
    final sku = hideInternalPaletteCode ? null : variant?.sku ?? product.sku;
    final total = product.totalFor(_quantity, variantId: _variantId);
    final canAdd = product.canRequest(_quantity, variantId: _variantId);
    final imageFit = productImageFit(product, variant: variant);
    final activeVariants = product.variants
        .where((item) => item.isActive)
        .toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs y barra superior
          ResponsivePage(
            maxWidth: 1200,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                IconButton.outlined(
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: widget.onNavigateHome ??
                              () => Navigator.maybePop(context),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Inicio',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        InkWell(
                          onTap: () {
                            if (widget.onNavigateCategory != null) {
                              widget.onNavigateCategory!(product.category);
                            } else {
                              Navigator.maybePop(context);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              product.category.label,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.onHelp != null) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: widget.onHelp,
                    tooltip: '¿Necesitas ayuda?',
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                  ),
                ],
              ],
            ),
          ),

          // Sección Principal (Foto a la izquierda + Buy Box a la derecha estilo Rosatel)
          ResponsivePage(
            maxWidth: 1200,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 760;
                final squareVisual = product.id == 'limpiapipas-premium-8mm';

                final visualWidget = Container(
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
                    filterQuality: FilterQuality.medium,
                    cropBottomFraction: productImageCropBottom(
                      product,
                      variant: variant,
                    ),
                    alignment: productImageAlignment(product),
                  ),
                );

                final imageColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (mobile)
                      AspectRatio(
                        aspectRatio: squareVisual ? 1 : 1.18,
                        child: visualWidget,
                      )
                    else if (squareVisual)
                      AspectRatio(aspectRatio: 1, child: visualWidget)
                    else
                      SizedBox(height: 520, child: visualWidget),
                    if (activeVariants.length > 1) ...[
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final option in activeVariants) ...[
                              InkWell(
                                onTap: () => setState(() {
                                  _variantId = option.id;
                                  _quantity = 1;
                                }),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _variantId == option.id
                                          ? AppColors.ink
                                          : AppColors.border,
                                      width: _variantId == option.id ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: option.imageUrl != null &&
                                          option.imageUrl!.isNotEmpty
                                      ? Image.asset(
                                          option.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.image_outlined,
                                            size: 20,
                                            color: AppColors.muted,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.palette_outlined,
                                          size: 20,
                                          color: AppColors.muted,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );

                final informationColumn = Container(
                  padding: EdgeInsets.all(mobile ? 18 : 28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categoría y Código SKU
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${product.category.label.toUpperCase()} · ${product.name.toUpperCase()}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.muted,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: _isFavorite
                                ? 'Quitar de favoritos'
                                : 'Guardar en favoritos',
                            icon: Icon(
                              _isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _isFavorite
                                  ? AppColors.pinkStrong
                                  : AppColors.muted,
                            ),
                            onPressed: () {
                              setState(() => _isFavorite = !_isFavorite);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isFavorite
                                        ? 'Agregado a tus favoritos 🌸'
                                        : 'Eliminado de tus favoritos',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Título del producto
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontFamily: 'PlayfairDisplay',
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              height: 1.18,
                            ),
                      ),
                      const SizedBox(height: 6),

                      // SKU
                      Text(
                        'SKU: ${sku ?? product.id.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Precio Prominente estilo Rosatel
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            '${product.startingAt ? 'Desde ' : ''}S/ ${unitPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'por ${product.unitLabel}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Disponibilidad
                      _AvailabilityPill(
                        status: product.stockStatusFor(_variantId),
                        stock: variant?.stock ?? product.stock,
                        unitLabel: product.unitLabel,
                      ),
                      const SizedBox(height: 18),

                      // Precios por mayor (si tiene)
                      if (tiers.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.loyalty_outlined,
                                    size: 16,
                                    color: AppColors.ink,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ahorra por mayor',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tiers
                                    .map(
                                      (tier) =>
                                          '${tier.minQuantity} ${product.unitLabel}${product.unitLabel == 'unidad' ? 'es' : 's'}: S/ ${tier.unitPrice.toStringAsFixed(2)} c/u',
                                    )
                                    .join(' · '),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Selector de opciones / variantes (ChoiceChips con texto limpio)
                      if (activeVariants.length > 1) ...[
                        Text(
                          'OPCIONES / COLORES',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in activeVariants)
                              ChoiceChip(
                                label: Text(variantDisplayName(option).toUpperCase()),
                                selected: _variantId == option.id,
                                onSelected: (_) => setState(() {
                                  _variantId = option.id;
                                  _quantity = 1;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],

                      // Botones de compra estilo Rosatel
                      // Fila 1: Selector de Cantidad + Botón Comprar Ahora
                      Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: _QuantitySelector(
                              value: _quantity,
                              onDecrease: _quantity == 1
                                  ? null
                                  : () => setState(() => _quantity--),
                              onIncrease: product.canRequest(
                                _quantity + 1,
                                variantId: _variantId,
                              )
                                  ? () => setState(() => _quantity++)
                                  : null,
                              onQuantityEntered: (val) {
                                if (product.canRequest(val, variantId: _variantId)) {
                                  setState(() => _quantity = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: canAdd ? _handleBuyNow : null,
                                style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  side: const BorderSide(
                                    color: AppColors.ink,
                                    width: 1.5,
                                  ),
                                  foregroundColor: AppColors.ink,
                                ),
                                child: const Text(
                                  'Comprar ahora',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Fila 2: Botón Primario Añadir al Carrito (full width pill)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: canAdd ? _handleAdd : null,
                          icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                          label: Text(
                            canAdd
                                ? 'Añadir al carrito · S/ ${total.toStringAsFixed(2)}'
                                : 'No disponible por ahora',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Tarjeta de Entrega y Programación estilo Rosatel
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.ink,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Puedes programar la fecha y horario de entrega o recojo en tu carrito.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.ink,
                                      height: 1.35,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                if (mobile) {
                  return Column(
                    children: [
                      imageColumn,
                      const SizedBox(height: 24),
                      informationColumn,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: imageColumn),
                    const SizedBox(width: 32),
                    Expanded(flex: 5, child: informationColumn),
                  ],
                );
              },
            ),
          ),

          // SECCIÓN 2: Franja de Sellos de Confianza (Estilo Rosatel - Imagen 2)
          ResponsivePage(
            maxWidth: 1200,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TrustBadgesStrip(
              whatsappNumber: widget.settings?.normalizedWhatsappNumber,
            ),
          ),
          const SizedBox(height: 36),

          // SECCIÓN 3: Descripción del Producto (Estilo Rosatel - Imagen 2)
          ResponsivePage(
            maxWidth: 1200,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descripción del producto',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'PlayfairDisplay',
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Línea ${product.category.label} · Expresiones',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    product.description.isNotEmpty
                        ? product.description
                        : 'Elaborado artesanalmente con materiales seleccionados de la más alta calidad para garantizar acabados impecables.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          height: 1.55,
                        ),
                  ),
                  if (product.attributes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in product.attributes.entries)
                          if (!entry.key.startsWith('merged') &&
                              entry.value.toString().trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '${entry.key.toUpperCase()}: ${entry.value}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          // SECCIÓN 4: Productos en la misma categoría (Estilo Rosatel - Imagen 3)
          if (widget.relatedProducts.isNotEmpty) ...[
            ResponsivePage(
              maxWidth: 1200,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productos en la misma categoría',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'PlayfairDisplay',
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 310,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.relatedProducts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final related = widget.relatedProducts[index];
                        final relatedImage = related.imageUrl ??
                            related.thumbnailUrl ??
                            (related.variants.isNotEmpty
                                ? related.variants.first.imageUrl
                                : null);
                        return Container(
                          width: 210,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              if (widget.onSelectRelated != null) {
                                widget.onSelectRelated!(related);
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    color: Colors.white,
                                    width: double.infinity,
                                    child: ProductVisual(
                                      label: related.name,
                                      imageAsset: relatedImage,
                                      categoryKey: related.category.key,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        related.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'S/ ${related.basePrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 34,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            if (widget.onSelectRelated != null) {
                                              widget.onSelectRelated!(related);
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            shape: const StadiumBorder(),
                                            padding: EdgeInsets.zero,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: const Text(
                                            'Ver detalle',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],

          // SECCIÓN 5: Banner Informativo y Banner Especial (Estilo Rosatel - Imagen 4)
          ResponsivePage(
            maxWidth: 1200,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const StoreDisclaimerBanner(),
                const SizedBox(height: 20),
                StoreSpecialOrderBanner(
                  whatsappNumber: widget.settings?.normalizedWhatsappNumber,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // SECCIÓN 6: Pie de Página Integral (Estilo Rosatel - Imagen 4)
          StoreFooter(
            onSelectCategory: widget.onNavigateCategory,
            whatsappNumber: widget.settings?.normalizedWhatsappNumber,
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == StockStatus.outOfStock
                  ? Icons.block_rounded
                  : Icons.check_circle_outline_rounded,
              size: 15,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
