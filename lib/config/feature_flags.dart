abstract final class FeatureFlags {
  static const customerAccounts = bool.fromEnvironment(
    'ENABLE_CUSTOMER_ACCOUNTS',
    defaultValue: false,
  );

  static const demoPayment = bool.fromEnvironment(
    'ENABLE_DEMO_PAYMENT',
    defaultValue: false,
  );
}
