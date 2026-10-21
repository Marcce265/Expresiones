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
              tile.variant?.previewImageUrl != null ||
              tile.product.previewImageUrl != null,
        )
        .take(6)
        .toList();

    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1180,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(
              quoteQuantity: widget.quoteQuantity,
              onOpenQuote: widget.onOpenQuote,
            ),
            const SizedBox(height: 28),
            _HomeIntro(
              searchController: _searchController,
              query: _query,
              onSearchChanged: _onSearchChanged,
              onSearchSubmitted: _reportEmptySearch,
              onClearSearch: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              onBrowse: () => widget.onBrowse(ProductCategory.materials),
              showHero: query.isEmpty,
            ),
            const SizedBox(height: 30),
            if (query.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Resultados',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${results.length} ${results.length == 1 ? 'producto' : 'productos'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SearchResults(results: results, onProduct: widget.onProduct),
            ] else ...[
              SectionHeader(
                title: 'Más consultados',
                actionLabel: 'Ver todo',
                onAction: () => widget.onBrowse(ProductCategory.materials),
              ),
              const SizedBox(height: 12),
              if (featured.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'El catálogo se está preparando',
                  message:
                      'Los productos aparecerán aquí cuando estén disponibles.',
                )
              else
                _FeaturedProducts(
                  products: featured,
                  onProduct: widget.onProduct,
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
    final hasResult = expandCatalogTiles(products)
        .any((tile) => _matches(tile, query));
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
    final usesDesktopNavigation = MediaQuery.sizeOf(context).width >= 1024;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (!usesDesktopNavigation)
            Expanded(
              child: Text(
                'Expresiones',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const Spacer(),
          Badge.count(
            count: quoteQuantity,
            isLabelVisible: quoteQuantity > 0,
            backgroundColor: AppColors.pinkStrong,
            child: constraints.maxWidth >= 560
                ? OutlinedButton.icon(
                    onPressed: onOpenQuote,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 19),
                    label: const Text('Mi cotización'),
                  )
                : IconButton.outlined(
                    onPressed: onOpenQuote,
                    tooltip: 'Mi cotización',
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro({
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onBrowse,
    required this.showHero,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onBrowse;
  final bool showHero;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Eyebrow('Catálogo de materiales'),
        const SizedBox(height: 10),
        Text(
          'Encuentra lo que necesitas',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Materiales, colores y acabados para crear detalles que expresan más.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          onSubmitted: onSearchSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar por material, color o código',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        _CategoryChips(onBrowse: (_) => onBrowse()),
      ],
    );

    if (!showHero) return copy;

    final hero = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/catalog_hero.webp', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x33000000)],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 22), hero],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 5, child: copy),
            const SizedBox(width: 36),
            Expanded(flex: 6, child: hero),
          ],
        );
      },
    );
  }
}

class _FeaturedProducts extends StatelessWidget {
  const _FeaturedProducts({required this.products, required this.onProduct});

  final List<CatalogTile> products;
  final ProductSelected onProduct;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final tile = products[index];
                return SizedBox(
                  width: 156,
                  child: ProductCard(
                    product: tile.product,
                    variant: tile.variant,
                    compact: true,
                    onTap: () => onProduct(tile.product, tile.variant?.id),
                  ),
                );
              },
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 245,
            mainAxisExtent: 292,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final tile = products[index];
            return ProductCard(
              product: tile.product,
              variant: tile.variant,
              onTap: () => onProduct(tile.product, tile.variant?.id),
            );
          },
        );
      },
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
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_rounded, size: 17),
      ],
    );
    return selected
        ? FilledButton(onPressed: onTap, child: child)
        : OutlinedButton(onPressed: onTap, child: child);
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
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: constraints.maxWidth < 600 ? 210 : 250,
          mainAxisExtent: constraints.maxWidth < 600 ? 248 : 292,
          crossAxisSpacing: constraints.maxWidth < 600 ? 12 : 16,
          mainAxisSpacing: constraints.maxWidth < 600 ? 12 : 16,
        ),
        itemBuilder: (context, index) {
          final tile = results[index];
          return ProductCard(
            product: tile.product,
            variant: tile.variant,
            compact: constraints.maxWidth < 600,
            onTap: () => onProduct(tile.product, tile.variant?.id),
          );
        },
      ),
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
