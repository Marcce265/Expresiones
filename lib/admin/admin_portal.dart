import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/catalog_models.dart';
import '../theme/app_theme.dart';
import 'admin_analytics_screen.dart';
import 'admin_catalog_repository.dart';
import 'admin_capacity_screen.dart';
import 'admin_operations_repository.dart';

class AdminPortalApp extends StatelessWidget {
  const AdminPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expresiones · Administración',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AdminPortal(),
    );
  }
}

/// Authenticates staff and verifies the `admin: true` Firebase custom claim.
class AdminPortal extends StatelessWidget {
  const AdminPortal({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AdminLoading();
        }
        final user = snapshot.data;
        if (user == null) return AdminLoginScreen(auth: auth);
        return _ClaimGate(user: user, auth: auth);
      },
    );
  }
}

class _ClaimGate extends StatefulWidget {
  const _ClaimGate({required this.user, required this.auth});

  final User user;
  final FirebaseAuth auth;

  @override
  State<_ClaimGate> createState() => _ClaimGateState();
}

class _ClaimGateState extends State<_ClaimGate> {
  late Future<bool> _allowed;

  @override
  void initState() {
    super.initState();
    _allowed = _checkClaim();
  }

  Future<bool> _checkClaim() async {
    final result = await widget.user.getIdTokenResult(true);
    return result.claims?['admin'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _allowed,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AdminLoading();
        }
        if (snapshot.hasError || snapshot.data != true) {
          return _AccessDenied(
            email: widget.user.email ?? '',
            onRetry: () => setState(() => _allowed = _checkClaim()),
            onSignOut: widget.auth.signOut,
          );
        }
        return AdminDashboardScreen(
          repository: AdminCatalogRepository(),
          userEmail: widget.user.email ?? '',
          onSignOut: widget.auth.signOut,
        );
      },
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.auth});

  final FirebaseAuth auth;

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
      await widget.auth.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _error = switch (error.code) {
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'Correo o contraseña incorrectos.',
          'too-many-requests' =>
            'Demasiados intentos. Espera unos minutos y vuelve a intentar.',
          _ => 'No se pudo iniciar sesión (${error.code}).',
        };
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
                        'administrador asignado en Firebase.',
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
    required this.repository,
    required this.userEmail,
    required this.onSignOut,
  });

  final AdminCatalogRepository repository;
  final String userEmail;
  final Future<void> Function() onSignOut;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _search = TextEditingController();
  final _operations = AdminOperationsRepository();
  String _query = '';
  bool _onlyEstimated = false;

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
                builder: (_) => AdminCapacityScreen(repository: _operations),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Actividad y búsquedas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AdminAnalyticsScreen(repository: _operations),
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
          final allProducts = snapshot.data!;
          final products = allProducts.where((product) {
            if (_onlyEstimated && !product.priceIsEstimate) return false;
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

          final active = allProducts.where((item) => item.isActive).length;
          final estimates = allProducts
              .where((item) => item.priceIsEstimate)
              .length;
          final lowStock = allProducts.where((item) {
            return item.stockStatus == StockStatus.lowStock ||
                item.stockStatus == StockStatus.outOfStock ||
                item.variants.any(
                  (variant) =>
                      variant.stockStatus == StockStatus.lowStock ||
                      variant.stockStatus == StockStatus.outOfStock,
                );
          }).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: 'Productos',
                    value: '${allProducts.length}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _MetricCard(
                    label: 'Publicados',
                    value: '$active',
                    icon: Icons.public_rounded,
                  ),
                  _MetricCard(
                    label: 'Precio por revisar',
                    value: '$estimates',
                    icon: Icons.price_check_outlined,
                  ),
                  _MetricCard(
                    label: 'Stock bajo o agotado',
                    value: '$lowStock',
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 420,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            labelText: 'Buscar nombre, código o variante',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                        ),
                      ),
                      FilterChip(
                        selected: _onlyEstimated,
                        label: const Text('Solo precios por revisar'),
                        onSelected: (value) =>
                            setState(() => _onlyEstimated = value),
                      ),
                      Text('${products.length} resultados'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (products.isEmpty)
                const _AdminError(
                  title: 'No hay resultados',
                  message: 'Prueba con otra búsqueda o quita los filtros.',
                )
              else
                for (final product in products) ...[
                  _ProductAdminCard(
                    product: product,
                    onEdit: () => _openEditor(product),
                    onActiveChanged: (active) async {
                      try {
                        await widget.repository.setProductActive(
                          product.id,
                          active,
                        );
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No se pudo guardar: $error'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _ProductAdminCard extends StatelessWidget {
  const _ProductAdminCard({
    required this.product,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final CatalogProduct product;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final stockLabel = product.stock == null
        ? product.stockStatus.label
        : '${product.stock} ${product.unitLabel}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: product.isActive ? AppColors.pinkSoft : AppColors.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                product.isActive
                    ? Icons.inventory_2_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${product.sku ?? product.id} · ${product.category.label} · '
                    '${product.variants.length} variantes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (product.priceIsEstimate)
              const Chip(label: Text('Precio por revisar')),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/ ${product.basePrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    stockLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(value: product.isActive, onChanged: onActiveChanged),
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
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
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _description = TextEditingController(text: product?.description ?? '');
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
        _VariantDraft(variant),
    ];
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _description,
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
    if (!_formKey.currentState!.validate() || _saving) return;
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
        'imageUrl': widget.product?.imageUrl ?? '',
        'tags': widget.product?.tags ?? const <String>[],
        'attributes': widget.product?.attributes ?? const <String, String>{},
      };
      if (stock != null) {
        data['stock'] = stock;
      } else if (widget.product != null) {
        data['stock'] = FieldValue.delete();
      }

      final product = widget.product;
      if (product == null) {
        data.removeWhere((key, value) => value is FieldValue);
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
                    if (_variants.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Variantes (${_variants.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Puedes corregir precio, stock y disponibilidad sin '
                        'cambiar las imágenes ni los códigos.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      for (final variant in _variants)
                        _VariantEditorTile(
                          draft: variant,
                          onChanged: () => setState(() {}),
                        ),
                    ],
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
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
    : price = TextEditingController(
        text: variant.priceOverride?.toStringAsFixed(2) ?? '',
      ),
      stock = TextEditingController(text: variant.stock?.toString() ?? ''),
      status = variant.stockStatus,
      active = variant.isActive;

  final ProductVariant variant;
  final TextEditingController price;
  final TextEditingController stock;
  StockStatus status;
  bool active;

  Map<String, dynamic> toMap() {
    final data = Map<String, dynamic>.from(variant.toMap());
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
    price.dispose();
    stock.dispose();
  }
}

class _VariantEditorTile extends StatelessWidget {
  const _VariantEditorTile({required this.draft, required this.onChanged});

  final _VariantDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.canvas,
      child: ExpansionTile(
        title: Text(draft.variant.name),
        subtitle: Text(draft.variant.sku ?? draft.variant.id),
        trailing: Switch(
          value: draft.active,
          onChanged: (value) {
            draft.active = value;
            onChanged();
          },
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: draft.stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock exacto'),
                  validator: _optionalNonNegativeInt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<StockStatus>(
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ],
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
