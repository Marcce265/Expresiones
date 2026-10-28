import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../models/checkout_order.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.products,
    this.popularProducts = const [],
    required this.onBrowse,
    required this.onProduct,
    required this.onOpenQuote,
    required this.quoteQuantity,
    this.settings = const StorefrontSettings(),
    this.onZeroResultSearch,
    this.lastOrder,
    this.onOpenLastOrder,
  });

  final List<CatalogProduct> products;
  final List<CatalogProduct> popularProducts;
  final ValueChanged<ProductCategory> onBrowse;
  final ProductSelected onProduct;
  final VoidCallback onOpenQuote;
  final int quoteQuantity;
  final StorefrontSettings settings;
  final ValueChanged<String>? onZeroResultSearch;
  final CheckoutOrder? lastOrder;
  final ValueChanged<CheckoutOrder>? onOpenLastOrder;

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
    final rankedProducts = widget.popularProducts
        .where(
          (product) =>
              product.isActive && product.category == ProductCategory.materials,
        )
        .toList(growable: false);
    final featured = _featuredProductTiles(
      rankedProducts.isEmpty ? products : rankedProducts,
      fallbackProducts: products,
    );

    return SingleChildScrollView(
      child: ResponsivePage(
        maxWidth: 1400,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(
              settings: widget.settings,
              quoteQuantity: widget.quoteQuantity,
              onOpenQuote: widget.onOpenQuote,
            ),
            if (widget.lastOrder != null && widget.onOpenLastOrder != null) ...[
              const SizedBox(height: 18),
              _LastOrderCard(
                order: widget.lastOrder!,
                onOpen: () => widget.onOpenLastOrder!(widget.lastOrder!),
              ),
            ],
            const SizedBox(height: 28),
            _HomeIntro(
              settings: widget.settings,
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
                title: widget.settings.text(StorefrontText.homeFeaturedTitle),
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
                  onBrowse: () => widget.onBrowse(ProductCategory.materials),
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

class _LastOrderCard extends StatelessWidget {
  const _LastOrderCard({required this.order, required this.onOpen});

  final CheckoutOrder order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pinkSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Último pedido simulado',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.id} · S/ ${order.simulatedTotal.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onOpen, child: const Text('Ver')),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.settings,
    required this.quoteQuantity,
    required this.onOpenQuote,
  });

  final StorefrontSettings settings;
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
                settings.text(StorefrontText.brandName),
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
                    label: const Text('Mi carrito'),
                  )
                : IconButton.outlined(
                    onPressed: onOpenQuote,
                    tooltip: 'Mi carrito',
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
    required this.settings,
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onBrowse,
    required this.showHero,
  });

  final StorefrontSettings settings;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onBrowse;
  final bool showHero;

  @override
  Widget build(BuildContext context) {
    final heroSource = settings.text(StorefrontText.homeHeroImage).trim();
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Eyebrow(settings.text(StorefrontText.homeEyebrow)),
        const SizedBox(height: 10),
        Text(
          settings.text(StorefrontText.homeTitle),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          settings.text(StorefrontText.homeSubtitle),
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
            hintText: settings.text(StorefrontText.homeSearchHint),
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
            _HomeHeroImage(source: heroSource),
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
        if (constraints.maxWidth >= 1180) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: copy),
              const SizedBox(width: 28),
              Expanded(flex: 5, child: hero),
              const SizedBox(width: 18),
              const SizedBox(width: 220, child: _HomeTrustRail()),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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

class _HomeHeroImage extends StatelessWidget {
  const _HomeHeroImage({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final clean = source.isEmpty ? 'assets/images/catalog_hero.webp' : source;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/catalog_hero.webp',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      );
    }
    return Image.asset(
      clean,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/images/catalog_hero.webp',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _FeaturedProducts extends StatelessWidget {
  const _FeaturedProducts({
    required this.products,
    required this.onProduct,
    required this.onBrowse,
  });

  final List<CatalogTile> products;
  final ProductSelected onProduct;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final showBrowseCard = constraints.maxWidth >= 1260;
        final itemCount = products.length + (showBrowseCard ? 1 : 0);
        final targetColumns = showBrowseCard
            ? 7
            : constraints.maxWidth >= 1040
            ? 6
            : constraints.maxWidth >= 700
            ? 3
            : 2;
        final columns = itemCount < targetColumns ? itemCount : targetColumns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns == 0 ? 1 : columns,
            mainAxisExtent: compact ? 250 : 292,
            crossAxisSpacing: compact ? 12 : 16,
            mainAxisSpacing: compact ? 12 : 16,
          ),
          itemBuilder: (context, index) {
            if (index == products.length) {
              return _BrowseCatalogCard(onTap: onBrowse);
            }
            final tile = products[index];
            return ProductCard(
              product: tile.product,
              variant: tile.variant,
              compact: compact,
              onTap: () => onProduct(tile.product, tile.variant?.id),
            );
          },
        );
      },
    );
  }
}

class _HomeTrustRail extends StatelessWidget {
  const _HomeTrustRail();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _HomeTrustItem(
          icon: Icons.lock_open_rounded,
          title: 'Sin registro',
          description: 'Arma tu carrito libremente.',
        ),
        SizedBox(height: 10),
        _HomeTrustItem(
          icon: Icons.stacked_line_chart_rounded,
          title: 'Precios por volumen',
          description: 'Calculamos el mejor precio por cantidad.',
        ),
        SizedBox(height: 10),
        _HomeTrustItem(
          icon: Icons.local_shipping_outlined,
          title: 'Recojo o envío',
          description: 'Huancayo y agencias Shalom.',
        ),
      ],
    );
  }
}

class _HomeTrustItem extends StatelessWidget {
  const _HomeTrustItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.pinkSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(height: 11),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _BrowseCatalogCard extends StatelessWidget {
  const _BrowseCatalogCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pinkSoft,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.grid_view_rounded),
              ),
              const Spacer(),
              Text(
                'Todo el catálogo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                'Explora materiales, colores y acabados.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ver productos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 19),
                ],
              ),
            ],
          ),
        ),
      ),
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

List<CatalogTile> _featuredProductTiles(
  Iterable<CatalogProduct> rankedProducts, {
  required Iterable<CatalogProduct> fallbackProducts,
}) {
  final tiles = <CatalogTile>[];
  final seen = <String>{};

  void add(CatalogTile tile) {
    final key = '${tile.product.id}::${tile.variant?.id ?? ''}';
    if (seen.add(key)) tiles.add(tile);
  }

  for (final product in rankedProducts) {
    final variants = product.variants
        .where(
          (variant) =>
              variant.isActive && variant.stockStatus != StockStatus.outOfStock,
        )
        .toList(growable: false);
    final hasActiveVariants = product.variants.any(
      (variant) => variant.isActive,
    );
    if (hasActiveVariants && variants.isEmpty) continue;
    if (!hasActiveVariants && product.stockStatus == StockStatus.outOfStock) {
      continue;
    }
    add((product: product, variant: variants.isEmpty ? null : variants.first));
    if (tiles.length == 6) return List.unmodifiable(tiles);
  }

  for (final tile in expandCatalogTiles(fallbackProducts).where(
    (tile) =>
        tile.product.isActive &&
        tile.product.stockStatusFor(tile.variant?.id) != StockStatus.outOfStock,
  )) {
    add(tile);
    if (tiles.length == 6) break;
  }
  return List.unmodifiable(tiles);
}
