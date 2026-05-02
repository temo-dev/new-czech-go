import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/interview/screens/interview_intro_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

ExerciseDetail _convDetail({List<String> tips = const []}) => ExerciseDetail.fromJson({
      'id': 'ex-conv-1',
      'title': 'Gia đình và bạn bè',
      'exercise_type': 'interview_conversation',
      'learner_instruction': '',
      'detail': {
        'topic': 'Gia đình và bạn bè',
        'tips': tips,
        'system_prompt': 'You are Jana. Ask about family.',
        'max_turns': 8,
        'show_transcript': true,
      },
    });

ExerciseDetail _choiceDetail() => ExerciseDetail.fromJson({
      'id': 'ex-choice-1',
      'title': 'Chọn địa điểm du lịch',
      'exercise_type': 'interview_choice_explain',
      'learner_instruction': '',
      'detail': {
        'question': 'Bạn muốn đi du lịch ở đâu?',
        'system_prompt': 'You are Jana. The learner chose {selected_option}.',
        'max_turns': 6,
        'show_transcript': false,
        'options': [
          {'id': '1', 'label': 'Praha', 'image_asset_id': ''},
          {'id': '2', 'label': 'Brno', 'image_asset_id': ''},
          {'id': '3', 'label': 'Ostrava', 'image_asset_id': ''},
        ],
      },
    });

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('InterviewIntroScreen — conversation type', () {
    testWidgets('shows topic title', (tester) async {
      final detail = _convDetail();
      await tester.pumpWidget(_wrap(InterviewIntroScreen.withDetail(
        detail: detail,
        client: ApiClient(),
        moduleId: 'mod-1',
      )));
      await tester.pump();

      expect(find.textContaining('Gia đình'), findsWidgets);
    });

    testWidgets('start button is enabled immediately (no selection required)', (tester) async {
      final detail = _convDetail();
      await tester.pumpWidget(_wrap(InterviewIntroScreen.withDetail(
        detail: detail,
        client: ApiClient(),
        moduleId: 'mod-1',
      )));
      await tester.pump();

      // Find "Bắt đầu phỏng vấn" button — should be enabled
      final startFinder = find.text('Bắt đầu phỏng vấn');
      expect(startFinder, findsOneWidget);

      // Button should be enabled (its ancestor ElevatedButton/GestureDetector
      // should not be disabled). Check via finding the widget with non-null onPressed.
      final button = tester.widget<FilledButton>(
        find.ancestor(of: startFinder, matching: find.byType(FilledButton)).first,
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows tips when provided', (tester) async {
      final detail = _convDetail(tips: ['Trả lời đầy đủ', 'Dùng từ nối']);
      await tester.pumpWidget(_wrap(InterviewIntroScreen.withDetail(
        detail: detail,
        client: ApiClient(),
        moduleId: 'mod-1',
      )));
      await tester.pump();

      expect(find.textContaining('Trả lời đầy đủ'), findsOneWidget);
    });
  });

  group('InterviewIntroScreen — choice_explain type', () {
    testWidgets('start button is disabled before any option selected', (tester) async {
      final detail = _choiceDetail();
      await tester.pumpWidget(_wrap(InterviewIntroScreen.withDetail(
        detail: detail,
        client: ApiClient(),
        moduleId: 'mod-1',
      )));
      await tester.pump();

      final startFinder = find.text('Bắt đầu với lựa chọn này');
      expect(startFinder, findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.ancestor(of: startFinder, matching: find.byType(FilledButton)).first,
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping option enables start button', (tester) async {
      final detail = _choiceDetail();
      await tester.pumpWidget(_wrap(InterviewIntroScreen.withDetail(
        detail: detail,
        client: ApiClient(),
        moduleId: 'mod-1',
      )));
      await tester.pump();

      // Tap first option
      await tester.tap(find.text('Praha'));
      await tester.pump();

      final startFinder = find.text('Bắt đầu với lựa chọn này');
      final button = tester.widget<FilledButton>(
        find.ancestor(of: startFinder, matching: find.byType(FilledButton)).first,
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('all 3 options are shown', (tester) async {
      final detail = _choiceDetail();
      await tester.pumpWidget(_wrap(InterviewIntroScreen.withDetail(
        detail: detail,
        client: ApiClient(),
        moduleId: 'mod-1',
      )));
      await tester.pump();

      expect(find.text('Praha'), findsOneWidget);
      expect(find.text('Brno'), findsOneWidget);
      expect(find.text('Ostrava'), findsOneWidget);
    });

    testWidgets('reset button clears selection and disables start', (tester) async {
      final detail = _choiceDetail();
      await tester.pumpWidget(_wrap(InterviewIntroScreen.withDetail(
        detail: detail,
        client: ApiClient(),
        moduleId: 'mod-1',
      )));
      await tester.pump();

      // Select Praha
      await tester.tap(find.text('Praha'));
      await tester.pump();

      // Verify start is enabled
      final startFinder = find.text('Bắt đầu với lựa chọn này');
      expect(
        tester.widget<FilledButton>(
          find.ancestor(of: startFinder, matching: find.byType(FilledButton)).first,
        ).onPressed,
        isNotNull,
      );

      // "Chọn lại" is in bottomNavigationBar (always visible)
      await tester.tap(find.text('Chọn lại'));
      await tester.pump();

      // Start should be disabled again
      expect(
        tester.widget<FilledButton>(
          find.ancestor(of: startFinder, matching: find.byType(FilledButton)).first,
        ).onPressed,
        isNull,
      );
    });
  });
}
