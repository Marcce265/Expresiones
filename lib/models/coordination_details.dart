import '../security/input_sanitizer.dart';

enum DeliveryMethod { pickup, shalom }

class CoordinationDetails {
  const CoordinationDetails({
    this.name = '',
    this.phone = '',
    this.deliveryMethod = DeliveryMethod.pickup,
    this.destination = '',
    this.shalomAgencyId = '',
    this.shalomAgencyName = '',
    this.shalomAgencyAddress = '',
    this.shalomAgencyLocality = '',
    this.shalomAgencyLatitude,
    this.shalomAgencyLongitude,
    this.desiredDate,
    this.note = '',
    this.customFields = const {},
    this.termsAcceptedAt,
    this.privacyAcceptedAt,
    this.legalPolicyVersion,
    this.legalAcceptedVia,
  });

  final String name;
  final String phone;
  final DeliveryMethod deliveryMethod;
  final String destination;
  final String shalomAgencyId;
  final String shalomAgencyName;
  final String shalomAgencyAddress;
  final String shalomAgencyLocality;

  /// Coordenadas de la agencia Shalom seleccionada (pueden ser nulas si
  /// la agencia no tiene datos de geolocalización registrados).
  final double? shalomAgencyLatitude;
  final double? shalomAgencyLongitude;
  final DateTime? desiredDate;
  final String note;

  /// Additional checkout answers keyed by the label shown to the customer.
  /// Labels are stored with the order so later admin renames do not alter old
  /// receipts or WhatsApp messages.
  final Map<String, String> customFields;

  /// Registro auditable de cuándo y cómo se aceptaron los Términos y la
  /// Política de Privacidad por separado (Ley N° 29733 y D.S. N° 016-2024-JUS).
  final DateTime? termsAcceptedAt;
  final DateTime? privacyAcceptedAt;
  final String? legalPolicyVersion;
  final String? legalAcceptedVia;

  String get deliveryLabel {
    if (deliveryMethod == DeliveryMethod.pickup) return 'Recojo en Huancayo';
    if (shalomAgencyId.isNotEmpty) return 'Envío por Shalom';
    return 'Envío por Shalom${destination.trim().isEmpty ? '' : ' a ${destination.trim()}'}';
  }

  CoordinationDetails copyWith({
    String? name,
    String? phone,
    DeliveryMethod? deliveryMethod,
    String? destination,
    String? shalomAgencyId,
    String? shalomAgencyName,
    String? shalomAgencyAddress,
    String? shalomAgencyLocality,
    double? shalomAgencyLatitude,
    double? shalomAgencyLongitude,
    bool clearAgencyCoords = false,
    DateTime? desiredDate,
    bool clearDesiredDate = false,
    String? note,
    Map<String, String>? customFields,
    DateTime? termsAcceptedAt,
    DateTime? privacyAcceptedAt,
    String? legalPolicyVersion,
    String? legalAcceptedVia,
  }) {
    return CoordinationDetails(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      destination: destination ?? this.destination,
      shalomAgencyId: shalomAgencyId ?? this.shalomAgencyId,
      shalomAgencyName: shalomAgencyName ?? this.shalomAgencyName,
      shalomAgencyAddress: shalomAgencyAddress ?? this.shalomAgencyAddress,
      shalomAgencyLocality: shalomAgencyLocality ?? this.shalomAgencyLocality,
      shalomAgencyLatitude: clearAgencyCoords
          ? null
          : shalomAgencyLatitude ?? this.shalomAgencyLatitude,
      shalomAgencyLongitude: clearAgencyCoords
          ? null
          : shalomAgencyLongitude ?? this.shalomAgencyLongitude,
      desiredDate: clearDesiredDate ? null : desiredDate ?? this.desiredDate,
      note: note ?? this.note,
      customFields: customFields == null
          ? this.customFields
          : Map.unmodifiable(customFields),
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
      legalPolicyVersion: legalPolicyVersion ?? this.legalPolicyVersion,
      legalAcceptedVia: legalAcceptedVia ?? this.legalAcceptedVia,
    );
  }

