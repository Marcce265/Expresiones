import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/product_card.dart';
import '../widgets/product_visual.dart';
import 'admin_analytics_screen.dart';
import 'admin_catalog_repository.dart';
import 'admin_capacity_screen.dart';
import 'admin_operations_repository.dart';

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
class AdminPortal extends StatelessWidget {
  const AdminPortal({super.key, required this.client});

  final SupabaseClient client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminError(
            title: 'No se pudo comprobar la sesión',
            message: '${snapshot.error}',
          );
        }
        final user = snapshot.data?.session?.user ?? client.auth.currentUser;
        if (snapshot.connectionState == ConnectionState.waiting &&
            user == null) {
          return const _AdminLoading();
        }
        if (user == null) return AdminLoginScreen(client: client);
        return _AdminSecurityGate(client: client, user: user);
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
            message: '${snapshot.error}',
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
            : 'No se pudo iniciar sesión. ${error.message}';
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
  String _query = '';
  String _catalogGroup = 'Todos';

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
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor([CatalogProduct? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdminProductEditorDialog(
        repository: widget.repository,
        product: product,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product == null ? 'Producto creado.' : 'Producto actualizado.',
          ),
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ChangePasswordDialog(client: widget.client),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expresiones · Catálogo'),
        actions: [
          IconButton(
            tooltip: 'Capacidad de producción',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    AdminCapacityScreen(repository: widget.operations),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Actividad y búsquedas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    AdminAnalyticsScreen(repository: widget.operations),
              ),
            ),
            icon: const Icon(Icons.query_stats_outlined),
          ),
          if (widget.userEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text(widget.userEmail)),
            ),
          IconButton(
            tooltip: 'Crear o cambiar contraseña',
            onPressed: _changePassword,
            icon: const Icon(Icons.password_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo producto'),
      ),
      body: StreamBuilder<List<CatalogProduct>>(
        stream: widget.repository.watchProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminError(
              title: 'No se pudo leer el catálogo',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) return const _AdminLoading();
          final allProducts = snapshot.data!
              .where((product) => !product.attributes.containsKey('mergedInto'))
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
                          const Eyebrow('Modo administrador'),
                          const SizedBox(height: 6),
                          Text(
                            'Edita el mismo catálogo que ven tus clientes',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cada tarjeta corresponde a un producto del catálogo público.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          const InfoBanner(
                            icon: Icons.edit_outlined,
                            title: 'Cómo editar',
                            message: 'Pulsa el lápiz de la esquina superior derecha para cambiar la foto, el nombre, la descripción, el precio, el stock o sus variantes.',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: 'Buscar material, color o código',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
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
                          const SizedBox(height: 12),
                          Text(
                            '${products.length} productos',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
          onPressed: _busy ? null : () => Navigator.pop(context, false),
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
  late final TextEditingController _imageUrl;
  late final TextEditingController _unitLabel;
  late final TextEditingController _basePrice;
  late final TextEditingController _stock;
  late final TextEditingController _leadDays;
  late final TextEditingController _productionPoints;
  late final TextEditingController _sortOrder;
  late final List<_VariantDraft> _variants;
  late ProductCategory _category;
  late StockStatus _stockStatus;
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
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _unitLabel = TextEditingController(text: product?.unitLabel ?? 'unidad');
    _basePrice = TextEditingController(
      text: product == null ? '' : product.basePrice.toStringAsFixed(2),
    );
    _stock = TextEditingController(text: product?.stock?.toString() ?? '');
    _leadDays = TextEditingController(text: '${product?.leadDays ?? 0}');
    _productionPoints = TextEditingController(
      text: '${product?.productionPoints ?? 0}',
    );
    _sortOrder = TextEditingController(text: '${product?.sortOrder ?? 0}');
    _category = product?.category ?? ProductCategory.materials;
    _stockStatus = product?.stockStatus ?? StockStatus.inStock;
    _isActive = product?.isActive ?? true;
    _isFeatured = product?.isFeatured ?? false;
    _priceIsEstimate = product?.priceIsEstimate ?? false;
    _variants = [
      for (final variant in product?.variants ?? const <ProductVariant>[])
        if (variant.isActive) _VariantDraft(variant),
    ];
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _description,
      _imageUrl,
      _unitLabel,
      _basePrice,
      _stock,
      _leadDays,
      _productionPoints,
      _sortOrder,
    ]) {
      controller.dispose();
    }
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving || _uploadingImage) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final stock = _optionalInt(_stock.text);
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'category': _category.key,
        'description': _description.text.trim(),
        'sku': _sku.text.trim(),
        'unitLabel': _unitLabel.text.trim(),
        'basePrice': _decimal(_basePrice.text),
        'startingAt': widget.product?.startingAt ?? false,
        'priceIsEstimate': _priceIsEstimate,
        'priceTiers': [
          for (final tier in widget.product?.priceTiers ?? const <PriceTier>[])
            tier.toMap(),
        ],
        'variants': [for (final variant in _variants) variant.toMap()],
        'stockStatus': _stockStatus.key,
        'leadDays': int.parse(_leadDays.text.trim()),
        'productionPoints': int.parse(_productionPoints.text.trim()),
        'isActive': _isActive,
        'isFeatured': _isFeatured,
        'sortOrder': int.parse(_sortOrder.text.trim()),
        'imageUrl': _imageUrl.text.trim(),
        'tags': widget.product?.tags ?? const <String>[],
        'attributes': widget.product?.attributes ?? const <String, String>{},
      };
      if (stock != null) {
        data['stock'] = stock;
      } else if (widget.product != null) {
        data['stock'] = null;
      }

      final product = widget.product;
      if (product == null) {
        await widget.repository.createProduct(
          documentId: _sku.text.trim().isEmpty ? _name.text : _sku.text,
          data: data,
        );
      } else {
        await widget.repository.updateProduct(product.id, data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addVariant() {
    final draft = _VariantDraft.create(
      id: 'variante-${DateTime.now().microsecondsSinceEpoch}',
    );
    setState(() => _variants.add(draft));
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
      if (mounted) Navigator.pop(context, true);
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
      final path = await widget.repository.uploadCatalogImage(
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
          _imageUrl.text = path;
        } else {
          variant.imageUrl.text = path;
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
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product == null
                          ? 'Nuevo producto'
                          : 'Editar producto',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _ImageEditor(
                      label: _name.text.trim().isEmpty
                          ? 'Imagen del producto'
                          : _name.text.trim(),
                      imageUrl: _previewUrl(_imageUrl.text),
                      uploading: _uploadingImage,
                      onPick: _pickImage,
                    ),
                    const SizedBox(height: 18),
                    _formRow([
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                        ),
                        validator: _required,
                      ),
                      TextFormField(
                        controller: _sku,
                        decoration: const InputDecoration(
                          labelText: 'Código / SKU',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _formRow([
                      DropdownButtonFormField<ProductCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: [
                          for (final category in ProductCategory.values)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _category = value);
                        },
                      ),
                      TextFormField(
                        controller: _unitLabel,
                        decoration: const InputDecoration(
                          labelText: 'Unidad de venta *',
                          hintText: 'unidad, rollo, paquete',
                        ),
                        validator: _required,
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _formRow([
                      TextFormField(
                        controller: _basePrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio base (S/) *',
                        ),
                        validator: _nonNegativeDecimal,
                      ),
                      TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock exacto',
                          hintText: 'Vacío si no se publica',
                        ),
                        validator: _optionalNonNegativeInt,
                      ),
                      DropdownButtonFormField<StockStatus>(
                        initialValue: _stockStatus,
                        decoration: const InputDecoration(
                          labelText: 'Disponibilidad',
                        ),
                        items: [
                          for (final status in StockStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _stockStatus = value);
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _formRow([
                      TextFormField(
                        controller: _leadDays,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Días de preparación',
                        ),
                        validator: _nonNegativeInt,
                      ),
                      TextFormField(
                        controller: _productionPoints,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Puntos de producción',
                        ),
                        validator: _nonNegativeInt,
                      ),
                      TextFormField(
                        controller: _sortOrder,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Orden'),
                        validator: _nonNegativeInt,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Publicado'),
                          value: _isActive,
                          onChanged: (value) =>
                              setState(() => _isActive = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Destacado'),
                          value: _isFeatured,
                          onChanged: (value) =>
                              setState(() => _isFeatured = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Precio por revisar'),
                          value: _priceIsEstimate,
                          onChanged: (value) =>
                              setState(() => _priceIsEstimate = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Variantes (${_variants.length})',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _addVariant,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar variante'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Abre cada variante para editar su nombre, código, color, '
                      'imagen, precio, stock y disponibilidad.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    if (_variants.isEmpty)
                      const InfoBanner(
                        icon: Icons.layers_outlined,
                        title: 'Este producto aún no tiene variantes',
                        message: 'Agrégalas cuando el material se venda en distintos colores, tamaños o modelos.',
                      )
                    else
                      for (final variant in _variants)
                        _VariantEditorTile(
                          draft: variant,
                          imageUrl: _previewUrl(variant.imageUrl.text),
                          uploading: _uploadingImage,
                          onPickImage: () => _pickImage(variant: variant),
                          onDelete: () => _removeVariant(variant),
                          onChanged: () => setState(() {}),
                        ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.product != null)
                    TextButton.icon(
                      onPressed: _saving ? null : _deleteProduct,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Eliminar producto'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
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
                      _uploadingImage ? 'Subiendo imagen…' : 'Guardar cambios',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formRow(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                fields[index],
                if (index != fields.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              Expanded(child: fields[index]),
              if (index != fields.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _VariantDraft {
  _VariantDraft(this.variant)
    : name = TextEditingController(text: variant.name),
      sku = TextEditingController(text: variant.sku ?? ''),
      colorHex = TextEditingController(text: variant.colorHex ?? ''),
      imageUrl = TextEditingController(text: variant.imageUrl ?? ''),
      price = TextEditingController(
        text: variant.priceOverride?.toStringAsFixed(2) ?? '',
      ),
      stock = TextEditingController(text: variant.stock?.toString() ?? ''),
      status = variant.stockStatus,
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
  final TextEditingController colorHex;
  final TextEditingController imageUrl;
  final TextEditingController price;
  final TextEditingController stock;
  StockStatus status;
  bool active;

  Map<String, dynamic> toMap() {
    final data = Map<String, dynamic>.from(variant.toMap());
    data['name'] = name.text.trim();
    data['sku'] = sku.text.trim();
    final normalizedColor = _normalizedHex(colorHex.text);
    if (normalizedColor == null) {
      data.remove('colorHex');
    } else {
      data['colorHex'] = normalizedColor;
    }
    data['imageUrl'] = imageUrl.text.trim();
    data.remove('thumbnailUrl');
    final parsedPrice = _optionalDecimal(price.text);
    final parsedStock = _optionalInt(stock.text);
    if (parsedPrice == null) {
      data.remove('priceOverride');
    } else {
      data['priceOverride'] = parsedPrice;
    }
    if (parsedStock == null) {
      data.remove('stock');
    } else {
      data['stock'] = parsedStock;
    }
    data['stockStatus'] = status.key;
    data['isActive'] = active;
    return data;
  }

  void dispose() {
    name.dispose();
    sku.dispose();
    colorHex.dispose();
    imageUrl.dispose();
    price.dispose();
    stock.dispose();
  }
}

class _VariantEditorTile extends StatelessWidget {
  const _VariantEditorTile({
    required this.draft,
    required this.imageUrl,
    required this.uploading,
    required this.onPickImage,
    required this.onDelete,
    required this.onChanged,
  });

  final _VariantDraft draft;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPickImage;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.canvas,
      child: ExpansionTile(
        leading: _ColorSwatch(value: draft.colorHex.text),
        title: Text(draft.name.text),
        subtitle: Text(
          draft.sku.text.trim().isEmpty ? draft.variant.id : draft.sku.text,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _ImageEditor(
            label: draft.name.text,
            imageUrl: imageUrl,
            colorHex: draft.colorHex.text,
            uploading: uploading,
            onPick: onPickImage,
            compact: true,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                TextFormField(
                  controller: draft.name,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: _required,
                  onChanged: (_) => onChanged(),
                ),
                TextFormField(
                  controller: draft.sku,
                  decoration: const InputDecoration(labelText: 'Código / SKU'),
                  onChanged: (_) => onChanged(),
                ),
                TextFormField(
                  controller: draft.colorHex,
                  decoration: InputDecoration(
                    labelText: 'Color (HEX)',
                    hintText: '#E7A2B4',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _ColorSwatch(value: draft.colorHex.text),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  validator: _optionalHexColor,
                  onChanged: (_) => onChanged(),
                ),
              ];
              if (constraints.maxWidth < 700) {
                return Column(
                  children: [
                    for (var index = 0; index < fields.length; index++) ...[
                      fields[index],
                      if (index < fields.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var index = 0; index < fields.length; index++) ...[
                    Expanded(child: fields[index]),
                    if (index < fields.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                TextFormField(
                  controller: draft.price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio propio (S/)',
                    hintText: 'Vacío: usa precio base',
                  ),
                  validator: _optionalNonNegativeDecimal,
                ),
                TextFormField(
                  controller: draft.stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock exacto'),
                  validator: _optionalNonNegativeInt,
                ),
                DropdownButtonFormField<StockStatus>(
                  initialValue: draft.status,
                  decoration: const InputDecoration(
                    labelText: 'Disponibilidad',
                  ),
                  items: [
                    for (final status in StockStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      draft.status = value;
                      onChanged();
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  title: const Text('Publicada'),
                  subtitle: const Text('Visible en el catálogo'),
                  value: draft.active,
                  onChanged: (value) {
                    draft.active = value;
                    onChanged();
                  },
                ),
              ];
              if (constraints.maxWidth < 700) {
                return Column(
                  children: [
                    for (var index = 0; index < fields.length; index++) ...[
                      fields[index],
                      if (index < fields.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < fields.length; index++) ...[
                    Expanded(child: fields[index]),
                    if (index < fields.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Quitar esta variante'),
            ),
          ),
        ],
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
    this.colorHex,
    this.compact = false,
  });

  final String label;
  final String? imageUrl;
  final String? colorHex;
  final bool uploading;
  final VoidCallback onPick;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 108.0 : 150.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ProductVisual(
            label: label,
            imageAsset: imageUrl,
            colorHex: colorHex,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                compact ? 'Imagen de esta variante' : 'Imagen principal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 5),
              Text(
                'JPG, PNG o WebP. Máximo 8 MB.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: uploading ? null : onPick,
                icon: uploading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(uploading ? 'Subiendo…' : 'Cambiar imagen'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(value);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: color == null
          ? const Icon(Icons.palette_outlined, size: 15)
          : null,
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Clave secreta copiada.'),
                                    ),
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
  const _AdminError({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            SelectableText(message, textAlign: TextAlign.center),
          ],
        ),
      ),
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

int? _optionalInt(String value) {
  final text = value.trim();
  return text.isEmpty ? null : int.tryParse(text);
}

String? _nonNegativeDecimal(String? value) {
  final parsed = _optionalDecimal(value ?? '');
  return parsed == null || parsed < 0 ? 'Ingresa un monto válido.' : null;
}

String? _optionalNonNegativeDecimal(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = _optionalDecimal(value);
  return parsed == null || parsed < 0 ? 'Ingresa un monto válido.' : null;
}

String? _nonNegativeInt(String? value) {
  final parsed = int.tryParse(value?.trim() ?? '');
  return parsed == null || parsed < 0 ? 'Ingresa un número válido.' : null;
}

String? _optionalNonNegativeInt(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = int.tryParse(value.trim());
  return parsed == null || parsed < 0 ? 'Ingresa un número válido.' : null;
}

String? _normalizedHex(String? value) {
  final text = value?.trim().replaceFirst('#', '').toUpperCase() ?? '';
  return RegExp(r'^[0-9A-F]{6}$').hasMatch(text) ? '#$text' : null;
}

String? _optionalHexColor(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return _normalizedHex(value) == null
      ? 'Usa un color HEX como #E7A2B4.'
      : null;
}

Color? _colorFromHex(String? value) {
  final normalized = _normalizedHex(value);
  if (normalized == null) return null;
  return Color(0xFF000000 | int.parse(normalized.substring(1), radix: 16));
}
