import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/catalog_repository.dart';
import 'data/production_capacity_repository.dart';
import 'data/product_popularity_repository.dart';
import 'data/site_settings_repository.dart';
import 'models/catalog_models.dart';
import 'models/checkout_order.dart';
import 'models/coordination_details.dart';
import 'models/quote_line.dart';
import 'models/storefront_settings.dart';
import 'screens/catalog_screen.dart';
import 'screens/coordination_screen.dart';
import 'screens/help_screen.dart';
import 'screens/home_screen.dart';
import 'screens/order_success_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/quote_screen.dart';
import 'screens/review_screen.dart';
import 'services/quote_message.dart';
import 'services/simulated_payment_service.dart';
import 'services/supabase_bootstrap.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';
import 'widgets/app_notice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabase = await SupabaseBootstrap.initialize();

  final repository = CatalogRepository(client: supabase.client);
  final store = AppStore(
    repository.loadProducts,
    catalogStreamLoader: repository.watchProducts,
    capacityRepository: SupabaseCapacityRepository(client: supabase.client),
    siteSettingsRepository: SupabaseSiteSettingsRepository(
      client: supabase.client,
    ),
    popularityRepository: SupabaseProductPopularityRepository(
      client: supabase.client,
    ),
    // Analytics stays disabled until the planned Phase 9.
    telemetry: null,
  );

  runApp(
    ChangeNotifierProvider.value(value: store, child: const ExpresionesApp()),
  );
  unawaited(store.initialize());
}

