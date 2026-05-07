import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/storage/cefr_prefs.dart';

void main() {
  group('CefrPrefs', () {
    test('defaults: existing prompt not shown, banner not dismissed', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await CefrPrefs.create();

      expect(prefs.isExistingPromptShown, isFalse);
      expect(prefs.isBannerDismissedFor('a2'), isFalse);
      expect(prefs.isBannerDismissedFor('b1'), isFalse);
    });

    test('markExistingPromptShown persists across instances', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await CefrPrefs.create();

      await first.markExistingPromptShown();

      expect(first.isExistingPromptShown, isTrue);

      final second = await CefrPrefs.create();
      expect(second.isExistingPromptShown, isTrue);
    });

    test('dismissBannerFor isolates per level', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await CefrPrefs.create();

      await prefs.dismissBannerFor('a2');

      expect(prefs.isBannerDismissedFor('a2'), isTrue);
      expect(prefs.isBannerDismissedFor('b1'), isFalse);

      await prefs.dismissBannerFor('b1');
      expect(prefs.isBannerDismissedFor('a2'), isTrue);
      expect(prefs.isBannerDismissedFor('b1'), isTrue);
    });

    test('writes to documented SharedPreferences keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await CefrPrefs.create();

      await prefs.markExistingPromptShown();
      await prefs.dismissBannerFor('a2');

      final raw = await SharedPreferences.getInstance();
      expect(raw.getBool('cefr_existing_prompt_shown'), isTrue);
      expect(raw.getBool('promo_banner_dismissed_for_a2'), isTrue);
      expect(raw.getBool('promo_banner_dismissed_for_b1'), isNull);
    });

    test('rejects empty level when dismissing banner', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await CefrPrefs.create();

      expect(() => prefs.dismissBannerFor(''), throwsArgumentError);
      expect(() => prefs.isBannerDismissedFor(''), throwsArgumentError);
    });
  });
}
