import 'package:shared_preferences/shared_preferences.dart';

class GuidePreferences {
  const GuidePreferences();

  static const _onboardingSeenKey = 'expresiones.guide.onboarding_seen.v2';
  static const _assistantMutedKey = 'expresiones.guide.assistant_muted.v1';

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

  Future<bool> isAssistantMuted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_assistantMutedKey) ?? false;
  }

  Future<void> muteAssistant() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_assistantMutedKey, true);
  }

  Future<void> unmuteAssistant() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_assistantMutedKey);
  }
}
