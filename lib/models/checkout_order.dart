import 'coordination_details.dart';
import 'quote_line.dart';
import 'simulated_payment.dart';

class CheckoutOrderItem {
  const CheckoutOrderItem({
    required this.productId,
    required this.productName,
    required this.unitLabel,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.variantId,
    this.variantName,
    this.sku,
    this.imageUrl,
    this.customization = '',
  });

  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final String? sku;
  final String unitLabel;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String customization;

  factory CheckoutOrderItem.fromResolved(ResolvedQuoteLine resolved) {
    return CheckoutOrderItem(
      productId: resolved.product.id,
      productName: resolved.product.name,
      variantId: resolved.variant?.id,
      variantName: resolved.variant?.name,
      sku: resolved.code,
      unitLabel: resolved.product.unitLabel,
      imageUrl: resolved.variant?.imageUrl ?? resolved.product.previewImageUrl,
      quantity: resolved.line.quantity,
      unitPrice: resolved.unitPrice,
      lineTotal: resolved.total,
      customization: resolved.line.customization.trim(),
    );
  }

  String get displayName => variantName == null || variantName!.isEmpty
      ? productName
      : '$productName · $variantName';

  Map<String, Object?> toJson() => {
    'productId': productId,
    'productName': productName,
    'variantId': variantId,
    'variantName': variantName,
    'sku': sku,
    'unitLabel': unitLabel,
    'imageUrl': imageUrl,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineTotal': lineTotal,
    'customization': customization,
  };

  factory CheckoutOrderItem.fromJson(Map<String, Object?> json) {
    return CheckoutOrderItem(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      variantId: _nullableString(json['variantId']),
      variantName: _nullableString(json['variantName']),
      sku: _nullableString(json['sku']),
      unitLabel: json['unitLabel']?.toString() ?? 'unidad',
      imageUrl: _nullableString(json['imageUrl']),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      customization: json['customization']?.toString() ?? '',
    );
  }
}

class CheckoutOrder {
  const CheckoutOrder({
    required this.id,
    required this.items,
    required this.details,
    required this.productsSubtotal,
    required this.payment,
    required this.createdAt,
    this.shippingPending = true,
  });

  final String id;
  final List<CheckoutOrderItem> items;
  final CoordinationDetails details;
  final double productsSubtotal;
  final bool shippingPending;
  final SimulatedPayment payment;
  final DateTime createdAt;

  bool get isSimulation => true;
  double get simulatedTotal => productsSubtotal;
  int get totalQuantity =>
      items.fold(0, (total, item) => total + item.quantity);

  factory CheckoutOrder.fromQuote({
    required String id,
    required Iterable<ResolvedQuoteLine> lines,
    required CoordinationDetails details,
    required SimulatedPayment payment,
    required DateTime createdAt,
  }) {
    final items = lines.map(CheckoutOrderItem.fromResolved).toList();
    return CheckoutOrder(
      id: id,
      items: List.unmodifiable(items),
      details: details,
      productsSubtotal: items.fold(0, (total, item) => total + item.lineTotal),
      shippingPending: details.deliveryMethod == DeliveryMethod.shalom,
      payment: payment,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'items': items.map((item) => item.toJson()).toList(),
    'details': details.toJson(),
    'productsSubtotal': productsSubtotal,
    'shippingPending': shippingPending,
    'payment': payment.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'isSimulation': true,
  };

  factory CheckoutOrder.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    final rawDetails = json['details'];
    final rawPayment = json['payment'];
    return CheckoutOrder(
      id: json['id']?.toString() ?? '',
      items: List.unmodifiable(
        rawItems is Iterable
            ? rawItems.whereType<Map>().map(
                (value) => CheckoutOrderItem.fromJson(_stringMap(value)),
              )
            : const <CheckoutOrderItem>[],
      ),
      details: rawDetails is Map
          ? CoordinationDetails.fromJson(_stringMap(rawDetails))
          : const CoordinationDetails(),
      productsSubtotal: (json['productsSubtotal'] as num?)?.toDouble() ?? 0,
      shippingPending: json['shippingPending'] != false,
      payment: rawPayment is Map
          ? SimulatedPayment.fromJson(_stringMap(rawPayment))
          : SimulatedPayment(
              reference: '',
              method: SimulatedPaymentMethod.demoCard,
              status: SimulatedPaymentStatus.declined,
              amount: 0,
              processedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

Map<String, Object?> _stringMap(Map<dynamic, dynamic> value) =>
    value.map((key, item) => MapEntry(key.toString(), item));

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
