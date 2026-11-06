import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/feature_flags.dart';
import 'data/catalog_repository.dart';
import 'data/guide_preferences.dart';
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
import 'widgets/assistant_guide.dart';
import 'widgets/jashy_tour.dart';

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
  final _guidePreferences = const GuidePreferences();
  final _navigationKeys = List<GlobalKey>.generate(4, (_) => GlobalKey());
  final _assistantButtonKey = GlobalKey();
  int _index = 0;
  ProductCategory? _catalogCategory;
  bool _guideCheckScheduled = false;
  bool _assistantReady = false;
  bool _assistantMuted = false;

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
              onHelp: () => _showContextGuide(
                routeContext,
                const JashyTourStep(
                  title: 'Elige y agrega',
                  message: 'Elige una opción y la cantidad.',
                  imageAsset: 'assets/images/jashy_book.png',
                ),
              ),
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
        builder: (coordinationContext) => _checkoutScaffold(
          routeContext: coordinationContext,
          assistantStep: const JashyTourStep(
            title: 'Completa tus datos',
            message: 'Llena los campos y elige entrega y fecha.',
            imageAsset: 'assets/images/jashy_writing.png',
          ),
          child: CoordinationScreen(
            settings: store.storefrontSettings,
            initial: store.details,
            earliestDate: store.earliestDesiredDate,
            deliveryWeekdays: store.deliveryWeekdaysFor,
            pickupTimeSlots: store.pickupTimeSlots,
            isDateAvailable: store.isDesiredDateAvailable,
            onSubmit: (details) {
              store.updateDetails(details);
              _openReview(coordinationContext, details);
            },
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
        builder: (reviewContext) => _checkoutScaffold(
          routeContext: reviewContext,
          assistantStep: const JashyTourStep(
            title: 'Revisa y envía',
            message: 'Verifica todo y envía por WhatsApp.',
            imageAsset: 'assets/images/jashy_writing.png',
          ),
          child: ReviewScreen(
            settings: store.storefrontSettings,
            lines: lines,
            details: details,
            quoteId: quoteId,
            message: message,
            onSendWhatsapp: () => _openWhatsapp(message, recordQuoteSent: true),
            onCopyMessage: () {
              Clipboard.setData(ClipboardData(text: message));
            },
            onEditQuote: () {
              setState(() => _index = 2);
              Navigator.of(reviewContext).popUntil((route) => route.isFirst);
            },
            onContinueToPayment: FeatureFlags.demoPayment
                ? () => _openPayment(reviewContext, lines, details)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _checkoutScaffold({
    required BuildContext routeContext,
    required Widget child,
    required JashyTourStep assistantStep,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final store = context.watch<AppStore>();
        final desktop = constraints.maxWidth >= 1024;
        void leaveCheckout(int destination) {
          Navigator.of(routeContext).popUntil((route) => route.isFirst);
          _selectDestination(destination);
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  _DesktopNavigation(
                    settings: store.storefrontSettings,
                    currentIndex: 2,
                    quoteQuantity: store.cartQuantity,
                    onSelect: leaveCheckout,
                  ),
                Expanded(child: child),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : _MobileNavigation(
                  selectedIndex: 2,
                  quoteQuantity: store.cartQuantity,
                  onSelect: leaveCheckout,
                ),
          floatingActionButton: _assistantHelpButton(assistantStep),
        );
      },
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

  void _scheduleAssistantOnboarding() {
    if (_guideCheckScheduled) return;
    _guideCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final muted = await _guidePreferences.isAssistantMuted();
      final shouldShow = await _guidePreferences.shouldShowOnboarding();
      if (!mounted) return;
      setState(() {
        _assistantReady = true;
        _assistantMuted = muted;
      });
      if (muted || !shouldShow) return;
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        await _showTour(context, steps: _fullTourSteps(), remember: true);
      }
    });
  }

  List<JashyTourStep> _fullTourSteps() => [
    const JashyTourStep(
      title: '¡Hola! Soy Jashy',
      message: 'Te enseñaré cómo cotizar.',
      imageAsset: 'assets/images/jashy_assistant.png',
    ),
    JashyTourStep(
      title: 'Inicio',
      message: 'Busca materiales aquí.',
      targetKey: _navigationKeys[0],
      imageAsset: 'assets/images/jashy_assistant.png',
    ),
    JashyTourStep(
      title: 'Catálogo',
      message: 'Mira productos, colores y precios.',
      targetKey: _navigationKeys[1],
      imageAsset: 'assets/images/jashy_book.png',
    ),
    JashyTourStep(
      title: 'Carrito',
      message: 'Revisa productos y cantidades.',
      targetKey: _navigationKeys[2],
      imageAsset: 'assets/images/jashy_writing.png',
    ),
    JashyTourStep(
      title: 'Ayuda',
      message: 'Encuentra respuestas o escríbenos.',
      targetKey: _navigationKeys[3],
      imageAsset: 'assets/images/jashy_question.png',
    ),
    JashyTourStep(
      title: 'Aquí estaré',
      message: 'Tócame cuando necesites ayuda.',
      targetKey: _assistantButtonKey,
      imageAsset: 'assets/images/jashy_bouquet.png',
    ),
  ];

  JashyTourStep _sectionGuideStep({required bool hasQuote}) {
    final messages = [
      'Busca por nombre, color o código.',
      'Toca un producto, elige y agrega.',
      hasQuote
          ? 'Cambia cantidades y toca Continuar.'
          : 'Agrega productos desde Catálogo.',
      'Abre una pregunta o escríbenos.',
    ];
    final titles = ['Inicio', 'Catálogo', 'Carrito', 'Ayuda'];
    final assets = [
      'assets/images/jashy_assistant.png',
      'assets/images/jashy_book.png',
      'assets/images/jashy_writing.png',
      'assets/images/jashy_question.png',
    ];
    return JashyTourStep(
      title: titles[_index],
      message: messages[_index],
      targetKey: _navigationKeys[_index],
      imageAsset: assets[_index],
    );
  }

  Future<void> _showTour(
    BuildContext guideContext, {
    required List<JashyTourStep> steps,
    bool remember = false,
  }) async {
    final result = await showJashyTour(context: guideContext, steps: steps);
    if (remember) await _guidePreferences.markOnboardingSeen();
    if (result == JashyTourResult.doNotDisturb) {
      await _guidePreferences.muteAssistant();
      if (mounted) setState(() => _assistantMuted = true);
    }
  }

  Future<void> _showContextGuide(
    BuildContext guideContext,
    JashyTourStep step,
  ) => _showTour(guideContext, steps: [step]);

  Future<void> _repeatAssistantTour(BuildContext guideContext) async {
    if (_assistantMuted) {
      await _guidePreferences.unmuteAssistant();
      if (!mounted) return;
      setState(() => _assistantMuted = false);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted && guideContext.mounted) {
      await _showTour(guideContext, steps: _fullTourSteps());
    }
  }

  Widget? _assistantHelpButton(
    JashyTourStep step, {
    Key? key,
    double bottomOffset = 0.0,
  }) {
    if (!_assistantReady || _assistantMuted) return null;
    return AssistantHelpButton(
      key: key,
      title: step.title,
      message: step.message,
      imageAsset: step.imageAsset,
      bottomOffset: bottomOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (store.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _scheduleAssistantOnboarding();

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
        lastOrder: FeatureFlags.demoPayment ? store.lastOrder : null,
        onOpenLastOrder: FeatureFlags.demoPayment ? _openLastOrder : null,
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
        assistantMuted: _assistantMuted,
        onAssistantGuide: () => _repeatAssistantTour(context),
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
                    itemKeys: _navigationKeys,
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
              : _MobileNavigation(
                  selectedIndex: _index,
                  quoteQuantity: store.cartQuantity,
                  onSelect: _selectDestination,
                  itemKeys: _navigationKeys,
                ),
          floatingActionButton: _assistantHelpButton(
            _sectionGuideStep(hasQuote: store.hasQuote),
            key: _assistantButtonKey,
            bottomOffset: _index == 1 ? 64.0 : 0.0,
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

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.selectedIndex,
    required this.quoteQuantity,
    required this.onSelect,
    this.itemKeys,
  });

  final int selectedIndex;
  final int quoteQuantity;
  final ValueChanged<int> onSelect;
  final List<GlobalKey>? itemKeys;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      destinations: [
        NavigationDestination(
          key: itemKeys?[0],
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          key: itemKeys?[1],
          icon: const Icon(Icons.grid_view_outlined),
          selectedIcon: const Icon(Icons.grid_view_rounded),
          label: 'Catálogo',
        ),
        NavigationDestination(
          key: itemKeys?[2],
          icon: Badge.count(
            count: quoteQuantity,
            isLabelVisible: quoteQuantity > 0,
            child: const Icon(Icons.shopping_bag_outlined),
          ),
          selectedIcon: Badge.count(
            count: quoteQuantity,
            isLabelVisible: quoteQuantity > 0,
            child: const Icon(Icons.shopping_bag_rounded),
          ),
          label: 'Carrito',
        ),
        NavigationDestination(
          key: itemKeys?[3],
          icon: const Icon(Icons.help_outline_rounded),
          selectedIcon: const Icon(Icons.help_rounded),
          label: 'Ayuda',
        ),
      ],
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.settings,
    required this.currentIndex,
    required this.quoteQuantity,
    required this.onSelect,
    this.itemKeys,
  });

  final StorefrontSettings settings;
  final int currentIndex;
  final int quoteQuantity;
  final ValueChanged<int> onSelect;
  final List<GlobalKey>? itemKeys;

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
            Center(
              child: Semantics(
                label: settings.text(StorefrontText.brandName),
                header: true,
                child: Image.asset(
                  'assets/images/brand_lockup_black.png',
                  width: 162,
                  height: 162,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < destinations.length; index++) ...[
              _DesktopNavigationItem(
                key: itemKeys?[index],
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
    super.key,
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
