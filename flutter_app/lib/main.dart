import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_models.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/auth_storage.dart';
import 'core/iap/iap_service.dart';
import 'core/iap/iap_service_provider.dart';
import 'core/iap/real_iap_service.dart';
import 'core/interview/interview_preference_service.dart';
import 'core/locale/locale_provider.dart';
import 'core/locale/locale_scope.dart';
import 'core/voice/voice_preference_service.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'core/api/level_api.dart';
import 'features/auth/screens/signup_screen.dart' show AuthServiceProvider;
import 'features/auth/screens/welcome_screen.dart' as auth_welcome show WelcomeScreen;
import 'features/exercise/screens/exercise_screen.dart' as exercise_feature;
import 'features/onboarding/cefr_auth_gate.dart';
import 'features/onboarding/placement_test_screen.dart';
import 'features/onboarding/welcome_screen.dart' as onboarding_welcome show WelcomeScreen;
import 'features/exercise/screens/listening_exercise_screen.dart';
import 'features/exercise/screens/reading_exercise_screen.dart';
import 'features/exercise/screens/vocab_grammar_exercise_screen.dart';
import 'features/exercise/screens/writing_exercise_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/home/screens/course_list_screen.dart';
import 'features/mock_exam/screens/mock_test_list_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'models/models.dart';
import 'shared/widgets/app_bottom_nav.dart';

/// V17 self-serve auth is opt-in via the build flag so the legacy
/// dev-fixture login path keeps working unchanged for development +
/// existing widget tests. Production cutover flips this to true via
/// `--dart-define=USE_V17_AUTH=true`.
const bool kUseV17Auth = bool.fromEnvironment('USE_V17_AUTH');

/// V25 production StoreKit binding. The default is on; pass
/// `--dart-define=IAP_ENABLED=false` to force the in-memory stub
/// (useful for sandbox-less smoke runs and Android branches that
/// have not yet shipped Billing).
const bool kIapEnabled = bool.fromEnvironment(
  'IAP_ENABLED',
  defaultValue: true,
);

/// Returns the real plugin-backed [IAPService] only when iOS + V17
/// auth are both wired. Anywhere else (Android, web, dev shell
/// without V17) falls back to the stub so Buy renders the existing
/// "coming soon" path. The wired AuthService is the verify bridge.
IAPService _buildIAPService(AuthService? authService) {
  final isIosProd = kIapEnabled && !kIsWeb && Platform.isIOS;
  if (!isIosProd || authService == null) {
    return StubIAPService();
  }
  return RealIAPService(
    verifyReceipt: ({required String receipt, required String productId}) async {
      await authService.apiClientForScreens.verifyAppleReceiptV17(
        receipt: receipt,
        productId: productId,
      );
      await authService.refresh();
    },
  )..start();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeProvider = await LocaleProvider.load();

  // When the V17 flag is enabled, build the AuthService eagerly so the
  // bootstrap (read token from storage + validate via /v1/users/me)
  // races with the first frame instead of behind it.
  AuthService? authService;
  if (kUseV17Auth) {
    final storage = await AuthStorage.create();
    authService = AuthService(apiClient: ApiClient(), storage: storage);
    unawaited(authService.bootstrap());
  }

  final iapService = _buildIAPService(authService);

  runApp(MluveniSprintApp(
    localeProvider: localeProvider,
    authService: authService,
    iapService: iapService,
  ));
}

class MluveniSprintApp extends StatefulWidget {
  const MluveniSprintApp({
    super.key,
    required this.localeProvider,
    this.authService,
    this.iapService,
  });

  final LocaleProvider localeProvider;
  final AuthService? authService;

  /// Optional override; when null the widget creates a [StubIAPService]
  /// so legacy widget tests + dev builds keep working unchanged.
  final IAPService? iapService;

  @override
  State<MluveniSprintApp> createState() => _MluveniSprintAppState();
}

class _MluveniSprintAppState extends State<MluveniSprintApp> {
  late final IAPService _iapService;