  Map<String, Object?> toJson() => {
    'name': InputSanitizer.sanitizeText(name, maxLength: 120),
    'phone': InputSanitizer.sanitizeText(phone, maxLength: 24),
    'deliveryMethod': deliveryMethod.name,
    'destination': InputSanitizer.sanitizeText(destination, maxLength: 160),
    'shalomAgencyId': InputSanitizer.sanitizeText(
      shalomAgencyId,
      maxLength: 80,
    ),
    'shalomAgencyName': InputSanitizer.sanitizeText(
      shalomAgencyName,
      maxLength: 140,
    ),
    'shalomAgencyAddress': InputSanitizer.sanitizeText(
      shalomAgencyAddress,
      maxLength: 220,
    ),
    'shalomAgencyLocality': InputSanitizer.sanitizeText(
      shalomAgencyLocality,
      maxLength: 140,
    ),
    'shalomAgencyLatitude': shalomAgencyLatitude,
    'shalomAgencyLongitude': shalomAgencyLongitude,
    'desiredDate': desiredDate?.toIso8601String(),
    'note': InputSanitizer.sanitizeText(
      note,
      maxLength: 500,
      allowNewlines: true,
    ),
    'customFields': InputSanitizer.sanitizeCustomFields(customFields),
    if (termsAcceptedAt != null)
      'termsAcceptedAt': termsAcceptedAt!.toUtc().toIso8601String(),
    if (privacyAcceptedAt != null)
      'privacyAcceptedAt': privacyAcceptedAt!.toUtc().toIso8601String(),
    if (legalPolicyVersion != null)
      'legalPolicyVersion': InputSanitizer.sanitizeText(
        legalPolicyVersion!,
        maxLength: 40,
      ),
    if (legalAcceptedVia != null)
      'legalAcceptedVia': InputSanitizer.sanitizeText(
        legalAcceptedVia!,
        maxLength: 80,
      ),
  };

  factory CoordinationDetails.fromJson(Map<String, Object?> json) {
    final deliveryName = json['deliveryMethod'] as String?;
    final rawCustomFields = json['customFields'];
    final customFields = <String, String>{};
    if (rawCustomFields is Map) {
      for (final entry in rawCustomFields.entries) {
        final label = entry.key.toString().trim();
        final value = entry.value?.toString().trim() ?? '';
        if (label.isNotEmpty && value.isNotEmpty) customFields[label] = value;
      }
    }
    return CoordinationDetails(
      name: InputSanitizer.sanitizeText(
        json['name'] as String? ?? '',
        maxLength: 120,
      ),
      phone: InputSanitizer.sanitizeText(
        json['phone'] as String? ?? '',
        maxLength: 24,
      ),
      deliveryMethod: DeliveryMethod.values.firstWhere(
        (value) => value.name == deliveryName,
        orElse: () => DeliveryMethod.pickup,
      ),
      destination: InputSanitizer.sanitizeText(
        json['destination'] as String? ?? '',
        maxLength: 160,
      ),
      shalomAgencyId: InputSanitizer.sanitizeText(
        json['shalomAgencyId'] as String? ?? '',
        maxLength: 80,
      ),
      shalomAgencyName: InputSanitizer.sanitizeText(
        json['shalomAgencyName'] as String? ?? '',
        maxLength: 140,
      ),
      shalomAgencyAddress: InputSanitizer.sanitizeText(
        json['shalomAgencyAddress'] as String? ?? '',
        maxLength: 220,
      ),
      shalomAgencyLocality: InputSanitizer.sanitizeText(
        json['shalomAgencyLocality'] as String? ?? '',
        maxLength: 140,
      ),
      shalomAgencyLatitude: (json['shalomAgencyLatitude'] as num?)?.toDouble(),
      shalomAgencyLongitude: (json['shalomAgencyLongitude'] as num?)
          ?.toDouble(),
      desiredDate: DateTime.tryParse(json['desiredDate'] as String? ?? ''),
      note: InputSanitizer.sanitizeText(
        json['note'] as String? ?? '',
        maxLength: 500,
        allowNewlines: true,
      ),
      customFields: InputSanitizer.sanitizeCustomFields(customFields),
      termsAcceptedAt: DateTime.tryParse(
        json['termsAcceptedAt'] as String? ?? '',
      ),
      privacyAcceptedAt: DateTime.tryParse(
        json['privacyAcceptedAt'] as String? ?? '',
      ),
      legalPolicyVersion: json['legalPolicyVersion'] == null
          ? null
          : InputSanitizer.sanitizeText(
              '${json['legalPolicyVersion']}',
              maxLength: 40,
            ),
      legalAcceptedVia: json['legalAcceptedVia'] == null
          ? null
          : InputSanitizer.sanitizeText(
              '${json['legalAcceptedVia']}',
              maxLength: 80,
            ),
    );
  }
}

/// Name fields saved by older checkout versions are already represented by
/// [CoordinationDetails.name] and must not be rendered a second time.
bool isLegacyNameCustomField(String label) {
  final normalized = label.trim().toLowerCase();
  return normalized == 'nombre' ||
      normalized == 'nombres' ||
      normalized == 'apellido' ||
      normalized == 'apellidos' ||
      normalized == 'nombre completo' ||
      normalized == 'nombres y apellidos';
}
