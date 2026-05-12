import 'package:flutter/material.dart';
import 'package:flutter_app/features/mock_exam/screens/answer_sheet_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

MockExamSection _sec({
  required int seq,
  required int disp,
  required int maxPts,
  required String skillKind,
  required String exerciseType,
  String status = 'pending',
}) {
  return MockExamSection(
    sequenceNo: seq,
    skillKind: skillKind,
    exerciseId: 'ex-$seq',
    exerciseType: exerciseType,
    maxPoints: maxPts,
    attemptId: '',
    sectionScore: 0,
    status: status,
    displayOrder: disp,
  );
}

MockExamSessionView _session(List<MockExamSection> sections) {
  return MockExamSessionView(
    id: 's1',
    status: 'in_progress',
    mockTestId: 'mt-1',
    overallScore: 0,
    passed: false,
    passThresholdPercent: 60,
    overallReadinessLevel: '',
    overallSummary: '',
    sections: sections,
  );
}

Widget _wrap(MockExamSessionView session, {int current = 0}) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: AnswerSheetScreen(session: session, currentDisplayOrder: current),
);

void main() {
  group('AnswerSheetScreen', () {
    testWidgets('renders one chip per section', (tester) async {
      final session = _session([
        _sec(
          seq: 1,
          disp: 1,
          maxPts: 5,
          skillKind: 'doc',
          exerciseType: 'cteni_1',
        ),
        _sec(
          seq: 2,
          disp: 2,
          maxPts: 8,
          skillKind: 'noi',
          exerciseType: 'uloha_1_topic_answers',
        ),
      ]);
      await tester.pumpWidget(_wrap(session));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('summary footer reflects done/skipped/remaining counts', (
      tester,
    ) async {
      final session = _session([
        _sec(
          seq: 1,
          disp: 1,
          maxPts: 5,
          skillKind: 'doc',
          exerciseType: 'cteni_1',
          status: 'completed',
        ),
        _sec(
          seq: 2,
          disp: 2,
          maxPts: 8,
          skillKind: 'noi',
          exerciseType: 'uloha_1_topic_answers',
          status: 'skipped',
        ),
        _sec(
          seq: 3,
          disp: 3,
          maxPts: 10,
          skillKind: 'doc',
          exerciseType: 'cteni_2',
          status: 'pending',
        ),
      ]);
      await tester.pumpWidget(_wrap(session));
      expect(find.text('1/3 đã làm · 1 bỏ qua · 1 chưa'), findsOneWidget);
    });

    testWidgets('skill headers appear when sections of that kind exist', (
      tester,
    ) async {
      final session = _session([
        _sec(
          seq: 1,
          disp: 1,
          maxPts: 5,
          skillKind: 'doc',
          exerciseType: 'cteni_1',
        ),
        _sec(
          seq: 2,
          disp: 2,
          maxPts: 8,
          skillKind: 'noi',
          exerciseType: 'uloha_1_topic_answers',
        ),
      ]);
      await tester.pumpWidget(_wrap(session));
      // Reading + Speaking skills present → both uppercased VI headers
      // appear (skillDoc='Đọc' → 'ĐỌC'; skillNoi='Nói' → 'NÓI').
      expect(find.text('ĐỌC'), findsOneWidget);
      expect(find.text('NÓI'), findsOneWidget);
    });

    // V39 S7 — chip tap pops the sheet with that section's display_order.
    testWidgets('tapping a chip pops with the displayOrder', (tester) async {
      final session = _session([
        _sec(
          seq: 1,
          disp: 1,
          maxPts: 5,
          skillKind: 'doc',
          exerciseType: 'cteni_1',
        ),
        _sec(
          seq: 2,
          disp: 2,
          maxPts: 8,
          skillKind: 'noi',
          exerciseType: 'uloha_1_topic_answers',
        ),
      ]);
      int? popped;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(ctx).push<int>(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => AnswerSheetScreen(session: session),
                    ),
                  );
                },
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      // Tap the chip for display_order=2.
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(popped, 2);
    });

    testWidgets('legend renders three state items', (tester) async {
      final session = _session([
        _sec(
          seq: 1,
          disp: 1,
          maxPts: 5,
          skillKind: 'doc',
          exerciseType: 'cteni_1',
        ),
      ]);
      await tester.pumpWidget(_wrap(session));
      expect(find.text('Đã làm'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(find.text('Chưa làm'), findsOneWidget);
    });
  });
}
