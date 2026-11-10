import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/crown_icon.dart';
import '../widgets/product_card.dart';
import '../widgets/product_description_card.dart';
import '../widgets/product_visual.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.products,
    required this.onProduct,
    required this.onBack,
    required this.onOpenQuote,
    this.settings = const StorefrontSettings(),
    this.initialCategory,
    this.onCategoryChanged,
    this.onZeroResultSearch,
  });

  final List<CatalogProduct> products;
  final ProductCategory? initialCategory;
  final ValueChanged<ProductCategory>? onCategoryChanged;
  final ProductSelected onProduct;
  final VoidCallback onBack;
  final VoidCallback onOpenQuote;
  final StorefrontSettings settings;
  final ValueChanged<String>? onZeroResultSearch;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  final Set<String> _reportedEmptySearches = {};
  Timer? _searchDebounce;
  late ProductCategory _selectedCategory;
  String? _selectedFamilyId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? ProductCategory.materials;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null &&
        widget.initialCategory != oldWidget.initialCategory &&
        widget.initialCategory != _selectedCategory) {
      _selectedCategory = widget.initialCategory!;
      _selectedFamilyId = null;
      _query = '';
      _searchController.clear();
    } else if (_selectedFamilyId != null && _selectedFamily == null) {
      _selectedFamilyId = null;
      _query = '';
      _searchController.clear();
    }
  }

  void _switchCategory(ProductCategory category) {
    setState(() {
      _selectedCategory = category;
      _selectedFamilyId = null;
      _query = '';
      _searchController.clear();
    });
    widget.onCategoryChanged?.call(category);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final family = _selectedFamily;
    final sharedPricing = family != null && usesSharedFamilyPricing(family);
    final availableProducts = widget.products.where(
      (product) =>
          product.isActive && product.category == _selectedCategory,
    );
    final baseTiles = family == null
        ? [
            for (final product in availableProducts)
              (product: product, variant: null),
          ]
        : expandCatalogTiles([family]);
    final tiles = baseTiles.where((tile) => _matches(tile, query)).toList();

    final catalogTitle = family != null
        ? familyDisplayName(family)
        : _selectedCategory.label;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ResponsivePage(
                  maxWidth: 1180,
                  padding: const EdgeInsets.fromLTRB(14, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _back,
                            tooltip: 'Volver al inicio',
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              catalogTitle,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                        ],
                      ),
                      if (family != null) ...[
                        const SizedBox(height: 14),
                        _FamilyOverview(
                          product: family,
                          sharedPricing: sharedPricing,
                        ),
                        const SizedBox(height: 18),
                        Eyebrow(_familyOptionLabel(family)),
                        const SizedBox(height: 8),
                      ] else ...[
                        const SizedBox(height: 10),
                        _ModuleSelectorBar(
                          selectedCategory: _selectedCategory,
                          onSelectCategory: _switchCategory,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _onSearchSubmitted,
                        decoration: InputDecoration(
                          hintText: widget.settings.text(
                            StorefrontText.catalogSearchHint,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () {
                                    _searchDebounce?.cancel();
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (tiles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      _query.isEmpty &&
                          (_selectedCategory ==
                                  ProductCategory.koreanPaper ||
                              _selectedCategory == ProductCategory.crowns)
                      ? _ConstructionModuleState(category: _selectedCategory)
                      : EmptyState(
                          icon: Icons.search_off_rounded,
                          title: widget.settings.text(
                            StorefrontText.catalogEmptyTitle,
                          ),
                          message: widget.settings.text(
                            StorefrontText.catalogEmptyBody,
                          ),
                        ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.zero,
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final viewportWidth = constraints.crossAxisExtent;
                      final compact = viewportWidth < 640;
                      final horizontalPadding = viewportWidth > 1180
                          ? (viewportWidth - 1180) / 2 + 20
                          : 20.0;
                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          14,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: compact ? 210 : 260,
                                mainAxisExtent: compact ? 250 : 304,
                                crossAxisSpacing: compact ? 12 : 16,
                                mainAxisSpacing: compact ? 12 : 16,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final tile = tiles[index];
                              return ProductCard(
                                product: tile.product,
                                variant: tile.variant,
                                compact: compact,
                                showCategory:
                                    family == null &&
                                    tile.product.category ==
                                        ProductCategory.materials,
                                showPrice: !sharedPricing,
                                onTap: () => _openTile(tile),
                              );
                            },
                            childCount: tiles.length,
                            addRepaintBoundaries: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  CatalogProduct? get _selectedFamily {
    final selectedId = _selectedFamilyId;
    if (selectedId == null) return null;
    for (final product in widget.products) {
      if (product.id == selectedId &&
          product.isActive &&
          product.category == _selectedCategory) {
        return product;
      }
    }
    return null;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value);
      _reportEmptySearch(value);
    });
  }

  void _onSearchSubmitted(String value) {
    _searchDebounce?.cancel();
    setState(() => _query = value);
    _reportEmptySearch(value);
  }

  void _reportEmptySearch(String rawQuery) {
    if (!mounted || widget.onZeroResultSearch == null) return;
    final query = rawQuery.trim().toLowerCase();
    if (query.length < 2 || _reportedEmptySearches.contains(query)) return;
    final availableProducts = widget.products.where(
      (product) =>
          product.isActive && product.category == _selectedCategory,
    );
    final family = _selectedFamily;
    final baseTiles = family == null
        ? [
            for (final product in availableProducts)
              (product: product, variant: null),
          ]
        : expandCatalogTiles([family]);
    final hasResult = baseTiles.any((tile) => _matches(tile, query));
    if (hasResult) return;
    _reportedEmptySearches.add(query);
    widget.onZeroResultSearch!(query);
  }

  void _openTile(CatalogTile tile) {
    final variants = tile.product.variants
        .where((variant) => variant.isActive)
        .toList();
    if (_selectedFamilyId == null && variants.length > 1) {
      _searchController.clear();
      setState(() {
        _selectedFamilyId = tile.product.id;
        _query = '';
      });
      return;
    }
    widget.onProduct(tile.product, tile.variant?.id);
  }

  void _back() {
    if (_selectedFamilyId == null) {
      widget.onBack();
      return;
    }
    _searchController.clear();
    setState(() {
      _selectedFamilyId = null;
      _query = '';
    });
  }
}

bool _matches(CatalogTile tile, String query) {
  if (query.isEmpty) return true;
  final product = tile.product;
  final variant = tile.variant;
  return [
    product.name,
    product.description,
    product.sku ?? '',
    ...product.tags,
    ...product.attributes.values,
    variant?.name ?? '',
    variant?.sku ?? '',
    ...?variant?.attributes.values,
    if (variant == null)
      for (final option in product.variants) ...[option.name, option.sku ?? ''],
  ].any((value) => value.toLowerCase().contains(query));
}

bool usesSharedFamilyPricing(CatalogProduct product) {
  final variants = product.variants.where((variant) => variant.isActive);
  return variants.isNotEmpty &&
      variants.every(
        (variant) =>
            variant.priceOverride == null && variant.priceTiers.isEmpty,
      );
}

String familyDisplayName(CatalogProduct product) => switch (product.id) {
  'limpiapipas-premium-8mm' => 'Limpiapipas',
  'cinta-satinada-100m' => 'Cinta satinada',
  _ => product.name,
};

String _familyOptionLabel(CatalogProduct family) => switch (family.id) {
  'limpiapipas-premium-8mm' || 'cinta-satinada-100m' => 'Elige un color',
  _ => 'Elige una opción',
};

class _FamilyOverview extends StatelessWidget {
  const _FamilyOverview({required this.product, required this.sharedPricing});

  final CatalogProduct product;
  final bool sharedPricing;

  @override
  Widget build(BuildContext context) {
    final cover = AspectRatio(
      aspectRatio: 4 / 3,
      child: _FamilyCover(product: product),
    );
    final prices = _FamilyPricePanel(
      product: product,
      sharedPricing: sharedPricing,
    );

    return KeyedSubtree(
      key: ValueKey('family-overview-${product.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cover, const SizedBox(height: 12), prices],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: cover),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: prices),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          ProductDescriptionCard(product: product, compact: true),
        ],
      ),
    );
  }
}

class _FamilyCover extends StatelessWidget {
  const _FamilyCover({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final familyCover = productFamilyCoverImage(product);
    final images = <String>[];
    for (final variant in product.variants.where((item) => item.isActive)) {
      final image = variant.previewImageUrl;
      if (image != null && image.isNotEmpty && !images.contains(image)) {
        images.add(image);
      }
      if (images.length == 4) break;
    }
    if (images.isEmpty) {
      final image = product.previewImageUrl;
      if (image != null && image.isNotEmpty) images.add(image);
    }

    final visual = familyCover != null
        ? _coverImage(familyCover)
        : _FamilyMosaic(product: product, images: images);

    return Semantics(
      image: true,
      label: 'Portada de ${familyDisplayName(product)}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(color: Colors.white, child: visual),
        ),
      ),
    );
  }

  Widget _coverImage(String image) {
    return ProductVisual(
      label: familyDisplayName(product),
      imageAsset: image,
      categoryKey: product.category.key,
      fit: BoxFit.cover,
    );
  }
}

class _FamilyMosaic extends StatelessWidget {
  const _FamilyMosaic({required this.product, required this.images});

  final CatalogProduct product;
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    Widget tile(String? image) => ProductVisual(
      label: familyDisplayName(product),
      imageAsset: image,
      categoryKey: product.category.key,
      fit: BoxFit.cover,
    );

    return switch (images.length) {
      0 => tile(product.previewImageUrl),
      1 => tile(images.first),
      2 => Row(
        children: [
          Expanded(child: tile(images[0])),
          const SizedBox(width: 3),
          Expanded(child: tile(images[1])),
        ],
      ),
      3 => Row(
        children: [
          Expanded(child: tile(images[0])),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              children: [
                Expanded(child: tile(images[1])),
                const SizedBox(height: 3),
                Expanded(child: tile(images[2])),
              ],
            ),
          ),
        ],
      ),
      _ => GridView.count(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 4 / 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        children: [for (final image in images.take(4)) tile(image)],
      ),
    };
  }
}

