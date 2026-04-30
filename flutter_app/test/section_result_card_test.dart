import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/mock_exam/widgets/section_result_card.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

AttemptResult _speakingResult({String exerciseType = 'uloha_1_topic_answers'}) =>
    const AttemptResult(
      id: 'a1',
      exerciseId: 'ex-1',
      exerciseType: 'uloha_1_topic_answers',
      status: 'completed',
      startedAt: '',
      readinessLevel: 'good',
      failureCode: '',
      transcriptProvider: 'local',
      transcriptIsSynthetic: false,
      transcript: 'Já rád cestuji.',
      feedback: AttemptFeedbackView(
        readinessLevel: 'good',
        overallSummary: 'Good answer',
        strengths: ['Clear'],
        improvements: [],
        retryAdvice: [],
        sampleAnswer: 'Rád cestuji do hor.',
      ),
    );

AttemptResult _objectiveResult({
  String exerciseType = 'poslech_1',
  int score = 3,
  int maxScore = 5,
  List<QuestionResult> breakdown = const [],
}) =>
    AttemptResult(
      id: 'a2',
      exerciseId: 'ex-2',
      exerciseType: exerciseType,
      status: 'completed',
      startedAt: '',
      readinessLevel: '',
      failureCode: '',
      transcriptProvider: '',
      transcriptIsSynthetic: false,
      feedback: AttemptFeedbackView(
        readinessLevel: '',
        overallSummary: '',
        strengths: const [],
        improvements: const [],
        retryAdvice: const [],
        sampleAnswer: '',
        objectiveResult: ObjectiveResult(
          score: score,
          maxScore: maxScore,
          breakdown: breakdown,
        ),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  final client = ApiClient();

  // ── dispatch ──────────────────────────────────────────────────────────────

  group('SectionResultCard dispatch', () {
    testWidgets('noi → shows ResultCard tab bar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _speakingResult(),
            skillKind: 'noi',
            maxPoints: 37,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Feedback'), findsOneWidget);
    });

    testWidgets('viet → shows ResultCard tab bar', (tester) async {
      const writingResult = AttemptResult(
        id: 'a3',
        exerciseId: 'ex-3',
        exerciseType: 'psani_1_formular',
        status: 'completed',
        startedAt: '',
        readinessLevel: '',
        failureCode: '',
        transcriptProvider: '',
        transcriptIsSynthetic: false,
        transcript: 'Jmenuji se Jana.',
        feedback: AttemptFeedbackView(
          readinessLevel: '',
          overallSummary: '',
          strengths: [],
          improvements: [],
          retryAdvice: [],
          sampleAnswer: '',
        ),
      );

      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: writingResult,
            skillKind: 'viet',
            maxPoints: 8,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Feedback'), findsOneWidget);
    });

    testWidgets('nghe → shows ObjectiveResultCard breakdown title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              exerciseType: 'poslech_1',
              breakdown: const [
                QuestionResult(
                  questionNo: 1,
                  learnerAnswer: 'Ano',
                  correctAnswer: 'Ano',
                  isCorrect: true,
                ),
              ],
            ),
            skillKind: 'nghe',
            maxPoints: 25,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Question breakdown'), findsOneWidget);
      expect(find.text('Feedback'), findsNothing);
    });

    testWidgets('doc → shows ObjectiveResultCard breakdown title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              exerciseType: 'cteni_1',
              breakdown: const [
                QuestionResult(
                  questionNo: 1,
                  learnerAnswer: 'A',
                  correctAnswer: 'A',
                  isCorrect: true,
                ),
              ],
            ),
            skillKind: 'doc',
            maxPoints: 25,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Question breakdown'), findsOneWidget);
      expect(find.text('Feedback'), findsNothing);
    });

    testWidgets('empty skillKind + exerciseType poslech_ → fallback nghe', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              exerciseType: 'poslech_3',
              breakdown: const [
                QuestionResult(
                  questionNo: 1,
                  learnerAnswer: 'Ano',
                  correctAnswer: 'Ano',
                  isCorrect: true,
                ),
              ],
            ),
            skillKind: '',
            maxPoints: 10,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Question breakdown'), findsOneWidget);
      expect(find.text('Feedback'), findsNothing);
    });

    testWidgets('empty skillKind + exerciseType cteni_ → fallback doc', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              exerciseType: 'cteni_2',
              breakdown: const [
                QuestionResult(
                  questionNo: 1,
                  learnerAnswer: 'B',
                  correctAnswer: 'C',
                  isCorrect: false,
                ),
              ],
            ),
            skillKind: '',
            maxPoints: 10,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Question breakdown'), findsOneWidget);
    });

    testWidgets(
        'empty skillKind + exerciseType uloha_ → fallback noi → ResultCard',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _speakingResult(),
            skillKind: '',
            maxPoints: 12,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('Question breakdown'), findsNothing);
    });
  });

  // ── header ────────────────────────────────────────────────────────────────

  group('SectionResultCard header', () {
    testWidgets('nghe header shows score X/maxPoints', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(score: 18, maxScore: 25),
            skillKind: 'nghe',
            maxPoints: 25,
            onRetry: () {},
          ),
        ),
      );

      // "18/25" appears in both _SectionHeader and ObjectiveResultCard score header
      expect(find.text('18/25'), findsAtLeastNWidgets(1));
    });

    testWidgets('noi header does not show score number', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _speakingResult(),
            skillKind: 'noi',
            maxPoints: 37,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('0/37'), findsNothing);
    });

    testWidgets('nghe header shows Listening skill label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(),
            skillKind: 'nghe',
            maxPoints: 25,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Listening'), findsOneWidget);
    });

    testWidgets('doc header shows Reading skill label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(exerciseType: 'cteni_1'),
            skillKind: 'doc',
            maxPoints: 25,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('noi header shows Speaking skill label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _speakingResult(),
            skillKind: 'noi',
            maxPoints: 37,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Speaking'), findsOneWidget);
    });
  });

  // ── question cards ────────────────────────────────────────────────────────

  group('ObjectiveResultCard question cards', () {
    testWidgets('correct question shows check icon, correct answer only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              breakdown: const [
                QuestionResult(
                  questionNo: 1,
                  learnerAnswer: 'Ano',
                  correctAnswer: 'Ano',
                  isCorrect: true,
                ),
              ],
            ),
            skillKind: 'nghe',
            maxPoints: 10,
            onRetry: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
      // Correct answer shown
      expect(find.text('Ano'), findsOneWidget);
      // Labels for wrong answer NOT shown
      expect(find.text('Your answer:'), findsNothing);
      expect(find.text('Correct answer:'), findsNothing);
    });

    testWidgets('wrong question shows cancel icon + both answers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              breakdown: const [
                QuestionResult(
                  questionNo: 2,
                  learnerAnswer: 'Ne',
                  correctAnswer: 'Ano',
                  isCorrect: false,
                ),
              ],
            ),
            skillKind: 'nghe',
            maxPoints: 10,
            onRetry: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text('Your answer:'), findsOneWidget);
      expect(find.text('Correct answer:'), findsOneWidget);
      expect(find.text('Ne'), findsOneWidget);
      expect(find.text('Ano'), findsOneWidget);
    });

    testWidgets('empty learner answer shows (no answer) fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              breakdown: const [
                QuestionResult(
                  questionNo: 1,
                  learnerAnswer: '',
                  correctAnswer: 'Ano',
                  isCorrect: false,
                ),
              ],
            ),
            skillKind: 'nghe',
            maxPoints: 10,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('(no answer)'), findsOneWidget);
    });

    testWidgets('multiple questions render all Q labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionResultCard(
            client: client,
            result: _objectiveResult(
              breakdown: const [
                QuestionResult(
                  questionNo: 1,
                  learnerAnswer: 'Ano',
                  correctAnswer: 'Ano',
                  isCorrect: true,
                ),
                QuestionResult(
                  questionNo: 2,
                  learnerAnswer: 'Ne',
                  correctAnswer: 'Nevím',
                  isCorrect: false,
                ),
              ],
            ),
            skillKind: 'nghe',
            maxPoints: 10,
            onRetry: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text('Q1:'), findsOneWidget);
      expect(find.text('Q2:'), findsOneWidget);
    });
  });
}
