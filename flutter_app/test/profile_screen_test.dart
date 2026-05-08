import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/auth/auth_models.dart';
import 'package:flutter_app/core/auth/auth_service.dart';
import 'package:flutter_app/core/auth/auth_storage.dart';
import 'package:flutter_app/core/iap/iap_models.dart';
import 'package:flutter_app/core/iap/iap_service.dart';
import 'package:flutter_app/core/iap/iap_service_provider.dart';
import 'package:flutter_app/core/interview/interview_preference_service.dart';
import 'package:flutter_app/core/locale/locale_provider.dart';
import 'package:flutter_app/core/locale/locale_scope.dart';
import 'package:flutter_app/core/voice/voice_option.dart';
import 'package:flutter_app/core/voice/voice_preference_service.dart';
import 'package:flutter_app/features/auth/screens/signup_screen.dart' show AuthServiceProvider;
import 'package:flutter_app/features/paywall/screens/paywall_screen.dart';
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

  // ── V25-F2: Pro upgrade tile ───────────────────────────────────────────

  testWidgets('Profile shows upgrade tile for free user + tap pushes paywall',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = await LocaleProvider.load();
    final voiceService = await VoicePreferenceService.create();
    final interviewService = await InterviewPreferenceService.create();

    final auth = AuthService(
      apiClient: ApiClient(baseUrl: 'http://127.0.0.1:1'),
      storage: await AuthStorage.create(),
    );
    auth.adoptUser(AuthUser.fromJson({
      'id': 'u_free',
      'email': 'free@x.com',
      'email_verified': true,
      'display_name': 'Free',
      'role': 'learner',
      'pro_tier': 'free',
      'grace_attempts_left': 999,
    }));

    await tester.pumpWidget(
      LocaleScope(
        notifier: localeProvider,
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuthServiceProvider(
            service: auth,
            child: IAPServiceProvider(
              service: StubIAPService(),
              child: Scaffold(
                body: ProfileScreen(
                  client: _FakeProfileApiClient(),
                  voiceService: voiceService,
                  interviewService: interviewService,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Free user sees the upgrade CTA, not the manage-subscription one.
    expect(find.byKey(const Key('profile_upgrade_pro')), findsOneWidget);
    expect(find.byKey(const Key('profile_manage_subscription')), findsNothing);
    expect(find.text('Nâng cấp Pro'), findsWidgets);

    await tester.tap(find.byKey(const Key('profile_upgrade_pro')));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('Profile shows manage-subscription tile for Pro user',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = await LocaleProvider.load();
    final voiceService = await VoicePreferenceService.create();
    final interviewService = await InterviewPreferenceService.create();

    final auth = AuthService(
      apiClient: ApiClient(baseUrl: 'http://127.0.0.1:1'),
      storage: await AuthStorage.create(),
    );
    auth.adoptUser(AuthUser.fromJson({
      'id': 'u_pro',
      'email': 'pro@x.com',
      'email_verified': true,
      'display_name': 'Pro',
      'role': 'learner',
      'pro_tier': 'pro',
      'grace_attempts_left': 999,
    }));

    await tester.pumpWidget(
      LocaleScope(
        notifier: localeProvider,
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuthServiceProvider(
            service: auth,
            child: IAPServiceProvider(
              service: StubIAPService(),
              child: Scaffold(
                body: ProfileScreen(
                  client: _FakeProfileApiClient(),
                  voiceService: voiceService,
                  interviewService: interviewService,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('profile_manage_subscription')), findsOneWidget);
    expect(find.byKey(const Key('profile_upgrade_pro')), findsNothing);
    expect(find.text('Quản lý đăng ký Pro'), findsOneWidget);
  });
}