class _FamilyPricePanel extends StatelessWidget {
  const _FamilyPricePanel({required this.product, required this.sharedPricing});

  final CatalogProduct product;
  final bool sharedPricing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Precios de la familia'),
          const SizedBox(height: 7),
          Text(
            sharedPricing
                ? 'Mismos precios para todas las opciones'
                : 'El precio depende de la presentación',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            sharedPricing
                ? 'Elige la opción que prefieras; la escala de precios es la misma.'
                : 'Revisa el precio indicado en cada modelo antes de elegir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (sharedPricing) ...[
            _PriceRow(
              label: 'Por ${product.unitLabel}',
              price: product.basePrice,
            ),
            for (final tier in product.priceTiers) ...[
              const Divider(height: 18),
              _PriceRow(
                label: tier.label ?? 'Desde ${tier.minQuantity}',
                price: tier.unitPrice,
              ),
            ],
          ] else
            const InfoBanner(
              title: 'Precios individuales',
              message: 'Cada presentación conserva su propio precio.',
              color: AppColors.canvas,
            ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.price});

  final String label;
  final double price;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    final priceText = Text(
      'S/ ${price.toStringAsFixed(2)} c/u',
      style: Theme.of(context).textTheme.labelLarge,
    );
    final usesLargeText = MediaQuery.textScalerOf(context).scale(16) >= 24;

    if (usesLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          labelText,
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: priceText),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: labelText),
        const SizedBox(width: 12),
        priceText,
      ],
    );
  }
}

