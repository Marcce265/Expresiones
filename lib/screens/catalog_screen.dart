import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_card.dart';
import '../widgets/product_visual.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.products,
    required this.onProduct,
    required this.onBack,
    required this.onOpenQuote,
    this.initialCategory,
    this.onZeroResultSearch,
  });

  final List<CatalogProduct> products;
  final ProductCategory? initialCategory;
  final ProductSelected onProduct;
  final VoidCallback onBack;
  final VoidCallback onOpenQuote;
  final ValueChanged<String>? onZeroResultSearch;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  final Set<String> _reportedEmptySearches = {};
  Timer? _searchDebounce;
  String? _selectedFamilyId;
  String _query = '';
  String _filter = 'Todos';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedFamilyId != null && _selectedFamily == null) {
      _selectedFamilyId = null;
      _query = '';
      _filter = 'Todos';
      _searchController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final family = _selectedFamily;
    final sharedPricing = family != null && usesSharedFamilyPricing(family);
    final availableProducts = widget.products.where(
      (product) =>
          product.isActive && product.category == ProductCategory.materials,
    );
    final baseTiles = family == null
        ? [
            for (final product in availableProducts)
              (product: product, variant: null),
          ]
        : expandCatalogTiles([family]);
    final tiles = baseTiles.where((tile) {
      return _matches(tile, query) && _matchesFilter(tile, _filter);
    }).toList();
    final filters = family != null
        ? const <String>[]
        : const [
            'Todos',
            'Limpiapipas',
            'Cintas satinadas',
            'Cintas especiales',
            'Envolturas',
            'Accesorios',
            'Herramientas',
            'Frases',
          ];

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ResponsivePage(
                  maxWidth: 980,
                  padding: const EdgeInsets.fromLTRB(14, 7, 20, 12),
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
                              family == null
                                  ? 'Materiales'
                                  : familyDisplayName(family),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          Text(
                            '${tiles.length} ${_itemLabel(family)}',
                            style: Theme.of(context).textTheme.bodySmall,
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
                        const Eyebrow('Elige un color o modelo'),
                        const SizedBox(height: 8),
                      ] else
                        const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _reportEmptySearch,
                        decoration: InputDecoration(
                          hintText: 'Buscar por color o modelo',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      if (filters.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final filter in filters) ...[
                                ChoiceChip(
                                  label: Text(filter),
                                  selected: _filter == filter,
                                  onSelected: (_) => _selectFilter(filter),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (tiles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No encontramos productos',
                    message: 'Prueba otro término o elige un filtro diferente.',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.crossAxisExtent < 600;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: compact ? 220 : 280,
                          mainAxisExtent: compact ? 238 : 290,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
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
                        }, childCount: tiles.length),
                      );
                    },
                  ),
                ),
                if (family == null)
                  SliverToBoxAdapter(
                    child: ResponsivePage(
                      maxWidth: 980,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pinkSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Precio por volumen disponible',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cotiza por docena, medio cajón o cajón completo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        ResponsivePage(
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: widget.onOpenQuote,
            child: const Text('Ver mi cotización'),
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
          product.category == ProductCategory.materials) {
        return product;
      }
    }
    return null;
  }

  void _selectFilter(String filter) {
    setState(() {
      _filter = filter;
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 800),
      () => _reportEmptySearch(value),
    );
  }

  void _reportEmptySearch(String rawQuery) {
    if (!mounted || widget.onZeroResultSearch == null) return;
    final query = rawQuery.trim().toLowerCase();
    if (query.length < 2 || _reportedEmptySearches.contains(query)) return;
    final availableProducts = widget.products.where(
      (product) =>
          product.isActive && product.category == ProductCategory.materials,
    );
    final family = _selectedFamily;
    final baseTiles = family == null
        ? [
            for (final product in availableProducts)
              (product: product, variant: null),
          ]
        : expandCatalogTiles([family]);
    final hasResult = baseTiles.any(
      (tile) => _matches(tile, query) && _matchesFilter(tile, _filter),
    );
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
        _filter = 'Todos';
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
      _filter = 'Todos';
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

bool _matchesFilter(CatalogTile tile, String filter) {
  if (filter == 'Todos') return true;
  return tile.product.attributes['catalogGroup'] == filter;
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

String _itemLabel(CatalogProduct? family) {
  if (family == null) return 'productos';
  return switch (family.id) {
    'limpiapipas-premium-8mm' || 'cinta-satinada-100m' => 'colores',
    _ => 'modelos',
  };
}

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
      child: LayoutBuilder(
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
    );
  }
}

class _FamilyCover extends StatelessWidget {
  const _FamilyCover({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final heroAsset = productFamilyHeroAsset(product);
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

    final visual = heroAsset != null
        ? _coverImage(heroAsset)
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
