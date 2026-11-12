import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/assistant_guide.dart';
import '../widgets/product_description_card.dart';
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
  late final String? _variantId =
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

  Widget _buildTrustItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleAdd() {
    widget.onAdd(quantity: _quantity, variantId: _variantId, customization: '');
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
    final detailImage =
        variant?.imageUrl ??
        product.imageUrl ??
        variant?.thumbnailUrl ??
        product.thumbnailUrl;
    final previewImage =
        variant?.thumbnailUrl ?? product.thumbnailUrl ?? detailImage;
    final title = variant == null ? product.name : variantDisplayName(variant!);
    final hideInternalPaletteCode =
        variant?.attributes.containsKey('paletteNumber') ?? false;
    final sku = hideInternalPaletteCode ? null : variant?.sku ?? product.sku;
    final total = product.totalFor(_quantity, variantId: _variantId);
    final canAdd = product.canRequest(_quantity, variantId: _variantId);
    final imageFit = productImageFit(product, variant: variant);
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                // Breadcrumbs y barra superior
                ResponsivePage(
                  maxWidth: 1200,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      IconButton.outlined(
                        onPressed: () => Navigator.maybePop(context),
                        tooltip: 'Volver',
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              InkWell(
                                onTap:
                                    widget.onNavigateHome ??
                                    () => Navigator.maybePop(context),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    'INICIO',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
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
                                    widget.onNavigateCategory!(
                                      product.category,
                                    );
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
                                    product.category.label.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
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
                                  product.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
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
                          icon: const Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                          ),
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
                      final squareVisual =
                          product.id == 'limpiapipas-premium-8mm' ||
                          product.id == 'cinta-satinada-100m' ||
                          product.category == ProductCategory.koreanPaper;

                      final visualWidget = Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ProductVisual(
                          label: title,
                          imageAsset: detailImage,
                          placeholderImageAsset: previewImage,
                          colorHex: variant?.colorHex,
                          categoryKey: product.category.key,
                          fit: imageFit,
                          filterQuality: FilterQuality.medium,
                          decodeToLayout: true,
                          maxDecodeEdge: 1600,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
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
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.muted,
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
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
                                    onIncrease:
                                        product.canRequest(
                                          _quantity + 1,
                                          variantId: _variantId,
                                        )
                                        ? () => setState(() => _quantity++)
                                        : null,
                                    onQuantityEntered: (val) {
                                      if (product.canRequest(
                                        val,
                                        variantId: _variantId,
                                      )) {
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
                                icon: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 20,
                                ),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
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

                // SECCIÓN 2: Descripción a la izquierda y Sellos de Confianza a la derecha (Ahorro de espacio)
                ResponsivePage(
                  maxWidth: 1200,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isStacked = constraints.maxWidth < 800;

                      final descriptionCard = ProductDescriptionCard(
                        product: product,
                      );

                      final trustBadgesCard = Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.pinkSoft,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTrustItem(
                              icon: Icons.verified_outlined,
                              title: 'Calidad premium',
                              subtitle: 'Artesanía y acabados impecables',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(color: Colors.black12, height: 1),
                            ),
                            _buildTrustItem(
                              icon: Icons.inventory_2_outlined,
                              title: 'Productos seleccionados',
                              subtitle: 'Insumos importados duraderos',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(color: Colors.black12, height: 1),
                            ),
                            _buildTrustItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: 'Atención personalizada',
                              subtitle: 'Escríbenos directamente',
                            ),
                          ],
                        ),
                      );

                      if (isStacked) {
                        return Column(
                          children: [
                            descriptionCard,
                            const SizedBox(height: 18),
                            trustBadgesCard,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: descriptionCard),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: trustBadgesCard),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),

                // SECCIÓN 3: Pie de Página Integral (Estilo Rosatel)
                StoreFooter(
                  onSelectCategory: widget.onNavigateCategory,
                  whatsappNumber: widget.settings?.normalizedWhatsappNumber,
                ),
              ]),
            ),
          ],
        ),
        const Positioned(
          right: 18,
          bottom: 24,
          child: AssistantHelpButton(
            title: 'Consejo de Jashy 💕',
            message: '¡Me parece un excelente producto! 💕 Elige la cantidad y aprovecha los descuentos por mayor.',
            messages: [
              '¡Me parece un excelente producto! 💕 Elige la cantidad y aprovecha los descuentos por mayor.',
              '✨ Insumos de calidad premium seleccionados con acabados duraderos para tus creaciones.',
              '📦 Precios especiales por mayor automáticos a partir de 12 unidades.',
            ],
            imageAsset: 'assets/images/jashy_chibi_assistant.webp',
          ),
        ),
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
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
