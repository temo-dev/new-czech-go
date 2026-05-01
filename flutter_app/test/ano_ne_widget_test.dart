import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/exercise/widgets/ano_ne_widget.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

List<AnoNeStatementView> _stmts(int n) => List.generate(
      n,
      (i) => AnoNeStatementView(questionNo: i + 1, statement: 'Statement ${i + 1}'),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AnoNeWidget', () {
    testWidgets('renders all statements', (tester) async {
      await tester.pumpWidget(_wrap(AnoNeWidget(
        statements: _stmts(3),
        onAnswersChanged: (_) {},
      )));
      expect(find.text('Statement 1'), findsOneWidget);
      expect(find.text('Statement 2'), findsOneWidget);
      expect(find.text('Statement 3'), findsOneWidget);
    });

    testWidgets('renders ANO and NE buttons for each statement', (tester) async {
      await tester.pumpWidget(_wrap(AnoNeWidget(
        statements: _stmts(2),
        onAnswersChanged: (_) {},
      )));
      // 2 statements × 2 buttons each
      expect(find.text('ANO'), findsNWidgets(2));
      expect(find.text('NE'), findsNWidgets(2));
    });

    testWidgets('tapping ANO calls onAnswersChanged with ANO', (tester) async {
      final answers = <String, String>{};
      await tester.pumpWidget(_wrap(AnoNeWidget(
        statements: _stmts(1),
        onAnswersChanged: (a) => answers.addAll(a),
      )));
      await tester.tap(find.text('ANO').first);
      await tester.pump();
      expect(answers['1'], equals('ANO'));
    });

    testWidgets('tapping NE overwrites ANO selection', (tester) async {
      final answers = <String, String>{};
      await tester.pumpWidget(_wrap(AnoNeWidget(
        statements: _stmts(1),
        onAnswersChanged: (a) => answers.addAll(a),
      )));
      await tester.tap(find.text('ANO').first);
      await tester.pump();
      await tester.tap(find.text('NE').first);
      await tester.pump();
      expect(answers['1'], equals('NE'));
    });

    testWidgets('post-submit correct row shows correct hint', (tester) async {
      const result = ObjectiveResult(
        score: 1,
        maxScore: 1,
        breakdown: [
          QuestionResult(
            questionNo: 1,
            questionText: 'Statement 1',
            learnerAnswer: 'ANO',
            learnerAnswerText: '',
            correctAnswer: 'ANO',
            correctAnswerText: '',
            isCorrect: true,
          ),
        ],
      );
      await tester.pumpWidget(_wrap(AnoNeWidget(
        statements: _stmts(1),
        onAnswersChanged: (_) {},
        result: result,
        enabled: false,
      )));
      await tester.pump();
      expect(find.textContaining('Đúng'), findsWidgets);
    });
  });
}