class ExpresionesApp extends StatelessWidget {
  const ExpresionesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppStore>().storefrontSettings;
    return MaterialApp(
      title: settings.text(StorefrontText.brandName),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  ProductCategory? _catalogCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<AppStore>().detectAbandonedQuote());
    }
  }

  void _showCatalog([ProductCategory? category]) {
    setState(() {
      _catalogCategory = category;
      _index = 1;
    });
  }

  void _showQuote() => setState(() => _index = 2);

  void _openLastOrder(CheckoutOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(body: SafeArea(child: _orderSuccessScreen(order))),
      ),
    );
  }

  void _openPrivacy() {
    final store = context.read<AppStore>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (privacyContext) => PrivacyScreen(
          settings: store.storefrontSettings,
          onBack: () => Navigator.of(privacyContext).pop(),
          onClearLocalData: store.clearLocalData,
          onAdminLogin: () => unawaited(_openAdminPortal()),
        ),
      ),
    );
  }

  void _openProduct(CatalogProduct product, String? variantId) {
    context.read<AppStore>().recordProductView(product, variantId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          body: SafeArea(
            child: ProductDetailScreen(
              product: product,
              initialVariantId: variantId,
              onAdd: ({required quantity, variantId, required customization}) {
                context.read<AppStore>().addProduct(
                  product,
                  quantity: quantity,
                  variantId: variantId,
                  customization: customization,
                );
                Navigator.of(routeContext).pop();
                showAppNotice(
                  context,
                  '$quantity × ${product.name} agregado a tu carrito.',
                  actionLabel: 'Ver',
                  onAction: _showQuote,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openCoordination() {
    final store = context.read<AppStore>();
    if (!store.hasQuote) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (coordinationContext) => Scaffold(
          body: SafeArea(
            child: CoordinationScreen(
              settings: store.storefrontSettings,
              initial: store.details,
              earliestDate: store.earliestDesiredDate,
              deliveryWeekdays: store.deliveryWeekdaysFor,
              isDateAvailable: store.isDesiredDateAvailable,
              onSubmit: (details) {
                store.updateDetails(details);
                _openReview(coordinationContext, details);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openReview(
    BuildContext coordinationContext,
    CoordinationDetails details,
  ) {
    final store = context.read<AppStore>();
    final lines = store.resolvedLines;
    final quoteId = QuoteMessageBuilder.quoteId(DateTime.now());
    final message = QuoteMessageBuilder.build(
      id: quoteId,
      lines: lines,
      details: details,
      brandName: store.storefrontSettings.text(StorefrontText.brandName),
    );

    Navigator.of(coordinationContext).push(
      MaterialPageRoute<void>(
        builder: (reviewContext) => Scaffold(
          body: SafeArea(
            child: ReviewScreen(
              settings: store.storefrontSettings,
              lines: lines,
              details: details,
              quoteId: quoteId,
              message: message,
              onSendWhatsapp: () =>
                  _openWhatsapp(message, recordQuoteSent: true),
              onCopyMessage: () {
                Clipboard.setData(ClipboardData(text: message));
              },
              onEditQuote: () {
                setState(() => _index = 2);
                Navigator.of(reviewContext).popUntil((route) => route.isFirst);
              },
              onContinueToPayment: () =>
                  _openPayment(reviewContext, lines, details),
            ),
          ),
        ),
      ),
    );
  }

  void _openPayment(
    BuildContext reviewContext,
    List<ResolvedQuoteLine> lines,
    CoordinationDetails details,
  ) {
    final store = context.read<AppStore>();
    final service = SimulatedPaymentService();
    final amount = lines.fold<double>(0, (sum, line) => sum + line.total);
    Navigator.of(reviewContext).push(
      MaterialPageRoute<void>(
        builder: (paymentContext) => Scaffold(
          body: SafeArea(
            child: PaymentScreen(
              lines: lines,
              details: details,
              settings: store.storefrontSettings,
              onBack: () => Navigator.of(paymentContext).pop(),
              onProcessPayment: (method) =>
                  service.process(method: method, amount: amount),
              onApproved: (payment) async {
                final order = CheckoutOrder.fromQuote(
                  id: service.createOrderId(),
                  lines: lines,
                  details: details,
                  payment: payment,
                  createdAt: payment.processedAt,
                );
                await store.completeCheckout(order);
                if (!paymentContext.mounted || !mounted) return;
                setState(() => _index = 0);
                Navigator.of(paymentContext).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: SafeArea(child: _orderSuccessScreen(order)),
                    ),
                  ),
                  (route) => route.isFirst,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderSuccessScreen(CheckoutOrder order) {
    final store = context.read<AppStore>();
    final message = QuoteMessageBuilder.buildOrder(
      order: order,
      brandName: store.storefrontSettings.text(StorefrontText.brandName),
    );
    return OrderSuccessScreen(
      order: order,
      settings: store.storefrontSettings,
      onSendWhatsapp: () => _openWhatsapp(message, recordQuoteSent: true),
      onCopySummary: () => Clipboard.setData(ClipboardData(text: message)),
      onHome: () => _finishOrderFlow(catalog: false),
      onNewOrder: () => _finishOrderFlow(catalog: true),
    );
  }

  void _finishOrderFlow({required bool catalog}) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _catalogCategory = catalog ? ProductCategory.materials : null;
      _index = catalog ? 1 : 0;
    });
  }

  Future<void> _openWhatsapp(
    String message, {
    bool recordQuoteSent = false,
  }) async {
    final number = context
        .read<AppStore>()
        .storefrontSettings
        .normalizedWhatsappNumber;
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );
    final opened = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!opened) throw StateError('No se pudo abrir WhatsApp.');
    if (recordQuoteSent && mounted) {
      await context.read<AppStore>().recordQuoteSent();
    }
  }

  Future<void> _openAdminPortal() async {
    final uri = Uri.parse('https://expresiones.pages.dev/admin/');
    final opened = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!opened) throw StateError('No se pudo abrir el acceso administrativo.');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (store.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final page = switch (_index) {
      0 => HomeScreen(
        settings: store.storefrontSettings,
        products: store.products,
        popularProducts: store.popularProducts,
        onBrowse: _showCatalog,
        onProduct: _openProduct,
        onOpenQuote: _showQuote,
        quoteQuantity: store.cartQuantity,
        onZeroResultSearch: store.recordZeroResultSearch,
        lastOrder: store.lastOrder,
        onOpenLastOrder: _openLastOrder,
      ),
      1 => CatalogScreen(
        settings: store.storefrontSettings,
        key: ValueKey(_catalogCategory),
        products: store.products,
        initialCategory: _catalogCategory,
        onProduct: _openProduct,
        onBack: () => setState(() => _index = 0),
        onOpenQuote: _showQuote,
        onZeroResultSearch: store.recordZeroResultSearch,
      ),
      2 => QuoteScreen(
        settings: store.storefrontSettings,
        lines: store.resolvedLines,
        onQuantityChanged: store.updateQuantity,
        onRemove: store.removeLine,
        onContinue: _openCoordination,
        onBrowse: _showCatalog,
        onBack: () => setState(() => _index = 0),
      ),
      _ => HelpScreen(
        settings: store.storefrontSettings,
        onContact: () => _openWhatsapp(
          'Hola, ${store.storefrontSettings.text(StorefrontText.brandName)}. Quisiera hacer una consulta.',
        ),
        onPrivacy: _openPrivacy,
        onAdminLogin: () => unawaited(_openAdminPortal()),
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  _DesktopNavigation(
                    settings: store.storefrontSettings,
                    currentIndex: _index,
                    quoteQuantity: store.cartQuantity,
                    onSelect: _selectDestination,
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: KeyedSubtree(key: ValueKey(_index), child: page),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: _selectDestination,
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Inicio',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Catálogo',
                    ),
                    NavigationDestination(
                      icon: Badge.count(
                        count: store.cartQuantity,
                        isLabelVisible: store.cartQuantity > 0,
                        child: const Icon(Icons.shopping_bag_outlined),
                      ),
                      selectedIcon: Badge.count(
                        count: store.cartQuantity,
                        isLabelVisible: store.cartQuantity > 0,
                        child: const Icon(Icons.shopping_bag_rounded),
                      ),
                      label: 'Carrito',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.help_outline_rounded),
                      selectedIcon: Icon(Icons.help_rounded),
                      label: 'Ayuda',
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _selectDestination(int value) {
    setState(() {
      if (value == 1) _catalogCategory = null;
      _index = value;
    });
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.settings,
    required this.currentIndex,
    required this.quoteQuantity,
    required this.onSelect,
  });

  final StorefrontSettings settings;
  final int currentIndex;
  final int quoteQuantity;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final destinations =
        <({IconData icon, IconData selectedIcon, String label})>[
          (
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Inicio',
          ),
          (
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view_rounded,
            label: 'Catálogo',
          ),
          (
            icon: Icons.shopping_bag_outlined,
            selectedIcon: Icons.shopping_bag_rounded,
            label: 'Carrito',
          ),
          (
            icon: Icons.help_outline_rounded,
            selectedIcon: Icons.help_rounded,
            label: 'Ayuda',
          ),
        ];

    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.text(StorefrontText.brandName),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings.text(StorefrontText.brandTagline),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            for (var index = 0; index < destinations.length; index++) ...[
              _DesktopNavigationItem(
                icon: currentIndex == index
                    ? destinations[index].selectedIcon
                    : destinations[index].icon,
                label: destinations[index].label,
                selected: currentIndex == index,
                badgeCount: index == 2 ? quoteQuantity : 0,
                onTap: () => onSelect(index),
              ),
              const SizedBox(height: 6),
            ],
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.pinkSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_open_rounded, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    settings.text(StorefrontText.homeSidebarTitle),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    settings.text(StorefrontText.homeSidebarBody),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: selected
              ? Colors.white.withValues(alpha: .08)
              : AppColors.pinkSoft,
          focusColor: selected
              ? Colors.white.withValues(alpha: .12)
              : AppColors.pinkSoft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Badge.count(
                  count: badgeCount,
                  isLabelVisible: badgeCount > 0,
                  backgroundColor: AppColors.pinkStrong,
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
