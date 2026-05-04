import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/interview/interview_preference_service.dart';

void main() {
  group('InterviewPreferenceService', () {
    test('defaults to sound-wave mode with mild local audio boost', () async {
      SharedPreferences.setMockInitialValues({});

      final service = await InterviewPreferenceService.create();

      expect(service.avatarEnabled, isFalse);
      expect(service.localAudioVolume, 1.35);
      expect(await InterviewPreferenceService.readAvatarEnabled(), isFalse);
      expect(await InterviewPreferenceService.readLocalAudioVolume(), 1.35);
    });

    test('persists avatar opt-in and local audio volume', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await InterviewPreferenceService.create();

      await service.setAvatarEnabled(true);
      await service.setLocalAudioVolume(1.6);

      expect(service.avatarEnabled, isTrue);
      expect(service.localAudioVolume, 1.6);
      expect(await InterviewPreferenceService.readAvatarEnabled(), isTrue);
      expect(await InterviewPreferenceService.readLocalAudioVolume(), 1.6);
    });

    test('clamps local audio volume to a safe boost range', () {
      expect(InterviewPreferenceService.normalizeLocalAudioVolume(0.5), 1.0);
      expect(InterviewPreferenceService.normalizeLocalAudioVolume(2.5), 1.8);
      expect(
        InterviewPreferenceService.normalizeLocalAudioVolume(double.nan),
        1.35,
      );
    });
  });
}
