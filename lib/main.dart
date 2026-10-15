import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/catalog_repository.dart';
import 'data/firestore_telemetry_sink.dart';
import 'data/production_capacity_repository.dart';
import 'data/telemetry_local_store.dart';
import 'models/catalog_models.dart';
import 'models/coordination_details.dart';
import 'screens/catalog_screen.dart';
import 'screens/coordination_screen.dart';
import 'screens/help_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/quote_screen.dart';
import 'screens/review_screen.dart';
import 'services/firebase_bootstrap.dart';
import 'services/commerce_telemetry_service.dart';
import 'services/quote_message.dart';
import 'state/app_store.dart';
import 'theme/app_theme.dart';

const _whatsappNumber = '51956744914';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebase = await FirebaseBootstrap.initialize();

  const telemetryEnabled = bool.fromEnvironment(
    'ENABLE_TELEMETRY',
    defaultValue: false,
  );
  final telemetry = CommerceTelemetryService(
    localStore: const SharedPreferencesTelemetryStore(),
    sink: firebase.connected && telemetryEnabled
        ? FirestoreCommerceTelemetrySink(FirebaseFirestore.instance)
        : null,
  );

  final repository = CatalogRepository();
  final store = AppStore(
    repository.loadProducts,
    catalogStreamLoader: repository.watchProducts,
    capacityRepository: FirestoreCapacityRepository(),
    telemetry: telemetry,
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
    return MaterialApp(
      title: 'Expresiones',
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

  void _openPrivacy() {
    final store = context.read<AppStore>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (privacyContext) => PrivacyScreen(
          onBack: () => Navigator.of(privacyContext).pop(),
          onClearLocalData: store.clearLocalData,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$quantity × ${product.name} agregado a tu cotización.',
                    ),
                    action: SnackBarAction(
                      label: 'Ver',
                      textColor: Colors.white,
                      onPressed: _showQuote,
                    ),
                  ),
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
              initial: store.details,
              earliestDate: store.earliestDesiredDate,
              productionPoints: store.productionPoints,
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
    );

    Navigator.of(coordinationContext).push(
      MaterialPageRoute<void>(
        builder: (reviewContext) => Scaffold(
          body: SafeArea(
            child: ReviewScreen(
              lines: lines,
              details: details,
              quoteId: quoteId,
              message: message,
              onSendWhatsapp: () => _openWhatsapp(
                message,
                recordQuoteSent: true,
              ),
              onCopyMessage: () {
                Clipboard.setData(ClipboardData(text: message));
              },
              onEditQuote: () {
                setState(() => _index = 2);
                Navigator.of(reviewContext).popUntil((route) => route.isFirst);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsapp(
    String message, {
    bool recordQuoteSent = false,
  }) async {
    final uri = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent(message)}',
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (store.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final page = switch (_index) {
      0 => HomeScreen(
        products: store.products,
        onBrowse: _showCatalog,
        onProduct: _openProduct,
        onOpenQuote: _showQuote,
        quoteQuantity: store.cartQuantity,
        onZeroResultSearch: store.recordZeroResultSearch,
      ),
      1 => CatalogScreen(
        key: ValueKey(_catalogCategory),
        products: store.products,
        initialCategory: _catalogCategory,
        onProduct: _openProduct,
        onBack: () => setState(() => _index = 0),
        onOpenQuote: _showQuote,
        onZeroResultSearch: store.recordZeroResultSearch,
      ),
      2 => QuoteScreen(
        lines: store.resolvedLines,
        onQuantityChanged: store.updateQuantity,
        onRemove: store.removeLine,
        onContinue: _openCoordination,
        onBrowse: _showCatalog,
        onBack: () => setState(() => _index = 0),
      ),
      _ => HelpScreen(
        onContact: () =>
            _openWhatsapp('Hola, Expresiones. Quisiera hacer una consulta.'),
        onPrivacy: _openPrivacy,
      ),
    };

    return Scaffold(
      body: SafeArea(child: page),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) {
          setState(() {
            if (value == 1) _catalogCategory = null;
            _index = value;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Catálogo',
          ),
          BottomNavigationBarItem(
            icon: Badge.count(
              count: store.cartQuantity,
              isLabelVisible: store.cartQuantity > 0,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            activeIcon: Badge.count(
              count: store.cartQuantity,
              isLabelVisible: store.cartQuantity > 0,
              child: const Icon(Icons.shopping_bag_rounded),
            ),
            label: 'Cotización',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.help_outline_rounded),
            activeIcon: Icon(Icons.help_rounded),
            label: 'Ayuda',
          ),
        ],
      ),
    );
  }
}
