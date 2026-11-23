import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin/admin_portal.dart';
import 'config/feature_flags.dart';
import 'data/catalog_repository.dart';
import 'data/customer_account_repository.dart';
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
import 'screens/account_screen.dart';
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
import 'services/quote_pdf_share_service.dart';
import 'services/simulated_payment_service.dart';
import 'services/supabase_bootstrap.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';
import 'widgets/app_notice.dart';
import 'widgets/assistant_guide.dart';
import 'widgets/skeleton_loader.dart';
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
    ChangeNotifierProvider.value(
      value: store,
      child: ExpresionesApp(supabaseClient: supabase.client),
    ),
  );
  unawaited(store.initialize());
}

class ExpresionesApp extends StatelessWidget {
  const ExpresionesApp({super.key, this.supabaseClient});

  final SupabaseClient? supabaseClient;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppStore>().storefrontSettings;
    return MaterialApp(
      title: settings.text(StorefrontText.brandName),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(supabaseClient: supabaseClient),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.supabaseClient});

  final SupabaseClient? supabaseClient;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final _guidePreferences = const GuidePreferences();
  final _navigationKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());
  final _assistantButtonKey = GlobalKey();
  int _catalogSearchRequest = 0;
  CustomerAccountRepository? _customerAccounts;
  StreamSubscription<AuthState>? _customerAuthSubscription;
  CustomerProfile? _customerProfile;
  bool _customerAuthReady = false;
  bool _openingPayment = false;
  bool _openingPickupVerification = false;
  int _profileRequest = 0;
  int _index = 0;
  ProductCategory? _catalogCategory;
  String? _catalogFamilyId;
  bool _guideCheckScheduled = false;
  bool _assistantMuted = false;

  bool get _customerAccountsEnabled =>
      (FeatureFlags.appEndToEnd || FeatureFlags.customerAccounts) &&
      widget.supabaseClient != null;

  bool get _paymentsEnabled =>
      FeatureFlags.appEndToEnd && _customerAccounts != null;

  @override
  void initState() {
    super.initState();
    if (_customerAccountsEnabled) {
      _customerAccounts = CustomerAccountRepository(
        client: widget.supabaseClient!,
      );
      _customerAuthSubscription = _customerAccounts!.authChanges.listen(
        (_) => unawaited(_refreshCustomerProfile()),
        onError: (_, _) => unawaited(_refreshCustomerProfile()),
      );
      unawaited(_refreshCustomerProfile());
    }
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _refreshCustomerProfile() async {
    final accounts = _customerAccounts;
    if (accounts == null) return;
    final request = ++_profileRequest;
    try {
      final profile = await accounts.currentProfile(includeAvatar: false);
      if (!mounted || request != _profileRequest) return;
      setState(() {
        _customerProfile = profile;
        _customerAuthReady = true;
      });
    } catch (_) {
      if (!mounted || request != _profileRequest) return;
      setState(() {
        if (_customerProfile?.userId != accounts.client.auth.currentUser?.id) {
          _customerProfile = null;
        }
        _customerAuthReady = true;
      });
    }
  }

  @override
  void dispose() {
    _customerAuthSubscription?.cancel();
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
      _catalogFamilyId = null;
      _catalogSearchRequest = 0;
      _index = 1;
    });
  }

  void _openCatalogFamily(CatalogProduct product) {
    setState(() {
      _catalogCategory = product.category;
      _catalogFamilyId = product.id;
      _catalogSearchRequest = 0;
      _index = 1;
    });
  }

  void _showQuote() => _selectDestination(2);

  void _addCardProduct(
    AppStore store,
    CatalogProduct product,
    String? variantId,
  ) {
    if (variantId == null &&
        product.variants.any((variant) => variant.isActive)) {
      _openCatalogFamily(product);
      return;
    }
    if (!product.canRequest(1, variantId: variantId) ||
        !store.addProduct(product, variantId: variantId)) {
      showAppNotice(
        context,
        'No se pudo agregar otra unidad. Revisa el carrito.',
      );
      return;
    }
    final variant = product.variantById(variantId);
    final label = variant == null ? product.name : variantDisplayName(variant);
    showAppNotice(
      context,
      '$label agregado a tu carrito.',
      actionLabel: 'Ver carrito',
      onAction: _showQuote,
    );
  }

  void _showHelp() => _selectDestination(_customerAccountsEnabled ? 4 : 3);

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
          customerAccountsEnabled: _customerAccountsEnabled,
          onBack: () => Navigator.of(privacyContext).pop(),
          onClearLocalData: store.clearLocalData,
          onAdminLogin: () => unawaited(_openAdminPortal()),
        ),
      ),
    );
  }

  void _openProduct(CatalogProduct product, String? variantId) {
    final store = context.read<AppStore>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          final currentGroup = product.attributes['catalogGroup']
              ?.toUpperCase()
              .trim();
          final sameGroup = currentGroup != null && currentGroup.isNotEmpty
              ? store.products
                    .where(
                      (p) =>
                          p.id != product.id &&
                          p.isActive &&
                          p.attributes['catalogGroup']?.toUpperCase().trim() ==
                              currentGroup,
                    )
                    .toList(growable: false)
              : <CatalogProduct>[];
          final related = sameGroup.isNotEmpty
              ? sameGroup
              : store.products
                    .where(
                      (p) =>
                          p.id != product.id &&
                          p.isActive &&
                          p.category == product.category,
                    )
                    .toList(growable: false);

          final detailScreen = ProductDetailScreen(
            product: product,
            initialVariantId: variantId,
            relatedProducts: related,
            settings: store.storefrontSettings,
            onSelectRelated: (p) => _openProduct(p, null),
            onNavigateCategory: (category) {
              Navigator.of(routeContext).pop();
              _showCatalog(category);
            },
            onNavigateHome: () {
              Navigator.of(routeContext).pop();
              setState(() => _index = 0);
            },
            onOpenQuote: () {
              Navigator.of(routeContext).pop();
              _showQuote();
            },
            onOpenHelp: () {
              Navigator.of(routeContext).pop();
              _showHelp();
            },
            onBuyNow: ({required quantity, variantId, required customization}) {
              store.addProduct(
                product,
                quantity: quantity,
                variantId: variantId,
                customization: customization,
              );
              Navigator.of(routeContext).pop();
              _openCoordination();
            },
            onHelp: () => _showContextGuide(
              routeContext,
              const JashyTourStep(
                title: 'Elige y agrega',
                message: 'Elige una opción y la cantidad.',
                imageAsset: 'assets/images/jashy_chibi_book.webp',
              ),
            ),
            onAdd: ({required quantity, variantId, required customization}) {
              store.addProduct(
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
          );

          return detailScreen;
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.recordProductView(product, variantId);
    });
  }

  void _openCoordination() {
    final store = context.read<AppStore>();
    if (!store.hasQuote) return;
    final profile = _customerProfile;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (coordinationContext) => _flowScreen(
          CoordinationScreen(
            settings: store.storefrontSettings,
            customerAccountsEnabled: _customerAccountsEnabled,
            onSelectCategory: (category) {
              Navigator.of(coordinationContext).popUntil((r) => r.isFirst);
              _showCatalog(category);
            },
            onOpenHelp: () {
              Navigator.of(coordinationContext).popUntil((r) => r.isFirst);
              _showHelp();
            },
            initial: profile == null
                ? store.details
                : store.details.copyWith(
                    name: profile.fullName,
                    phone: profile.phone,
                  ),
            earliestDate: store.earliestDesiredDate,
            deliveryWeekdays: store.deliveryWeekdaysFor,
            pickupTimeSlots: store.pickupTimeSlots,
            pickupTimeSlotsForDate: store.pickupTimeSlotsFor,
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
        builder: (reviewContext) => _flowScreen(
          ReviewScreen(
            settings: store.storefrontSettings,
            customerAccountsEnabled: _customerAccountsEnabled,
            onSelectCategory: (category) {
              Navigator.of(reviewContext).popUntil((r) => r.isFirst);
              _showCatalog(category);
            },
            onOpenHelp: () {
              Navigator.of(reviewContext).popUntil((r) => r.isFirst);
              _showHelp();
            },
            lines: lines,
            details: details,
            quoteId: quoteId,
            message: message,
            onSharePdf: (sharePositionOrigin) => QuotePdfShareService.share(
              quoteId: quoteId,
              lines: lines,
              details: details,
              sharePositionOrigin: sharePositionOrigin,
            ),
            onSendWhatsapp: FeatureFlags.appEndToEnd
                ? null
                : () async {
                    final number =
                        store.storefrontSettings.normalizedWhatsappNumber;
                    final shortMessage = QuoteMessageBuilder.buildWhatsappIntro(
                      id: quoteId,
                      details: details,
                    );
                    final uri = Uri.https('wa.me', '/$number', {
                      'text': shortMessage,
                    });
                    final opened = await launchUrl(
                      uri,
                      mode: kIsWeb
                          ? LaunchMode.platformDefault
                          : LaunchMode.externalApplication,
                    );
                    if (!opened) {
                      throw StateError('No se pudo abrir WhatsApp.');
                    }
                    unawaited(store.recordQuoteSent());
                  },
            onCopyMessage: () {
              Clipboard.setData(ClipboardData(text: message));
            },
            onEditQuote: () {
              setState(() => _index = 2);
              Navigator.of(reviewContext).popUntil((route) => route.isFirst);
            },
            onContinueToPayment: _paymentsEnabled
                ? () => unawaited(_openPayment(reviewContext, lines, details))
                : null,
          ),
        ),
      ),
    );
  }

  /// Pantallas del flujo de compra: se abren encima de las pestañas y
  /// dibujan su propia barra superior con flecha de regreso.
  Widget _flowScreen(Widget child) => Scaffold(body: SafeArea(child: child));

  Future<void> _openPayment(
    BuildContext reviewContext,
    List<ResolvedQuoteLine> lines,
    CoordinationDetails details,
  ) async {
    if (_openingPayment) return;
    _openingPayment = true;
    try {
      await _startPayment(reviewContext, lines, details);
    } catch (_) {
      if (reviewContext.mounted) {
        showAppNotice(
          reviewContext,
          'No pudimos abrir el pago. Revisa tu conexión e inténtalo otra vez.',
        );
      }
    } finally {
      _openingPayment = false;
    }
  }

  Future<void> _startPayment(
    BuildContext reviewContext,
    List<ResolvedQuoteLine> lines,
    CoordinationDetails details,
  ) async {
    final accounts = _customerAccounts;
    if (accounts == null) return;
    final profile = await accounts.currentProfile(includeAvatar: false);
    if (profile == null) {
      if (!reviewContext.mounted) return;
      final authenticated = await Navigator.of(reviewContext).push<bool>(
        MaterialPageRoute<bool>(
          builder: (accountContext) => Scaffold(
            body: SafeArea(
              child: AccountScreen(
                repository: accounts,
                checkoutMode: true,
                initialName: details.name,
                initialPhone: details.phone,
                onAuthenticated: () => Navigator.of(accountContext).pop(true),
              ),
            ),
          ),
        ),
      );
      if (authenticated != true || !reviewContext.mounted) return;
    }
    if (!mounted || !reviewContext.mounted) return;
    final store = context.read<AppStore>();
    final service = SimulatedPaymentService();
    final amount = lines.fold<double>(0, (sum, line) => sum + line.total);
    final quantity = lines.fold<int>(
      0,
      (sum, line) => sum + line.line.quantity,
    );
    if (amount <= 0 || amount > 100000 || quantity < 1 || quantity > 10000) {
      showAppNotice(
        reviewContext,
        'Revisa las cantidades y el total del carrito antes de pagar.',
      );
      return;
    }
    if (!_isCheckoutCurrent(store, lines, details)) {
      showAppNotice(
        reviewContext,
        'El catálogo o los horarios cambiaron. Vuelve al carrito para revisar tu pedido.',
      );
      return;
    }
    final orderId = service.createOrderId();
    await Navigator.of(reviewContext).push(
      MaterialPageRoute<void>(
        builder: (paymentContext) => Scaffold(
          body: SafeArea(
            child: PaymentScreen(
              lines: lines,
              details: details,
              settings: store.storefrontSettings,
              onBack: () => Navigator.of(paymentContext).pop(),
              onProcessPayment: (method) {
                if (!_isCheckoutCurrent(store, lines, details)) {
                  throw const FormatException(
                    'El catálogo o los horarios cambiaron. Vuelve al carrito para revisar tu pedido.',
                  );
                }
                return service.process(method: method, amount: amount);
              },
              onApproved: (payment) async {
                final order = CheckoutOrder.fromQuote(
                  id: orderId,
                  lines: lines,
                  details: details,
                  payment: payment,
                  createdAt: payment.processedAt,
                );
                await accounts.saveOrder(order);
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

  bool _isCheckoutCurrent(
    AppStore store,
    List<ResolvedQuoteLine> reviewed,
    CoordinationDetails details,
  ) {
    final current = {
      for (final item in store.resolvedLines) item.line.key: item,
    };
    if (current.length != reviewed.length) return false;
    final quantities = <(String, String?), int>{};
    for (final item in reviewed) {
      final updated = current[item.line.key];
      if (updated == null ||
          updated.line.quantity != item.line.quantity ||
          updated.unitPrice != item.unitPrice ||
          (item.line.variantId != null && updated.variant?.isActive != true)) {
        return false;
      }
      final key = (updated.product.id, updated.line.variantId);
      final quantity = (quantities[key] ?? 0) + updated.line.quantity;
      if (!updated.product.canRequest(quantity, variantId: key.$2)) {
        return false;
      }
      quantities[key] = quantity;
    }
    final date = details.desiredDate;
    if (date == null ||
        !store.isDesiredDateAvailable(date, details.deliveryMethod)) {
      return false;
    }
    return details.deliveryMethod != DeliveryMethod.pickup ||
        store
            .pickupTimeSlotsFor(date)
            .contains(details.customFields['Horario de recojo']);
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

  Future<void> _openPickupVerification() async {
    if (_openingPickupVerification) return;
    final client = SupabaseBootstrap.pickupStaffClient();
    _openingPickupVerification = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              AdminPortal(client: client, pickupVerificationOnly: true),
        ),
      );
    } finally {
      try {
        if (client.auth.currentSession != null) await client.auth.signOut();
      } on AuthException {
        // The isolated session is discarded even when the server is unreachable.
      } finally {
        _openingPickupVerification = false;
        await client.dispose();
      }
    }
  }

  void _scheduleAssistantOnboarding() {
    if (_guideCheckScheduled) return;
    _guideCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final muted = await _guidePreferences.isAssistantMuted();
      final shouldShow = await _guidePreferences.shouldShowOnboarding();
      if (!mounted) return;
      setState(() {
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
      imageAsset: 'assets/images/jashy_chibi_assistant.webp',
    ),
    JashyTourStep(
      title: 'Inicio',
      message: 'Busca materiales aquí.',
      targetKey: _guideNavigationKey(0),
      imageAsset: 'assets/images/jashy_chibi_assistant.webp',
    ),
    JashyTourStep(
      title: 'Catálogo',
      message: 'Mira productos, colores y precios. Precio por volumen: docena, medio cajón o cajón completo.',
      targetKey: _guideNavigationKey(1),
      imageAsset: 'assets/images/jashy_chibi_book.webp',
    ),
    JashyTourStep(
      title: 'Carrito',
      message: 'Revisa productos y cantidades.',
      targetKey: _guideNavigationKey(2),
      imageAsset: 'assets/images/jashy_chibi_writing.webp',
    ),
    if (_customerAccountsEnabled)
      JashyTourStep(
        title: 'Cuenta',
        message: 'Revisa tus compras guardadas.',
        targetKey: _guideNavigationKey(3),
        imageAsset: 'assets/images/jashy_chibi_writing.webp',
      ),
    JashyTourStep(
      title: 'Ayuda',
      message: 'Encuentra respuestas o escríbenos.',
      targetKey: _guideNavigationKey(_customerAccountsEnabled ? 4 : 3),
      imageAsset: 'assets/images/jashy_chibi_question.webp',
    ),
    JashyTourStep(
      title: 'Aquí estaré',
      message: 'Tócame cuando necesites ayuda.',
      targetKey: _assistantButtonKey,
      imageAsset: 'assets/images/jashy_chibi_bouquet.webp',
    ),
  ];

  JashyTourStep _sectionGuideStep({required bool hasQuote}) {
    final messages = <String>[
      'Busca por nombre, color o código.',
      'Toca un producto, elige y agrega. Precio por volumen: docena, medio cajón o cajón completo.',
      hasQuote
          ? 'Cambia cantidades y toca Continuar.'
          : 'Agrega productos desde Catálogo.',
      if (_customerAccountsEnabled) 'Inicia sesión y revisa tus compras.',
      'Abre una pregunta o escríbenos.',
    ];
    final titles = <String>[
      'Inicio',
      'Catálogo',
      'Carrito',
      if (_customerAccountsEnabled) 'Cuenta',
      'Ayuda',
    ];
    final assets = <String>[
      'assets/images/jashy_chibi_assistant.webp',
      'assets/images/jashy_chibi_book.webp',
      'assets/images/jashy_chibi_writing.webp',
      if (_customerAccountsEnabled) 'assets/images/jashy_chibi_writing.webp',
      'assets/images/jashy_chibi_question.webp',
    ];
    return JashyTourStep(
      title: titles[_index],
      message: messages[_index],
      targetKey: _guideNavigationKey(_index),
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

  Widget _assistantHelpButton(
    JashyTourStep step, {
    Key? key,
    double bottomOffset = 0.0,
  }) {
    final tipsBySection = <int, List<String>>{
      0: [
        '¡Bienvenido a Expresiones! 💕 Encuentra aquí los mejores materiales y rosas eternas.',
        '🔍 Tip: Escribe un color o código en el buscador para hallarlo al instante.',
        '🚚 Realizamos envíos diarios a todo el Perú por Shalom y Olva Courier.',
      ],
      1: [
        '🌸 Explora nuestros tonos de limpiapipas y papeles coreanos importados.',
        '📦 Descuentos por volumen: Precios por mayor automáticos a partir de 12 unidades.',
        '🎨 Toca cualquier producto para elegir el tono que más te guste.',
      ],
      2: [
        '🛒 Revisa las cantidades de tus materiales antes de enviar tu cotización.',
        '💬 Al confirmar, tu pedido se enviará ordenado por WhatsApp para coordinar la entrega.',
        '🚚 Elige recojo local en Huancayo o envío a tu agencia favorita.',
      ],
      3: [
        if (_customerAccountsEnabled)
          '👤 Revisa tu historial de compras y pedidos registrados.'
        else
          '❓ ¿Tienes dudas sobre pagos o envíos? Revisa las preguntas frecuentes.',
        '📲 Si prefieres atención directa, escríbenos a nuestro WhatsApp.',
      ],
      4: [
        '❓ ¿Tienes dudas sobre pagos o Shalom? Revisa las preguntas frecuentes.',
        '📲 Si prefieres atención directa, escríbenos a nuestro WhatsApp.',
      ],
    };

    return AssistantHelpButton(
      key: key,
      title: 'Consejo de Jashy 💕',
      message: step.message,
      messages: tipsBySection[_index] ?? [step.message],
      imageAsset: step.imageAsset,
      bottomOffset: bottomOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (_paymentsEnabled && !_customerAuthReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_paymentsEnabled && _customerProfile == null) {
      return Scaffold(
        body: SafeArea(
          child: AccountScreen(
            repository: _customerAccounts!,
            accessGate: true,
            onVerifyPickup: () => unawaited(_openPickupVerification()),
            onAuthenticated: () => unawaited(_refreshCustomerProfile()),
          ),
        ),
      );
    }

    if (store.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: Text(
            'Expresiones',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: const SafeArea(
          child: SingleChildScrollView(
            child: CatalogGridSkeleton(itemCount: 8),
          ),
        ),
      );
    }
    _scheduleAssistantOnboarding();

    final page = switch (_index) {
      0 => HomeScreen(
        settings: store.storefrontSettings,
        products: store.products,
        popularProducts: store.popularProducts,
        onBrowse: _showCatalog,
        onProduct: _openProduct,
        onAddToCart: FeatureFlags.appEndToEnd
            ? (product, variantId) => _addCardProduct(store, product, variantId)
            : null,
        onOpenFamily: _openCatalogFamily,
        onOpenQuote: _showQuote,
        onOpenHelp: _showHelp,
        quoteQuantity: store.cartQuantity,
        onZeroResultSearch: store.recordZeroResultSearch,
        lastOrder: _paymentsEnabled ? store.lastOrder : null,
        onOpenLastOrder: _paymentsEnabled ? _openLastOrder : null,
      ),
      1 => CatalogScreen(
        settings: store.storefrontSettings,
        key: ValueKey('$_catalogCategory:${_catalogFamilyId ?? ''}'),
        products: store.products,
        initialCategory: _catalogCategory,
        initialFamilyId: _catalogFamilyId,
        searchRequest: _catalogSearchRequest,
        onCategoryChanged: (category) => setState(() {
          _catalogCategory = category;
          _catalogFamilyId = null;
          _catalogSearchRequest = 0;
        }),
        onProduct: _openProduct,
        onAddToCart: FeatureFlags.appEndToEnd
            ? (product, variantId) => _addCardProduct(store, product, variantId)
            : null,
        onBack: () => setState(() => _index = 0),
        onOpenQuote: _showQuote,
        onOpenHelp: _showHelp,
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
        onSelectCategory: _showCatalog,
        onOpenHelp: _showHelp,
      ),
      3 when _customerAccountsEnabled => AccountScreen(
        repository: _customerAccounts!,
      ),
      _ => HelpScreen(
        settings: store.storefrontSettings,
        customerAccountsEnabled: _customerAccountsEnabled,
        onBack: () => setState(() => _index = 0),
        onSelectCategory: _showCatalog,
        onOpenQuote: _showQuote,
        onPrivacy: _openPrivacy,
        onAdminLogin: () => unawaited(_openAdminPortal()),
        onVerifyPickup: _paymentsEnabled
            ? () => unawaited(_openPickupVerification())
            : null,
        assistantMuted: _assistantMuted,
        onAssistantGuide: () => _repeatAssistantTour(context),
      ),
    };

    // Jashy flota solo donde no tapa una barra de acción (el carrito tiene su
    // propio botón "Continuar" fijo).
    final helpIndex = _customerAccountsEnabled ? 4 : 3;
    final showAssistant = _index == 0 || _index == 1 || _index == helpIndex;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(key: ValueKey(_index), child: page),
        ),
      ),
      bottomNavigationBar: _AppTabBar(
        selectedIndex: _index,
        quoteQuantity: store.cartQuantity,
        onSelect: _selectDestination,
        showAccount: _customerAccountsEnabled,
        itemKeys: _navigationKeys,
      ),
      floatingActionButton: showAssistant
          ? _assistantHelpButton(
              _sectionGuideStep(hasQuote: store.hasQuote),
              key: _assistantButtonKey,
            )
          : null,
    );
  }

  void _selectDestination(int value) {
    setState(() {
      _catalogSearchRequest = 0;
      if (value == 1 && _catalogCategory == null) {
        _catalogCategory = ProductCategory.materials;
      }
      _index = value;
    });
  }

  GlobalKey _guideNavigationKey(int index) => _navigationKeys[index];
}

/// Barra inferior de la app: única navegación principal.
///
/// En tablets y navegadores se limita al ancho de la columna de contenido para
/// que los destinos no queden separados por cientos de píxeles.
class _AppTabBar extends StatelessWidget {
  const _AppTabBar({
    required this.selectedIndex,
    required this.quoteQuantity,
    required this.onSelect,
    required this.showAccount,
    this.itemKeys,
  });

  final int selectedIndex;
  final int quoteQuantity;
  final ValueChanged<int> onSelect;
  final bool showAccount;
  final List<GlobalKey>? itemKeys;

  @override
  Widget build(BuildContext context) {
    final helpIndex = showAccount ? 4 : 3;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: NavigationBar(
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
                  backgroundColor: AppColors.rose,
                  count: quoteQuantity,
                  isLabelVisible: quoteQuantity > 0,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                selectedIcon: Badge.count(
                  backgroundColor: AppColors.rose,
                  count: quoteQuantity,
                  isLabelVisible: quoteQuantity > 0,
                  child: const Icon(Icons.shopping_bag_rounded),
                ),
                label: 'Carrito',
              ),
              if (showAccount)
                NavigationDestination(
                  key: itemKeys?[3],
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: 'Cuenta',
                ),
              NavigationDestination(
                key: itemKeys?[helpIndex],
                icon: const Icon(Icons.help_outline_rounded),
                selectedIcon: const Icon(Icons.help_rounded),
                label: 'Ayuda',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
