/// Sections shown in the public catalog.
enum ProductCategory {
  materials('materials', 'Materiales'),
  bouquets('bouquets', 'Ramos'),
  personalizedGifts('personalized_gifts', 'Regalos personalizados');

  const ProductCategory(this.key, this.label);

  final String key;
  final String label;

  static ProductCategory fromValue(Object? value) {
    final normalized = _normalized(value);
    return switch (normalized) {
      'bouquet' || 'bouquets' || 'ramo' || 'ramos' => bouquets,
      'personalizedgift' ||
      'personalizedgifts' ||
      'regalopersonalizado' ||
      'regalospersonalizados' => personalizedGifts,
      _ => materials,
    };
  }
}

/// Availability can be explicit even when an exact stock count is unavailable.
enum StockStatus {
  inStock('in_stock', 'Disponible'),
  lowStock('low_stock', 'Pocas unidades'),
  outOfStock('out_of_stock', 'Agotado'),
  madeToOrder('made_to_order', 'Hecho a pedido'),
  checkAvailability('check_availability', 'Consultar disponibilidad');

  const StockStatus(this.key, this.label);

  final String key;
  final String label;

  static StockStatus fromValue(Object? value, {int? stock}) {
    final normalized = _normalized(value);
    if (normalized.isEmpty && stock != null) {
      return stock <= 0 ? outOfStock : inStock;
    }
    return switch (normalized) {
      'instock' || 'disponible' => inStock,
      'lowstock' || 'pocasunidades' => lowStock,
      'outofstock' || 'agotado' || 'sinstock' => outOfStock,
      'madetoorder' || 'hechoapedido' || 'porpedido' => madeToOrder,
      _ => checkAvailability,
    };
  }
}

/// A quantity threshold and its effective unit price.
class PriceTier {
  const PriceTier({
    required this.minQuantity,
    required this.unitPrice,
    this.label,
  });

  final int minQuantity;
  final double unitPrice;
  final String? label;

  bool appliesTo(int quantity) => quantity >= minQuantity;

  factory PriceTier.fromMap(Map<String, dynamic> map) {
    return PriceTier(
      minQuantity: _asInt(
        _first(map, const [
          'minQuantity',
          'min_quantity',
          'minimumQuantity',
          'cantidadMinima',
          'quantity',
        ]),
        fallback: 1,
        minimum: 1,
      ),
      unitPrice: _asDouble(
        _first(map, const ['unitPrice', 'unit_price', 'price', 'precio']),
      ),
      label: _asNullableString(map['label'] ?? map['etiqueta']),
    );
  }

  Map<String, dynamic> toMap() => {
    'minQuantity': minQuantity,
    'unitPrice': unitPrice,
    if (label != null) 'label': label,
  };
}

/// A selectable presentation, size, color or model of a product.
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.name,
    this.sku,
    this.colorHex,
    this.imageUrl,
    this.priceOverride,
    this.priceTiers = const [],
    this.stock,
    this.stockStatus = StockStatus.checkAvailability,
    this.leadDays,
    this.productionPoints,
    this.isActive = true,
    this.attributes = const {},
  });

  final String id;
  final String name;
  final String? sku;
  final String? colorHex;
  final String? imageUrl;

  /// Overrides the product base price when this presentation is selected.
  final double? priceOverride;
  final List<PriceTier> priceTiers;

  /// Null means the catalog does not publish an exact count.
  final int? stock;
  final StockStatus stockStatus;
  final int? leadDays;
  final int? productionPoints;
  final bool isActive;
  final Map<String, String> attributes;

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    final stock = _asNullableInt(
      _first(map, const ['stock', 'stockCount', 'existencias']),
    );
    final rawTiers = _mapList(
      _first(map, const ['priceTiers', 'price_tiers', 'tiers', 'tramos']),
    );
    final tiers = rawTiers.map(PriceTier.fromMap).toList()
      ..sort((a, b) => a.minQuantity.compareTo(b.minQuantity));

    final name = _asString(
      _first(map, const ['name', 'nombre', 'label']),
      fallback: 'Opción',
    );
    final rawId = _asNullableString(
      _first(map, const ['id', 'variantId', 'variant_id', 'code', 'codigo']),
    );

    return ProductVariant(
      id: rawId ?? _slug(name),
      name: name,
      sku: _asNullableString(map['sku'] ?? map['code'] ?? map['codigo']),
      colorHex: _asNullableString(
        _first(map, const ['colorHex', 'color_hex', 'hex']),
      ),
      imageUrl: _asNullableString(
        _first(map, const ['imageUrl', 'image_url', 'image', 'imagen']),
      ),
      priceOverride: _asNullableDouble(
        _first(map, const [
          'priceOverride',
          'price_override',
          'basePrice',
          'price',
          'precio',
        ]),
      ),
      priceTiers: List.unmodifiable(tiers),
      stock: stock,
      stockStatus: StockStatus.fromValue(
        _first(map, const ['stockStatus', 'stock_status', 'availability']),
        stock: stock,
      ),
      leadDays: _asNullableInt(
        _first(map, const ['leadDays', 'lead_days', 'diasPreparacion']),
      ),
      productionPoints: _asNullableInt(
        _first(map, const [
          'productionPoints',
          'production_points',
          'puntosProduccion',
        ]),
      ),
      isActive: _asBool(
        map['isActive'] ?? map['active'] ?? map['activo'],
        fallback: true,
      ),
      attributes: _stringMap(map['attributes'] ?? map['atributos']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (sku != null) 'sku': sku,
    if (colorHex != null) 'colorHex': colorHex,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (priceOverride != null) 'priceOverride': priceOverride,
    'priceTiers': priceTiers.map((tier) => tier.toMap()).toList(),
    if (stock != null) 'stock': stock,
    'stockStatus': stockStatus.key,
    if (leadDays != null) 'leadDays': leadDays,
    if (productionPoints != null) 'productionPoints': productionPoints,
    'isActive': isActive,
    if (attributes.isNotEmpty) 'attributes': attributes,
  };
}

