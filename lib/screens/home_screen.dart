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
    final usesDesktopNavigation = MediaQuery.sizeOf(context).width >= 1024;
    final showTrustRow = MediaQuery.sizeOf(context).width >= 700;
    final products =
        widget.products
            .where(
              (product) =>
                  product.isActive &&
                  (product.category == ProductCategory.materials ||
                      product.category == ProductCategory.koreanPaper),
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
              product.isActive &&
              (product.category == ProductCategory.materials ||
                  product.category == ProductCategory.koreanPaper),
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
            if (!usesDesktopNavigation) ...[
              _TopBar(
                settings: widget.settings,
                quoteQuantity: widget.quoteQuantity,
                onOpenQuote: widget.onOpenQuote,
              ),
              const SizedBox(height: 28),
            ],
            if (widget.lastOrder != null && widget.onOpenLastOrder != null) ...[
              _LastOrderCard(
                order: widget.lastOrder!,
                onOpen: () => widget.onOpenLastOrder!(widget.lastOrder!),
              ),
              const SizedBox(height: 18),
            ],
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
              showHero: query.isEmpty,
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 30),
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
              if (showTrustRow) ...[
                const SizedBox(height: 24),
                const _HomeTrustRow(),
                const SizedBox(height: 32),
              ] else
                const SizedBox(height: 28),
              _FeaturedHeader(
                title: widget.settings.text(StorefrontText.homeFeaturedTitle),
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
          product.isActive &&
          (product.category == ProductCategory.materials ||
              product.category == ProductCategory.koreanPaper),
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
          const Icon(Icons.shopping_bag_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu última compra simulada',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'S/ ${order.simulatedTotal.toStringAsFixed(2)} · ${order.totalQuantity} ${order.totalQuantity == 1 ? "producto" : "productos"}',
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
    required this.showHero,
  });

  final StorefrontSettings settings;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final bool showHero;

  @override
  Widget build(BuildContext context) {
    final heroSource = settings.text(StorefrontText.homeHeroImage).trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 940;
        final copyCard = Container(
          padding: EdgeInsets.fromLTRB(
            isWide ? 30 : 22,
            isWide ? 19 : 22,
            isWide ? 30 : 22,
            isWide ? 19 : 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeroBadge(label: settings.text(StorefrontText.homeEyebrow)),
              SizedBox(height: isWide ? 9 : 11),
              _HomeHeadline(
                title: settings.text(StorefrontText.homeTitle),
                compact: !isWide,
              ),
              const SizedBox(height: 8),
              Text(
                settings.text(StorefrontText.homeSubtitle),
                maxLines: isWide ? 2 : null,
                overflow: isWide ? TextOverflow.ellipsis : null,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  fontSize: isWide ? 13 : 14,
                  height: 1.42,
                ),
              ),
              SizedBox(height: isWide ? 16 : 18),
              _HomeSearchField(
                controller: searchController,
                query: query,
                hintText: settings.text(StorefrontText.homeSearchHint),
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
                onClear: onClearSearch,
              ),
              SizedBox(height: isWide ? 11 : 13),
              _PopularSearches(
                controller: searchController,
                onSelected: onSearchChanged,
              ),
            ],
          ),
        );

        if (!showHero) return copyCard;

        final hero = ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copyCard,
              const SizedBox(height: 16),
              AspectRatio(aspectRatio: 1.48, child: hero),
            ],
          );
        }

        return SizedBox(
          height: 334,
          child: Row(
            children: [
              Expanded(flex: 58, child: copyCard),
              const SizedBox(width: 18),
              Expanded(flex: 42, child: hero),
            ],
          ),
        );
      },
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6E8E4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: Color(0xFFA84B5A),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 10,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeadline extends StatelessWidget {
  const _HomeHeadline({required this.title, required this.compact});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const accentText = 'crear y expresar';
    final accentStart = title.toLowerCase().indexOf(accentText);
    final baseStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontSize: compact ? 32 : 36,
      height: 1.03,
      fontWeight: FontWeight.w600,
      letterSpacing: compact ? -0.45 : -0.7,
    );
    if (accentStart < 0) {
      return Text(
        title,
        maxLines: compact ? 4 : 3,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    final accentEnd = accentStart + accentText.length;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: title.substring(0, accentStart)),
          TextSpan(
            text: title.substring(accentStart, accentEnd),
            style: const TextStyle(
              color: Color(0xFFA84B5A),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(text: title.substring(accentEnd)),
        ],
      ),
      maxLines: compact ? 4 : 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _HomeSearchField extends StatelessWidget {
  const _HomeSearchField({
    required this.controller,
    required this.query,
    required this.hintText,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 11),
          const Icon(Icons.search_rounded, size: 19, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.ink, fontSize: 11),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF99958F), fontSize: 11),
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar búsqueda',
              onPressed: onClear,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(32),
                maximumSize: const Size.square(32),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.close_rounded, size: 16),
            ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: 66,
              height: 34,
              child: FilledButton(
                onPressed: () => onSubmitted(controller.text),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(66, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Buscar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularSearches extends StatelessWidget {
  const _PopularSearches({required this.controller, required this.onSelected});

  final TextEditingController controller;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const searches = ['Limpiapipas', 'Cintas satinadas', 'Coronitas'];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Popular:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
        for (final search in searches)
          _PopularChip(
            label: search,
            onTap: () {
              controller.value = TextEditingValue(
                text: search,
                selection: TextSelection.collapsed(offset: search.length),
              );
              onSelected(search);
            },
          ),
      ],
    );
  }
}

