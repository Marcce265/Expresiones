import 'package:shared_preferences/shared_preferences.dart';

class GuidePreferences {
  const GuidePreferences();

  static const _onboardingSeenKey = 'expresiones.guide.onboarding_seen.v1';

  Future<bool> shouldShowOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(_onboardingSeenKey) ?? false);
  }

  Future<void> markOnboardingSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingSeenKey, true);
  }

  Future<void> reactivateOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_onboardingSeenKey);
  }
}
