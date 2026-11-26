import 'catalog_models.dart';
import 'coordination_details.dart';

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
  const ResolvedQuoteLine({
    required this.line,
    required this.product,
    this.pricingQuantity,
  });

  final QuoteLine line;
  final CatalogProduct product;

  /// Total units of the same product family in the quote. Quantity tiers use
  /// this value, so one unit of each colour still reaches the dozen price.
  final int? pricingQuantity;

  int get tierQuantity => pricingQuantity ?? line.quantity;

  ProductVariant? get variant => product.variantById(line.variantId);
  double get unitPrice =>
      product.unitPriceFor(tierQuantity, variantId: line.variantId);
  double get total => unitPrice * (line.quantity < 1 ? 1 : line.quantity);
  String get displayName =>
      variant == null ? product.name : '${product.name} · ${variant!.name}';
  String? get code => variant?.sku ?? product.sku;
  int get productionPoints =>
      product.productionPointsFor(line.variantId) * line.quantity;

  String? get appliedPriceTierLabel {
    final tiers = variant != null && variant!.priceTiers.isNotEmpty
        ? variant!.priceTiers
        : product.priceTiers;
    PriceTier? selected;
    for (final tier in tiers) {
      if (tier.appliesTo(tierQuantity)) selected = tier;
    }
    if (selected == null) return null;
    return selected.label ?? 'Desde ${selected.minQuantity}';
  }

  String get priceTierLabel =>
      appliedPriceTierLabel ??
      (line.quantity == 1 ? 'Por ${product.unitLabel}' : 'Precio aplicado');
}

Iterable<List<ResolvedQuoteLine>> groupQuoteLines(
  Iterable<ResolvedQuoteLine> lines,
) {
  final families = <String, List<ResolvedQuoteLine>>{};
  for (final line in lines) {
    families.putIfAbsent(line.product.id, () => []).add(line);
  }
  return families.values;
}

bool sharesQuoteUnitPrice(List<ResolvedQuoteLine> family) => family.every(
  (line) =>
      line.unitPrice == family.first.unitPrice &&
      line.appliedPriceTierLabel == family.first.appliedPriceTierLabel,
);

({double subtotal, double transportAndPacking, double total}) quoteAmounts(
  List<ResolvedQuoteLine> lines,
  DeliveryMethod? method,
) {
  final subtotal = lines.fold<double>(0, (sum, line) => sum + line.total);
  final transportAndPacking = method == DeliveryMethod.shalom
      ? shalomPackingFee(lines.fold(0, (sum, line) => sum + line.line.quantity))
      : 0.0;
  return (
    subtotal: subtotal,
    transportAndPacking: transportAndPacking,
    total: subtotal + transportAndPacking,
  );
}

/// Resolves every quote line against the catalog.
///
/// Product-level quantity tiers are shared by all variants: twelve units of
/// different colours count as a dozen. Variants that define their own tiers
/// are grouped separately so their special prices are not mixed.
List<ResolvedQuoteLine> resolveQuoteLines({
  required Iterable<QuoteLine> lines,
  required Map<String, CatalogProduct> products,
}) {
  final resolved = <({QuoteLine line, CatalogProduct product})>[];
  final quantities = <String, int>{};
  for (final line in lines) {
    final product = products[line.productId];
    if (product == null) continue;
    resolved.add((line: line, product: product));
    final group = _pricingGroup(product, line.variantId);
    final quantity = line.quantity < 1 ? 1 : line.quantity;
    quantities[group] = (quantities[group] ?? 0) + quantity;
  }
  return [
    for (final item in resolved)
      ResolvedQuoteLine(
        line: item.line,
        product: item.product,
        pricingQuantity:
            quantities[_pricingGroup(item.product, item.line.variantId)]!,
      ),
  ];
}

String _pricingGroup(CatalogProduct product, String? variantId) {
  final variant = product.variantById(variantId);
  return variant != null && variant.priceTiers.isNotEmpty
      ? '${product.id}::${variant.id}'
      : product.id;
}
