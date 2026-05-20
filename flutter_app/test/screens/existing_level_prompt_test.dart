import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/storage/cefr_prefs.dart';
import 'package:flutter_app/features/onboarding/cefr_auth_gate.dart';
import 'package:flutter_app/features/onboarding/existing_level_confirm_dialog.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ─── fakes ────────────────────────────────────────────────────────────────────

class _FakeLevelApi extends LevelApi {
  _FakeLevelApi() : super(baseUrl: 'http://fake', tokenProvider: () => 'tok');

  LevelProgressResponse? _progress;
  int skipCalls = 0;

  void stubProgress(LevelProgressResponse p) => _progress = p;

  @override
  Future<LevelProgressResponse> fetchLevelProgress() async => _progress!;

  @override
  Future<PlacementCompleteResult> skipPlacement() async {
    skipCalls++;
    return PlacementCompleteResult(
      assignedLevel: CefrLevel.a2,
      scorePct: 0,
      currentLevel: CefrLevel.a2,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2},
      placementTakenAt: DateTime(2026, 5, 7),
    );
  }
}

LevelProgressResponse _a2Progress({bool placementTaken = false}) =>
    LevelProgressResponse(
      userID: 'u1',
      currentLevel: CefrLevel.a2,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2},
      nextLevel: CefrLevel.b1,
      placementTakenAt: placementTaken ? DateTime(2026, 5, 7) : null,
      skillMastery: const {},
      coveragePct: 0,
      coverageThresholdPct: 80,
      allSkillsPass: false,
      promotionUnlocked: false,
    );

// ─── dialog standalone tests ─────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ExistingLevelConfirmDialog widget', () {
    Widget wrap({
      required CefrLevel level,
      VoidCallback? onConfirm,
      VoidCallback? onRetest,
    }) {
      return MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExistingLevelConfirmDialog(
            level: level,
            onConfirm: onConfirm ?? () {},
            onRetest: onRetest ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders level label in title and both CTAs', (tester) async {
      await tester.pumpWidget(wrap(level: CefrLevel.a2));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('existing_prompt_confirm')), findsOneWidget);
      expect(find.byKey(const Key('existing_prompt_retest')), findsOneWidget);
      expect(find.textContaining('A2'), findsWidgets);
    });

    testWidgets('confirm CTA fires onConfirm callback', (tester) async {
      int confirmCalls = 0;
      await tester.pumpWidget(
        wrap(level: CefrLevel.a2, onConfirm: () => confirmCalls++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('existing_prompt_confirm')));
      await tester.pumpAndSettle();

      expect(confirmCalls, 1);
    });

    testWidgets('retest CTA fires onRetest callback', (tester) async {
      int retestCalls = 0;
      await tester.pumpWidget(
        wrap(level: CefrLevel.a2, onRetest: () => retestCalls++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('existing_prompt_retest')));
      await tester.pumpAndSettle();

      expect(retestCalls, 1);
    });

    testWidgets('system back gesture is absorbed — no pop without choice', (
      tester,
    ) async {
      bool dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () async {
                    await showDialog<void>(
                      context: ctx,
                      barrierDismissible: false,
                      builder:
                          (_) => ExistingLevelConfirmDialog(
                            level: CefrLevel.a2,
                            onConfirm: () => Navigator.pop(ctx),
                            onRetest: () => Navigator.pop(ctx),
                          ),
                    );
                    dismissed = true;
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Dialog open. Simulate back — PopScope absorbs it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Dialog still visible and dismissed flag not set.
      expect(dismissed, isFalse);
      expect(find.byKey(const Key('existing_prompt_confirm')), findsOneWidget);
    });
  });

  // ─── CefrAuthGate integration tests for existing-A2 flow ─────────────────

  group('CefrAuthGate — existing A2 prompt', () {
    const childKey = Key('learner_shell');
    const welcomeKey = Key('welcome_screen');

    Widget wrapGate(_FakeLevelApi api, {VoidCallback? onExistingRetest}) =>
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CefrAuthGate(
            levelApi: api,
            onExistingRetest: onExistingRetest,
            welcomeScreen: const Scaffold(key: welcomeKey),
            child: const Scaffold(key: childKey),
          ),
        );

    testWidgets('existing-A2 user without prompt shown sees dialog', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api =
          _FakeLevelApi()..stubProgress(_a2Progress(placementTaken: false));

      await tester.pumpWidget(wrapGate(api));
      await tester.pumpAndSettle();

      // Child is rendered underneath, dialog is shown on top.
      expect(find.byKey(childKey), findsOneWidget);
      expect(find.byKey(const Key('existing_prompt_confirm')), findsOneWidget);
      expect(find.byKey(const Key('existing_prompt_retest')), findsOneWidget);
    });

    testWidgets('existing-A2 user with prompt already shown sees child only', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'cefr_existing_prompt_shown_u1_a2': true,
      });
      final api =
          _FakeLevelApi()..stubProgress(_a2Progress(placementTaken: false));

      await tester.pumpWidget(wrapGate(api));
      await tester.pumpAndSettle();

      expect(find.byKey(childKey), findsOneWidget);
      expect(find.byKey(const Key('existing_prompt_confirm')), findsNothing);
    });

    testWidgets(
      'confirm: calls skipPlacement + sets prefs + dismisses dialog',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final api =
            _FakeLevelApi()..stubProgress(_a2Progress(placementTaken: false));

        await tester.pumpWidget(wrapGate(api));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('existing_prompt_confirm')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('existing_prompt_confirm')));
        await tester.pumpAndSettle();

        expect(api.skipCalls, 1);
        final prefs = await CefrPrefs.create();
        expect(
          prefs.isExistingPromptShownFor(userID: 'u1', level: 'a2'),
          isTrue,
        );
        expect(find.byKey(const Key('existing_prompt_confirm')), findsNothing);
      },
    );

    testWidgets('back-gesture absorbed: prefs flag stays false', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api =
          _FakeLevelApi()..stubProgress(_a2Progress(placementTaken: false));

      await tester.pumpWidget(wrapGate(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('existing_prompt_confirm')), findsOneWidget);

      // Simulate back gesture via handlePopRoute — PopScope absorbs.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final prefs = await CefrPrefs.create();
      expect(
        prefs.isExistingPromptShownFor(userID: 'u1', level: 'a2'),
        isFalse,
      );
      expect(find.byKey(const Key('existing_prompt_confirm')), findsOneWidget);
    });

    testWidgets('retest: sets scoped prefs and calls route callback', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      var retestCalls = 0;
      final api =
          _FakeLevelApi()..stubProgress(_a2Progress(placementTaken: false));

      await tester.pumpWidget(
        wrapGate(api, onExistingRetest: () => retestCalls++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('existing_prompt_retest')));
      await tester.pumpAndSettle();

      final prefs = await CefrPrefs.create();
      expect(prefs.isExistingPromptShownFor(userID: 'u1', level: 'a2'), isTrue);
      expect(retestCalls, 1);
      expect(find.byKey(const Key('existing_prompt_retest')), findsNothing);
    });
  });
}
