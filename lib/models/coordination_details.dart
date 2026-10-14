enum DeliveryMethod { pickup, shalom }

class CoordinationDetails {
  const CoordinationDetails({
    this.name = '',
    this.phone = '',
    this.deliveryMethod = DeliveryMethod.pickup,
    this.destination = '',
    this.desiredDate,
    this.note = '',
  });

  final String name;
  final String phone;
  final DeliveryMethod deliveryMethod;
  final String destination;
  final DateTime? desiredDate;
  final String note;

  String get deliveryLabel => deliveryMethod == DeliveryMethod.pickup
      ? 'Recojo en Huancayo'
      : 'Envío por Shalom${destination.trim().isEmpty ? '' : ' a ${destination.trim()}'}';

  CoordinationDetails copyWith({
    String? name,
    String? phone,
    DeliveryMethod? deliveryMethod,
    String? destination,
    DateTime? desiredDate,
    bool clearDesiredDate = false,
    String? note,
  }) {
    return CoordinationDetails(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      destination: destination ?? this.destination,
      desiredDate: clearDesiredDate ? null : desiredDate ?? this.desiredDate,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'deliveryMethod': deliveryMethod.name,
    'destination': destination,
    'desiredDate': desiredDate?.toIso8601String(),
    'note': note,
  };

  factory CoordinationDetails.fromJson(Map<String, Object?> json) {
    final deliveryName = json['deliveryMethod'] as String?;
    return CoordinationDetails(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      deliveryMethod: DeliveryMethod.values.firstWhere(
        (value) => value.name == deliveryName,
        orElse: () => DeliveryMethod.pickup,
      ),
      destination: json['destination'] as String? ?? '',
      desiredDate: DateTime.tryParse(json['desiredDate'] as String? ?? ''),
      note: json['note'] as String? ?? '',
    );
  }
}
