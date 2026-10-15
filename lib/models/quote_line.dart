import 'catalog_models.dart';

class QuoteLine {
  const QuoteLine({
    required this.productId,
    required this.quantity,
    this.variantId,
    this.customization = '',
  });

  final String productId;
  final String? variantId;
  final int quantity;
  final String customization;

  String get key => '$productId::${variantId ?? ''}::${customization.trim()}';

  QuoteLine copyWith({
    int? quantity,
    String? variantId,
    bool clearVariant = false,
    String? customization,
  }) {
    return QuoteLine(
      productId: productId,
      quantity: quantity ?? this.quantity,
      variantId: clearVariant ? null : variantId ?? this.variantId,
      customization: customization ?? this.customization,
    );
  }

  Map<String, Object?> toJson() => {
    'productId': productId,
    'variantId': variantId,
    'quantity': quantity,
    'customization': customization,
  };

  factory QuoteLine.fromJson(Map<String, Object?> json) {
    return QuoteLine(
      productId: json['productId'] as String? ?? '',
      variantId: json['variantId'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      customization: json['customization'] as String? ?? '',
    );
  }
}

class ResolvedQuoteLine {
  const ResolvedQuoteLine({required this.line, required this.product});

  final QuoteLine line;
  final CatalogProduct product;

  ProductVariant? get variant => product.variantById(line.variantId);
  double get unitPrice =>
      product.unitPriceFor(line.quantity, variantId: line.variantId);
  double get total =>
      product.totalFor(line.quantity, variantId: line.variantId);
  String get displayName =>
      variant == null ? product.name : '${product.name} · ${variant!.name}';
  String? get code => variant?.sku ?? product.sku;
  int get leadDays => product.leadDaysFor(line.variantId);
  int get productionPoints =>
      product.productionPointsFor(line.variantId) * line.quantity;

  String get priceTierLabel {
    final tiers = variant != null && variant!.priceTiers.isNotEmpty
        ? variant!.priceTiers
        : product.priceTiers;
    PriceTier? selected;
    for (final tier in tiers) {
      if (tier.appliesTo(line.quantity)) selected = tier;
    }
    return selected?.label ??
        (line.quantity == 1 ? 'Por ${product.unitLabel}' : 'Precio aplicado');
  }
}
