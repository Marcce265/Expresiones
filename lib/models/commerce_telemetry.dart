import 'dart:math' as math;

enum CommerceEventType {
  zeroResultSearch('zero_result_search'),
  productView('product_view'),
  productAdded('product_added'),
  quoteAbandoned('quote_abandoned'),
  quoteSent('quote_sent');

  const CommerceEventType(this.key);
  final String key;

  static CommerceEventType? fromKey(Object? value) {
    for (final type in values) {
      if (type.key == value) return type;
    }
    return null;
  }
}

/// Anonymous commerce event. It cannot hold names, phones, notes or addresses.
class CommerceTelemetryEvent {
  const CommerceTelemetryEvent({
    required this.type,
    required this.occurredAt,
    this.productId,
    this.variantId,
    this.searchTerm,
    this.quantityBucket,
    this.itemCountBucket,
    this.valueBucket,
    this.abandonmentHoursBucket,
  });

  static const schemaVersion = 1;

  final CommerceEventType type;
  final DateTime occurredAt;
  final String? productId;
  final String? variantId;
  final String? searchTerm;
  final String? quantityBucket;
  final String? itemCountBucket;
  final String? valueBucket;
  final String? abandonmentHoursBucket;

  String get day => _dayKey(occurredAt);

  Map<String, Object?> toJson() => {
    'eventType': type.key,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'day': day,
    'schemaVersion': schemaVersion,
    if (productId != null) 'productId': productId,
    if (variantId != null) 'variantId': variantId,
    if (searchTerm != null) 'searchTerm': searchTerm,
    if (quantityBucket != null) 'quantityBucket': quantityBucket,
    if (itemCountBucket != null) 'itemCountBucket': itemCountBucket,
    if (valueBucket != null) 'valueBucket': valueBucket,
    if (abandonmentHoursBucket != null)
      'abandonmentHoursBucket': abandonmentHoursBucket,
  };

  /// Allow-listed fields for the remote event. Arbitrary metadata is never sent.
  Map<String, Object> toRemoteMap() => {
    'eventType': type.key,
    'day': day,
    'schemaVersion': schemaVersion,
    'productId': ?productId,
    'variantId': ?variantId,
    'searchTerm': ?searchTerm,
    'quantityBucket': ?quantityBucket,
    'itemCountBucket': ?itemCountBucket,
    'valueBucket': ?valueBucket,
    'abandonmentHoursBucket': ?abandonmentHoursBucket,
  };

  factory CommerceTelemetryEvent.fromJson(Map<String, Object?> json) {
    final type = CommerceEventType.fromKey(json['eventType']);
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    if (type == null || occurredAt == null) {
      throw const FormatException('Evento de telemetría inválido.');
    }
    return CommerceTelemetryEvent(
      type: type,
      occurredAt: occurredAt,
      productId: _optionalString(json['productId']),
      variantId: _optionalString(json['variantId']),
      searchTerm: _optionalString(json['searchTerm']),
      quantityBucket: _optionalString(json['quantityBucket']),
      itemCountBucket: _optionalString(json['itemCountBucket']),
      valueBucket: _optionalString(json['valueBucket']),
      abandonmentHoursBucket: _optionalString(json['abandonmentHoursBucket']),
    );
  }
}

class AnonymousQuoteActivity {
  const AnonymousQuoteActivity({
    required this.startedAt,
    required this.lastActivityAt,
    required this.itemCountBucket,
    required this.valueBucket,
  });

  final DateTime startedAt;
  final DateTime lastActivityAt;
  final String itemCountBucket;
  final String valueBucket;

  Map<String, Object> toJson() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    'lastActivityAt': lastActivityAt.toUtc().toIso8601String(),
    'itemCountBucket': itemCountBucket,
    'valueBucket': valueBucket,
  };

  factory AnonymousQuoteActivity.fromJson(Map<String, Object?> json) {
    final startedAt = DateTime.tryParse(json['startedAt']?.toString() ?? '');
    final lastActivityAt = DateTime.tryParse(
      json['lastActivityAt']?.toString() ?? '',
    );
    if (startedAt == null || lastActivityAt == null) {
      throw const FormatException('Actividad de cotización inválida.');
    }
    return AnonymousQuoteActivity(
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
      itemCountBucket: _optionalString(json['itemCountBucket']) ?? '1',
      valueBucket: _optionalString(json['valueBucket']) ?? '0-49',
    );
  }
}

/// Keeps useful missing-product terms while discarding likely personal data.
abstract final class SearchTermPrivacyFilter {
  static String? sanitize(String input) {
    var value = input.toLowerCase().trim();
    if (value.length < 2 || value.length > 120) return null;

    final looksLikePrivateData =
        value.contains('@') ||
        RegExp(r'https?://|www\.', caseSensitive: false).hasMatch(value) ||
        RegExp(r'\d{5,}').hasMatch(value) ||
        RegExp(r'(?:\d[\s+().-]*){7,}').hasMatch(value) ||
        RegExp(
          r'\b(dni|ruc|tel[eé]fono|celular|whatsapp|correo|email|direcci[oó]n|avenida|av|jir[oó]n|jr|calle|pasaje|urbanizaci[oó]n|me llamo|mi nombre)\b',
          caseSensitive: false,
        ).hasMatch(value);
    if (looksLikePrivateData) return null;

    value = value
        .replaceAll(RegExp(r'[^a-záéíóúüñ0-9# +.\-/]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.length < 2) return null;
    return value.substring(0, math.min(48, value.length)).trim();
  }
}

String quantityBucket(int quantity) {
  if (quantity <= 1) return '1';
  if (quantity <= 5) return '2-5';
  if (quantity <= 11) return '6-11';
  if (quantity <= 49) return '12-49';
  if (quantity <= 99) return '50-99';
  return '100+';
}

String itemCountBucket(int count) {
  if (count <= 1) return '1';
  if (count <= 3) return '2-3';
  if (count <= 6) return '4-6';
  return '7+';
}

String valueBucket(double value) {
  if (value < 50) return '0-49';
  if (value < 100) return '50-99';
  if (value < 250) return '100-249';
  if (value < 500) return '250-499';
  return '500+';
}

String abandonmentHoursBucket(Duration age) {
  if (age.inHours < 24) return '0-23';
  if (age.inHours < 72) return '24-71';
  if (age.inHours < 168) return '72-167';
  return '168+';
}

String _dayKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
