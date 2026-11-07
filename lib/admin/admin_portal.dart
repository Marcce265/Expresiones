import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../models/catalog_models.dart';
import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/app_notice.dart';
import '../widgets/confirm_cancel_dialog.dart';
import '../widgets/product_card.dart';
import 'admin_image_draft.dart';
import '../widgets/product_visual.dart';
import 'admin_audit_log_screen.dart';
import 'admin_customer_orders_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_catalog_repository.dart';
import 'admin_checkout_settings_screen.dart';
import 'admin_operations_repository.dart';
import 'admin_site_settings_repository.dart';
import 'admin_site_settings_screen.dart';
import '../data/customer_account_repository.dart';
import 'admin_ui.dart';

class AdminPortalApp extends StatelessWidget {
  const AdminPortalApp({super.key, required this.client});

  final SupabaseClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expresiones · Administración',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AdminPortal(client: client),
    );
  }
}

/// Authenticates staff and requires both an admin allowlist entry and TOTP.
class AdminPortal extends StatefulWidget {
  const AdminPortal({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  int _sessionAttempt = 0;

  void _retrySession() => setState(() => _sessionAttempt++);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      key: ValueKey(_sessionAttempt),
      stream: widget.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminError(
            title: 'No se pudo comprobar la sesión',
            message: _friendlyAuthMessage(snapshot.error),
            onRetry: _retrySession,
          );
        }
        final user =
            snapshot.data?.session?.user ?? widget.client.auth.currentUser;
        if (snapshot.connectionState == ConnectionState.waiting &&
            user == null) {
          return const _AdminLoading();
        }
        if (user == null) return AdminLoginScreen(client: widget.client);
        return _AdminSecurityGate(client: widget.client, user: user);
      },
    );
  }
}

class _AdminSecurityGate extends StatefulWidget {
  const _AdminSecurityGate({required this.client, required this.user});

  final SupabaseClient client;
  final User user;

  @override
  State<_AdminSecurityGate> createState() => _AdminSecurityGateState();
}

class _AdminSecurityGateState extends State<_AdminSecurityGate> {
  late Future<_AdminAccessState> _access;

  @override
  void initState() {
    super.initState();
    _access = _checkAccess();
  }

  Future<_AdminAccessState> _checkAccess() async {
    final allowed = await widget.client.rpc('is_current_admin');
    if (allowed != true) return const _AdminAccessState.denied();

    final assurance = widget.client.auth.mfa.getAuthenticatorAssuranceLevel();
    if (assurance.currentLevel == AuthenticatorAssuranceLevels.aal2) {
      return const _AdminAccessState.allowed();
    }

    final factors = await widget.client.auth.mfa.listFactors();
    if (factors.totp.isNotEmpty) {
      return _AdminAccessState.challenge(factors.totp.first.id);
    }
    return const _AdminAccessState.enroll();
  }

  void _retry() => setState(() => _access = _checkAccess());

  Future<void> _signOut() => widget.client.auth.signOut();

  @override
  void didUpdateWidget(covariant _AdminSecurityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) _retry();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminAccessState>(
      future: _access,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AdminLoading();
        }
        if (snapshot.hasError) {
          return _AdminError(
            title: 'No se pudo comprobar el acceso',
            message: _friendlyAuthMessage(snapshot.error),
            onRetry: _retry,
          );
        }
        final access = snapshot.data;
        if (access == null || access.mode == _AdminAccessMode.denied) {
          return _AccessDenied(
            email: widget.user.email ?? '',
            onRetry: _retry,
            onSignOut: _signOut,
          );
        }
        return switch (access.mode) {
          _AdminAccessMode.enroll => _TotpEnrollmentScreen(
            client: widget.client,
            onVerified: _retry,
            onSignOut: _signOut,
          ),
          _AdminAccessMode.challenge => _TotpChallengeScreen(
            client: widget.client,
            factorId: access.factorId!,
            onVerified: _retry,
            onSignOut: _signOut,
          ),
          _AdminAccessMode.allowed => AdminDashboardScreen(
            client: widget.client,
            repository: AdminCatalogRepository(client: widget.client),
            operations: AdminOperationsRepository(client: widget.client),
            userEmail: widget.user.email ?? '',
            onSignOut: _signOut,
          ),
          _AdminAccessMode.denied => const _AdminLoading(),
        };
      },
    );
  }
}

enum _AdminAccessMode { denied, enroll, challenge, allowed }

class _AdminAccessState {
  const _AdminAccessState._(this.mode, [this.factorId]);

  const _AdminAccessState.denied() : this._(_AdminAccessMode.denied);
  const _AdminAccessState.enroll() : this._(_AdminAccessMode.enroll);
  const _AdminAccessState.challenge(String factorId)
    : this._(_AdminAccessMode.challenge, factorId);
  const _AdminAccessState.allowed() : this._(_AdminAccessMode.allowed);

