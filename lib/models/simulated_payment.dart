enum SimulatedPaymentMethod { demoCard, demoYape }

enum SimulatedPaymentStatus { approved, declined }

class SimulatedPayment {
  const SimulatedPayment({
    required this.reference,
    required this.method,
    required this.status,
    required this.amount,
    required this.processedAt,
    this.methodLabelSnapshot,
  });

  final String reference;
  final SimulatedPaymentMethod method;
  final SimulatedPaymentStatus status;
  final double amount;
  final DateTime processedAt;
  final String? methodLabelSnapshot;

  bool get isApproved => status == SimulatedPaymentStatus.approved;

  String get methodLabel {
    final snapshot = methodLabelSnapshot?.trim() ?? '';
    if (snapshot.isNotEmpty) return snapshot;
    return switch (method) {
      SimulatedPaymentMethod.demoCard => 'Tarjeta de demostración',
      SimulatedPaymentMethod.demoYape => 'Yape de demostración',
    };
  }

  SimulatedPayment withMethodLabel(String value) => SimulatedPayment(
    reference: reference,
    method: method,
    status: status,
    amount: amount,
    processedAt: processedAt,
    methodLabelSnapshot: value.trim().isEmpty ? null : value.trim(),
  );

  Map<String, Object?> toJson() => {
    'reference': reference,
    'method': method.name,
    'status': status.name,
    'amount': amount,
    'processedAt': processedAt.toIso8601String(),
    'methodLabel': methodLabel,
    'isSimulation': true,
  };

  factory SimulatedPayment.fromJson(Map<String, Object?> json) {
    return SimulatedPayment(
      reference: json['reference']?.toString() ?? '',
      method: SimulatedPaymentMethod.values.firstWhere(
        (value) => value.name == json['method'],
        orElse: () => SimulatedPaymentMethod.demoCard,
      ),
      status: SimulatedPaymentStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => SimulatedPaymentStatus.declined,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      processedAt:
          DateTime.tryParse(json['processedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      methodLabelSnapshot: _nullableString(json['methodLabel']),
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