  @override
  void initState() {
    super.initState();
    _iapService = widget.iapService ?? StubIAPService();
  }

  @override
  void dispose() {
    // Production [RealIAPService] holds a long-lived purchaseStream
    // subscription; tear it down so hot-restart in dev does not pile
    // up duplicate listeners. The stub has no resources to release.
    final iap = _iapService;
    if (iap is RealIAPService) {
      iap.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.authService != null
        ? _V17AuthGate(service: widget.authService!)
        : const LearnerShell();
    final app = LocaleScope(
      notifier: widget.localeProvider,
      child: AnimatedBuilder(
        animation: widget.localeProvider,
        builder:
            (context, _) => MaterialApp(
              title: 'A2 Mluveni Sprint',
              theme: AppTheme.light,
              home: home,
              builder: (context, child) {
                if (child == null) return const SizedBox.shrink();
                final wrapped = IAPServiceProvider(
                  service: _iapService,
                  child: child,
                );
                return widget.authService != null
                    ? AuthServiceProvider(service: widget.authService!, child: wrapped)
                    : wrapped;
              },
              locale: Locale(widget.localeProvider.code),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
      ),
    );
    return app;
  }
}

/// V17 router. Listens to [AuthService] and shows the right screen for
/// the current state. Only mounted when the build flag is on.
class _V17AuthGate extends StatelessWidget {
  const _V17AuthGate({required this.service});

  final AuthService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        switch (service.state) {
          case AuthState.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthState.unauthenticated:
            return const auth_welcome.WelcomeScreen();
          case AuthState.needsVerify:
          case AuthState.authenticated:
            return _CefrOnboarding(service: service);
        }
      },
    );
  }
}

/// V21.3 onboarding wrapper. Sits between authentication and LearnerShell so
/// that fresh-signup users land on the placement test before the course list.
class _CefrOnboarding extends StatefulWidget {
  const _CefrOnboarding({required this.service});

  final AuthService service;

  @override
  State<_CefrOnboarding> createState() => _CefrOnboardingState();
}

class _CefrOnboardingState extends State<_CefrOnboarding> {
  late final GlobalKey<CefrAuthGateState> _gateKey;
  late final LevelApi _levelApi;
  late final ApiClient _client;

  @override
  void initState() {
    super.initState();
    _gateKey = GlobalKey<CefrAuthGateState>();
    _client = widget.service.apiClientForScreens;
    _levelApi = LevelApi(
      baseUrl: _client.baseUrl,
      tokenProvider: () => _client.currentToken,
    );
  }

  void _refreshGate() => _gateKey.currentState?.refresh();

  Future<void> _handleSkip() async {
    try {
      await _levelApi.skipPlacement();
    } catch (_) {
      // Best-effort: if skip fails (e.g. already taken), refresh anyway so
      // the gate re-evaluates.
    }
    _refreshGate();
  }

  @override
  Widget build(BuildContext context) {
    return CefrAuthGate(
      key: _gateKey,
      levelApi: _levelApi,
      child: const LearnerShell(),
      welcomeScreen: onboarding_welcome.WelcomeScreen(
        onStart: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder:
                (_) => PlacementTestScreen(
                  levelApi: _levelApi,
                  client: _client,
                  onFinished: _refreshGate,
                ),
          ),
        ),
        onSkip: _handleSkip,
      ),
    );
  }
}

class LearnerShell extends StatefulWidget {
  const LearnerShell({super.key});

  @override
  State<LearnerShell> createState() => _LearnerShellState();
}

class _LearnerShellState extends State<LearnerShell> {
  late final ApiClient _client = _resolveClient();

