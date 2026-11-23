abstract final class PickupOrderQr {
  static const _prefix = 'expresiones:recojo:1:';
  static final _orderId = RegExp(r'^PED-[0-9]{8}-[0-9]{6}-[0-9]{3}$');

  static String? encode(String orderId) =>
      _orderId.hasMatch(orderId) ? '$_prefix$orderId' : null;

  static String? decode(String payload) {
    if (!payload.startsWith(_prefix)) return null;
    final orderId = payload.substring(_prefix.length);
    return _orderId.hasMatch(orderId) ? orderId : null;
  }
}
