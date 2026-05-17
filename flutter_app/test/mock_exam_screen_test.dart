import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/mock_exam/screens/mock_exam_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

class _FlowApiClient extends ApiClient {
  _FlowApiClient() : super(baseUrl: 'http://fake');

  final List<String> getExerciseCalls = [];
  final List<String?> mockExamSessionIds = [];

  @override
  Future<Map<String, dynamic>> getExercise(
    String exerciseId, {
    String? mockExamSessionId,
  }) async {
    getExerciseCalls.add(exerciseId);
    mockExamSessionIds.add(mockExamSessionId);
    return {
      'id': exerciseId,
      'title': exerciseId == 'ex-1' ? 'First question' : 'Second question',
      'exercise_type': 'cteni_6',
      'learner_instruction': 'Chọn đáp án đúng.',
      'prompt': <String, dynamic>{},
      'assets': <dynamic>[],
      'detail': {
        'passage': exerciseId == 'ex-1' ? 'First passage' : 'Second passage',
        'statements': [
          {
            'question_no': 1,
            'statement':
                exerciseId == 'ex-1' ? 'First statement' : 'Second statement',
          },
        ],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> createAttempt(
    String exerciseId, {
    String? locale,
  }) async {
    return {'id': 'attempt-$exerciseId'};
  }

  @override
  Future<Map<String, dynamic>> submitAnswers(
    String attemptId,
    Map<String, String> answers,
  ) async {
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> advanceMockExam(
    String id, {
    required String attemptId,
    int? targetDisplayOrder,
  }) async {
    final firstDone = attemptId == 'attempt-ex-1';
    return _sessionJson(
      firstStatus: 'completed',
      firstAttemptId: 'attempt-ex-1',
      secondStatus: firstDone ? 'pending' : 'completed',
      secondAttemptId: firstDone ? '' : 'attempt-ex-2',
    );
  }

  static Map<String, dynamic> _sessionJson({
    required String firstStatus,
    required String secondStatus,
    String firstAttemptId = '',
    String secondAttemptId = '',
  }) {
    return {
      'id': 'session-1',
      'status': 'in_progress',
      'mock_test_id': 'mt-1',
      'overall_score': 0,
      'passed': false,
      'pass_threshold_percent': 60,
      'overall_readiness_level': '',
      'overall_summary': '',
      'sections': [
        {
          'sequence_no': 1,
          'skill_kind': 'doc',
          'exercise_id': 'ex-1',
          'exercise_type': 'cteni_6',
          'max_points': 5,
          'attempt_id': firstAttemptId,
          'section_score': 0,
          'status': firstStatus,
          'display_order': 1,
        },
        {
          'sequence_no': 2,
          'skill_kind': 'doc',
          'exercise_id': 'ex-2',
          'exercise_type': 'cteni_6',
          'max_points': 8,
          'attempt_id': secondAttemptId,
          'section_score': 0,
          'status': secondStatus,
          'display_order': 2,
        },
      ],
    };
  }
}

class _InterviewFlowApiClient extends ApiClient {
  _InterviewFlowApiClient() : super(baseUrl: 'http://fake');

  final List<String> getExerciseCalls = [];
  final advanceCompleter = Completer<void>();
  int submitInterviewCalls = 0;

  @override
  Future<Map<String, dynamic>> getExercise(
    String exerciseId, {
    String? mockExamSessionId,
  }) async {
    getExerciseCalls.add(exerciseId);
    if (exerciseId == 'ex-interview') {
      return {
        'id': exerciseId,
        'title': 'Interview question',
        'exercise_type': 'interview_conversation',
        'learner_instruction': '',
        'prompt': <String, dynamic>{},
        'assets': <dynamic>[],
        'detail': {
          'topic': 'Gia đình',
          'tips': ['giới thiệu bản thân'],
          'max_turns': 1,
        },
      };
    }
    return {
      'id': exerciseId,
      'title': 'Next question',
      'exercise_type': 'cteni_6',
      'learner_instruction': 'Chọn đáp án đúng.',
      'prompt': <String, dynamic>{},
      'assets': <dynamic>[],
      'detail': {
        'passage': 'Next passage',
        'statements': [
          {'question_no': 1, 'statement': 'Next statement'},
        ],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> createAttempt(
    String exerciseId, {
    String? locale,
  }) async {
    return {'id': 'attempt-$exerciseId'};
  }

  @override
  Future<Map<String, dynamic>> getInterviewToken({
    required String exerciseId,
    required String attemptId,
    String? selectedOption,
  }) async {
    return {'signed_url': '', 'system_prompt': ''};
  }

  @override
  Future<Map<String, dynamic>> submitInterview(
    String attemptId, {
    required List<Map<String, dynamic>> turns,
    required int durationSec,
  }) async {
    submitInterviewCalls += 1;
    return {'id': attemptId, 'status': 'completed'};
  }

  @override
  Future<Map<String, dynamic>> advanceMockExam(
    String id, {
    required String attemptId,
    int? targetDisplayOrder,
  }) async {
    await advanceCompleter.future;
    return _sessionJson(
      firstStatus: 'completed',
      firstAttemptId: attemptId,
      secondStatus: 'pending',
    );
  }

  static Map<String, dynamic> _sessionJson({
    required String firstStatus,
    required String secondStatus,
    String firstAttemptId = '',
    String secondAttemptId = '',
  }) {
    return {
      'id': 'session-interview',
      'status': 'in_progress',
      'mock_test_id': 'mt-placement',
      'overall_score': 0,
      'passed': false,
      'pass_threshold_percent': 60,
      'overall_readiness_level': '',
      'overall_summary': '',
      'sections': [
        {
          'sequence_no': 1,
          'skill_kind': 'interview',
          'exercise_id': 'ex-interview',
          'exercise_type': 'interview_conversation',
          'max_points': 5,
          'attempt_id': firstAttemptId,
          'section_score': 0,
          'status': firstStatus,
          'display_order': 1,
        },
        {
          'sequence_no': 2,
          'skill_kind': 'doc',
          'exercise_id': 'ex-next',
          'exercise_type': 'cteni_6',
          'max_points': 5,
          'attempt_id': secondAttemptId,
          'section_score': 0,
          'status': secondStatus,
          'display_order': 2,
        },
      ],
    };
  }
}

class _TimerApiClient extends ApiClient {
  _TimerApiClient() : super(baseUrl: 'http://fake');

  int expireCalls = 0;
  int completeCalls = 0;

  @override
  Future<Map<String, dynamic>> expireMockExam(String id) async {
    expireCalls += 1;
    return _completedSessionJson(overallScore: 0, passed: false);
  }

  @override
  Future<Map<String, dynamic>> completeMockExam(String id) async {
    completeCalls += 1;
    return _completedSessionJson(overallScore: 0, passed: false);
  }

  static Map<String, dynamic> _completedSessionJson({
    required int overallScore,
    required bool passed,
  }) {
    final now = DateTime.now().toUtc();
    return {
      'id': 'session-expired',
      'status': 'completed',
      'mock_test_id': 'mt-1',
      'overall_score': overallScore,
      'passed': passed,
      'pass_threshold_percent': 60,
      'overall_readiness_level': '',
      'overall_summary': '',
      'started_at': now.subtract(const Duration(seconds: 1)).toIso8601String(),
      'duration_sec': 1,
      'expires_at': now.subtract(const Duration(seconds: 1)).toIso8601String(),
      'sections': [
        {
          'sequence_no': 1,
          'skill_kind': 'doc',
          'exercise_id': 'ex-1',
          'exercise_type': 'cteni_1',
          'max_points': 5,
          'attempt_id': '',
          'section_score': 0,
          'status': 'skipped',
          'display_order': 1,
        },
      ],
    };
  }
}

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
          autoStartFirstSection: false,
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

  // V39 — Skip button per section tile.
  testWidgets('MockExamScreen shows "Bỏ qua" per pending section tile', (
    tester,
  ) async {
    final session = MockExamSessionView(
      id: 'session-1',
      status: 'in_progress',
      mockTestId: 'mt-1',
      overallScore: 0,
      passed: false,
      passThresholdPercent: 60,
      overallReadinessLevel: '',
      overallSummary: '',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'doc',
          exerciseId: 'ex-1',
          exerciseType: 'cteni_1',
          maxPoints: 5,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
          displayOrder: 1,
        ),
        MockExamSection(
          sequenceNo: 2,
          skillKind: 'noi',
          exerciseId: 'ex-2',
          exerciseType: 'uloha_1_topic_answers',
          maxPoints: 8,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
          displayOrder: 2,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: ApiClient(),
          initialSession: session,
          autoStartFirstSection: false,
        ),
      ),
    );

    // Two pending sections → two "Bỏ qua" buttons.
    expect(find.text('Bỏ qua'), findsNWidgets(2));
  });

  testWidgets('MockExamScreen can show a prominent submit action', (
    tester,
  ) async {
    final session = MockExamSessionView(
      id: 'session-1',
      status: 'in_progress',
      mockTestId: 'mt-1',
      overallScore: 0,
      passed: false,
      passThresholdPercent: 60,
      overallReadinessLevel: '',
      overallSummary: '',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'doc',
          exerciseId: 'ex-1',
          exerciseType: 'cteni_1',
          maxPoints: 5,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
          displayOrder: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: ApiClient(),
          initialSession: session,
          autoStartFirstSection: false,
          showProminentSubmitAction: true,
        ),
      ),
    );

    expect(find.byKey(const Key('mock_exam_prominent_submit')), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('mock_exam_prominent_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Nộp bài ngay?'), findsOneWidget);
    expect(
      find.text('Còn 1/1 câu chưa làm. Các câu đó sẽ tính 0 điểm.'),
      findsOneWidget,
    );
  });

  // V39 — top-right grid icon opens the read-only Answer Sheet.
  testWidgets('MockExamScreen AppBar action pushes the Answer Sheet route', (
    tester,
  ) async {
    final session = MockExamSessionView(
      id: 'session-1',
      status: 'in_progress',
      mockTestId: 'mt-1',
      overallScore: 0,
      passed: false,
      passThresholdPercent: 60,
      overallReadinessLevel: '',
      overallSummary: '',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'doc',
          exerciseId: 'ex-1',
          exerciseType: 'cteni_1',
          maxPoints: 5,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
          displayOrder: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: ApiClient(),
          initialSession: session,
          autoStartFirstSection: false,
        ),
      ),
    );

    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách câu'), findsOneWidget);
    expect(find.text('0/1 đã làm · 0 bỏ qua · 1 chưa'), findsOneWidget);
  });