class _ModuleSelectorBar extends StatelessWidget {
  const _ModuleSelectorBar({
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final ProductCategory selectedCategory;
  final ValueChanged<ProductCategory> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          _ModuleChip(
            category: ProductCategory.materials,
            label: 'Materiales',
            isSelected: selectedCategory == ProductCategory.materials,
            onTap: () => onSelectCategory(ProductCategory.materials),
          ),
          const SizedBox(width: 8),
          _ModuleChip(
            category: ProductCategory.koreanPaper,
            label: 'Papel Coreano',
            isSelected: selectedCategory == ProductCategory.koreanPaper,
            onTap: () => onSelectCategory(ProductCategory.koreanPaper),
          ),
        ],
      ),
    );
  }
}

class _ModuleChip extends StatelessWidget {
  const _ModuleChip({
    required this.category,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final ProductCategory category;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  Widget _icon(Color color) => switch (category) {
    ProductCategory.materials => Icon(
      Icons.auto_awesome_rounded,
      size: 16,
      color: color,
    ),
    ProductCategory.koreanPaper => Icon(
      Icons.layers_rounded,
      size: 16,
      color: color,
    ),
    ProductCategory.crowns => CrownIcon(size: 16, color: color),
    _ => Icon(Icons.local_florist_rounded, size: 16, color: color),
  };

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : AppColors.ink;

    return Material(
      color: isSelected ? AppColors.ink : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: isSelected ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.ink : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConstructionModuleState extends StatelessWidget {
  const _ConstructionModuleState({required this.category});

  final ProductCategory category;

  @override
  Widget build(BuildContext context) {
    final isKoreanPaper = category == ProductCategory.koreanPaper;
    final message = isKoreanPaper
        ? 'Estamos preparando los pliegos más hermosos y exclusivos para tus ramos y manualidades. ¡Muy pronto disponibles para cotizar!'
        : 'Estamos preparando las coronas más hermosas y exclusivas para tus reinas, quinceañeras y eventos especiales. ¡Muy pronto disponibles para cotizar!';
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 700;
    final availableHeight = media.height - (compact ? 290 : 310);
    final imageHeight = (availableHeight * (compact ? 0.50 : 0.55))
        .clamp(compact ? 160.0 : 200.0, compact ? 280.0 : 360.0);
    final haloSize = imageHeight * 0.92;

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 32,
          12,
          compact ? 20 : 32,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: imageHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: haloSize,
                    height: haloSize,
                    decoration: BoxDecoration(
                      color: AppColors.pinkSoft.withValues(alpha: .6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Image.asset(
                    'assets/images/jashy_constructora.webp',
                    height: imageHeight,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel:
                        'Jashy con casco y herramientas de construcción',
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              'SECCIÓN EN CONSTRUCCIÓN',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
                color: AppColors.pinkStrong,
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                '¡${category.label} muy pronto!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 28 : 38,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.5,
                  fontSize: compact ? 13.5 : 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
