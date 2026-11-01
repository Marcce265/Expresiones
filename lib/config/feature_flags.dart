abstract final class FeatureFlags {
  static const demoPayment = bool.fromEnvironment(
    'ENABLE_DEMO_PAYMENT',
    defaultValue: false,
  );
}
