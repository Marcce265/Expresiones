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
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'deliveryMethod': deliveryMethod.name,
    'destination': destination,
    'shalomAgencyId': shalomAgencyId,
    'shalomAgencyName': shalomAgencyName,
    'shalomAgencyAddress': shalomAgencyAddress,
    'shalomAgencyLocality': shalomAgencyLocality,
    'shalomAgencyLatitude': shalomAgencyLatitude,
    'shalomAgencyLongitude': shalomAgencyLongitude,
    'desiredDate': desiredDate?.toIso8601String(),
    'note': note,
    'customFields': customFields,
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
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      deliveryMethod: DeliveryMethod.values.firstWhere(
        (value) => value.name == deliveryName,
        orElse: () => DeliveryMethod.pickup,
      ),
      destination: json['destination'] as String? ?? '',
      shalomAgencyId: json['shalomAgencyId'] as String? ?? '',
      shalomAgencyName: json['shalomAgencyName'] as String? ?? '',
      shalomAgencyAddress: json['shalomAgencyAddress'] as String? ?? '',
      shalomAgencyLocality: json['shalomAgencyLocality'] as String? ?? '',
      shalomAgencyLatitude: (json['shalomAgencyLatitude'] as num?)?.toDouble(),
      shalomAgencyLongitude: (json['shalomAgencyLongitude'] as num?)
          ?.toDouble(),
      desiredDate: DateTime.tryParse(json['desiredDate'] as String? ?? ''),
      note: json['note'] as String? ?? '',
      customFields: Map.unmodifiable(customFields),
    );
  }
}