/// Backend-neutral catalog entity used by the UI and quote calculator.
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.basePrice,
    this.description = '',
    this.sku,
    this.unitLabel = 'unidad',
    this.startingAt = false,
    this.priceIsEstimate = false,
    this.priceTiers = const [],
    this.variants = const [],
    this.stock,
    this.stockStatus = StockStatus.checkAvailability,
    this.leadDays = 0,
    this.productionPoints = 0,
    this.isActive = true,
    this.isFeatured = false,
    this.sortOrder = 0,
    this.imageUrl,
    this.tags = const [],
    this.attributes = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final ProductCategory category;
  final String description;
  final String? sku;
  final String unitLabel;
  final double basePrice;
  final bool startingAt;

  /// True only for provisional seed values that still need business validation.
  final bool priceIsEstimate;
  final List<PriceTier> priceTiers;
  final List<ProductVariant> variants;
  final int? stock;
  final StockStatus stockStatus;

  /// Preparation time and workload let the ordering flow check capacity.
  final int leadDays;
  final int productionPoints;
  final bool isActive;
  final bool isFeatured;
  final int sortOrder;
  final String? imageUrl;
  final List<String> tags;
  final Map<String, String> attributes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductVariant? variantById(String? variantId) {
    if (variantId == null || variantId.isEmpty) return null;
    for (final variant in variants) {
      if (variant.id == variantId) return variant;
    }
    return null;
  }

  double unitPriceFor(int quantity, {String? variantId}) {
    final safeQuantity = quantity < 1 ? 1 : quantity;
    final variant = variantById(variantId);
    final base = variant?.priceOverride ?? basePrice;
    final tiers = variant != null && variant.priceTiers.isNotEmpty
        ? variant.priceTiers
        : priceTiers;

    var price = base;
    for (final tier in tiers) {
      if (tier.appliesTo(safeQuantity)) {
        price = tier.unitPrice;
      }
    }
    return price;
  }

  double totalFor(int quantity, {String? variantId}) {
    final safeQuantity = quantity < 1 ? 1 : quantity;
    return unitPriceFor(safeQuantity, variantId: variantId) * safeQuantity;
  }

  int leadDaysFor(String? variantId) =>
      variantById(variantId)?.leadDays ?? leadDays;

  int productionPointsFor(String? variantId) =>
      variantById(variantId)?.productionPoints ?? productionPoints;

  int? stockFor(String? variantId) => variantById(variantId)?.stock ?? stock;

  StockStatus stockStatusFor(String? variantId) =>
      variantById(variantId)?.stockStatus ?? stockStatus;

  bool canRequest(int quantity, {String? variantId}) {
    if (!isActive || quantity < 1) return false;
    final status = stockStatusFor(variantId);
    if (status == StockStatus.outOfStock) return false;
    final availableStock = stockFor(variantId);
    return availableStock == null || availableStock >= quantity;
  }

  factory CatalogProduct.fromFirestore(
    Map<String, dynamic> data, {
    String? id,
  }) {
    return CatalogProduct.fromMap(data, id: id);
  }

  factory CatalogProduct.fromMap(Map<String, dynamic> map, {String? id}) {
    final name = _asString(
      _first(map, const ['name', 'nombre', 'title', 'titulo']),
      fallback: 'Producto',
    );
    final resolvedId =
        _asNullableString(id) ??
        _asNullableString(map['id']) ??
        _asNullableString(map['slug']) ??
        _slug(name);
    final stock = _asNullableInt(
      _first(map, const ['stock', 'stockCount', 'existencias']),
    );

    final tiers =
        _mapList(
            _first(map, const ['priceTiers', 'price_tiers', 'tiers', 'tramos']),
          ).map(PriceTier.fromMap).toList()
          ..sort((a, b) => a.minQuantity.compareTo(b.minQuantity));
    final variants = _mapList(
      _first(map, const ['variants', 'variantes', 'options', 'opciones']),
    ).map(ProductVariant.fromMap).toList();

    return CatalogProduct(
      id: resolvedId,
      name: name,
      category: ProductCategory.fromValue(
        _first(map, const ['category', 'categoryId', 'categoria']),
      ),
      description: _asString(
        map['description'] ?? map['descripcion'],
        fallback: '',
      ),
      sku: _asNullableString(map['sku'] ?? map['code'] ?? map['codigo']),
      unitLabel: _asString(
        _first(map, const ['unitLabel', 'unit_label', 'unit', 'unidad']),
        fallback: 'unidad',
      ),
      basePrice: _asDouble(
        _first(map, const ['basePrice', 'base_price', 'price', 'precio']),
      ),
      startingAt: _asBool(
        _first(map, const ['startingAt', 'starting_at', 'desde']),
      ),
      priceIsEstimate: _asBool(
        _first(map, const [
          'priceIsEstimate',
          'price_is_estimate',
          'precioReferencial',
        ]),
      ),
      priceTiers: List.unmodifiable(tiers),
      variants: List.unmodifiable(variants),
      stock: stock,
      stockStatus: StockStatus.fromValue(
        _first(map, const ['stockStatus', 'stock_status', 'availability']),
        stock: stock,
      ),
      leadDays: _asInt(
        _first(map, const ['leadDays', 'lead_days', 'diasPreparacion']),
        minimum: 0,
      ),
      productionPoints: _asInt(
        _first(map, const [
          'productionPoints',
          'production_points',
          'puntosProduccion',
        ]),
        minimum: 0,
      ),
      isActive: _asBool(
        map['isActive'] ?? map['active'] ?? map['activo'],
        fallback: true,
      ),
      isFeatured: _asBool(
        map['isFeatured'] ?? map['featured'] ?? map['destacado'],
      ),
      sortOrder: _asInt(
        _first(map, const ['sortOrder', 'sort_order', 'order', 'orden']),
        minimum: 0,
      ),
      imageUrl: _asNullableString(
        _first(map, const ['imageUrl', 'image_url', 'image', 'imagen']),
      ),
      tags: _stringList(map['tags'] ?? map['etiquetas']),
      attributes: _stringMap(map['attributes'] ?? map['atributos']),
      createdAt: _asDateTime(map['createdAt'] ?? map['created_at']),
      updatedAt: _asDateTime(map['updatedAt'] ?? map['updated_at']),
    );
  }

  /// Serializable shape used by the local cache and admin save RPC.
  Map<String, dynamic> toDataMap() => {
    'name': name,
    'category': category.key,
    'description': description,
    if (sku != null) 'sku': sku,
    'unitLabel': unitLabel,
    'basePrice': basePrice,
    'startingAt': startingAt,
    'priceIsEstimate': priceIsEstimate,
    'priceTiers': priceTiers.map((tier) => tier.toMap()).toList(),
    'variants': variants.map((variant) => variant.toMap()).toList(),
    if (stock != null) 'stock': stock,
    'stockStatus': stockStatus.key,
    'leadDays': leadDays,
    'productionPoints': productionPoints,
    'isActive': isActive,
    'isFeatured': isFeatured,
    'sortOrder': sortOrder,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'tags': tags,
    if (attributes.isNotEmpty) 'attributes': attributes,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  /// Compatibility alias for old callers while the Firebase migration lands.
  @Deprecated('Use toDataMap instead.')
  Map<String, dynamic> toFirestore() => toDataMap();

  Map<String, dynamic> toMap() => {
    'id': id,
    ...toDataMap(),
  };
}