  final _AdminAccessMode mode;
  final String? factorId;
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      setState(() {
        final message = error.message.toLowerCase();
        _error = message.contains('invalid login')
            ? 'Correo o contraseña incorrectos.'
            : _friendlyAuthMessage(error);
      });
    } catch (error) {
      setState(() {
        _error = _friendlyAuthMessage(error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Expresiones',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Panel administrativo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo administrativo',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) =>
                            value != null && value.contains('@')
                            ? null
                            : 'Ingresa un correo válido.',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Ingresa tu contraseña.'
                            : null,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _busy ? null : _login,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('Ingresar'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'El acceso requiere una cuenta con el permiso '
                        'administrador asignado en Supabase y un código de '
                        'verificación de tu aplicación autenticadora.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.client,
    required this.repository,
    required this.operations,
    required this.userEmail,
    required this.onSignOut,
  });

  final SupabaseClient client;
  final AdminCatalogRepository repository;
  final AdminOperationsRepository operations;
  final String userEmail;
  final Future<void> Function() onSignOut;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _search = TextEditingController();
  final _adminSearch = TextEditingController();
  final Set<String> _hiddenProductIds = {};
  late Stream<List<CatalogProduct>> _productsStream;
  String _query = '';
  String _catalogGroup = 'Todos';
  int _sectionIndex = 0;

  static const _catalogGroups = [
    'Todos',
    'Limpiapipas',
    'Cintas satinadas',
    'Cintas especiales',
    'Envolturas',
    'Accesorios',
    'Herramientas',
    'Frases',
  ];

  @override
  void initState() {
    super.initState();
    _productsStream = widget.repository.watchProducts();
  }

  @override
  void dispose() {
    _search.dispose();
    _adminSearch.dispose();
    super.dispose();
  }

  Future<void> _openSettings() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AdminSiteSettingsScreen(
        repository: AdminSiteSettingsRepository(client: widget.client),
      ),
    ),
  );

  Future<void> _openHeroEditor([StorefrontSettings? initial]) async {
    final settingsRepository = AdminSiteSettingsRepository(
      client: widget.client,
    );
    final settings = initial ?? await settingsRepository.watch().first;
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminHeroEditorDialog(
        catalogRepository: widget.repository,
        settingsRepository: settingsRepository,
        initialSettings: settings,
      ),
    );
    if (saved == true && mounted) _showNotice('Portada actualizada.');
  }

  Future<void> _openAnalytics() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AdminAnalyticsScreen(repository: widget.operations),
    ),
  );

  void _selectSection(int index) {
    if (_sectionIndex == index) return;
    setState(() {
      _sectionIndex = index;
      if (index == 1) {
        _productsStream = widget.repository.watchProducts();
      }
    });
  }

  String _normalizeSearch(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n');

  Future<void> _runAdminSearch(String rawQuery) async {
    final query = _normalizeSearch(rawQuery);
    if (query.isEmpty) return;

    if (query.contains('fecha') ||
        query.contains('calendario') ||
        query.contains('capacidad') ||
        query.contains('dia') ||
        query.contains('shalom') ||
        query.contains('recojo')) {
      setState(() => _sectionIndex = 2);
      return;
    }
    if (query.contains('portada')) {
      await _openHeroEditor();
      return;
    }
    if (query.contains('texto') ||
        query.contains('titulo') ||
        query.contains('descripcion') ||
        query.contains('whatsapp') ||
        query.contains('privacidad') ||
        query.contains('contenido')) {
      _openSettings();
      return;
    }
    if (query.contains('actividad') ||
        query.contains('consulta') ||
        query.contains('busqueda') ||
        query.contains('estadistica')) {
      _openAnalytics();
      return;
    }
    if (query.contains('historial') ||
        query.contains('auditoria') ||
        query.contains('registro administrativo')) {
      setState(() => _sectionIndex = 4);
      return;
    }
    if (query.contains('compra') ||
        query.contains('venta') ||
        query.contains('pago')) {
      setState(() => _sectionIndex = 3);
      return;
    }
    if (query.contains('carrito') ||
        query.contains('formulario') ||
        query.contains('entrega') ||
        query.contains('ubicacion') ||
        query.contains('mapa')) {
      setState(() => _sectionIndex = 2);
      return;
    }

    _search.text = rawQuery.trim();
    setState(() {
      _sectionIndex = 1;
      _productsStream = widget.repository.watchProducts();
      _catalogGroup = 'Todos';
      _query = rawQuery.trim().toLowerCase();
    });
  }

  Future<void> _openEditor([CatalogProduct? product]) async {
    final result = await showDialog<_ProductEditorResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminProductEditorDialog(
        repository: widget.repository,
        product: product,
      ),
    );
    if (result == null || !mounted) return;
    if (result == _ProductEditorResult.deleted && product != null) {
      _hiddenProductIds.add(product.id);
    }
    setState(() {
      // A new async stream performs an immediate database read. This keeps the
      // editor deterministic even when Realtime is delayed or disabled.
      _productsStream = widget.repository.watchProducts();
    });
    final message = switch (result) {
      _ProductEditorResult.created => 'Producto creado.',
      _ProductEditorResult.updated => 'Producto actualizado.',
      _ProductEditorResult.deleted => 'Producto eliminado.',
    };
    _showNotice(message);
  }

  void _showNotice(String message) {
    showAppNotice(context, message);
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ChangePasswordDialog(client: widget.client),
    );
    if (changed == true && mounted) {
      _showNotice('Contraseña actualizada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1024;
        final page = switch (_sectionIndex) {
          0 => _AdminHomeSection(
            repository: widget.repository,
            settingsRepository: AdminSiteSettingsRepository(
              client: widget.client,
            ),
            searchController: _adminSearch,
            onSearch: _runAdminSearch,
            onCatalog: () => _selectSection(1),
            onCheckout: () => _selectSection(2),
            onSettings: _openSettings,
            onAnalytics: _openAnalytics,
            onEditHero: _openHeroEditor,
          ),
          1 => _buildCatalogSection(),
          2 => AdminCheckoutSettingsScreen(
            repository: AdminSiteSettingsRepository(client: widget.client),
            operations: widget.operations,
          ),
          3 when FeatureFlags.demoPayment => AdminCustomerOrdersScreen(
            repository: CustomerAccountRepository(client: widget.client),
          ),
          _ => AdminAuditLogScreen(repository: widget.operations),
        };

        return Scaffold(
          appBar: _AdminAppBar(
            email: widget.userEmail,
            onSettings: _openSettings,
            onCapacity: () => _selectSection(2),
            onAnalytics: _openAnalytics,
            onPassword: _changePassword,
            onSignOut: widget.onSignOut,
          ),
          floatingActionButton: _sectionIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: _openEditor,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuevo producto'),
                )
              : null,
          body: Row(
            children: [
              if (desktop)
                _AdminNavigation(
                  selectedIndex: _sectionIndex,
                  email: widget.userEmail,
                  onSelect: _selectSection,
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(_sectionIndex),
                    child: page,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _sectionIndex,
                  onDestinationSelected: _selectSection,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Inicio',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Catálogo',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.shopping_bag_outlined),
                      selectedIcon: Icon(Icons.shopping_bag_rounded),
                      label: 'Carrito',
                    ),
                    if (FeatureFlags.demoPayment)
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded),
                        label: 'Compras',
                      ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'Auditoría',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCatalogSection() {
    return StreamBuilder<List<CatalogProduct>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminError(
            title: 'No se pudo leer el catálogo',
            message: '${snapshot.error}',
            onRetry: () {
              setState(() {
                _productsStream = widget.repository.watchProducts();
              });
            },
          );
        }
        if (!snapshot.hasData) return const _AdminLoading();
        final allProducts = snapshot.data!
            .where(
              (product) =>
                  !product.attributes.containsKey('mergedInto') &&
                  !_hiddenProductIds.contains(product.id),
            )
            .toList(growable: false);
        final products = allProducts.where((product) {
          if (_catalogGroup != 'Todos' &&
              product.attributes['catalogGroup'] != _catalogGroup) {
            return false;
          }
          if (_query.isEmpty) return true;
          final haystack = [
            product.name,
            product.sku ?? '',
            product.description,
            ...product.variants.map((variant) => variant.name),
            ...product.variants.map((variant) => variant.sku ?? ''),
          ].join(' ').toLowerCase();
          return haystack.contains(_query);
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ResponsivePage(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 28,
                      compact ? 16 : 26,
                      compact ? 16 : 28,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminSectionIntro(
                          eyebrow: 'Catálogo administrativo',
                          title: 'Edita la tienda tal como la ven tus clientes',
                          description: 'Busca un material o entra por categoría. Cada tarjeta conserva la misma foto, información y estilo del catálogo público.',
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        const InfoBanner(
                          icon: Icons.edit_outlined,
                          title: 'Editar es sencillo',
                          message: 'Toca el lápiz ✏️ de cualquier producto para cambiar fotos, textos, precio, stock y variantes.',
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _search,
                                decoration: InputDecoration(
                                  hintText: 'Buscar material, color o código',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _query.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Limpiar búsqueda',
                                          onPressed: () {
                                            _search.clear();
                                            setState(() => _query = '');
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                                onChanged: (value) => setState(
                                  () => _query = value.trim().toLowerCase(),
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(width: 12),
                              Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${products.length} productos',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final group in _catalogGroups) ...[
                                ChoiceChip(
                                  label: Text(group),
                                  selected: _catalogGroup == group,
                                  onSelected: (_) =>
                                      setState(() => _catalogGroup = group),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        if (compact) ...[
                          const SizedBox(height: 10),
                          Text(
                            '${products.length} productos',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (products.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _AdminError(
                      title: 'No hay resultados',
                      message: 'Prueba con otra búsqueda o categoría.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 28,
                      4,
                      compact ? 16 : 28,
                      110,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: compact ? 210 : 260,
                        mainAxisExtent: compact ? 250 : 304,
                        crossAxisSpacing: compact ? 12 : 16,
                        mainAxisSpacing: compact ? 12 : 16,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = products[index];
                        return _EditableProductCard(
                          product: product,
                          compact: compact,
                          onEdit: () => _openEditor(product),
                        );
                      }, childCount: products.length),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.selectedIndex,
    required this.email,
    required this.onSelect,
  });

  final int selectedIndex;
  final String email;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Catálogo'),
      (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Carrito'),
      if (FeatureFlags.demoPayment)
        (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Compras'),
      (Icons.history_outlined, Icons.history_rounded, 'Auditoría'),
    ];
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text('🌸', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expresiones',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontFamily: 'PlayfairDisplay',
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Modo administrador',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          for (var index = 0; index < destinations.length; index++) ...[
            _AdminNavigationItem(
              icon: selectedIndex == index
                  ? destinations[index].$2
                  : destinations[index].$1,
              label: destinations[index].$3,
              selected: selectedIndex == index,
              onTap: () => onSelect(index),
            ),
            const SizedBox(height: 6),
          ],
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sesión protegida',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavigationItem extends StatelessWidget {
  const _AdminNavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: AppColors.canvas,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 13),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminHomeSection extends StatelessWidget {
  const _AdminHomeSection({
    required this.repository,
    required this.settingsRepository,
    required this.searchController,
    required this.onSearch,
    required this.onCatalog,
    required this.onCheckout,
    required this.onSettings,
    required this.onAnalytics,
    required this.onEditHero,
  });

  final AdminCatalogRepository repository;
  final AdminSiteSettingsRepository settingsRepository;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onCatalog;
  final VoidCallback onCheckout;
  final VoidCallback onSettings;
  final VoidCallback onAnalytics;
  final ValueChanged<StorefrontSettings> onEditHero;

  @override
  Widget build(BuildContext context) {
    final cached = AdminSiteSettingsRepository.cachedSettings;
    return StreamBuilder<StorefrontSettings>(
      stream: settingsRepository.watch(),
      initialData: cached,
      builder: (context, settingsSnapshot) {
        final settings = settingsSnapshot.data ?? cached ?? const StorefrontSettings();
        return StreamBuilder<List<CatalogProduct>>(
          stream: repository.watchProducts(),
          builder: (context, productsSnapshot) {
            final productCount =
                productsSnapshot.data
                    ?.where(
                      (product) =>
                          !product.attributes.containsKey('mergedInto'),
                    )
                    .length ??
                0;
            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                return SingleChildScrollView(
                  child: ResponsivePage(
                    maxWidth: 1240,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 32,
                      compact ? 18 : 30,
                      compact ? 16 : 32,
                      42,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdminSectionIntro(
                          eyebrow: 'Administración de Expresiones',
                          title: 'Modo administrador',
                          description: settings.text(
                            StorefrontText.adminHomeDescription,
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 24),
                        TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '¿Qué quieres editar? Ej.: fecha, producto o portada',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'Buscar en administración',
                              onPressed: () => onSearch(searchController.text),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ),
                          onSubmitted: onSearch,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final suggestion in const [
                              'Editar portada',
                              'Buscar producto',
                              'Configurar fechas',
                              'Formulario del carrito',
                            ])
                              ActionChip(
                                label: Text(suggestion),
                                onPressed: () {
                                  searchController.text = suggestion;
                                  onSearch(suggestion);
                                },
                              ),
                          ],
                        ),
                        SizedBox(height: compact ? 20 : 28),
                        _AdminHeroPreview(
                          settings: settings,
                          onEdit: () => onEditHero(settings),
                        ),
                        SizedBox(height: compact ? 20 : 28),
                        Text(
                          'Accesos rápidos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: compact ? 1 : 2,
                          childAspectRatio: compact ? 2.55 : 2.7,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          children: [
                            _AdminQuickAction(
                              icon: Icons.grid_view_rounded,
                              title: 'Catálogo',
                              description:
                                  '$productCount productos. Edita imágenes, textos, precios, stock y variantes.',
                              actionLabel: 'Abrir catálogo',
                              onTap: onCatalog,
                            ),
                            _AdminQuickAction(
                              icon: Icons.shopping_bag_outlined,
                              title: 'Carrito y entrega',
                              description: 'Configura formulario, ubicaciones, mapas y calendarios de entrega.',
                              actionLabel: 'Configurar carrito',
                              onTap: onCheckout,
                            ),
                            _AdminQuickAction(
                              icon: Icons.text_fields_rounded,
                              title: 'Contenido de la web',
                              description: 'Actualiza los textos públicos, WhatsApp, ayuda y privacidad.',
                              actionLabel: 'Editar contenido',
                              onTap: onSettings,
                            ),
                            _AdminQuickAction(
                              icon: Icons.query_stats_rounded,
                              title: 'Actividad',
                              description: 'Revisa búsquedas, consultas y señales de interés del catálogo.',
                              actionLabel: 'Ver actividad',
                              onTap: onAnalytics,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminHeroPreview extends StatelessWidget {
  const _AdminHeroPreview({required this.settings, required this.onEdit});

  final StorefrontSettings settings;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final copy = Padding(
            padding: EdgeInsets.all(compact ? 20 : 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PORTADA PÚBLICA',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(letterSpacing: 1.1, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Text(
                  settings.text(StorefrontText.homeTitle),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  settings.text(StorefrontText.homeSubtitle),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  label: const Text('Editar portada'),
                ),
              ],
            ),
          );
          final image = Stack(
            fit: StackFit.expand,
            children: [
              _AdminConfiguredImage(
                source: settings.text(StorefrontText.homeHeroImage),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: IconButton.filled(
                  tooltip: 'Cambiar portada',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              children: [
                SizedBox(height: 220, child: image),
                copy,
              ],
            );
          }
          return SizedBox(
            height: 310,
            child: Row(
              children: [
                Expanded(flex: 5, child: copy),
                Expanded(flex: 6, child: image),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminConfiguredImage extends StatelessWidget {
  const _AdminConfiguredImage({required this.source, this.memoryBytes});

  final String source;
  final Uint8List? memoryBytes;

  @override
  Widget build(BuildContext context) {
    if (memoryBytes != null) {
      return Image.memory(memoryBytes!, fit: BoxFit.cover);
    }
    final clean = source.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (clean.isEmpty) {
      return _fallback();
    }
    return Image.asset(
      clean,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => const ColoredBox(
    color: AppColors.pinkSoft,
    child: Center(child: Icon(Icons.image_outlined, size: 42)),
  );
}

class _AdminQuickAction extends StatelessWidget {
  const _AdminQuickAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, size: 24, color: AppColors.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminHeroEditorDialog extends StatefulWidget {
  const _AdminHeroEditorDialog({
    required this.catalogRepository,
    required this.settingsRepository,
    required this.initialSettings,
  });

  final AdminCatalogRepository catalogRepository;
  final AdminSiteSettingsRepository settingsRepository;
  final StorefrontSettings initialSettings;

  @override
  State<_AdminHeroEditorDialog> createState() => _AdminHeroEditorDialogState();
}

class _AdminHeroEditorDialogState extends State<_AdminHeroEditorDialog> {
  late final TextEditingController _adminDescription;
  late final TextEditingController _eyebrow;
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageContentType;
  bool _saving = false;
  String? _error;

  bool get _hasChanges =>
      _adminDescription.text !=
          widget.initialSettings.text(StorefrontText.adminHomeDescription) ||
      _eyebrow.text !=
          widget.initialSettings.text(StorefrontText.homeEyebrow) ||
      _title.text != widget.initialSettings.text(StorefrontText.homeTitle) ||
      _subtitle.text !=
          widget.initialSettings.text(StorefrontText.homeSubtitle) ||
      _imageBytes != null;

  @override
  void initState() {
    super.initState();
    _adminDescription = TextEditingController(
      text: widget.initialSettings.text(StorefrontText.adminHomeDescription),
    );
    _eyebrow = TextEditingController(
      text: widget.initialSettings.text(StorefrontText.homeEyebrow),
    );
    _title = TextEditingController(
      text: widget.initialSettings.text(StorefrontText.homeTitle),
    );
    _subtitle = TextEditingController(
      text: widget.initialSettings.text(StorefrontText.homeSubtitle),
    );
  }

  @override
  void dispose() {
    _adminDescription.dispose();
    _eyebrow.dispose();
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _requestCancel() async {
    if (_saving) return;
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    final confirmed = await confirmCancelAction(context);
    if (confirmed && mounted) Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    const types = XTypeGroup(
      label: 'Imágenes',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [types]);
    if (file == null) return;
    final extension = file.name.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    try {
      final bytes = await file.readAsBytes();
      AdminCatalogRepository.validateCatalogImageUpload(
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
        _imageContentType = contentType;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _title.text.trim().isEmpty ||
        _subtitle.text.trim().isEmpty ||
        _adminDescription.text.trim().isEmpty) {
      setState(() => _error = 'Completa el título y las descripciones.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var heroImage = widget.initialSettings.text(StorefrontText.homeHeroImage);
      if (_imageBytes != null) {
        final path = await widget.catalogRepository.uploadCatalogImage(
          bytes: _imageBytes!,
          fileName: _imageName!,
          contentType: _imageContentType!,
          folder: 'site/home',
        );
        heroImage = widget.catalogRepository.client.storage
            .from('catalog')
            .getPublicUrl(path);
      }
      final texts = <String, String>{
        ...widget.initialSettings.texts,
        StorefrontText.adminHomeDescription: _adminDescription.text.trim(),
        StorefrontText.homeEyebrow: _eyebrow.text.trim(),
        StorefrontText.homeTitle: _title.text.trim(),
        StorefrontText.homeSubtitle: _subtitle.text.trim(),
        StorefrontText.homeHeroImage: heroImage,
      };
      await widget.settingsRepository.save(
        widget.initialSettings.copyWith(texts: texts),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar la portada: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(width < 600 ? 20 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar portada e inicio',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _saving ? null : _requestCancel,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Cambia la bienvenida del administrador y la portada que verán tus clientes.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              AspectRatio(
                aspectRatio: 2.4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _AdminConfiguredImage(
                    source: widget.initialSettings.text(
                      StorefrontText.homeHeroImage,
                    ),
                    memoryBytes: _imageBytes,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _imageName == null
                      ? 'Cambiar imagen de portada'
                      : 'Imagen elegida: $_imageName',
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _adminDescription,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción del modo administrador',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _eyebrow,
                decoration: const InputDecoration(
                  labelText: 'Etiqueta de la portada pública',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Título de la portada pública',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _subtitle,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción de la portada pública',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AdminAppBar({
    required this.email,
    required this.onSettings,
    required this.onCapacity,
    required this.onAnalytics,
    required this.onPassword,
    required this.onSignOut,
  });

  final String email;
  final VoidCallback onSettings;
  final VoidCallback onCapacity;
  final VoidCallback onAnalytics;
  final VoidCallback onPassword;
  final Future<void> Function() onSignOut;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return AppBar(
      toolbarHeight: 72,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: .8),
      ),
      titleSpacing: compact ? 16 : 24,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Expresiones',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.pinkSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'ADMINISTRACIÓN',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontSize: 9, letterSpacing: .9),
              ),
            ),
          ],
        ],
      ),
      actions: [
        _AdminTopAction(
          tooltip: 'Contenido de la web',
          icon: Icons.settings_outlined,
          onPressed: onSettings,
        ),
        _AdminTopAction(
          tooltip: 'Días de entrega',
          icon: Icons.calendar_month_outlined,
          onPressed: onCapacity,
        ),
        _AdminTopAction(
          tooltip: 'Actividad del catálogo',
          icon: Icons.query_stats_outlined,
          onPressed: onAnalytics,
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Cuenta administrativa',
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) {
            if (value == 'password') onPassword();
            if (value == 'logout') onSignOut();
          },
          itemBuilder: (context) => [
            if (email.isNotEmpty)
              PopupMenuItem<String>(
                enabled: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'password',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.password_rounded),
                title: Text('Cambiar contraseña'),
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded),
                title: Text('Cerrar sesión'),
              ),
            ),
          ],
          child: Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: Text(
              email.trim().isEmpty ? 'A' : email.trim()[0].toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminTopAction extends StatelessWidget {
  const _AdminTopAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(backgroundColor: AppColors.pinkSoft),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.client});

  final SupabaseClient client;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _requestCancel() async {
    if (_busy) return;
    if (_password.text.isEmpty && _confirmation.text.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    final confirmed = await confirmCancelAction(context);
    if (confirmed && mounted) Navigator.pop(context, false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo actualizar. ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear o cambiar contraseña'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Usa al menos 12 caracteres. También podrás seguir entrando '
                'con el enlace seguro enviado a tu correo.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => (value?.length ?? 0) >= 12
                    ? null
                    : 'Usa al menos 12 caracteres.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmation,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Repite la contraseña',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: (value) => value == _password.text
                    ? null
                    : 'Las contraseñas no coinciden.',
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _requestCancel,
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar contraseña'),
        ),
      ],
    );
  }
}

class _EditableProductCard extends StatelessWidget {
  const _EditableProductCard({
    required this.product,
    required this.compact,
    required this.onEdit,
  });

  final CatalogProduct product;
  final bool compact;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ProductCard(
            product: product,
            compact: compact,
            showCategory: true,
            showUnavailableOverlay: false,
            onTap: onEdit,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: AppColors.ink,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              key: ValueKey('edit-${product.id}'),
              tooltip: 'Editar ${product.name}',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ProductEditorResult { created, updated, deleted }

const _adminStockStatuses = <StockStatus>[
  StockStatus.inStock,
  StockStatus.lowStock,
  StockStatus.outOfStock,
];

class _VariantStatusSelector extends StatelessWidget {
  const _VariantStatusSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StockStatus value;
  final ValueChanged<StockStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth >= 430;
        final choices = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final status in _adminStockStatuses)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildChoice(context, status),
                ),
              ),
          ],
        );
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: compact ? 4 : 7,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: compact
              ? Row(
                  children: [
                    Text(
                      'Disponibilidad',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: SizedBox(height: 38, child: choices)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 3, bottom: 5),
                      child: Text(
                        'Disponibilidad',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    SizedBox(height: 38, child: choices),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildChoice(BuildContext context, StockStatus status) {
    final selected = status == value;
    return Tooltip(
      message: status.label,
      child: Material(
        color: selected ? AppColors.ink : AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(status),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Center(
                child: Text(
                  status.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminProductEditorDialog extends StatefulWidget {
  const AdminProductEditorDialog({
    super.key,
    required this.repository,
    this.product,
  });

  final AdminCatalogRepository repository;
  final CatalogProduct? product;

  @override
  State<AdminProductEditorDialog> createState() =>
      _AdminProductEditorDialogState();
}

class _AdminProductEditorDialogState extends State<AdminProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _description;
  late final AdminImageDraft _image;
  late final TextEditingController _unitLabel;
  late final TextEditingController _basePrice;
  late final TextEditingController _sortOrder;
  late final List<_PriceTierDraft> _priceTiers;
  late final List<_VariantDraft> _variants;
  late final String _initialDraftSnapshot;
  late bool _isActive;
  late bool _isFeatured;
  late bool _priceIsEstimate;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _image = AdminImageDraft.fromProduct(product);
    _unitLabel = TextEditingController(text: product?.unitLabel ?? 'unidad');
    _basePrice = TextEditingController(
      text: product == null ? '' : product.basePrice.toStringAsFixed(2),
    );
    _sortOrder = TextEditingController(text: '${product?.sortOrder ?? 0}');
    _priceTiers = [
      for (final tier in product?.priceTiers ?? const <PriceTier>[])
        _PriceTierDraft.fromTier(tier),
    ];
    _isActive = product?.isActive ?? true;
    _isFeatured = product?.isFeatured ?? false;
    _priceIsEstimate = product?.priceIsEstimate ?? false;
    _variants = [
      for (final variant in product?.variants ?? const <ProductVariant>[])
        if (variant.isActive) _VariantDraft(variant),
    ];
    _initialDraftSnapshot = _draftSnapshot();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _description,
      _unitLabel,
      _basePrice,
      _sortOrder,
    ]) {
      controller.dispose();
    }
    for (final variant in _variants) {
      variant.dispose();
    }
    for (final tier in _priceTiers) {
      tier.dispose();
    }
    super.dispose();
  }

  Future<void> _requestCancel() async {
    if (_saving || _uploadingImage) return;
    if (_draftSnapshot() == _initialDraftSnapshot) {
      Navigator.pop(context);
      return;
    }
    final confirmed = await confirmCancelAction(
      context,
      message: widget.product == null
          ? 'Se descartará el producto nuevo y todos sus cambios.'
          : 'Se descartarán los cambios que todavía no guardaste.',
    );
    if (confirmed && mounted) Navigator.pop(context);
  }

  String _draftSnapshot() => jsonEncode({
    'name': _name.text,
    'sku': _sku.text,
    'description': _description.text,
    'unitLabel': _unitLabel.text,
    'basePrice': _basePrice.text,
    'sortOrder': _sortOrder.text,
    'isActive': _isActive,
    'isFeatured': _isFeatured,
    'priceIsEstimate': _priceIsEstimate,
    'imageChanged': _image.changed,
    'priceTiers': [
      for (final tier in _priceTiers)
        {
          'quantity': tier.quantity.text,
          'totalPrice': tier.totalPrice.text,
          'label': tier.label,
          'initialQuantity': tier.initialQuantity,
        },
    ],
    'variants': [
      for (final variant in _variants)
        {
          'id': variant.variant.id,
          'name': variant.name.text,
          'sku': variant.sku.text,
          'status': variant.status.key,
          'active': variant.active,
          'imageChanged': variant.image.changed,
        },
    ],
  });

  Future<void> _save() async {
    if (_saving || _uploadingImage) {
      return;
    }
    final validForm = _formKey.currentState!.validate();
    final pricingError = _pricingError();
    if (!validForm || pricingError != null) {
      if (pricingError != null) setState(() => _error = pricingError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final activeVariants = _variants.where((variant) => variant.active);
      final familyStockStatus =
          activeVariants.isEmpty ||
              activeVariants.every(
                (variant) => variant.status == StockStatus.outOfStock,
              )
          ? StockStatus.outOfStock
          : activeVariants.any(
              (variant) => variant.status == StockStatus.inStock,
            )
          ? StockStatus.inStock
          : StockStatus.lowStock;
      final data = <String, dynamic>{
        'name': _name.text.trim().toUpperCase(),
        'category':
            widget.product?.category.key ?? ProductCategory.materials.key,
        'description': _description.text.trim().toUpperCase(),
        'sku': _sku.text.trim().toUpperCase(),
        'unitLabel': _unitLabel.text.trim().isEmpty
            ? 'UNIDAD'
            : _unitLabel.text.trim().toUpperCase(),
        'basePrice': _decimal(_basePrice.text),
        'startingAt': widget.product?.startingAt ?? false,
        'priceIsEstimate': _priceIsEstimate,
        'priceTiers': [for (final tier in _priceTiers) tier.toMap()],
        'variants': [for (final variant in _variants) variant.toMap()],
        'stock': null,
        'stockStatus': familyStockStatus.key,
        'isActive': _isActive,
        'isFeatured': _isFeatured,
        'sortOrder': int.parse(_sortOrder.text.trim()),
        'tags': widget.product?.tags ?? const <String>[],
        'attributes': widget.product?.attributes ?? const <String, String>{},
      };
      _image.writeReplacementTo(data);
      final product = widget.product;
      if (product == null) {
        await widget.repository.createProduct(
          documentId: _sku.text.trim().isEmpty ? _name.text : _sku.text,
          data: data,
        );
      } else {
        await widget.repository.updateProduct(product.id, data);
      }
      if (mounted) {
        Navigator.pop(
          context,
          product == null
              ? _ProductEditorResult.created
              : _ProductEditorResult.updated,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addVariant({bool atEnd = false}) {
    final draft = _VariantDraft.create(
      id: 'variante-${DateTime.now().microsecondsSinceEpoch}',
    );
    setState(() {
      if (atEnd) {
        _variants.add(draft);
      } else {
        _variants.insert(0, draft);
      }
    });
  }

  void _reorderVariant(_VariantDraft dragged, _VariantDraft target) {
    final from = _variants.indexOf(dragged);
    final to = _variants.indexOf(target);
    if (from < 0 || to < 0 || from == to) return;
    setState(() {
      final moved = _variants.removeAt(from);
      _variants.insert(to, moved);
    });
  }

  void _addPriceTier(List<_PriceTierDraft> tiers, [int? preset]) {
    final quantities = tiers
        .map((tier) => int.tryParse(tier.quantity.text.trim()))
        .whereType<int>()
        .toSet();
    if (preset != null && quantities.contains(preset)) return;
    var quantity = preset ?? 2;
    while (quantities.contains(quantity)) {
      quantity++;
    }
    setState(() => tiers.add(_PriceTierDraft.create(quantity: quantity)));
  }

  void _removePriceTier(List<_PriceTierDraft> tiers, _PriceTierDraft tier) {
    setState(() => tiers.remove(tier));
    tier.dispose();
  }

  String? _pricingError() {
    final skuOwners = <String, String>{};
    for (final variant in _variants) {
      final sku = variant.sku.text.trim();
      if (sku.isEmpty) continue;
      final normalized = sku.toLowerCase();
      final previousOwner = skuOwners[normalized];
      if (previousOwner != null) {
        return 'El código $sku está repetido en “$previousOwner” y '
            '“${variant.name.text.trim()}”. Cada opción necesita un código distinto.';
      }
      skuOwners[normalized] = variant.name.text.trim().isEmpty
          ? 'una opción sin nombre'
          : variant.name.text.trim();
    }
    final productError = _priceTierListError(_priceTiers, owner: 'el producto');
    if (productError != null) return productError;
    return null;
  }

  Future<void> _removeVariant(_VariantDraft draft) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar variante'),
        content: Text(
          '¿Quieres quitar “${draft.name.text}” de este producto? '
          'El cambio se aplicará cuando guardes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar variante'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() => _variants.remove(draft));
    draft.dispose();
  }

  Future<void> _deleteProduct() async {
    final product = widget.product;
    if (product == null || _saving) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Quieres eliminar “${product.name}” del catálogo? '
          'Esta acción también quitará sus variantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteProduct(product.id);
      if (mounted) Navigator.pop(context, _ProductEditorResult.deleted);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo eliminar el producto: $error';
        });
      }
    }
  }

  Future<void> _pickImage({_VariantDraft? variant}) async {
    const imageTypes = XTypeGroup(
      label: 'Imágenes',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [imageTypes]);
    if (file == null || _uploadingImage) return;
    setState(() {
      _uploadingImage = true;
      _error = null;
    });
    try {
      final extension = file.name.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final folderId =
          widget.product?.id ??
          AdminCatalogRepository.normalizedDocumentId(_name.text);
      final upload = await widget.repository.uploadCatalogImageSet(
        bytes: await file.readAsBytes(),
        fileName: file.name,
        contentType: contentType,
        folder: variant == null
            ? 'products/$folderId'
            : 'products/$folderId/variants',
      );
      if (!mounted) return;
      setState(() {
        if (variant == null) {
          _image.replaceWith(
            upload.detailPath,
            thumbnailValue: upload.thumbnailPath,
          );
        } else {
          variant.image.replaceWith(
            upload.detailPath,
            thumbnailValue: upload.thumbnailPath,
          );
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo subir la imagen: $error');
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String? _previewUrl(String value) {
    final path = value.trim();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('assets/')) {
      return path;
    }
    return widget.repository.client.storage.from('catalog').getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final isMobile = media.width < 768;

    final header = Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 14 : 18,
        16,
        isMobile ? 14 : 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product == null
                      ? 'CREAR EN EL CATÁLOGO'
                      : 'EDITAR EN EL CATÁLOGO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.product == null
                      ? 'Nuevo producto'
                      : widget.product!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 20 : null,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _saving || _uploadingImage ? null : _requestCancel,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );

    final editorBody = Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 940;

                    final imageCard = _cardContainer(
                      context: context,
                      title: 'Imagen principal',
                      subtitle:
                          'Foto de portada que se mostrará en el catálogo',
                      children: [
                        _ImageEditor(
                          label: _name.text.trim().isEmpty
                              ? 'Imagen del producto'
                              : _name.text.trim(),
                          imageUrl: _previewUrl(_image.previewValue),
                          uploading: _uploadingImage,
                          onPick: _pickImage,
                        ),
                      ],
                    );

                    final infoCard = _cardContainer(
                      context: context,
                      title: 'Información básica',
                      subtitle: 'Datos visibles y clasificación del producto',
                      children: [
                        TextFormField(
                          controller: _name,
                          scrollPadding:
                              const EdgeInsets.fromLTRB(20, 80, 20, 140),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: const [
                            UppercaseTextInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Nombre del producto *',
                            hintText: 'Ej. Limpiapipas premium 8 mm',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, c) {
                            final stack = c.maxWidth < 460;
                            final skuField = TextFormField(
                              controller: _sku,
                              scrollPadding:
                                  const EdgeInsets.fromLTRB(20, 80, 20, 140),
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: const [
                                UppercaseTextInputFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Código / SKU',
                                hintText: 'Ej. XS',
                              ),
                            );
                            final orderField = TextFormField(
                              controller: _sortOrder,
                              scrollPadding:
                                  const EdgeInsets.fromLTRB(20, 80, 20, 140),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Orden en catálogo',
                                prefixIcon: Icon(Icons.sort_rounded, size: 18),
                              ),
                              validator: _nonNegativeInt,
                            );
                            if (stack) {
                              return Column(
                                children: [
                                  skuField,
                                  const SizedBox(height: 12),
                                  orderField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(flex: 2, child: skuField),
                                const SizedBox(width: 12),
                                Expanded(child: orderField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _description,
                          scrollPadding:
                              const EdgeInsets.fromLTRB(20, 80, 20, 140),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: const [
                            UppercaseTextInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Detalles, material, dimensiones o uso recomendado...',
                          ),
                        ),
                      ],
                    );

                    final pricingCard = _cardContainer(
                      context: context,
                      title: 'Precios',
                      children: [
                        LayoutBuilder(
                          builder: (context, c) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: c.maxWidth < 280 ? c.maxWidth : 280,
                                child: TextFormField(
                                  controller: _basePrice,
                                  scrollPadding:
                                      const EdgeInsets.fromLTRB(20, 80, 20, 140),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Precio base (S/) *',
                                    prefixText: 'S/ ',
                                    hintText: '0.00',
                                  ),
                                  validator: _nonNegativeDecimal,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _PriceTiersEditor(
                          tiers: _priceTiers,
                          onAdd: (quantity) =>
                              _addPriceTier(_priceTiers, quantity),
                          onRemove: (tier) =>
                              _removePriceTier(_priceTiers, tier),
                        ),
                      ],
                    );

                    final visibilityCard = _cardContainer(
                      context: context,
                      title: 'Visibilidad y Estado',
                      subtitle: 'Controla si se muestra y cómo se presenta a los clientes',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Publicado en catálogo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Visible para los clientes en la tienda',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          value: _isActive,
                          onChanged: (value) =>
                              setState(() => _isActive = value),
                        ),
                        const Divider(height: 14, color: AppColors.border),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Producto destacado',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Aparece en inicio y recomendaciones destacadas',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          value: _isFeatured,
                          onChanged: (value) =>
                              setState(() => _isFeatured = value),
                        ),
                        const Divider(height: 14, color: AppColors.border),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Precio por revisar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            "Muestra etiqueta 'A consultar' en vez del precio fijo",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          value: _priceIsEstimate,
                          onChanged: (value) =>
                              setState(() => _priceIsEstimate = value),
                        ),
                      ],
                    );

                    final variantsCard = _cardContainer(
                      context: context,
                      title: 'Variantes (${_variants.length})',
                      subtitle: 'Arrastra la foto de una opción para cambiar su orden.',
                      children: [
                        if (_variants.isEmpty)
                          const InfoBanner(
                            icon: Icons.layers_outlined,
                            title: 'Este producto aún no tiene variantes',
                            message: 'Agrégalas cuando el producto se venda en diferentes opciones o colores.',
                          ),
                      ],
                    );

                    final topContent = isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 62,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    infoCard,
                                    const SizedBox(height: 18),
                                    pricingCard,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 38,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    imageCard,
                                    const SizedBox(height: 18),
                                    visibilityCard,
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              imageCard,
                              const SizedBox(height: 14),
                              infoCard,
                              const SizedBox(height: 14),
                              pricingCard,
                              const SizedBox(height: 14),
                              visibilityCard,
                            ],
                          );
                    final padding = isMobile ? 12.0 : 24.0;
                    // A variant uses a horizontal media/fields layout only
                    // when it has enough room. Keeping one column below this
                    // breakpoint prevents a compact desktop dialog from
                    // clipping the taller mobile-style tile.
                    final twoVariantColumns = constraints.maxWidth >= 1180;

                    Widget buildVariant(int index) {
                      final variant = _variants[index];
                      return RepaintBoundary(
                        child: _VariantEditorTile(
                          draft: variant,
                          imageUrl: _previewUrl(variant.image.previewValue),
                          uploading: _uploadingImage,
                          onPickImage: () => _pickImage(variant: variant),
                          onDelete: () => _removeVariant(variant),
                          onReorder: _reorderVariant,
                        ),
                      );
                    }

                    return CustomScrollView(
                      key: const PageStorageKey('admin-product-editor-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            padding,
                            padding,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(child: topContent),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(padding, 18, padding, 0),
                          sliver: SliverToBoxAdapter(child: variantsCard),
                        ),
                        if (_variants.isNotEmpty)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              14,
                              padding,
                              0,
                            ),
                            sliver: twoVariantColumns
                                ? SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 14,
                                          mainAxisExtent: 282,
                                        ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => buildVariant(index),
                                      childCount: _variants.length,
                                    ),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom: index == _variants.length - 1
                                              ? 0
                                              : 14,
                                        ),
                                        child: buildVariant(index),
                                      ),
                                      childCount: _variants.length,
                                    ),
                                  ),
                          ),
                        if (_variants.isNotEmpty)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              14,
                              padding,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: OutlinedButton.icon(
                                onPressed: () => _addVariant(atEnd: true),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Agregar otra opción'),
                              ),
                            ),
                          ),
                        if (_error != null)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              16,
                              padding,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            22,
                            padding,
                            MediaQuery.paddingOf(context).bottom + 28,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _editorActions(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );

    final dialogContent = Column(
      children: [
        header,
        const Divider(height: 1, color: AppColors.border),
        Expanded(child: editorBody),
      ],
    );

    if (isMobile) {
      return Dialog.fullscreen(
        backgroundColor: AppColors.canvas,
        child: Scaffold(
          backgroundColor: AppColors.canvas,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: dialogContent,
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AppColors.canvas,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1680,
          maxHeight: media.height - 24,
        ),
        child: dialogContent,
      ),
    );
  }

  Widget _editorActions(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final saveButton = FilledButton.icon(
              onPressed: _saving || _uploadingImage ? null : _save,
              icon: _saving || _uploadingImage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _uploadingImage ? 'Subiendo imagen...' : 'Guardar cambios',
              ),
            );
            final deleteButton = TextButton.icon(
              onPressed: _saving ? null : _deleteProduct,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Eliminar producto'),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  saveButton,
                  if (widget.product != null) ...[
                    const SizedBox(height: 4),
                    deleteButton,
                  ],
                ],
              );
            }
            return Row(
              children: [
                if (widget.product != null) deleteButton,
                const Spacer(),
                saveButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cardContainer({
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PriceTierDraft {
  _PriceTierDraft._({
    required int minQuantity,
    required double? totalPrice,
    required this.label,
  }) : initialQuantity = minQuantity,
       quantity = TextEditingController(text: '$minQuantity'),
       totalPrice = TextEditingController(
         text: totalPrice?.toStringAsFixed(2) ?? '',
       );

  factory _PriceTierDraft.fromTier(PriceTier tier) => _PriceTierDraft._(
    minQuantity: tier.minQuantity,
    totalPrice: tier.presentationTotal,
    label: tier.label,
  );

  factory _PriceTierDraft.create({required int quantity}) =>
      _PriceTierDraft._(minQuantity: quantity, totalPrice: null, label: null);

  final TextEditingController quantity;
  final TextEditingController totalPrice;
  final int initialQuantity;
  final String? label;

  Map<String, dynamic> toMap() {
    final minQuantity = int.parse(quantity.text.trim());
    return PriceTier.fromPresentationTotal(
      minQuantity: minQuantity,
      totalPrice: _decimal(totalPrice.text),
      label: minQuantity == initialQuantity && label != null
          ? label
          : _defaultPriceTierLabel(minQuantity),
    ).toMap();
  }

  void dispose() {
    quantity.dispose();
    totalPrice.dispose();
  }
}

class _PriceTiersEditor extends StatelessWidget {
  const _PriceTiersEditor({
    required this.tiers,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_PriceTierDraft> tiers;
  final ValueChanged<int?> onAdd;
  final ValueChanged<_PriceTierDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final quantities = tiers
        .map((tier) => int.tryParse(tier.quantity.text.trim()))
        .whereType<int>()
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Por cantidad',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: quantities.contains(12) ? null : () => onAdd(12),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Docena'),
            ),
            OutlinedButton.icon(
              onPressed: quantities.contains(100) ? null : () => onAdd(100),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Ciento'),
            ),
            TextButton.icon(
              onPressed: () => onAdd(null),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Otra cantidad'),
            ),
          ],
        ),
        if (tiers.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final tier in tiers) ...[
            _PriceTierRow(
              tier: tier,
              onRemove: () => onRemove(tier),
            ),
            if (tier != tiers.last) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _PriceTierRow extends StatefulWidget {
  const _PriceTierRow({
    required this.tier,
    required this.onRemove,
  });

  final _PriceTierDraft tier;
  final VoidCallback onRemove;

  @override
  State<_PriceTierRow> createState() => _PriceTierRowState();
}

class _PriceTierRowState extends State<_PriceTierRow> {
  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final quantity = int.tryParse(tier.quantity.text.trim());
    final total = _optionalDecimal(tier.totalPrice.text);
    final unitPrice = quantity == null || quantity < 1 || total == null
        ? null
        : total / quantity;
    final hint = unitPrice == null
        ? 'Completa cantidad y precio total.'
        : '${_presentationName(quantity!)} · '
              'S/ ${unitPrice.toStringAsFixed(2)} por unidad de venta';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final quantityField = TextFormField(
            controller: tier.quantity,
            keyboardType: TextInputType.number,
            scrollPadding: const EdgeInsets.fromLTRB(20, 80, 20, 140),
            decoration: const InputDecoration(labelText: 'Cantidad'),
            validator: _positiveInt,
            onChanged: (_) => setState(() {}),
          );
          final totalField = TextFormField(
            controller: tier.totalPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            scrollPadding: const EdgeInsets.fromLTRB(20, 80, 20, 140),
            decoration: const InputDecoration(
              labelText: 'Precio total (S/)',
              hintText: 'Ej. 30.00',
            ),
            validator: _nonNegativeDecimal,
            onChanged: (_) => setState(() {}),
          );
          final removeButton = IconButton(
            onPressed: widget.onRemove,
            tooltip: 'Quitar precio por cantidad',
            icon: const Icon(Icons.delete_outline_rounded),
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: quantityField),
                    const SizedBox(width: 10),
                    Expanded(child: totalField),
                    removeButton,
                  ],
                ),
                const SizedBox(height: 6),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: quantityField),
              const SizedBox(width: 10),
              SizedBox(width: 180, child: totalField),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    hint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: removeButton,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VariantDraft {
  _VariantDraft(this.variant)
    : name = TextEditingController(text: variant.name),
      sku = TextEditingController(text: variant.sku ?? ''),
      image = AdminImageDraft.fromVariant(variant),
      status = _adminStockStatuses.contains(variant.stockStatus)
          ? variant.stockStatus
          : StockStatus.inStock,
      active = variant.isActive;

  factory _VariantDraft.create({required String id}) => _VariantDraft(
    ProductVariant(
      id: id,
      name: 'Nueva variante',
      stockStatus: StockStatus.inStock,
    ),
  );

  final ProductVariant variant;
  final TextEditingController name;
  final TextEditingController sku;
  final AdminImageDraft image;
  StockStatus status;
  bool active;

  Map<String, dynamic> toMap() {
    final data = Map<String, dynamic>.from(variant.toMap());
    data['name'] = name.text.trim().toUpperCase();
    data['sku'] = sku.text.trim().toUpperCase();
    data.remove('colorHex');
    data.remove('priceOverride');
    data.remove('priceTiers');
    image.writeReplacementTo(data);
    data.remove('stock');
    data['stockStatus'] = status.key;
    data['isActive'] = active;
    return data;
  }

  void dispose() {
    name.dispose();
    sku.dispose();
  }
}

class _VariantEditorTile extends StatefulWidget {
  const _VariantEditorTile({
    required this.draft,
    required this.imageUrl,
    required this.uploading,
    required this.onPickImage,
    required this.onDelete,
    required this.onReorder,
  });

  final _VariantDraft draft;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPickImage;
  final VoidCallback onDelete;
  final void Function(_VariantDraft dragged, _VariantDraft target) onReorder;

  @override
  State<_VariantEditorTile> createState() => _VariantEditorTileState();
}

class _VariantEditorTileState extends State<_VariantEditorTile> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return DragTarget<_VariantDraft>(
      onWillAcceptWithDetails: (details) => details.data != draft,
      onAcceptWithDetails: (details) => widget.onReorder(details.data, draft),
      builder: (context, candidates, rejected) => Card(
        key: ValueKey('variant-editor-${draft.variant.id}'),
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: candidates.isEmpty ? AppColors.border : AppColors.ink,
            width: candidates.isEmpty ? 1 : 2,
          ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final nameField = TextFormField(
                key: ValueKey('variant-name-${draft.variant.id}'),
                controller: draft.name,
                scrollPadding: const EdgeInsets.fromLTRB(20, 80, 20, 140),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UppercaseTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej. Verde militar',
                ),
                validator: _required,
              );
              final skuField = TextFormField(
                key: ValueKey('variant-sku-${draft.variant.id}'),
                controller: draft.sku,
                scrollPadding: const EdgeInsets.fromLTRB(20, 80, 20, 140),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: const [UppercaseTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Código / SKU',
                  hintText: 'Ej. XS-1',
                ),
              );
              final statusField = _VariantStatusSelector(
                key: ValueKey('variant-status-${draft.variant.id}'),
                value: draft.status,
                onChanged: (value) {
                  setState(() => draft.status = value);
                },
              );
              final isTouch =
                  Theme.of(context).platform == TargetPlatform.android ||
                      Theme.of(context).platform == TargetPlatform.iOS;
              final imageChild = Tooltip(
                message: isTouch
                    ? 'Mantén presionado para cambiar el orden'
                    : 'Arrastra la foto para cambiar el orden',
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: _VariantImage(
                    label: draft.name.text,
                    imageUrl: widget.imageUrl,
                  ),
                ),
              );
              final imageFeedback = Material(
                color: Colors.transparent,
                elevation: 10,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 190,
                  child: _VariantImage(
                    label: draft.name.text,
                    imageUrl: widget.imageUrl,
                  ),
                ),
              );
              final imageWhenDragging = Opacity(
                opacity: .3,
                child: _VariantImage(
                  label: draft.name.text,
                  imageUrl: widget.imageUrl,
                ),
              );
              final image = isTouch
                  ? LongPressDraggable<_VariantDraft>(
                      data: draft,
                      delay: const Duration(milliseconds: 250),
                      feedback: imageFeedback,
                      childWhenDragging: imageWhenDragging,
                      child: imageChild,
                    )
                  : Draggable<_VariantDraft>(
                      data: draft,
                      feedback: imageFeedback,
                      childWhenDragging: imageWhenDragging,
                      child: imageChild,
                    );
              final controls = _VariantImageActions(
                label: draft.name.text,
                visible: draft.active,
                uploading: widget.uploading,
                onPickImage: widget.onPickImage,
                onDelete: widget.onDelete,
                onVisibilityChanged: () {
                  setState(() => draft.active = !draft.active);
                },
              );
              final fields = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: nameField),
                      const SizedBox(width: 10),
                      Expanded(child: skuField),
                    ],
                  ),
                  const SizedBox(height: 10),
                  statusField,
                ],
              );
              final media = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  controls,
                  const SizedBox(width: 10),
                  if (narrow)
                    Expanded(child: image)
                  else
                    SizedBox.square(dimension: 250, child: image),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [media, const SizedBox(height: 12), fields],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  media,
                  const SizedBox(width: 14),
                  Expanded(child: fields),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VariantImage extends StatelessWidget {
  const _VariantImage({required this.label, required this.imageUrl});

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      key: ValueKey('variant-image-${label.trim()}'),
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.canvas,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ProductVisual(
            label: label,
            imageAsset: imageUrl,
            decodeToLayout: true,
          ),
        ),
      ),
    );
  }
}

class _VariantImageActions extends StatelessWidget {
  const _VariantImageActions({
    required this.label,
    required this.visible,
    required this.uploading,
    required this.onPickImage,
    required this.onDelete,
    required this.onVisibilityChanged,
  });

  final String label;
  final bool visible;
  final bool uploading;
  final VoidCallback onPickImage;
  final VoidCallback onDelete;
  final VoidCallback onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VariantActionButton(
          key: ValueKey('edit-variant-image-${label.trim()}'),
          onPressed: uploading ? null : onPickImage,
          tooltip: 'Cambiar foto',
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          icon: uploading
              ? const SizedBox.square(
                  dimension: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.photo_camera_rounded, size: 16),
        ),
        const SizedBox(height: 6),
        _VariantActionButton(
          key: ValueKey('toggle-variant-visibility-${label.trim()}'),
          onPressed: onVisibilityChanged,
          tooltip: visible ? 'Ocultar del catálogo' : 'Mostrar en el catálogo',
          backgroundColor: visible
              ? AppColors.ink
              : AppColors.ink.withValues(alpha: .32),
          foregroundColor: Colors.white,
          icon: Icon(
            visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 16,
          ),
        ),
        const SizedBox(height: 18),
        _VariantActionButton(
          key: ValueKey('delete-variant-${label.trim()}'),
          onPressed: onDelete,
          tooltip: 'Quitar esta opción',
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.error,
          borderColor: Theme.of(context).colorScheme.error
              .withValues(alpha: .5),
          icon: const Icon(Icons.delete_outline_rounded, size: 16),
        ),
      ],
    );
  }
}

class _VariantActionButton extends StatelessWidget {
  const _VariantActionButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    this.borderColor,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(32),
          maximumSize: const Size.square(32),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: AppColors.ink.withValues(alpha: .45),
          disabledForegroundColor: Colors.white,
          shape: const CircleBorder(),
          side: borderColor == null ? null : BorderSide(color: borderColor!),
        ),
        icon: icon,
      ),
    );
  }
}

class _ImageEditor extends StatelessWidget {
  const _ImageEditor({
    required this.label,
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
  });

  final String label;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: _EditableImage(
        label: label,
        imageUrl: imageUrl,
        uploading: uploading,
        onPick: onPick,
        radius: 16,
      ),
    );
  }
}

class _EditableImage extends StatelessWidget {
  const _EditableImage({
    required this.label,
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
    required this.radius,
  });

  final String label;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('edit-image-$label'),
      button: true,
      label: 'Cambiar foto de $label',
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: uploading ? null : onPick,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ProductVisual(
                label: label,
                imageAsset: imageUrl,
                decodeToLayout: true,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x33000000), blurRadius: 8),
                    ],
                  ),
                  child: uploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({
    required this.email,
    required this.onRetry,
    required this.onSignOut,
  });

  final String email;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'Cuenta sin permiso de administración',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$email inició sesión, pero todavía no tiene el atributo '
                      'admin. Asigna el permiso y vuelve a comprobarlo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: onSignOut,
                          child: const Text('Usar otra cuenta'),
                        ),
                        FilledButton(
                          onPressed: onRetry,
                          child: const Text('Comprobar permiso'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotpEnrollmentScreen extends StatefulWidget {
  const _TotpEnrollmentScreen({
    required this.client,
    required this.onVerified,
    required this.onSignOut,
  });

  final SupabaseClient client;
  final VoidCallback onVerified;
  final Future<void> Function() onSignOut;

  @override
  State<_TotpEnrollmentScreen> createState() => _TotpEnrollmentScreenState();
}

class _TotpEnrollmentScreenState extends State<_TotpEnrollmentScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _verifying = false;
  String? _error;
  String? _factorId;
  String? _secret;
  String? _totpUri;

  @override
  void initState() {
    super.initState();
    _startEnrollment();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final factors = await widget.client.auth.mfa.listFactors();
      final pendingTotpFactors = factors.all.where(
        (factor) =>
            factor.factorType == FactorType.totp &&
            factor.status == FactorStatus.unverified,
      );
      for (final factor in pendingTotpFactors) {
        await widget.client.auth.mfa.unenroll(factor.id);
      }

      final response = await widget.client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'Expresiones',
        friendlyName: 'Expresiones',
      );
      setState(() {
        _factorId = response.id;
        _secret = response.totp?.secret;
        _totpUri = response.totp?.uri;
        _loading = false;
      });
    } on AuthException catch (_) {
      setState(() {
        _error =
            'No se pudo preparar el autenticador. Reintenta en unos segundos.';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo preparar el autenticador. Revisa tu conexión y vuelve a intentarlo.';
        _loading = false;
      });
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate() || _verifying) return;
    final factorId = _factorId;
    if (factorId == null) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: _codeController.text.trim(),
      );
      widget.onVerified();
    } on AuthException catch (_) {
      setState(() {
        _error = 'Código de verificación incorrecto o expirado.';
      });
    } catch (e) {
      setState(() {
        _error = 'Error de verificación: $e';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security_rounded, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'Configurar verificación en dos pasos',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Escanea este código con tu aplicación autenticadora (Google Authenticator, Microsoft Authenticator o Bitwarden).',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )
                    else if (_error != null && _factorId == null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: widget.onSignOut,
                            child: const Text('Cerrar sesión'),
                          ),
                          FilledButton(
                            onPressed: _startEnrollment,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ] else ...[
                      if (_totpUri != null && _totpUri!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: QrImageView(
                            data: _totpUri!,
                            version: QrVersions.auto,
                            size: 190.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      if (_secret != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          'O escribe esta clave secreta en tu aplicación:',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: SelectableText(
                                  _secret!,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: 'Copiar clave',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _secret!),
                                  );
                                  showAppNotice(
                                    context,
                                    'Clave secreta copiada.',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                letterSpacing: 6,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Código de 6 dígitos',
                                hintText: '000000',
                                counterText: '',
                                prefixIcon: Icon(Icons.pin_outlined),
                              ),
                              validator: (v) {
                                final code = v?.trim() ?? '';
                                if (code.length != 6 ||
                                    int.tryParse(code) == null) {
                                  return 'Ingresa el código de 6 dígitos.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _verify(),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: widget.onSignOut,
                                    child: const Text('Cerrar sesión'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _verifying ? null : _verify,
                                    child: _verifying
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Activar y entrar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotpChallengeScreen extends StatefulWidget {
  const _TotpChallengeScreen({
    required this.client,
    required this.factorId,
    required this.onVerified,
    required this.onSignOut,
  });

  final SupabaseClient client;
  final String factorId;
  final VoidCallback onVerified;
  final Future<void> Function() onSignOut;

  @override
  State<_TotpChallengeScreen> createState() => _TotpChallengeScreenState();
}

class _TotpChallengeScreenState extends State<_TotpChallengeScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate() || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await widget.client.auth.mfa.challengeAndVerify(
        factorId: widget.factorId,
        code: _codeController.text.trim(),
      );
      widget.onVerified();
    } on AuthException catch (_) {
      setState(() {
        _error = 'Código de verificación incorrecto o expirado.';
      });
    } catch (e) {
      setState(() {
        _error = 'Error de autenticación: $e';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 54),
                      const SizedBox(height: 16),
                      Text(
                        'Verificación en dos pasos',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresa el código de 6 dígitos que muestra tu app autenticadora.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Código TOTP',
                          hintText: '000000',
                          counterText: '',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (v) {
                          final code = v?.trim() ?? '';
                          if (code.length != 6 || int.tryParse(code) == null) {
                            return 'Ingresa los 6 dígitos del autenticador.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _verify(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onSignOut,
                              child: const Text('Cerrar sesión'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _verifying ? null : _verify,
                              child: _verifying
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Ingresar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminLoading extends StatelessWidget {
  const _AdminLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.title, required this.message, this.onRetry});

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 22),
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyAuthMessage(Object? error) {
  final detail = '$error'.toLowerCase();
  if (detail.contains('failed to fetch') ||
      detail.contains('network') ||
      detail.contains('socket')) {
    return 'No se pudo conectar con Supabase. Revisa tu conexión e '
        'inténtalo otra vez.';
  }
  return 'No se pudo validar el acceso en este momento. Inténtalo otra vez.';
}

/// Converts catalog text as it is entered while preserving the caret position.
class UppercaseTextInputFormatter extends TextInputFormatter {
  const UppercaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Mobile keyboards (Gboard, iOS) keep the word being typed in a
    // "composing" region. Rewriting the text mid-composition forces the
    // keyboard to resynchronise on every keystroke, which felt laggy and broke
    // suggestions on phones. Wait until the word is committed; the field also
    // requests uppercase from the keyboard and values are uppercased on save.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final upperText = newValue.text.toUpperCase();
    if (upperText == newValue.text) return newValue;

    int uppercaseOffset(int offset) {
      if (offset < 0) return offset;
      final safeOffset = offset.clamp(0, newValue.text.length).toInt();
      return newValue.text.substring(0, safeOffset).toUpperCase().length;
    }

    return newValue.copyWith(
      text: upperText,
      selection: TextSelection(
        baseOffset: uppercaseOffset(newValue.selection.baseOffset),
        extentOffset: uppercaseOffset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
      composing: TextRange.empty,
    );
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Este campo es obligatorio.' : null;

double _decimal(String value) =>
    double.parse(value.trim().replaceAll(',', '.'));

double? _optionalDecimal(String value) {
  final text = value.trim();
  return text.isEmpty ? null : double.tryParse(text.replaceAll(',', '.'));
}

String? _nonNegativeDecimal(String? value) {
  final parsed = _optionalDecimal(value ?? '');
  return parsed == null || !parsed.isFinite || parsed < 0
      ? 'Ingresa un monto válido.'
      : null;
}

String? _nonNegativeInt(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  return parsed == null || parsed < 0 ? 'Ingresa un número válido.' : null;
}

String? _positiveInt(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  return parsed == null || parsed < 2 ? 'Mínimo 2.' : null;
}

String? _priceTierListError(
  List<_PriceTierDraft> tiers, {
  required String owner,
}) {
  final quantities = <int>{};
  for (final tier in tiers) {
    final quantity = int.tryParse(tier.quantity.text.trim());
    final total = _optionalDecimal(tier.totalPrice.text);
    if (quantity == null ||
        quantity < 2 ||
        total == null ||
        !total.isFinite ||
        total < 0) {
      return 'Revisa las cantidades y precios totales de $owner.';
    }
    if (!quantities.add(quantity)) {
      return 'La cantidad $quantity está repetida en $owner.';
    }
  }
  return null;
}

String _defaultPriceTierLabel(int quantity) => switch (quantity) {
  1 => 'Unidad',
  6 => 'Media docena',
  12 => 'Docena',
  100 => 'Ciento',
  _ => 'Desde $quantity',
};

String _presentationName(int quantity) => switch (quantity) {
  1 => 'Unidad',
  6 => 'Media docena',
  12 => 'Docena',
  100 => 'Ciento',
  _ => '$quantity unidades',
};