class _PopularChip extends StatelessWidget {
  const _PopularChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.ink, fontSize: 9.5, height: 1),
          ),
        ),
      ),
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

class _HomeTrustRow extends StatelessWidget {
  const _HomeTrustRow();

  static const _items = [
    _TrustContent(
      icon: Icons.check_rounded,
      iconBackground: Color(0xFFFBECEF),
      iconColor: Color(0xFFB64D66),
      title: 'Cotiza sin registro',
      description: 'Selecciona los productos y coordina directamente sin contraseñas ni registros forzados.',
    ),
    _TrustContent(
      icon: Icons.percent_rounded,
      iconBackground: Color(0xFFFFF5DE),
      iconColor: Color(0xFFE28A24),
      title: 'Precios por volumen',
      description: 'Escalas automáticas por mayor en limpiapipas, rollos de cinta y accesorios.',
    ),
    _TrustContent(
      icon: Icons.inventory_2_outlined,
      iconBackground: Color(0xFFEAF6F0),
      iconColor: Color(0xFF4B8C72),
      title: 'Recojo local y envíos Shalom',
      description: 'Recojo en nuestro local de Huancayo o encomienda segura a agencias de todo el país.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (var index = 0; index < _items.length; index++) ...[
                _HomeTrustItem(content: _items[index]),
                if (index != _items.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < _items.length; index++) ...[
                Expanded(child: _HomeTrustItem(content: _items[index])),
                if (index != _items.length - 1) const SizedBox(width: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TrustContent {
  const _TrustContent({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String description;
}

class _HomeTrustItem extends StatelessWidget {
  const _HomeTrustItem({required this.content});

  final _TrustContent content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: content.iconBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(content.icon, size: 17, color: content.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 11.5),
                ),
                const SizedBox(height: 3),
                Text(
                  content.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 9.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedHeader extends StatelessWidget {
  const _FeaturedHeader({required this.title, required this.onAction});

  final String title;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text(
                'Los favoritos de nuestros artesanos y decoradores',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFA84B5A),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 13),
          label: const Text('Ver todo el catálogo'),
        ),
      ],
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
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 620;
        final visibleProducts = products.take(6).toList(growable: false);
        final itemCount = visibleProducts.length;
        final targetColumns = isDesktop
            ? 6
            : isTablet
            ? 3
            : 2;
        final columns = itemCount < targetColumns ? itemCount : targetColumns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns == 0 ? 1 : columns,
            mainAxisExtent: isDesktop
                ? 304
                : isTablet
                ? 304
                : 250,
            crossAxisSpacing: isDesktop ? 14 : 12,
            mainAxisSpacing: isDesktop ? 14 : 12,
          ),
          itemBuilder: (context, index) {
            final tile = visibleProducts[index];
            return ProductCard(
              product: tile.product,
              variant: tile.variant,
              compact: !isTablet,
              showCategory: true,
              onTap: () => onProduct(tile.product, tile.variant?.id),
            );
          },
        );
      },
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
