import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/interview/interview_preference_service.dart';
import 'package:flutter_app/core/locale/locale_provider.dart';
import 'package:flutter_app/core/locale/locale_scope.dart';
import 'package:flutter_app/core/voice/voice_option.dart';
import 'package:flutter_app/core/voice/voice_preference_service.dart';
import 'package:flutter_app/features/profile/screens/profile_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

class _FakeProfileApiClient extends ApiClient {
  @override
  Future<List<VoiceOption>> getVoices() async => const [];
}

Widget _wrap(Widget child, LocaleProvider localeProvider) => LocaleScope(
  notifier: localeProvider,
  child: MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('profile toggles Simli avatar preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = await LocaleProvider.load();
    final voiceService = await VoicePreferenceService.create();
    final interviewService = await InterviewPreferenceService.create();

    await tester.pumpWidget(
      _wrap(
        ProfileScreen(
          client: _FakeProfileApiClient(),
          voiceService: voiceService,
          interviewService: interviewService,
        ),
        localeProvider,
      ),
    );
    await tester.pump();

    expect(find.text('Dùng avatar Simli'), findsOneWidget);
    expect(find.text('Âm lượng giám khảo'), findsOneWidget);
    expect(interviewService.avatarEnabled, isFalse);
    expect(interviewService.localAudioVolume, 1.35);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(interviewService.avatarEnabled, isTrue);
  });
}
