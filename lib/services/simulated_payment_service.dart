import '../models/simulated_payment.dart';

class SimulatedPaymentService {
  SimulatedPaymentService({
    DateTime Function()? now,
    this.processingDelay = const Duration(milliseconds: 900),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration processingDelay;

  String createOrderId() => _reference('PED', _now());

  Future<SimulatedPayment> process({
    required SimulatedPaymentMethod method,
    required double amount,
    SimulatedPaymentStatus result = SimulatedPaymentStatus.approved,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Debe ser mayor que cero.');
    }
    if (processingDelay > Duration.zero) {
      await Future<void>.delayed(processingDelay);
    }
    final processedAt = _now();
    return SimulatedPayment(
      reference: _reference('SIM', processedAt),
      method: method,
      status: result,
      amount: amount,
      processedAt: processedAt,
    );
  }
}

String _reference(String prefix, DateTime value) {
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '$prefix-${value.year}${two(value.month)}${two(value.day)}-'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}-'
      '${three(value.millisecond)}';
}
