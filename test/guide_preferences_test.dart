import 'package:expresiones/data/guide_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const preferences = GuidePreferences();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('muestra la presentación una vez y permite reactivarla', () async {
    expect(await preferences.shouldShowOnboarding(), isTrue);

    await preferences.markOnboardingSeen();
    expect(await preferences.shouldShowOnboarding(), isFalse);

    await preferences.reactivateOnboarding();
    expect(await preferences.shouldShowOnboarding(), isTrue);
  });

  test('silencia y reactiva a Jashy de forma independiente', () async {
    expect(await preferences.isAssistantMuted(), isFalse);

    await preferences.muteAssistant();
    expect(await preferences.isAssistantMuted(), isTrue);
    expect(await preferences.shouldShowOnboarding(), isTrue);

    await preferences.unmuteAssistant();
    expect(await preferences.isAssistantMuted(), isFalse);
  });
}
