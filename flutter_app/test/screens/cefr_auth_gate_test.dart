import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/onboarding/cefr_auth_gate.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ─── fake ─────────────────────────────────────────────────────────────────────

class _FakeLevelApi extends LevelApi {
  _FakeLevelApi() : super(baseUrl: 'http://fake', tokenProvider: () => 'tok');

  LevelProgressResponse? _progress;
  Object? _error;

  void stubProgress(LevelProgressResponse p) => _progress = p;
  void stubError(Object e) => _error = e;

  @override
  Future<LevelProgressResponse> fetchLevelProgress() async {
    final err = _error;
    if (err != null) throw err;
    return _progress!;
  }
}

LevelProgressResponse _progress({
  CefrLevel level = CefrLevel.a0,
  bool placementTaken = false,
  bool promotionUnlocked = false,
}) {
  return LevelProgressResponse(
    userID: 'u1',
    currentLevel: level,
    unlockedLevels: {level},
    nextLevel: null,
    placementTakenAt: placementTaken ? DateTime(2026, 5, 7) : null,
    skillMastery: const {},
    coveragePct: 0,
    coverageThresholdPct: 80,
    allSkillsPass: false,
    promotionUnlocked: promotionUnlocked,
  );
}

// ─── widget helper ───────────────────────────────────────────────────────────

const _childKey = Key('learner_shell');
const _welcomeKey = Key('welcome_screen');

Widget _wrap({
  required _FakeLevelApi api,
  required Widget child,
  required Widget welcomeScreen,
}) {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CefrAuthGate(
      levelApi: api,
      welcomeScreen: welcomeScreen,
      child: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows loading spinner while fetchLevelProgress is in flight', (
    tester,
  ) async {
    final api = _BlockingProgressApi();

    await tester.pumpWidget(
      _wrap(
        api: api,
        child: const Scaffold(key: _childKey),
        welcomeScreen: const Scaffold(key: _welcomeKey),
      ),
    );
    await tester.pump(); // let initState fire, future pending

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(_childKey), findsNothing);
    expect(find.byKey(_welcomeKey), findsNothing);

    api.complete(_progress(level: CefrLevel.a0, placementTaken: true));
    await tester.pumpAndSettle();
    // After resolve with placementTaken → child
    expect(find.byKey(_childKey), findsOneWidget);
  });

  testWidgets('already-onboarded user (placementTaken) sees child directly', (
    tester,
  ) async {
    final api =
        _FakeLevelApi()
          ..stubProgress(_progress(level: CefrLevel.a2, placementTaken: true));

    await tester.pumpWidget(
      _wrap(
        api: api,
        child: const Scaffold(key: _childKey),
        welcomeScreen: const Scaffold(key: _welcomeKey),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_childKey), findsOneWidget);
    expect(find.byKey(_welcomeKey), findsNothing);
  });

  testWidgets('fresh A0 user (no placement) sees WelcomeScreen', (
    tester,
  ) async {
    final api =
        _FakeLevelApi()
          ..stubProgress(_progress(level: CefrLevel.a0, placementTaken: false));

    await tester.pumpWidget(
      _wrap(
        api: api,
        child: const Scaffold(key: _childKey),
        welcomeScreen: const Scaffold(key: _welcomeKey),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_welcomeKey), findsOneWidget);
    expect(find.byKey(_childKey), findsNothing);
  });

  testWidgets('fresh A0 user ignores legacy existing-prompt flag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cefr_existing_prompt_shown': true,
    });
    final api =
        _FakeLevelApi()
          ..stubProgress(_progress(level: CefrLevel.a0, placementTaken: false));

    await tester.pumpWidget(
      _wrap(
        api: api,
        child: const Scaffold(key: _childKey),
        welcomeScreen: const Scaffold(key: _welcomeKey),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_welcomeKey), findsOneWidget);
    expect(find.byKey(_childKey), findsNothing);
  });

  testWidgets('gate re-evaluates after refresh() call', (tester) async {
    // Start as fresh A0 (no placement).
    final api =
        _FakeLevelApi()
          ..stubProgress(_progress(level: CefrLevel.a0, placementTaken: false));

    final gateKey = GlobalKey<CefrAuthGateState>();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CefrAuthGate(
          key: gateKey,
          levelApi: api,
          welcomeScreen: const Scaffold(key: _welcomeKey),
          child: const Scaffold(key: _childKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_welcomeKey), findsOneWidget);

    // Simulate user completing placement → server now returns placementTaken.
    api.stubProgress(_progress(level: CefrLevel.a2, placementTaken: true));
    gateKey.currentState?.refresh();
    await tester.pumpAndSettle();

    expect(find.byKey(_childKey), findsOneWidget);
    expect(find.byKey(_welcomeKey), findsNothing);
  });

  testWidgets('error during fetch shows error view with retry', (tester) async {
    final api =
        _FakeLevelApi()..stubError(
          const LevelApiException(
            statusCode: 500,
            code: 'server_error',
            message: 'Oops',
          ),
        );

    await tester.pumpWidget(
      _wrap(
        api: api,
        child: const Scaffold(key: _childKey),
        welcomeScreen: const Scaffold(key: _welcomeKey),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cefr_gate_error')), findsOneWidget);
    expect(find.byKey(const Key('cefr_gate_retry')), findsOneWidget);
    expect(find.byKey(_childKey), findsNothing);
  });

  testWidgets('scoped existing-prompt key is read on gate build', (
    tester,
  ) async {
    // A2 user with placement null but prompt already shown → show child
    // (this is the "existing user confirmed" state; Phase C dialog won't
    // re-fire because CefrPrefs.isExistingPromptShown is true).
    SharedPreferences.setMockInitialValues({
      'cefr_existing_prompt_shown_u1_a2': true,
    });
    final api =
        _FakeLevelApi()
          ..stubProgress(_progress(level: CefrLevel.a2, placementTaken: false));

    await tester.pumpWidget(
      _wrap(
        api: api,
        child: const Scaffold(key: _childKey),
        welcomeScreen: const Scaffold(key: _welcomeKey),
      ),
    );
    await tester.pumpAndSettle();

    // prompt shown → treat as onboarded → child visible
    expect(find.byKey(_childKey), findsOneWidget);
  });

  testWidgets('legacy global existing-prompt key does not suppress A2 dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cefr_existing_prompt_shown': true,
    });
    final api =
        _FakeLevelApi()
          ..stubProgress(_progress(level: CefrLevel.a2, placementTaken: false));

    await tester.pumpWidget(
      _wrap(
        api: api,
        child: const Scaffold(key: _childKey),
        welcomeScreen: const Scaffold(key: _welcomeKey),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_childKey), findsOneWidget);
    expect(find.byKey(const Key('existing_prompt_confirm')), findsOneWidget);
  });
}

// ─── helper fake ─────────────────────────────────────────────────────────────

class _BlockingProgressApi extends _FakeLevelApi {
  final _c = Completer<LevelProgressResponse>();
  void complete(LevelProgressResponse p) => _c.complete(p);

  @override
  Future<LevelProgressResponse> fetchLevelProgress() => _c.future;
}
