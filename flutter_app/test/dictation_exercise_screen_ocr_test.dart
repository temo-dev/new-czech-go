// V18.1 — DictationExerciseScreen branch tests for OCR + both modes.
//
// Coverage:
//   1. submission_mode="ocr" hides the typing TextField and shows camera CTA
//   2. submission_mode="type" preserves V18 behaviour (TextField visible)
//   3. submission_mode="both" renders the per-sentence toggle pill
//   4. The Both-mode toggle flips state from Type → OCR (camera CTA appears)
//
// We do not exercise the camera platform channel — `imagePicker` is overridden
// so the photo step is fully synthetic.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/locale/locale_provider.dart';
import 'package:flutter_app/core/locale/locale_scope.dart';
import 'package:flutter_app/features/exercise/screens/dictation_exercise_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

class _FakeDictationApi extends ApiClient {
  // The screen calls these only at submit-time, not on first paint, so we can
  // leave them unimplemented for the branch-rendering tests.
}

ExerciseDetail _detail(String mode) => ExerciseDetail.fromJson({
      'id': 'ex-d',
      'title': 'Test',
      'exercise_type': 'psani_3_dictation',
      'detail': {
        'topic': 'X',
        'sentences': [
          {'idx': 0, 'text': 'Pavel jde do kavárny.', 'audio_asset_id': ''},
          {'idx': 1, 'text': 'Děkuji.', 'audio_asset_id': ''},
        ],
        'max_replays_per_sentence': 3,
        'max_points': 10,
        'pass_threshold_percent': 60,
        'submission_mode': mode,
      },
    });

Future<Widget> _wrap(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final localeProvider = await LocaleProvider.load();
  return LocaleScope(
    notifier: localeProvider,
    child: MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<File?> _stubPicker() async => null;

void main() {
  testWidgets('OCR-only mode shows camera CTA and hides typing TextField',
      (tester) async {
    final widget = await _wrap(DictationExerciseScreen(
      client: _FakeDictationApi(),
      detail: _detail('ocr'),
      imagePicker: _stubPicker,
    ));
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Camera button is the only input affordance.
    expect(find.byKey(const Key('ocr-take-photo')), findsOneWidget);
    // No typing TextField on the OCR screen.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('type mode (V18 default) keeps the typing TextField visible',
      (tester) async {
    final widget = await _wrap(DictationExerciseScreen(
      client: _FakeDictationApi(),
      detail: _detail('type'),
    ));
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const Key('ocr-take-photo')), findsNothing);
    expect(find.byKey(const Key('mode-toggle-pill')), findsNothing);
  });

  testWidgets('both mode renders the per-sentence mode toggle pill',
      (tester) async {
    final widget = await _wrap(DictationExerciseScreen(
      client: _FakeDictationApi(),
      detail: _detail('both'),
    ));
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Toggle pill is mounted; default to Type so TextField is visible.
    expect(find.byKey(const Key('mode-toggle-pill')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('both mode toggle flips Type → OCR and surfaces camera CTA',
      (tester) async {
    final widget = await _wrap(DictationExerciseScreen(
      client: _FakeDictationApi(),
      detail: _detail('both'),
    ));
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Tap the OCR chip inside the toggle pill (camera label).
    await tester.tap(find.text('📷 Chụp ảnh').first);
    await tester.pumpAndSettle();

    // Camera CTA now visible; TextField hidden.
    expect(find.byKey(const Key('ocr-take-photo')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
