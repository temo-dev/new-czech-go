import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/interview/screens/interview_session_screen.dart';
import 'package:flutter_app/features/interview/widgets/session_status_pill.dart';
import 'package:flutter_app/features/interview/widgets/mic_waveform_widget.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

Widget _wrapHome(Widget child) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

class _FakeInterviewApiClient extends ApiClient {
  int submitCallCount = 0;
  List<Map<String, dynamic>>? submittedTurns;
  int? submittedDurationSec;
  final submitCompleter = Completer<Map<String, dynamic>>();

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
    submitCallCount++;
    submittedTurns = turns;
    submittedDurationSec = durationSec;
    return submitCompleter.future;
  }
}

const _interviewDetail = ExerciseDetail(
  id: 'exercise-1',
  title: 'Interview',
  exerciseType: 'interview_conversation',
  learnerInstruction: '',
  assets: [],
  questions: [],
  scenarioTitle: '',
  scenarioPrompt: '',
  requiredInfoSlots: [],
  customQuestionHint: '',
  storyTitle: '',
  imageAssetIds: [],
  narrativeCheckpoints: [],
  grammarFocus: [],
  choiceScenarioPrompt: '',
  choiceOptions: [],
  expectedReasoningAxes: [],
);

void main() {
  group('SessionStatusPill', () {
    testWidgets('connecting state shows amber dot and connecting text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SessionStatusPill(state: InterviewSessionState.connecting)),
      );
      expect(find.byType(SessionStatusPill), findsOneWidget);
      // "Đang kết nối" should appear in text
      expect(find.textContaining('kết nối'), findsOneWidget);
    });

    testWidgets('speaking state shows orange dot and speaking text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SessionStatusPill(state: InterviewSessionState.speaking)),
      );
      expect(find.textContaining('đang nói'), findsOneWidget);
    });

    testWidgets('listening state shows green dot and listening text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SessionStatusPill(state: InterviewSessionState.listening)),
      );
      expect(find.textContaining('lắng nghe'), findsOneWidget);
    });

    testWidgets('ready state shows ready text', (tester) async {
      await tester.pumpWidget(
        _wrap(const SessionStatusPill(state: InterviewSessionState.ready)),
      );
      expect(find.textContaining('ẵn sàng'), findsOneWidget);
    });
  });

  group('MicWaveformWidget', () {
    testWidgets('renders without crash in active state', (tester) async {
      await tester.pumpWidget(_wrap(const MicWaveformWidget(isActive: true)));
      expect(find.byType(MicWaveformWidget), findsOneWidget);
    });

    testWidgets('renders without crash in idle state', (tester) async {
      await tester.pumpWidget(_wrap(const MicWaveformWidget(isActive: false)));
      expect(find.byType(MicWaveformWidget), findsOneWidget);
    });
  });

  group('InterviewSessionScreen', () {
    test('uses one examiner audio source when Simli is ready', () {
      expect(
        shouldPlayInterviewAudioLocally(
          useSimliAudio: true,
          simliVideoReady: true,
        ),
        isFalse,
      );
      expect(
        shouldPlayInterviewAudioLocally(
          useSimliAudio: true,
          simliVideoReady: false,
        ),
        isTrue,
      );
      expect(
        shouldPlayInterviewAudioLocally(
          useSimliAudio: false,
          simliVideoReady: true,
        ),
        isTrue,
      );
    });

    testWidgets('end button submits immediately without confirmation dialog', (
      tester,
    ) async {
      final client = _FakeInterviewApiClient();

      await tester.pumpWidget(
        _wrapHome(
          InterviewSessionScreen(
            client: client,
            exerciseId: 'exercise-1',
            attemptId: 'attempt-1',
            detail: _interviewDetail,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Kết thúc'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(client.submitCallCount, 1);
      expect(client.submittedTurns, isEmpty);
      expect(client.submittedDurationSec, isNotNull);

      await tester.pump(const Duration(seconds: 3));
      client.submitCompleter.complete({'id': 'attempt-1', 'status': 'scoring'});
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
