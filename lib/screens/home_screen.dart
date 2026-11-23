import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../models/checkout_order.dart';
import '../models/storefront_settings.dart';
import '../services/catalog_search_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_card.dart';
import '../widgets/store_footer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.products,
    this.popularProducts = const [],
    required this.onBrowse,
    required this.onProduct,
    this.onAddToCart,
    required this.onOpenQuote,
    required this.quoteQuantity,
    this.onOpenFamily,
    this.onOpenHelp,
    this.settings = const StorefrontSettings(),
    this.onZeroResultSearch,
    this.lastOrder,
    this.onOpenLastOrder,
  });

  final List<CatalogProduct> products;
  final List<CatalogProduct> popularProducts;
  final ValueChanged<ProductCategory> onBrowse;
  final ProductSelected onProduct;
  final ProductSelected? onAddToCart;
  final VoidCallback onOpenQuote;
  final int quoteQuantity;
  final ValueChanged<CatalogProduct>? onOpenFamily;
  final VoidCallback? onOpenHelp;
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
  Timer? _filterDebounce;
  Timer? _telemetryDebounce;
  String _query = '';
  int _visibleResultLimit = CatalogSearchEngine.defaultPageSize;

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _telemetryDebounce?.cancel();
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
    final query = _query.trim();
    final results = query.isEmpty
        ? const <CatalogTile>[]
        : CatalogSearchEngine.searchProducts(
            products,
            query,
            expandFamilyMatches: true,
          );
    final visibleResults = results.length <= _visibleResultLimit
        ? results
        : results.take(_visibleResultLimit).toList(growable: false);
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
      child: Column(
        children: [
          ResponsivePage.storefront(
            top: 14,
            bottom: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!usesDesktopNavigation &&
                    MediaQuery.sizeOf(context).width >= 768) ...[
                  _TopBar(
                    settings: widget.settings,
                    quoteQuantity: widget.quoteQuantity,
                    onOpenQuote: widget.onOpenQuote,
                  ),
                  const SizedBox(height: 28),
                ],
                if (widget.lastOrder != null &&
                    widget.onOpenLastOrder != null) ...[
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
                  onSearchSubmitted: _onSearchSubmitted,
                  onClearSearch: () {
                    _filterDebounce?.cancel();
                    _telemetryDebounce?.cancel();
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _visibleResultLimit = CatalogSearchEngine.defaultPageSize;
                    });
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
                        '${results.length} ${results.length == 1 ? 'resultado' : 'resultados'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SearchResults(
                    results: visibleResults,
                    totalCount: results.length,
                    onLoadMore: results.length > visibleResults.length
                        ? () => setState(
                            () => _visibleResultLimit +=
                                CatalogSearchEngine.defaultPageSize,
                          )
                        : null,
                    onProduct: _handleSearchTileTap,
                    onAddToCart: widget.onAddToCart,
                  ),
                ] else ...[
                  if (showTrustRow) ...[
                    const SizedBox(height: 24),
                    const _HomeTrustRow(),
                    const SizedBox(height: 32),
                  ] else
                    const SizedBox(height: 28),
                  _FeaturedHeader(
                    title: widget.settings.text(
                      StorefrontText.homeFeaturedTitle,
                    ),
                    onAction: () => widget.onBrowse(ProductCategory.materials),
                  ),
                  const SizedBox(height: 12),
                  if (featured.isEmpty)
                    const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'El catálogo se está preparando',
                      message: 'Los productos aparecerán aquí cuando estén disponibles.',
                    )
                  else
                    _FeaturedProducts(
                      products: featured,
                      onProduct: widget.onProduct,
                      onAddToCart: widget.onAddToCart,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          StoreFooter(
            settings: widget.settings,
            onSelectCategory: widget.onBrowse,
            onOpenQuote: widget.onOpenQuote,
            onOpenHelp: widget.onOpenHelp,
            whatsappNumber: widget.settings.whatsappNumber,
          ),
        ],
      ),
    );
  }

  void _handleSearchTileTap(CatalogProduct product, String? variantId) {
    final activeVariants = product.variants
        .where((v) => v.isActive)
        .toList(growable: false);
    if (variantId == null &&
        activeVariants.length > 1 &&
        widget.onOpenFamily != null) {
      widget.onOpenFamily!(product);
      return;
    }
    widget.onProduct(product, variantId);
  }

  void _onSearchChanged(String value) {
    _filterDebounce?.cancel();
    _telemetryDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _query = '';
        _visibleResultLimit = CatalogSearchEngine.defaultPageSize;
      });
      return;
    }
    _filterDebounce = Timer(CatalogSearchEngine.inputFilterDebounce, () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _visibleResultLimit = CatalogSearchEngine.defaultPageSize;
      });
    });
    _telemetryDebounce = Timer(
      CatalogSearchEngine.zeroResultTelemetryDebounce,
      () => _reportEmptySearch(value),
    );
  }

  void _onSearchSubmitted(String value) {
    _filterDebounce?.cancel();
    _telemetryDebounce?.cancel();
    setState(() {
      _query = value;
      _visibleResultLimit = CatalogSearchEngine.defaultPageSize;
    });
    _reportEmptySearch(value);
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
    final hasResult = CatalogSearchEngine.searchProducts(
      products,
      query,
    ).isNotEmpty;
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
                  fontSize: isWide ? 12.5 : 14,
                  height: 1.42,
                ),
              ),
              SizedBox(height: isWide ? 16 : 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _HomeSearchField(
                  controller: searchController,
                  query: query,
                  hintText: settings.text(StorefrontText.homeSearchHint),
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                  onClear: onClearSearch,
                ),
              ),
              SizedBox(height: isWide ? 11 : 13),
              _PopularSearches(
                controller: searchController,
                onSelected: onSearchSubmitted,
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

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 350),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 55, child: copyCard),
                const SizedBox(width: 18),
                Expanded(
                  flex: 45,
                  child: Stack(children: [Positioned.fill(child: hero)]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeadline extends StatelessWidget {
  const _HomeHeadline({required this.title, required this.compact});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontFamily: AppTheme.displayFont,
      fontSize: compact ? 30 : 33,
      height: 1.12,
      fontWeight: FontWeight.w500,
      letterSpacing: compact ? -0.35 : -0.45,
      color: AppColors.ink,
    );

    const accentText = 'crear y expresar';
    final accentStart = title.toLowerCase().indexOf(accentText);
    if (accentStart >= 0) {
      final accentEnd = accentStart + accentText.length;
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: title.substring(0, accentStart)),
            TextSpan(
              text: title.substring(accentStart, accentEnd),
              style: const TextStyle(
                color: AppColors.pinkStrong,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(text: title.substring(accentEnd)),
          ],
        ),
        maxLines: compact ? 4 : 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Palabra clave en itálica rosada editorial
    final trimmed = title.trim();
    final lastSpace = trimmed.lastIndexOf(' ');
    if (lastSpace > 0 && lastSpace < trimmed.length - 1) {
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: trimmed.substring(0, lastSpace + 1)),
            TextSpan(
              text: trimmed.substring(lastSpace + 1),
              style: const TextStyle(
                color: AppColors.pinkStrong,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        maxLines: compact ? 4 : 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      title,
      maxLines: compact ? 4 : 3,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
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
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, size: 19, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.ink, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted, fontSize: 12.5),
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
              height: 36,
              child: FilledButton(
                onPressed: () => onSubmitted(controller.text),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(78, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
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
    const searches = ['Limpiapipas', 'Cintas satinadas'];
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
      iconBackground: AppColors.ink,
      iconColor: Colors.white,
      title: 'Cotiza sin registro',
      description:
          'Selecciona tus materiales y coordina directo sin contraseñas.',
    ),
    _TrustContent(
      icon: Icons.percent_rounded,
      iconBackground: AppColors.ink,
      iconColor: Colors.white,
      title: 'Precios por volumen',
      description:
          'Escalas automáticas por mayor en limpiapipas, cintas y accesorios.',
    ),
    _TrustContent(
      icon: Icons.local_shipping_outlined,
      iconBackground: AppColors.ink,
      iconColor: Colors.white,
      title: 'Recojo y envíos Shalom',
      description:
          'Recojo en nuestro local de Huancayo o envío seguro a todo el Perú.',
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: content.iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, size: 18, color: content.iconColor),
          ),
          const SizedBox(width: 13),
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
                      ?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  content.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11, height: 1.35),
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
    final trimmed = title.trim();
    final lastSpace = trimmed.lastIndexOf(' ');
    final headingStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontFamily: AppTheme.displayFont,
      fontSize: 27,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DESTACADOS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.8,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 34, height: 1, color: AppColors.border),
              ],
            ),
            const SizedBox(height: 5),
            if (lastSpace > 0 && lastSpace < trimmed.length - 1)
              Text.rich(
                TextSpan(
                  style: headingStyle,
                  children: [
                    TextSpan(text: trimmed.substring(0, lastSpace + 1)),
                    TextSpan(
                      text: trimmed.substring(lastSpace + 1),
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              )
            else
              Text(trimmed, style: headingStyle),
            const SizedBox(height: 3),
            Text(
              'Los favoritos de nuestros artesanos y decoradores',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 12),
            ),
          ],
        );
        final actionButton = FilledButton.icon(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
          icon: const Icon(Icons.grid_view_rounded, size: 17),
          label: const Text('Ver todo el catálogo'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: actionButton),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: 12),
            actionButton,
          ],
        );
      },
    );
  }
}

