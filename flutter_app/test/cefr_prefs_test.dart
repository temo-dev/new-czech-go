import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/storage/cefr_prefs.dart';

void main() {
  group('CefrPrefs', () {
    test('defaults: existing prompt not shown, banner not dismissed', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await CefrPrefs.create();

      expect(
        prefs.isExistingPromptShownFor(userID: 'u1', level: 'a2'),
        isFalse,
      );
      expect(prefs.isBannerDismissedFor('a2'), isFalse);
      expect(prefs.isBannerDismissedFor('b1'), isFalse);
    });

    test('markExistingPromptShownFor persists per user and level', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await CefrPrefs.create();

      await first.markExistingPromptShownFor(userID: 'u1', level: 'a2');

      expect(first.isExistingPromptShownFor(userID: 'u1', level: 'a2'), isTrue);
      expect(
        first.isExistingPromptShownFor(userID: 'u2', level: 'a2'),
        isFalse,
      );
      expect(
        first.isExistingPromptShownFor(userID: 'u1', level: 'b1'),
        isFalse,
      );

      final second = await CefrPrefs.create();
      expect(
        second.isExistingPromptShownFor(userID: 'u1', level: 'a2'),
        isTrue,
      );
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

      await prefs.markExistingPromptShownFor(userID: 'u1', level: 'a2');
      await prefs.dismissBannerFor('a2');

      final raw = await SharedPreferences.getInstance();
      expect(raw.getBool('cefr_existing_prompt_shown_u1_a2'), isTrue);
      expect(raw.getBool('cefr_existing_prompt_shown'), isNull);
      expect(raw.getBool('promo_banner_dismissed_for_a2'), isTrue);
      expect(raw.getBool('promo_banner_dismissed_for_b1'), isNull);
    });

    test('rejects empty keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await CefrPrefs.create();

      expect(() => prefs.dismissBannerFor(''), throwsArgumentError);
      expect(() => prefs.isBannerDismissedFor(''), throwsArgumentError);
      expect(
        () => prefs.markExistingPromptShownFor(userID: '', level: 'a2'),
        throwsArgumentError,
      );
      expect(
        () => prefs.isExistingPromptShownFor(userID: 'u1', level: ''),
        throwsArgumentError,
      );
    });
  });
}