  /// In V17 mode the AuthService already owns an [ApiClient] with the
  /// current bearer token attached; share it so the LearnerShell does
  /// not silently authenticate via the legacy dev-fixture credentials.
  ApiClient _resolveClient() {
    if (kUseV17Auth) {
      try {
        return AuthServiceProvider.of(context).apiClientForScreens;
      } catch (_) {
        // No provider in tree (legacy build); fall through.
      }
    }
    return ApiClient();
  }
  VoicePreferenceService? _voiceService;
  InterviewPreferenceService? _interviewService;
  bool _loading = true;
  String? _error;
  List<AttemptResult> _recentAttempts = const [];
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _voiceService ??= await VoicePreferenceService.create();
      _interviewService ??= await InterviewPreferenceService.create();
      // V17 mode: the AuthService bootstrap already attached the
      // session token to the shared ApiClient before LearnerShell
      // mounted. Legacy mode: hit the dev-fixture endpoint to seed the
      // token map.
      if (!kUseV17Auth) {
        await _client.login(email: 'learner@example.com', password: 'demo123');
      }
      final attemptsPayload = await _client.getAttempts();
      final recentAttempts =
          attemptsPayload
              .map(
                (item) => AttemptResult.fromJson(item as Map<String, dynamic>),
              )
              .toList();

      setState(() {
        _recentAttempts = recentAttempts;
      });
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRecentAttempts() async {
    try {
      final payload = await _client.getAttempts();
      if (!mounted) return;
      setState(() {
        _recentAttempts =
            payload
                .map(
                  (item) =>
                      AttemptResult.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      });
    } catch (_) {
      // Keep shell usable if refresh fails.
    }
  }

  Future<void> _openAttemptExercise(
    BuildContext context,
    AttemptResult attempt,
  ) async {
    final navigator = Navigator.of(context);
    final detail = ExerciseDetail.fromJson(
      await _client.getExercise(attempt.exerciseId),
    );
    if (!mounted) return;
    if (detail.isCteni) {
      await navigator.push(
        MaterialPageRoute(
          builder:
              (_) => ReadingExerciseScreen(client: _client, detail: detail),
        ),
      );
    } else if (detail.isPoslech) {
      await navigator.push(
        MaterialPageRoute(
          builder:
              (_) => ListeningExerciseScreen(client: _client, detail: detail),
        ),
      );
    } else if (detail.isPsani1 || detail.isPsani2) {
      await navigator.push(
        MaterialPageRoute(
          builder:
              (_) => WritingExerciseScreen(client: _client, detail: detail),
        ),
      );
    } else if (detail.isVocabGrammar) {
      await navigator.push(
        MaterialPageRoute(
          builder:
              (_) =>
                  VocabGrammarExerciseScreen(client: _client, detail: detail),
        ),
      );
    } else {
      await navigator.push(
        MaterialPageRoute(
          builder:
              (_) => exercise_feature.ExerciseScreen(
                client: _client,
                detail: detail,
              ),
        ),
      );
    }
    await _loadRecentAttempts();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _bootstrap, child: Text(l.retry)),
            ],
          ),
        ),
      );
    } else if (_tabIndex == 1) {
      body = HistoryScreen(
        attempts: _recentAttempts,
        exercisesByModule: const {},
        onOpenAttemptExercise: (a) => _openAttemptExercise(context, a),
      );
    } else if (_tabIndex == 2) {
      body = MockTestListScreen(client: _client);
    } else if (_tabIndex == 3) {
      body = ProfileScreen(
        client: _client,
        voiceService: _voiceService!,
        interviewService: _interviewService!,
      );
    } else {
      body = CourseListScreen(
        client: _client,
        levelApi: LevelApi(
          baseUrl: _client.baseUrl,
          tokenProvider: () => _client.currentToken,
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar:
          (_loading || _error != null)
              ? null
              : AppBottomNav(
                selectedIndex: _tabIndex,
                onSelected: (i) => setState(() => _tabIndex = i),
                items: [
                  AppBottomNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: l.bottomNavHome,
                  ),
                  AppBottomNavItem(
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history_rounded,
                    label: l.bottomNavHistory,
                  ),
                  AppBottomNavItem(
                    icon: Icons.assignment_outlined,
                    selectedIcon: Icons.assignment_rounded,
                    label: l.bottomNavTests,
                  ),
                  AppBottomNavItem(
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    label: l.bottomNavProfile,
                  ),
                ],
              ),
    );
  }
}