Object? _first(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key) && map[key] != null) return map[key];
  }
  return null;
}

String _normalized(Object? value) {
  return (value?.toString() ?? '').trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]'),
    '',
  );
}

String _slug(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'product' : slug;
}

String _asString(Object? value, {required String fallback}) {
  final parsed = value?.toString().trim();
  return parsed == null || parsed.isEmpty ? fallback : parsed;
}

String? _asNullableString(Object? value) {
  final parsed = value?.toString().trim();
  return parsed == null || parsed.isEmpty ? null : parsed;
}

double _asDouble(Object? value, {double fallback = 0}) {
  return _asNullableDouble(value) ?? fallback;
}

double? _asNullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  var raw = value.toString().trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (raw.isEmpty) return null;
  if (raw.contains(',') && raw.contains('.')) {
    if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
      raw = raw.replaceAll('.', '').replaceAll(',', '.');
    } else {
      raw = raw.replaceAll(',', '');
    }
  } else if (raw.contains(',')) {
    raw = raw.replaceAll(',', '.');
  }
  return double.tryParse(raw);
}

int _asInt(Object? value, {int fallback = 0, int? minimum}) {
  var parsed = _asNullableInt(value) ?? fallback;
  if (minimum != null && parsed < minimum) parsed = minimum;
  return parsed;
}

int? _asNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9-]'), ''));
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (_normalized(value)) {
    'true' || 'yes' || 'si' || '1' => true,
    'false' || 'no' || '0' => false,
    _ => fallback,
  };
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is num) {
    final milliseconds = value.abs() < 100000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt());
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

List<String> _stringList(Object? value) {
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is! Iterable) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}
