import 'dart:async';
import 'dart:typed_data';

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

    test('Simli avatar is learner opt-in and requires API key', () {
      expect(
        shouldStartSimliAvatar(learnerEnabled: false, apiKeyConfigured: true),
        isFalse,
      );
      expect(
        shouldStartSimliAvatar(learnerEnabled: true, apiKeyConfigured: false),
        isFalse,
      );
      expect(
        shouldStartSimliAvatar(learnerEnabled: true, apiKeyConfigured: true),
        isTrue,
      );
    });

    test('mic start is blocked while waiting for examiner turn', () {
      expect(
        canStartInterviewMic(
          conversationStarted: true,
          ending: false,
          micActive: false,
          micTransitioning: false,
          waitingForAgentAfterUserTurn: true,
          autoEndScheduled: false,
          state: InterviewSessionState.thinking,
        ),
        isFalse,
      );
      expect(
        canStartInterviewMic(
          conversationStarted: true,
          ending: false,
          micActive: false,
          micTransitioning: false,
          waitingForAgentAfterUserTurn: false,
          autoEndScheduled: false,
          state: InterviewSessionState.ready,
        ),
        isTrue,
      );
      expect(
        canStartInterviewMic(
          conversationStarted: true,
          ending: false,
          micActive: false,
          micTransitioning: false,
          waitingForAgentAfterUserTurn: false,
          autoEndScheduled: false,
          state: InterviewSessionState.connecting,
        ),
        isFalse,
      );
      expect(
        canStartInterviewMic(
          conversationStarted: true,
          ending: false,
          micActive: false,
          micTransitioning: false,
          waitingForAgentAfterUserTurn: false,
          autoEndScheduled: true,
          state: InterviewSessionState.ready,
        ),
        isFalse,
      );
    });

    test('mic preroll waits before streaming short taps', () {
      expect(
        shouldReleaseInterviewMicPreroll(
          elapsed: const Duration(milliseconds: 250),
          capturedBytes: 32000,
        ),
        isFalse,
      );
      expect(
        shouldReleaseInterviewMicPreroll(
          elapsed: interviewMicPrerollDuration,
          capturedBytes: interviewMinMicPrerollBytes,
        ),
        isTrue,
      );
    });

    test('auto end waits for learner answer to final examiner turn', () {
      expect(shouldArmInterviewAutoEnd(maxTurns: 3, examinerTurns: 2), isFalse);
      expect(shouldArmInterviewAutoEnd(maxTurns: 3, examinerTurns: 3), isTrue);
      expect(
        shouldFinishInterviewAfterLearnerTurn(
          maxTurns: 3,
          examinerTurns: 3,
          learnerTurns: 2,
          autoEndArmed: true,
        ),
        isFalse,
      );
      expect(
        shouldFinishInterviewAfterLearnerTurn(
          maxTurns: 3,
          examinerTurns: 3,
          learnerTurns: 3,
          autoEndArmed: true,
        ),
        isTrue,
      );
      expect(
        shouldFinishInterviewAfterLearnerTurn(
          maxTurns: 3,
          examinerTurns: 3,
          learnerTurns: 3,
          autoEndArmed: false,
        ),
        isFalse,
      );
    });

    test('VAD trailing silence is sent only for accepted learner turns', () {
      expect(
        shouldSendInterviewVadTrailingSilence(
          micPrerollReleased: true,
          waitForAgent: true,
        ),
        isTrue,
      );
      expect(
        shouldSendInterviewVadTrailingSilence(
          micPrerollReleased: false,
          waitForAgent: true,
        ),
        isFalse,
      );
      expect(
        shouldSendInterviewVadTrailingSilence(
          micPrerollReleased: true,
          waitForAgent: false,
        ),
        isFalse,
      );
    });

    test('local agent audio flush waits until recorder releases the mic', () {
      expect(
        shouldDeferLocalAgentAudioFlush(
          useSimliAudio: false,
          micActive: true,
          micTransitioning: false,
        ),
        isTrue,
      );
      expect(
        shouldDeferLocalAgentAudioFlush(
          useSimliAudio: false,
          micActive: false,
          micTransitioning: true,
        ),
        isTrue,
      );
      expect(
        shouldDeferLocalAgentAudioFlush(
          useSimliAudio: true,
          micActive: true,
          micTransitioning: false,
        ),
        isFalse,
      );
      expect(
        shouldDeferLocalAgentAudioFlush(
          useSimliAudio: false,
          micActive: false,
          micTransitioning: false,
        ),
        isFalse,
      );
    });

    test('VAD trailing silence is paced in realtime-sized chunks', () {
      expect(
        interviewVadSilenceChunkCount(
          totalDuration: interviewVadInitialSilenceDuration,
          chunkDuration: interviewVadSilenceChunkDuration,
        ),
        12,
      );
      expect(
        interviewVadSilenceChunkCount(
          totalDuration: const Duration(milliseconds: 250),
          chunkDuration: interviewVadSilenceChunkDuration,
        ),
        4,
      );
      expect(
        interviewVadSilenceChunkCount(
          totalDuration: Duration.zero,
          chunkDuration: interviewVadSilenceChunkDuration,
        ),
        0,
      );
    });

    test('PCM16 mic peak helper reads little-endian signed samples', () {
      final pcm = Uint8List.fromList([
        0x00, 0x00, // 0
        0x10, 0x00, // +16
        0x00, 0x80, // -32768
        0xff, 0x7f, // +32767
      ]);

      expect(interviewPcm16PeakAbs(pcm), 32768);
      expect(interviewPcm16PeakAbs(Uint8List.fromList([0, 0, 1])), 0);
    });

    test('outbound mic gain boosts PCM16 chunks with clipping', () {
      final pcm = Uint8List(8);
      final input = ByteData.sublistView(pcm);
      input.setInt16(0, 1000, Endian.little);
      input.setInt16(2, -1000, Endian.little);
      input.setInt16(4, 20000, Endian.little);
      input.setInt16(6, -20000, Endian.little);

      final boosted = applyInterviewPcm16Gain(pcm, 2.4);
      final output = ByteData.sublistView(boosted);

      expect(output.getInt16(0, Endian.little), 2400);
      expect(output.getInt16(2, Endian.little), -2400);
      expect(output.getInt16(4, Endian.little), 32767);
      expect(output.getInt16(6, Endian.little), -32768);
      expect(interviewPcm16PeakAbs(boosted), 32768);
      expect(normalizeInterviewMicSendGain(9), 3.0);
      expect(normalizeInterviewMicSendGain(double.nan), 1.0);
    });

    test('turn latency helper clamps negative clock drift', () {
      final startedAt = DateTime(2026, 5, 4, 14, 0, 0);
      expect(
        interviewTurnLatencyMs(
          startedAt: startedAt,
          now: startedAt.add(const Duration(milliseconds: 1234)),
        ),
        1234,
      );
      expect(interviewTurnLatencyMs(startedAt: null, now: startedAt), isNull);
      expect(
        interviewTurnLatencyMs(
          startedAt: startedAt,
          now: startedAt.subtract(const Duration(milliseconds: 50)),
        ),
        0,
      );
    });

    test(
      'prompt card body prefers learner-facing question over display prompt',
      () {
        const choiceDetail = ExerciseDetail(
          id: 'exercise-choice',
          title: 'Interview choice',
          exerciseType: 'interview_choice_explain',
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
          interviewQuestion: 'Bạn muốn đi du lịch ở đâu?',
          interviewDisplayPrompt: 'You are Jana. Ask follow-up questions.',
        );

        expect(
          interviewPromptBodyForLearner(choiceDetail),
          'Bạn muốn đi du lịch ở đâu?',
        );
      },
    );

    test('prompt card body falls back to topic then display prompt', () {
      const conversationDetail = ExerciseDetail(
        id: 'exercise-conversation',
        title: 'Interview conversation',
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
        interviewTopic: 'Gia đình và bạn bè',
        interviewDisplayPrompt: 'You are Jana. Ask about family.',
      );
      const legacyDetail = ExerciseDetail(
        id: 'exercise-legacy',
        title: 'Interview legacy',
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
        interviewDisplayPrompt: 'Mô tả công việc bạn muốn làm.',
      );

      expect(
        interviewPromptBodyForLearner(conversationDetail),
        'Gia đình và bạn bè',
      );
      expect(
        interviewPromptBodyForLearner(legacyDetail),
        'Mô tả công việc bạn muốn làm.',
      );
    });

    test(
      'prompt card tips trim blanks and keep at most five learner hints',
      () {
        const detail = ExerciseDetail(
          id: 'exercise-tips',
          title: 'Interview tips',
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
          interviewTips: [
            ' Velikosti bot ',
            '',
            'barva',
            'cena',
            'vlastní otázka',
            'materiál',
            'extra',
          ],
        );

        expect(interviewPromptTipsForLearner(detail), [
          'Velikosti bot',
          'barva',
          'cena',
          'vlastní otázka',
          'materiál',
        ]);
      },
    );

    test('prompt card tips prefer the selected choice option', () {
      final detail = ExerciseDetail.fromJson({
        'id': 'exercise-choice-tips',
        'title': 'Obchod',
        'exercise_type': 'interview_choice_explain',
        'learner_instruction': '',
        'detail': {
          'question': 'Jaké boty chcete?',
          'tips': ['global tip'],
          'system_prompt': 'You are Jana. The learner chose {selected_option}.',
          'max_turns': 6,
          'options': [
            {
              'id': '1',
              'label': 'Bílé boty',
              'tips': [' velikost ', '', 'barva'],
            },
            {
              'id': '2',
              'label': 'Černé boty',
              'tips': ['cena'],
            },
            {'id': '3', 'label': 'Modré boty'},
          ],
        },
      });

      expect(interviewPromptTipsForLearner(detail), ['global tip']);
      expect(
        interviewPromptTipsForLearner(detail, selectedOption: 'Bílé boty'),
        ['velikost', 'barva'],
      );
      expect(interviewPromptTipsForLearner(detail, selectedOption: '2'), [
        'cena',
      ]);
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

    testWidgets('compact interview layout keeps controls visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const compactDetail = ExerciseDetail(
        id: 'exercise-compact',
        title: 'Interview compact',
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
        interviewTopic: 'Obchod',
        interviewTips: [
          'Jste v obchodě s obuví. Potřebujete boty na sport.',
          'Velikosti bot',
          'barva',
          'cena',
          'vlastní otázka',
        ],
        interviewShowTranscript: true,
      );

      await tester.pumpWidget(
        _wrapHome(
          InterviewSessionScreen(
            client: _FakeInterviewApiClient(),
            exerciseId: 'exercise-compact',
            attemptId: 'attempt-compact',
            detail: compactDetail,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Kết thúc'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
