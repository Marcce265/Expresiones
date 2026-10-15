import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.products,
    required this.onBrowse,
    required this.onProduct,
    required this.onOpenQuote,
    required this.quoteQuantity,
    this.onZeroResultSearch,
  });

  final List<CatalogProduct> products;
  final ValueChanged<ProductCategory> onBrowse;
  final ProductSelected onProduct;
  final VoidCallback onOpenQuote;
  final int quoteQuantity;
  final ValueChanged<String>? onZeroResultSearch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final Set<String> _reportedEmptySearches = {};
  Timer? _searchDebounce;
  String _query = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products =
        widget.products
            .where(
              (product) =>
                  product.isActive &&
                  product.category == ProductCategory.materials,
            )
            .toList()
          ..sort((a, b) {
            final featured = (b.isFeatured ? 1 : 0) - (a.isFeatured ? 1 : 0);
            if (featured != 0) return featured;
            return a.sortOrder.compareTo(b.sortOrder);
          });
    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? const <CatalogTile>[]
        : expandCatalogTiles(products)
              .where((tile) => _matches(tile, query))
              .toList();
    final featured = expandCatalogTiles(products)
        .where(
          (tile) =>
              tile.variant?.imageUrl != null || tile.product.imageUrl != null,
        )
        .take(6)
        .toList();

    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 920,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(
              quoteQuantity: widget.quoteQuantity,
              onOpenQuote: widget.onOpenQuote,
            ),
            const SizedBox(height: 20),
            Text(
              'Encuentra lo que necesitas',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 3),
            Text(
              'Materiales para crear detalles que expresan más.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _reportEmptySearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar materiales',
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
            const SizedBox(height: 18),
            if (query.isNotEmpty)
              _SearchResults(results: results, onProduct: widget.onProduct)
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1.9,
                  child: Image.asset(
                    'assets/images/catalog_hero.webp',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Explora materiales',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 9),
              _CategoryChips(onBrowse: widget.onBrowse),
              const SizedBox(height: 18),
              SectionHeader(
                title: 'Más consultados',
                actionLabel: 'Ver todo',
                onAction: () => widget.onBrowse(ProductCategory.materials),
              ),
              const SizedBox(height: 8),
              if (featured.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'El catálogo se está preparando',
                  message:
                      'Los productos aparecerán aquí cuando estén disponibles.',
                )
              else
                SizedBox(
                  height: 202,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final tile = featured[index];
                      return SizedBox(
                        width: 148,
                        child: ProductCard(
                          product: tile.product,
                          variant: tile.variant,
                          compact: true,
                          onTap: () =>
                              widget.onProduct(tile.product, tile.variant?.id),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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
    final products = widget.products.where(
      (product) =>
          product.isActive && product.category == ProductCategory.materials,
    );
    final hasResult = expandCatalogTiles(products).any(
      (tile) => _matches(tile, query),
    );
    if (hasResult) return;
    _reportedEmptySearches.add(query);
    widget.onZeroResultSearch!(query);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.quoteQuantity, required this.onOpenQuote});

  final int quoteQuantity;
  final VoidCallback onOpenQuote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Expresiones',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Badge.count(
          count: quoteQuantity,
          isLabelVisible: quoteQuantity > 0,
          backgroundColor: AppColors.pinkStrong,
          child: IconButton.outlined(
            onPressed: onOpenQuote,
            tooltip: 'Mi cotización',
            icon: const Icon(Icons.shopping_bag_outlined, size: 20),
          ),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.onBrowse});

  final ValueChanged<ProductCategory> onBrowse;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CategoryButton(
          label: 'Materiales',
          selected: true,
          onTap: () => onBrowse(ProductCategory.materials),
        ),
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 39,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: const StadiumBorder(),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: const StadiumBorder(),
              ),
              child: Text(label),
            ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onProduct});

  final List<CatalogTile> results;
  final ProductSelected onProduct;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No encontramos coincidencias',
        message: 'Prueba con un color, código o nombre de producto.',
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 244,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final tile = results[index];
        return ProductCard(
          product: tile.product,
          variant: tile.variant,
          compact: true,
          onTap: () => onProduct(tile.product, tile.variant?.id),
        );
      },
    );
  }
}

bool _matches(CatalogTile tile, String query) {
  final product = tile.product;
  final variant = tile.variant;
  return [
    product.name,
    product.description,
    product.sku ?? '',
    product.category.label,
    ...product.tags,
    ...product.attributes.values,
    variant?.name ?? '',
    variant?.sku ?? '',
    ...?variant?.attributes.values,
  ].any((value) => value.toLowerCase().contains(query));
}