class _FeaturedProducts extends StatelessWidget {
  const _FeaturedProducts({
    required this.products,
    required this.onProduct,
    this.onAddToCart,
  });

  final List<CatalogTile> products;
  final ProductSelected onProduct;
  final ProductSelected? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 620;
        final targetColumns = isDesktop
            ? (constraints.maxWidth >= 1060 ? 5 : 4)
            : isTablet
            ? 3
            : 2;
        final visibleProducts = products
            .take(isDesktop ? targetColumns : 6)
            .toList(growable: false);
        final itemCount = visibleProducts.length;
        final columns = itemCount < targetColumns ? itemCount : targetColumns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns == 0 ? 1 : columns,
            mainAxisExtent: isDesktop
                ? 312
                : isTablet
                ? 312
                : 266,
            crossAxisSpacing: isDesktop ? 16 : 12,
            mainAxisSpacing: isDesktop ? 16 : 12,
          ),
          itemBuilder: (context, index) {
            final tile = visibleProducts[index];
            return ProductCard(
              product: tile.product,
              variant: tile.variant,
              compact: !isTablet,
              showCategory: true,
              onTap: () => onProduct(tile.product, tile.variant?.id),
              onAdd: onAddToCart,
            );
          },
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.totalCount,
    required this.onProduct,
    this.onAddToCart,
    this.onLoadMore,
  });

  final List<CatalogTile> results;
  final int totalCount;
  final ProductSelected onProduct;
  final ProductSelected? onAddToCart;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No encontramos coincidencias',
        message: 'Prueba con un color, código o nombre de producto.',
      );
    }
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: constraints.maxWidth < 600 ? 210 : 250,
              mainAxisExtent: constraints.maxWidth < 600 ? 266 : 300,
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
                onAdd: onAddToCart,
              );
            },
          ),
        ),
        if (onLoadMore != null) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more_rounded),
            label: Text(
              'Mostrar más resultados (${results.length} de $totalCount)',
            ),
          ),
        ],
      ],
    );
  }
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
