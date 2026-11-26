import 'package:flutter/foundation.dart';

abstract final class FeatureFlags {
  /// Sign-in gate for native customer builds.
  static const customerAccounts =
      !kIsWeb &&
      bool.fromEnvironment('ENABLE_CUSTOMER_ACCOUNTS', defaultValue: false);

  /// Enables simulated card/Yape payment on native builds.
  static const demoPayment =
      !kIsWeb &&
      bool.fromEnvironment('ENABLE_DEMO_PAYMENT', defaultValue: false);

  /// Android end-to-end build: account tab and in-app simulated checkout,
  /// while the catalog stays open for visitors without an account.
  static const appEndToEnd =
      !kIsWeb &&
      bool.fromEnvironment('ENABLE_APP_END_TO_END', defaultValue: false);

  /// Customer account UI: tab, profile and saved orders.
  static const accountsEnabled = customerAccounts || appEndToEnd;

  /// In-app checkout with the simulated payment.
  static const paymentsEnabled = demoPayment || appEndToEnd;

  /// Whether browsing requires signing in first.
  static const loginGate = customerAccounts || appEndToEnd;
}
