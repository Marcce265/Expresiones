import 'package:flutter/foundation.dart';

abstract final class FeatureFlags {
  static bool get appEndToEnd =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      const bool.fromEnvironment('ENABLE_APP_END_TO_END', defaultValue: true);

  static const customerAccounts = bool.fromEnvironment(
    'ENABLE_CUSTOMER_ACCOUNTS',
    defaultValue: false,
  );

  static const demoPayment = bool.fromEnvironment(
    'ENABLE_DEMO_PAYMENT',
    defaultValue: false,
  );
}
