import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/mock_exam/screens/mock_exam_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

void main() {
  test(
    'MockTest totalScoreMax only adds speaking bonus for full oral mock',
    () {
      const mixed = MockTest(
        id: 'mt-mixed',
        title: 'Mixed',
        description: '',
        estimatedDurationMinutes: 10,
        status: 'published',
        sections: [
          MockTestSection(
            sequenceNo: 1,
            skillKind: 'noi',
            exerciseId: 'ex-1',
            exerciseType: 'uloha_1_topic_answers',
            maxPoints: 8,
          ),
          MockTestSection(
            sequenceNo: 2,
            skillKind: 'doc',
            exerciseId: 'ex-2',
            exerciseType: 'cteni_1',
            maxPoints: 5,
          ),
        ],
      );
      const oral = MockTest(
        id: 'mt-oral',
        title: 'Oral',
        description: '',
        estimatedDurationMinutes: 15,
        status: 'published',
        sections: [
          MockTestSection(
            sequenceNo: 1,
            skillKind: 'noi',
            exerciseId: 'ex-1',
            exerciseType: 'uloha_1_topic_answers',
            maxPoints: 8,
          ),
          MockTestSection(
            sequenceNo: 2,
            skillKind: 'noi',
            exerciseId: 'ex-2',
            exerciseType: 'uloha_2_dialogue_questions',
            maxPoints: 12,
          ),
          MockTestSection(
            sequenceNo: 3,
            skillKind: 'noi',
            exerciseId: 'ex-3',
            exerciseType: 'uloha_3_story_narration',
            maxPoints: 10,
          ),
          MockTestSection(
            sequenceNo: 4,
            skillKind: 'noi',
            exerciseId: 'ex-4',
            exerciseType: 'uloha_4_choice_reasoning',
            maxPoints: 7,
          ),
        ],
      );

      expect(mixed.totalScoreMax, 13);
      expect(oral.totalScoreMax, 40);
    },
  );

  testWidgets('MockExamScreen uses selected mock test data in progress view', (
    tester,
  ) async {
    final mockTest = MockTest(
      id: 'mt-mixed',
      title: 'Sprint Mixed',
      description: '',
      estimatedDurationMinutes: 10,
      status: 'published',
      passThresholdPercent: 80,
      sections: const [
        MockTestSection(
          sequenceNo: 1,
          skillKind: 'noi',
          exerciseId: 'ex-1',
          exerciseType: 'uloha_1_topic_answers',
          maxPoints: 8,
        ),
        MockTestSection(
          sequenceNo: 2,
          skillKind: 'nghe',
          exerciseId: 'ex-2',
          exerciseType: 'poslech_2',
          maxPoints: 5,
        ),
      ],
    );
    final session = MockExamSessionView(
      id: 'session-1',
      status: 'in_progress',
      mockTestId: mockTest.id,
      overallScore: 0,
      passed: false,
      passThresholdPercent: 80,
      overallReadinessLevel: '',
      overallSummary: '',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'noi',
          exerciseId: 'ex-1',
          exerciseType: 'uloha_1_topic_answers',
          maxPoints: 8,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
        ),
        MockExamSection(
          sequenceNo: 2,
          skillKind: 'nghe',
          exerciseId: 'ex-2',
          exerciseType: 'poslech_2',
          maxPoints: 5,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: ApiClient(),
          initialSession: session,
          mockTest: mockTest,
        ),
      ),
    );

    expect(find.text('Sprint Mixed'), findsOneWidget);
    expect(find.text('Mock oral exam'), findsNothing);
    expect(find.text('2 sections, one attempt each'), findsOneWidget);
    expect(find.textContaining('Úloha 1'), findsOneWidget);
    expect(find.textContaining('Listening 2'), findsOneWidget);
    expect(find.text('ULOHA_1_TOPIC_ANSWERS'), findsNothing);
  });
}
