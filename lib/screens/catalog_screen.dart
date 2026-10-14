import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_card.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.products,
    required this.onProduct,
    required this.onBack,
    required this.onOpenQuote,
    this.initialCategory,
  });

  final List<CatalogProduct> products;
  final ProductCategory? initialCategory;
  final ProductSelected onProduct;
  final VoidCallback onBack;
  final VoidCallback onOpenQuote;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  late ProductCategory? _category = widget.initialCategory;
  CatalogProduct? _selectedFamily;
  String _query = '';
  String _filter = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final family = _selectedFamily;
    final availableProducts = widget.products.where(
      (product) =>
          product.isActive &&
          (_category == null || product.category == _category),
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
        : _category == ProductCategory.materials
        ? const [
            'Todos',
            'Limpiapipas',
            'Cintas satinadas',
            'Cintas especiales',
            'Envolturas',
            'Accesorios',
            'Herramientas',
            'Frases',
          ]
        : const ['Todos', 'Materiales', 'Ramos', 'Personalizados'];

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
                              family?.name ?? _category?.label ?? 'Catálogo',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          Text(
                            '${tiles.length} ${family == null ? 'productos' : 'modelos'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
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
                                tile.product.category ==
                                ProductCategory.materials,
                            onTap: () => _openTile(tile),
                          );
                        }, childCount: tiles.length),
                      );
                    },
                  ),
                ),
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

  void _selectFilter(String filter) {
    setState(() {
      if (_category == ProductCategory.materials) {
        _filter = filter;
      } else {
        _category = switch (filter) {
          'Materiales' => ProductCategory.materials,
          'Ramos' => ProductCategory.bouquets,
          'Personalizados' => ProductCategory.personalizedGifts,
          _ => null,
        };
        _filter = 'Todos';
      }
    });
  }

  void _openTile(CatalogTile tile) {
    final variants = tile.product.variants
        .where((variant) => variant.isActive)
        .toList();
    if (_selectedFamily == null && variants.length > 1) {
      _searchController.clear();
      setState(() {
        _selectedFamily = tile.product;
        _query = '';
        _filter = 'Todos';
      });
      return;
    }
    widget.onProduct(tile.product, tile.variant?.id);
  }

  void _back() {
    if (_selectedFamily == null) {
      widget.onBack();
      return;
    }
    _searchController.clear();
    setState(() {
      _selectedFamily = null;
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