  // V39 — AppBar shows server-anchored countdown when the session carries
  // a timer (duration_sec > 0 + expires_at set).
  testWidgets('MockExamScreen AppBar renders timer when session.hasTimer', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final session = MockExamSessionView(
      id: 'session-1',
      status: 'in_progress',
      mockTestId: 'mt-1',
      overallScore: 0,
      passed: false,
      passThresholdPercent: 60,
      overallReadinessLevel: '',
      overallSummary: '',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'doc',
          exerciseId: 'ex-1',
          exerciseType: 'cteni_1',
          maxPoints: 5,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
          displayOrder: 1,
        ),
      ],
      startedAt: now,
      durationSec: 5400,
      expiresAt: now.add(const Duration(seconds: 5400)),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: ApiClient(),
          initialSession: session,
          autoStartFirstSection: false,
        ),
      ),
    );
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    // Timer text should match MM:SS pattern; the exact value depends on
    // elapsed wall-clock between pumpWidget and assertion, but the
    // 89-90 minute range is safe given a 5400-second window.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data?.startsWith('89:') == true ||
                w.data?.startsWith('90:') == true),
      ),
      findsOneWidget,
    );
  });

  testWidgets('MockExamScreen AppBar omits timer for pre-V39 sessions', (
    tester,
  ) async {
    final session = MockExamSessionView(
      id: 'session-1',
      status: 'in_progress',
      mockTestId: 'mt-1',
      overallScore: 0,
      passed: false,
      passThresholdPercent: 60,
      overallReadinessLevel: '',
      overallSummary: '',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'doc',
          exerciseId: 'ex-1',
          exerciseType: 'cteni_1',
          maxPoints: 5,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
          displayOrder: 1,
        ),
      ],
      // durationSec=0, no expiresAt → no timer
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: ApiClient(),
          initialSession: session,
          autoStartFirstSection: false,
        ),
      ),
    );
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('MockExamScreen auto-submits when the server timer expires', (
    tester,
  ) async {
    final api = _TimerApiClient();
    final now = DateTime.now().toUtc();
    final session = MockExamSessionView(
      id: 'session-expired',
      status: 'in_progress',
      mockTestId: 'mt-1',
      overallScore: 0,
      passed: false,
      passThresholdPercent: 60,
      overallReadinessLevel: '',
      overallSummary: '',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'doc',
          exerciseId: 'ex-1',
          exerciseType: 'cteni_1',
          maxPoints: 5,
          attemptId: '',
          sectionScore: 0,
          status: 'pending',
          displayOrder: 1,
        ),
      ],
      startedAt: now.subtract(const Duration(seconds: 1)),
      durationSec: 1,
      expiresAt: now.subtract(const Duration(seconds: 1)),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: api,
          initialSession: session,
          autoStartFirstSection: false,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    expect(api.expireCalls, 1);
    expect(api.completeCalls, 1);
    expect(find.text('Nhận xét theo kỹ năng'), findsOneWidget);
    expect(find.text('Từng bài trong đề'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'MockExamScreen hides "Bỏ qua" for already-skipped or completed sections',
    (tester) async {
      final session = MockExamSessionView(
        id: 'session-1',
        status: 'in_progress',
        mockTestId: 'mt-1',
        overallScore: 0,
        passed: false,
        passThresholdPercent: 60,
        overallReadinessLevel: '',
        overallSummary: '',
        sections: const [
          MockExamSection(
            sequenceNo: 1,
            skillKind: 'doc',
            exerciseId: 'ex-1',
            exerciseType: 'cteni_1',
            maxPoints: 5,
            attemptId: '',
            sectionScore: 0,
            status: 'skipped',
            displayOrder: 1,
          ),
          MockExamSection(
            sequenceNo: 2,
            skillKind: 'noi',
            exerciseId: 'ex-2',
            exerciseType: 'uloha_1_topic_answers',
            maxPoints: 8,
            attemptId: 'a-2',
            sectionScore: 8,
            status: 'completed',
            displayOrder: 2,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MockExamScreen(
            client: ApiClient(),
            initialSession: session,
            autoStartFirstSection: false,
          ),
        ),
      );

      // Neither section is pending → no Bỏ qua buttons.
      expect(find.text('Bỏ qua'), findsNothing);
      // Skipped section's main button text mirrors its status.
      expect(find.text('Đã bỏ qua'), findsWidgets);
    },
  );

  testWidgets('MockExamScreen starts at first question and chains to next', (
    tester,
  ) async {
    final api = _FlowApiClient();
    final session = MockExamSessionView.fromJson(
      _FlowApiClient._sessionJson(
        firstStatus: 'pending',
        secondStatus: 'pending',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(client: api, initialSession: session),
      ),
    );

    await tester.pumpAndSettle();
    expect(api.getExerciseCalls, ['ex-1']);
    expect(api.mockExamSessionIds, ['session-1']);
    expect(find.text('First statement'), findsOneWidget);

    await tester.tap(find.text('ANO'));
    await tester.pump();
    await tester.tap(find.text('Submit answers'));
    await tester.pumpAndSettle();

    expect(api.getExerciseCalls, ['ex-1', 'ex-2']);
    expect(api.mockExamSessionIds, ['session-1', 'session-1']);
    expect(find.text('Second statement'), findsOneWidget);
  });

  testWidgets(
    'MockExamScreen waits for interview advance before chaining to next',
    (tester) async {
      final api = _InterviewFlowApiClient();
      final session = MockExamSessionView.fromJson(
        _InterviewFlowApiClient._sessionJson(
          firstStatus: 'pending',
          secondStatus: 'pending',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MockExamScreen(client: api, initialSession: session),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.getExerciseCalls, ['ex-interview']);
      expect(find.text('Kết thúc'), findsOneWidget);

      await tester.tap(find.text('Kết thúc'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(api.submitInterviewCalls, 1);
      expect(api.getExerciseCalls, ['ex-interview']);

      api.advanceCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(api.getExerciseCalls, ['ex-interview', 'ex-next']);
      expect(find.text('Next statement'), findsOneWidget);
    },
  );

  testWidgets('MockExamScreen shows skill feedback and custom result CTA', (
    tester,
  ) async {
    var ctaTaps = 0;
    final session = MockExamSessionView(
      id: 'session-done',
      status: 'completed',
      mockTestId: 'mt-1',
      overallScore: 9,
      passed: true,
      passThresholdPercent: 60,
      overallReadinessLevel: '',
      overallSummary: 'Bạn đã hoàn thành bài phân loại.',
      sections: const [
        MockExamSection(
          sequenceNo: 1,
          skillKind: 'doc',
          exerciseId: 'ex-1',
          exerciseType: 'cteni_1',
          maxPoints: 5,
          attemptId: 'attempt-1',
          sectionScore: 5,
          status: 'completed',
          displayOrder: 1,
        ),
        MockExamSection(
          sequenceNo: 2,
          skillKind: 'nghe',
          exerciseId: 'ex-2',
          exerciseType: 'poslech_2',
          maxPoints: 5,
          attemptId: 'attempt-2',
          sectionScore: 4,
          status: 'completed',
          displayOrder: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockExamScreen(
          client: ApiClient(),
          initialSession: session,
          resultCtaLabel: 'Bắt đầu học',
          onResultCta: () => ctaTaps += 1,
          autoStartFirstSection: false,
        ),
      ),
    );

    expect(find.text('Nhận xét theo kỹ năng'), findsOneWidget);
    expect(find.text('Từng bài trong đề'), findsOneWidget);
    expect(
      find.text(
        'Chạm vào một bài để xem đáp án, transcript và nhận xét chi tiết.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Bắt đầu học'), 300);
    await tester.tap(find.text('Bắt đầu học'));
    await tester.pump();

    expect(ctaTaps, 1);
  });
}
