import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../core/api/api_client.dart';
import '../../../core/interview/interview_preference_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../services/elevenlabs_ws_client.dart';
import '../services/pcm_audio_player.dart';
import '../services/simli_config.dart';
import '../services/simli_session_manager.dart';
import '../widgets/avatar_video_container.dart';
import '../widgets/prompt_card.dart';
import '../widgets/session_status_pill.dart';
import 'interview_result_screen.dart';

/// V16: gate routing of agent audio chunks. When Simli is enabled but the
/// avatar's video track has not yet rendered its first frame, the WebRTC
/// audio track is not yet attached and chunks sent to Simli are silently
/// dropped. The gate now waits for [simliVideoReady] (first frame rendered)
/// rather than [SimliSessionManager.isConnected] (WS handshake) which fires
/// hundreds of milliseconds earlier.
bool shouldPlayInterviewAudioLocally({
  required bool useSimliAudio,
  required bool simliVideoReady,
}) {
  return !(useSimliAudio && simliVideoReady);
}

@visibleForTesting
bool shouldStartSimliAvatar({
  required bool learnerEnabled,
  required bool apiKeyConfigured,
}) {
  return learnerEnabled && apiKeyConfigured;
}

@visibleForTesting
const Duration interviewMicPrerollDuration = Duration(milliseconds: 550);

@visibleForTesting
const Duration interviewAgentWaitTimeout = Duration(seconds: 12);

@visibleForTesting
const Duration interviewAutoEndDelay = Duration(milliseconds: 900);

@visibleForTesting
const Duration interviewVadInitialSilenceDuration = Duration(milliseconds: 900);

@visibleForTesting
const Duration interviewVadRecoverySilenceDuration = Duration(
  milliseconds: 1300,
);

@visibleForTesting
const Duration interviewVadRecoveryDelay = Duration(milliseconds: 2500);

@visibleForTesting
const Duration interviewVadSilenceChunkDuration = Duration(milliseconds: 80);

@visibleForTesting
const int interviewMinMicPrerollBytes = 1600;

@visibleForTesting
const double interviewSoundWaveMicSendGain = 2.4;

@visibleForTesting
bool canStartInterviewMic({
  required bool conversationStarted,
  required bool ending,
  required bool micActive,
  required bool micTransitioning,
  required bool waitingForAgentAfterUserTurn,
  required bool autoEndScheduled,
  required InterviewSessionState state,
}) {
  return conversationStarted &&
      !ending &&
      !micActive &&
      !micTransitioning &&
      !waitingForAgentAfterUserTurn &&
      !autoEndScheduled &&
      state == InterviewSessionState.ready;
}

@visibleForTesting
bool shouldReleaseInterviewMicPreroll({
  required Duration elapsed,
  required int capturedBytes,
}) {
  return elapsed >= interviewMicPrerollDuration &&
      capturedBytes >= interviewMinMicPrerollBytes;
}

@visibleForTesting
bool shouldArmInterviewAutoEnd({
  required int maxTurns,
  required int examinerTurns,
}) {
  return maxTurns > 0 && examinerTurns >= maxTurns;
}

@visibleForTesting
bool shouldFinishInterviewAfterLearnerTurn({
  required int maxTurns,
  required int examinerTurns,
  required int learnerTurns,
  required bool autoEndArmed,
}) {
  return autoEndArmed &&
      maxTurns > 0 &&
      examinerTurns >= maxTurns &&
      learnerTurns >= examinerTurns;
}

@visibleForTesting
bool shouldSendInterviewVadTrailingSilence({
  required bool micPrerollReleased,
  required bool waitForAgent,
}) {
  return micPrerollReleased && waitForAgent;
}

@visibleForTesting
bool shouldDeferLocalAgentAudioFlush({
  required bool useSimliAudio,
  required bool micActive,
  required bool micTransitioning,
}) {
  return !useSimliAudio && (micActive || micTransitioning);
}

@visibleForTesting
int interviewVadSilenceChunkCount({
  required Duration totalDuration,
  required Duration chunkDuration,
}) {
  if (totalDuration <= Duration.zero || chunkDuration <= Duration.zero) {
    return 0;
  }
  return (totalDuration.inMicroseconds / chunkDuration.inMicroseconds).ceil();
}

@visibleForTesting
int interviewPcm16PeakAbs(Uint8List pcm16) {
  var peak = 0;
  for (var i = 0; i + 1 < pcm16.length; i += 2) {
    var sample = pcm16[i] | (pcm16[i + 1] << 8);
    if (sample >= 0x8000) sample -= 0x10000;
    final abs = sample < 0 ? -sample : sample;
    if (abs > peak) peak = abs;
  }
  return peak;
}

@visibleForTesting
double normalizeInterviewMicSendGain(double gain) {
  if (gain.isNaN || gain.isInfinite) return 1.0;
  return gain.clamp(1.0, 3.0).toDouble();
}

@visibleForTesting
Uint8List applyInterviewPcm16Gain(Uint8List pcm16, double gain) {
  final normalizedGain = normalizeInterviewMicSendGain(gain);
  if (pcm16.isEmpty || normalizedGain == 1.0) return pcm16;

  final result = Uint8List.fromList(pcm16);
  final view = ByteData.sublistView(result);
  for (var offset = 0; offset + 1 < result.length; offset += 2) {
    final sample = view.getInt16(offset, Endian.little);
    final adjusted =
        (sample * normalizedGain).round().clamp(-32768, 32767).toInt();
    view.setInt16(offset, adjusted, Endian.little);
  }
  return result;
}

@visibleForTesting
int? interviewTurnLatencyMs({
  required DateTime? startedAt,
  required DateTime now,
}) {
  if (startedAt == null) return null;
  final latency = now.difference(startedAt).inMilliseconds;
  return latency < 0 ? 0 : latency;
}

@visibleForTesting
String interviewPromptBodyForLearner(ExerciseDetail detail) {
  final question = detail.interviewQuestion.trim();
  if (question.isNotEmpty) return question;

  final topic = detail.interviewTopic.trim();
  if (topic.isNotEmpty) return topic;

  return detail.interviewDisplayPrompt.trim();
}

InterviewOptionView? interviewSelectedOptionForLearner(
  ExerciseDetail detail,
  String? selectedOption,
) {
  final selected = selectedOption?.trim();
  if (selected == null || selected.isEmpty) return null;
  for (final option in detail.interviewOptions) {
    if (option.id.trim() == selected || option.label.trim() == selected) {
      return option;
    }
  }
  return null;
}

List<String> interviewPromptTipsForLearner(
  ExerciseDetail detail, {
  String? selectedOption,
}) {
  final option = interviewSelectedOptionForLearner(detail, selectedOption);
  final tips =
      option != null && option.tips.isNotEmpty
          ? option.tips
          : detail.interviewTips;
  return tips
      .map((tip) => tip.trim())
      .where((tip) => tip.isNotEmpty)
      .take(5)
      .toList();
}

class InterviewSessionScreen extends StatefulWidget {
  const InterviewSessionScreen({
    super.key,
    required this.client,
    required this.exerciseId,
    required this.attemptId,
    required this.detail,
    this.selectedOption,
  });

  final ApiClient client;
  final String exerciseId;
  final String attemptId;
  final ExerciseDetail detail;
  final String? selectedOption;

  @override
  State<InterviewSessionScreen> createState() => _InterviewSessionScreenState();
}

class _InterviewSessionScreenState extends State<InterviewSessionScreen> {
  InterviewSessionState _state = InterviewSessionState.connecting;
  final List<InterviewTranscriptTurn> _turns = [];
  String? _lastTranscriptText;
  bool _lastSpeakerIsExaminer = true;
  int _sessionStartSec = 0;
  bool _ending = false;
  bool _disposing = false;

  final _wsClient = ElevenLabsWsClient();
  final _audioPlayer = PcmAudioPlayer();
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  Timer? _sessionTimer;
  Timer? _agentAudioFlushTimer;

  // Sprint 2: Simli avatar. Only active when SIMLI_API_KEY is configured.
  SimliSessionManager? _simli;
  bool _simliConnected = false;
  bool _useSimliAudio = false;

  // V16: buffer agent audio chunks while Simli has connected its WS but the
  // first video frame (and therefore the WebRTC audio track) has not yet
  // attached. Flush as soon as `onVideoReady` fires; fall back to local
  // playback if the timeout expires first.
  final List<Uint8List> _pendingAgentChunks = [];
  Timer? _audioBufferTimeoutTimer;
  bool _videoReadyFired = false;

  // V16: prompt card key — used to trigger pulse on agent response complete.
  final GlobalKey<InterviewPromptCardState> _promptCardKey = GlobalKey();

  // V16 diagnostics: per-turn audio chunk counters. Reset on every
  // agent_response_complete so each turn logs how many chunks went where.
  int _turnChunksToSimli = 0;
  int _turnChunksToLocal = 0;
  int _turnChunksBuffered = 0;
  int _turnIndex = 0;

  // V16: progress through the 4 setup steps surfaced in the preparing overlay.
  // 0=initial, 1=session+token, 2=avatar ready, 3=examiner ready,
  // 4=first audio (overlay fades out).
  int _prepareStep = 0;
  bool _firstAgentChunkSeen = false;

  // V16 first-turn gate: defer mic + timer until the examiner finishes
  // greeting. Otherwise the mic captures pre-roll noise/silence and
  // ElevenLabs VAD registers an empty learner turn — the examiner then
  // apologises for a missing self-introduction.
  bool _conversationStarted = false;
  Timer? _firstTurnSafetyTimer;

  // V16 push-to-talk: mic is OFF until the learner taps the mic button.
  bool _micActive = false;
  bool _micTransitioning = false;
  bool _waitingForAgentAfterUserTurn = false;
  bool _micPrerollReleased = false;
  DateTime? _micStartedAt;
  int _micBytesCaptured = 0;
  int _micChunkCount = 0;
  int _micPeakAbs = 0;
  int _micSendPeakAbs = 0;
  int _examinerTurnCount = 0;
  int _learnerTurnCount = 0;
  bool _autoEndArmed = false;
  bool _autoEndScheduled = false;
  final List<Uint8List> _pendingMicChunks = [];
  Timer? _micPrerollTimer;
  Timer? _agentWaitTimer;
  Timer? _autoEndTimer;
  Timer? _vadSilenceTimer;
  Timer? _vadRecoveryTimer;
  DateTime? _lastUserTurnStoppedAt;
  int _userTurnLatencyIndex = 0;
  bool _loggedLearnerTranscriptLatency = false;
  bool _loggedExaminerTranscriptLatency = false;
  bool _loggedAgentAudioLatency = false;
  bool _loggedSimliSpeakLatency = false;
  bool _loggedAgentCompleteLatency = false;
  bool _userTurnVadScoreSeen = false;
  double _userTurnVadScoreMax = 0;

  // V16: agent silence detector. ElevenLabs occasionally fails to fire
  // agent_response_complete, leaving _state stuck on speaking and the PTT
  // mic button disabled. We treat 1500ms of no audio chunks as "agent
  // finished" and flip state to ready locally.
  Timer? _agentSilenceTimer;

  @override
  void initState() {
    super.initState();
    // _sessionStartSec is set on the first agent response complete so the
    // timer reflects conversation duration, not setup time.
    _startSession();
  }

  @override
  void dispose() {
    _disposing = true;
    _micSub?.cancel();
    _sessionTimer?.cancel();
    _agentAudioFlushTimer?.cancel();
    _audioBufferTimeoutTimer?.cancel();
    _firstTurnSafetyTimer?.cancel();
    _agentSilenceTimer?.cancel();
    _micPrerollTimer?.cancel();
    _agentWaitTimer?.cancel();
    _autoEndTimer?.cancel();
    _vadSilenceTimer?.cancel();
    _vadRecoveryTimer?.cancel();
    _pendingAgentChunks.clear();
    _pendingMicChunks.clear();
    _wsClient.disconnect();
    _audioPlayer.dispose();
    _recorder.dispose();
    _useSimliAudio = false;
    final simli = _simli;
    _simli = null;
    _disposeSimliAfterFrame(simli);
    super.dispose();
  }

  Future<void> _startSession() async {
    try {
      // 1. Get signed URL
      final tokenData = await widget.client.getInterviewToken(
        exerciseId: widget.exerciseId,
        attemptId: widget.attemptId,
        selectedOption: widget.selectedOption,
      );
      final signedUrl = tokenData['signed_url'] as String? ?? '';
      final systemPrompt = tokenData['system_prompt'] as String? ?? '';
      final voiceId = tokenData['voice_id'] as String? ?? '';
      if (signedUrl.isEmpty || !mounted) return;

      _advancePrepareStep(1);

      // 2. Simli is learner opt-in. The default sound-wave mode starts much
      // faster because it plays ElevenLabs audio directly instead of waiting
      // for avatar playback.
      final avatarEnabled =
          await InterviewPreferenceService.readAvatarEnabled();
      final localAudioVolume =
          await InterviewPreferenceService.readLocalAudioVolume();
      if (!mounted || _disposing) return;
      _audioPlayer.setVolumeGain(localAudioVolume);
      debugPrint(
        'Interview local audio gain=${localAudioVolume.toStringAsFixed(2)}',
      );
      final startSimli = shouldStartSimliAvatar(
        learnerEnabled: avatarEnabled,
        apiKeyConfigured: SimliConfig.apiKey.isNotEmpty,
      );
      if (startSimli) {
        await _configureDuplexAudioSession();
        _useSimliAudio = await _startSimliIfAvailable();
      } else {
        await _configureExaminerPlaybackAudioSession();
        debugPrint(
          avatarEnabled
              ? 'Simli disabled: SIMLI_API_KEY is empty'
              : 'Simli disabled by learner preference; using sound wave mode',
        );
        _useSimliAudio = false;
      }
      if (!mounted || _disposing) return;
      // If Simli is disabled, the avatar step is implicitly satisfied so the
      // overlay still moves forward.
      if (!_useSimliAudio) _advancePrepareStep(2);

      // 3. Wire WS callbacks
      _wsClient.onReady = () {
        if (!mounted) return;
        // Mic + timer start are deferred to the end of the examiner's first
        // turn (see _startConversation). onReady just flips visual state.
        setState(() => _state = InterviewSessionState.ready);
      };
      _wsClient.onMetadata = ({
        String? agentOutputAudioFormat,
        String? userInputAudioFormat,
      }) {
        debugPrint(
          'Interview WS metadata agentOutputFormat=$agentOutputAudioFormat '
          'userInputFormat=$userInputAudioFormat',
        );
        final _ = userInputAudioFormat;
        _audioPlayer.setOutputAudioFormat(agentOutputAudioFormat);
        _simli?.setInputAudioFormat(agentOutputAudioFormat);
        _advancePrepareStep(3);
        // Safety: if the agent never sends audio (e.g. firstMessage override
        // is rejected by Security settings), unblock the mic after 3s so the
        // learner can speak first instead of waiting indefinitely.
        Timer(const Duration(seconds: 3), () {
          if (!mounted || _ending || _conversationStarted) return;
          if (_firstAgentChunkSeen) return;
          debugPrint(
            'Agent silent 3s after metadata — enabling mic so learner can speak first',
          );
          _advancePrepareStep(4);
          _startConversation();
        });
      };
      _wsClient.onAudioChunk = (Uint8List chunk) {
        if (!mounted || _ending) return;
        if (_autoEndScheduled) return;
        if (_waitingForAgentAfterUserTurn && !_loggedAgentAudioLatency) {
          _loggedAgentAudioLatency = true;
          _logUserTurnLatency('first_agent_audio');
          debugPrint(
            'Interview VAD turn=$_userTurnLatencyIndex '
            'event=first_agent_audio max=${_userTurnVadScoreSummary()}',
          );
        }
        _markAgentTurnStarted();
        if (!_firstAgentChunkSeen) {
          _firstAgentChunkSeen = true;
          _advancePrepareStep(4);
          debugPrint('Interview first agent audio chunk received');
          // Safety net: if agent_response_complete never fires (network glitch
          // or short greeting), unblock mic 10s after the first audio chunk.
          _firstTurnSafetyTimer = Timer(
            const Duration(seconds: 10),
            _startConversation,
          );
        }
        setState(() => _state = InterviewSessionState.speaking);
        // Reset agent silence timer on every audio chunk. Only used when
        // Simli is unavailable (Simli's SPEAK/SILENT WS messages are the
        // authoritative signal otherwise). 2500ms accommodates pauses
        // between sentences within the same agent turn.
        if (!_useSimliAudio) {
          _agentSilenceTimer?.cancel();
          _agentSilenceTimer = Timer(
            const Duration(milliseconds: 2500),
            _onAgentSilenceTimeout,
          );
        }

        if (!_useSimliAudio) {
          _audioPlayer.addChunk(chunk);
          _turnChunksToLocal++;
          _scheduleAgentAudioFlush();
          return;
        }

        if (_videoReadyFired) {
          _simli?.sendAudio(chunk);
          _turnChunksToSimli++;
          return;
        }

        // Simli WS is connected but its WebRTC audio track is not yet
        // attached — buffer until onVideoReady fires (or fall back).
        _pendingAgentChunks.add(chunk);
        _turnChunksBuffered++;
        _audioBufferTimeoutTimer ??= Timer(
          Duration(milliseconds: widget.detail.interviewAudioBufferTimeoutMs),
          _fallbackToLocalAudio,
        );
      };
      _wsClient.onInterruption = () {
        debugPrint(
          'Interview interruption — clearing ${_useSimliAudio ? "Simli" : "local"} buffer '
          '(buffered=$_turnChunksBuffered)',
        );
        if (_useSimliAudio) {
          _simli?.clearBuffer();
        } else {
          _audioPlayer.clearBuffer();
        }
        _pendingAgentChunks.clear();
      };
      _wsClient.onTranscript = (speaker, text) {
        if (!mounted || _ending) return;
        // V16: drop empty / placeholder learner turns (e.g. "...", whitespace).
        // ElevenLabs occasionally registers a learner turn from echo/noise
        // with no transcribable content; surfacing these confuses the
        // examiner and clutters the result screen.
        if (speaker == 'learner' && !_isMeaningfulTranscript(text)) {
          debugPrint(
            'Interview dropping empty learner turn: ${text.trim()} '
            'vadMax=${_userTurnVadScoreSummary()}',
          );
          return;
        }
        if (_autoEndScheduled && speaker == 'examiner') {
          return;
        }
        if (speaker == 'learner' && !_loggedLearnerTranscriptLatency) {
          _loggedLearnerTranscriptLatency = true;
          _logUserTurnLatency('learner_transcript');
          debugPrint(
            'Interview VAD turn=$_userTurnLatencyIndex '
            'event=learner_transcript max=${_userTurnVadScoreSummary()}',
          );
        } else if (speaker == 'examiner' && !_loggedExaminerTranscriptLatency) {
          _loggedExaminerTranscriptLatency = true;
          _logUserTurnLatency('examiner_transcript');
        }
        final atSec =
            _conversationStarted
                ? (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
                    _sessionStartSec
                : 0;
        var shouldAutoFinish = false;
        setState(() {
          if (speaker == 'examiner') {
            _markAgentTurnStarted(updateState: false);
            _examinerTurnCount += 1;
            if (shouldArmInterviewAutoEnd(
              maxTurns: widget.detail.interviewMaxTurns,
              examinerTurns: _examinerTurnCount,
            )) {
              _autoEndArmed = true;
              debugPrint(
                'Interview max_turns reached: '
                'max=${widget.detail.interviewMaxTurns} '
                'examinerTurns=$_examinerTurnCount',
              );
            }
          } else if (speaker == 'learner') {
            _learnerTurnCount += 1;
            shouldAutoFinish = shouldFinishInterviewAfterLearnerTurn(
              maxTurns: widget.detail.interviewMaxTurns,
              examinerTurns: _examinerTurnCount,
              learnerTurns: _learnerTurnCount,
              autoEndArmed: _autoEndArmed,
            );
          }
          _turns.add(
            InterviewTranscriptTurn(speaker: speaker, text: text, atSec: atSec),
          );
          _lastTranscriptText = text;
          _lastSpeakerIsExaminer = speaker == 'examiner';
          if (speaker == 'examiner') {
            _state = InterviewSessionState.speaking;
          } else if (_waitingForAgentAfterUserTurn) {
            _state = InterviewSessionState.thinking;
          } else {
            _state = InterviewSessionState.listening;
          }
        });
        if (shouldAutoFinish) _scheduleAutoEndAfterMaxTurns();
      };
      _wsClient.onVadScore = (score) {
        if (!_micActive && !_waitingForAgentAfterUserTurn) return;
        _userTurnVadScoreSeen = true;
        if (score > _userTurnVadScoreMax) {
          _userTurnVadScoreMax = score;
        }
      };
      _wsClient.onAgentResponseComplete = () {
        if (!mounted) return;
        if (!_loggedAgentCompleteLatency) {
          _loggedAgentCompleteLatency = true;
          _logUserTurnLatency('agent_response_complete');
        }
        // V16 diagnostics: log per-turn audio routing summary, then reset.
        _turnIndex++;
        debugPrint(
          'Interview turn=$_turnIndex audio chunks: '
          'simli=$_turnChunksToSimli '
          'local=$_turnChunksToLocal '
          'buffered=$_turnChunksBuffered '
          'useSimliAudio=$_useSimliAudio '
          'videoReady=$_videoReadyFired',
        );
        _turnChunksToSimli = 0;
        _turnChunksToLocal = 0;
        _turnChunksBuffered = 0;

        if (!_useSimliAudio) {
          _scheduleAgentAudioFlush(
            delay: const Duration(milliseconds: 120),
            completeTurnAfterPlayback: true,
          );
          return;
        }
        // V16: when Simli is active, its SPEAK/SILENT WS messages are the
        // authoritative "is the avatar talking" signal. We still keep this
        // callback as a fallback for agent_response_complete.
        _promptCardKey.currentState?.onAgentResponseComplete();
        // Open the mic and start the timer once the examiner finishes their
        // first turn — mic before this point captures noise that ElevenLabs
        // VAD reports as an empty learner turn.
        _startConversation();
      };
      _wsClient.onDisconnected = () {
        if (mounted && !_ending) {
          setState(() => _state = InterviewSessionState.connecting);
        }
      };
      _wsClient.onError = (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).interviewConnectError),
            action: SnackBarAction(label: 'Thử lại', onPressed: _startSession),
          ),
        );
      };

      // 3. Connect — systemPrompt + voiceId + firstMessage sent via conversation_initiation_client_data.
      // firstMessage ensures the agent speaks first without waiting for learner.
      _wsClient.systemPrompt = systemPrompt;
      _wsClient.voiceId = voiceId.isNotEmpty ? voiceId : null;
      _wsClient.firstMessage =
          'Dobrý den! Jsem Jana Nováková, váš zkušební komisař. Jak se jmenujete?';
      await _wsClient.connect(signedUrl);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).interviewConnectError),
        ),
      );
    }
  }

  Future<bool> _startSimliIfAvailable() async {
    if (SimliConfig.apiKey.isEmpty) {
      debugPrint('Simli disabled: SIMLI_API_KEY is empty');
      return false;
    }

    debugPrint('Simli enabled faceId=${SimliConfig.faceId}');
    final simli = SimliSessionManager(
      apiKey: SimliConfig.apiKey,
      faceId: SimliConfig.faceId,
      model: SimliConfig.model,
    );
    _simli = simli;

    simli.onConnection = () {
      debugPrint('Simli connected');
      if (mounted && !_disposing) {
        setState(() => _simliConnected = true);
      }
    };
    simli.onVideoReady = () {
      debugPrint('Simli video ready');
      if (!mounted || _disposing) return;
      _videoReadyFired = true;
      _audioBufferTimeoutTimer?.cancel();
      _audioBufferTimeoutTimer = null;
      _flushPendingChunksToSimli();
      setState(() => _simliConnected = true);
      _advancePrepareStep(2);
    };
    simli.onDisconnected = () {
      debugPrint('Simli disconnected');
      if (mounted && !_disposing) {
        setState(() {
          _simliConnected = false;
          _useSimliAudio = false;
        });
      }
    };
    simli.onSpeakingChanged = (isSpeaking) {
      if (!mounted || _disposing || _ending || !_useSimliAudio) return;
      if (_autoEndScheduled) return;
      if (_waitingForAgentAfterUserTurn && !isSpeaking) {
        return;
      }
      if (isSpeaking) {
        if (!_loggedSimliSpeakLatency) {
          _loggedSimliSpeakLatency = true;
          _logUserTurnLatency('simli_speak');
        }
        _markAgentTurnStarted();
      }
      // Simli SPEAK/SILENT is the most accurate signal for "is the avatar
      // currently producing audio". With PTT, ready = waiting for the
      // learner to tap; listening = mic actively recording. Don't override
      // the visual state while the learner is recording.
      if (_micActive) return;
      // Cancel the local silence detector — Simli's signal is authoritative.
      _agentSilenceTimer?.cancel();
      _agentSilenceTimer = null;
      setState(() {
        _state =
            isSpeaking
                ? InterviewSessionState.speaking
                : InterviewSessionState.ready;
      });
      if (!isSpeaking) {
        // Simli finished playing — treat the same as agent_response_complete:
        // unblock the conversation start path and pulse the prompt card on
        // subsequent turns.
        _startConversation();
        _promptCardKey.currentState?.onAgentResponseComplete();
      }
    };
    simli.onFailed = (err) {
      debugPrint('Simli failed: $err');
      if (mounted && !_disposing) {
        setState(() {
          _simliConnected = false;
          _useSimliAudio = false;
        });
      }
    };

    if (mounted) setState(() {});

    try {
      await simli.start();
      await simli.waitUntilVideoReady();
      if (!mounted || _disposing || !identical(_simli, simli)) return false;
      debugPrint('Simli ready; starting ElevenLabs conversation');
      return true;
    } catch (err, stack) {
      debugPrint(
        'Simli not ready; falling back to ElevenLabs audio only: $err',
      );
      debugPrintStack(stackTrace: stack);
      if (mounted && !_disposing && identical(_simli, simli)) {
        setState(() {
          _simli = null;
          _simliConnected = false;
        });
      }
      _disposeSimliAfterFrame(simli);
      return false;
    }
  }

  Future<void> _configureDuplexAudioSession() async {
    final session = await AudioSession.instance;
    // V16: AVAudioSessionMode.videoChat enables iOS hardware acoustic echo
    // cancellation (AEC) + noise suppression. With spokenAudio (the previous
    // value) the mic picked up the speaker's playback of the examiner voice,
    // ElevenLabs VAD registered a fake learner turn, and the examiner then
    // apologised that it could not understand the learner.
    await session.configure(
      const AudioSessionConfiguration.speech().copyWith(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowBluetoothA2dp,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
      ),
    );
    await session.setActive(true);
  }

  Future<void> _configureMicCaptureAudioSession() async {
    if (_useSimliAudio) {
      await _configureDuplexAudioSession();
      return;
    }
    final session = await AudioSession.instance;
    // Sound-wave mode has no examiner playback while the learner records.
    // Avoid videoChat AEC/noise suppression here: on-device logs showed bytes
    // being sent but ElevenLabs VAD not detecting speech after a PTT turn.
    await session.configure(
      const AudioSessionConfiguration.speech().copyWith(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.measurement,
      ),
    );
    await session.setActive(true);
    debugPrint('Interview mic audio session mode=measurement');
  }

  Future<void> _configureExaminerPlaybackAudioSession() async {
    final session = await AudioSession.instance;
    // Sound-wave mode plays examiner audio locally. After a recording,
    // playAndRecord/videoChat can attenuate output for echo control, so we
    // switch back to playback/spokenAudio before playing each examiner turn.
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);
  }

  void _flushPendingChunksToSimli() {
    if (_pendingAgentChunks.isEmpty) return;
    debugPrint(
      'Flushing ${_pendingAgentChunks.length} buffered chunk(s) to Simli',
    );
    for (final chunk in _pendingAgentChunks) {
      _simli?.sendAudio(chunk);
    }
    _pendingAgentChunks.clear();
  }

  /// V16: Simli failed to attach its audio track within the buffer timeout
  /// — drop into local PCM playback so the learner still hears the agent.
  void _fallbackToLocalAudio() {
    if (!mounted || _videoReadyFired) return;
    debugPrint(
      'Audio buffer timeout — falling back to local audio (${_pendingAgentChunks.length} buffered chunks)',
    );
    setState(() {
      _useSimliAudio = false;
    });
    for (final chunk in _pendingAgentChunks) {
      _audioPlayer.addChunk(chunk);
    }
    _pendingAgentChunks.clear();
    _scheduleAgentAudioFlush();
  }

  void _scheduleAgentAudioFlush({
    Duration delay = const Duration(milliseconds: 450),
    bool completeTurnAfterPlayback = false,
  }) {
    _agentAudioFlushTimer?.cancel();
    _agentAudioFlushTimer = Timer(delay, () async {
      if (!mounted || _ending) return;
      if (shouldDeferLocalAgentAudioFlush(
        useSimliAudio: _useSimliAudio,
        micActive: _micActive,
        micTransitioning: _micTransitioning,
      )) {
        debugPrint('Interview local audio flush deferred while mic is active');
        _scheduleAgentAudioFlush(
          delay: const Duration(milliseconds: 300),
          completeTurnAfterPlayback: completeTurnAfterPlayback,
        );
        return;
      }
      try {
        if (!_useSimliAudio) {
          await _configureExaminerPlaybackAudioSession();
        }
        await _audioPlayer.flushAndPlay();
      } catch (err, stack) {
        debugPrint('Interview local audio flush failed: $err');
        debugPrintStack(stackTrace: stack);
        if (!mounted || _ending) return;
        _scheduleAgentAudioFlush(
          delay: const Duration(milliseconds: 300),
          completeTurnAfterPlayback: completeTurnAfterPlayback,
        );
        return;
      }
      if (!mounted || _ending) return;
      if (_autoEndScheduled) return;
      if (!_useSimliAudio) {
        if (completeTurnAfterPlayback) {
          _completeLocalAgentTurnAfterPlayback();
        }
        return;
      }
      setState(() {
        _state =
            _micActive
                ? InterviewSessionState.listening
                : InterviewSessionState.ready;
      });
    });
  }

  void _completeLocalAgentTurnAfterPlayback() {
    if (!mounted || _ending || _autoEndScheduled || _micActive) return;
    if (_conversationStarted && _state != InterviewSessionState.speaking) {
      return;
    }
    setState(() => _state = InterviewSessionState.ready);
    _startConversation();
    _promptCardKey.currentState?.onAgentResponseComplete();
  }

  /// V16 push-to-talk: tapping the mic button starts streaming PCM chunks
  /// from the recorder to the ElevenLabs WS. Tapping again stops the stream
  /// and lets server VAD finalise the turn (~700ms silence endpointing).
  /// The mic is never on while the examiner speaks, eliminating echo loops.
  Future<void> _toggleMic() async {
    if (!_conversationStarted || _ending || !mounted) return;
    if (_micTransitioning) return;
    if (_micActive) {
      await _stopMicStreaming();
    } else if (canStartInterviewMic(
      conversationStarted: _conversationStarted,
      ending: _ending,
      micActive: _micActive,
      micTransitioning: _micTransitioning,
      waitingForAgentAfterUserTurn: _waitingForAgentAfterUserTurn,
      autoEndScheduled: _autoEndScheduled,
      state: _state,
    )) {
      await _startMicStreaming();
    }
  }

  Future<void> _startMicStreaming() async {
    if (_micActive) return;
    if (mounted) setState(() => _micTransitioning = true);
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        setState(() => _micTransitioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).interviewMicDenied),
          ),
        );
      }
      return;
    }
    try {
      await _configureMicCaptureAudioSession();
      _cancelVadSilenceTimers();
      _pendingMicChunks.clear();
      _micBytesCaptured = 0;
      _micChunkCount = 0;
      _micPeakAbs = 0;
      _micSendPeakAbs = 0;
      _micPrerollReleased = false;
      _userTurnVadScoreSeen = false;
      _userTurnVadScoreMax = 0;
      await _recorder.ios?.manageAudioSession(false);
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          streamBufferSize: 512,
        ),
      );
      _micSub = stream.listen((chunk) {
        if (_ending || !_micActive) return;
        _handleMicChunk(Uint8List.fromList(chunk));
      });
      _micStartedAt = DateTime.now();
      _micPrerollTimer = Timer(
        interviewMicPrerollDuration,
        _releaseMicPrerollIfReady,
      );
      if (!mounted) return;
      debugPrint('Interview PTT: mic ON');
      setState(() {
        _micActive = true;
        _micTransitioning = false;
        _state = InterviewSessionState.listening;
      });
    } catch (err) {
      debugPrint('Interview PTT start failed: $err');
      if (mounted) setState(() => _micTransitioning = false);
    }
  }

  Future<void> _stopMicStreaming({bool waitForAgent = true}) async {
    if (!_micActive) return;
    final startedAt = _micStartedAt;
    final elapsed =
        startedAt == null
            ? Duration.zero
            : DateTime.now().difference(startedAt);
    final released = _micPrerollReleased;
    if (mounted) {
      setState(() {
        _micTransitioning = true;
        _micActive = false;
        if (waitForAgent && released) {
          _waitingForAgentAfterUserTurn = true;
          _state = InterviewSessionState.thinking;
        } else if (_state == InterviewSessionState.listening ||
            _state == InterviewSessionState.thinking) {
          _state = InterviewSessionState.ready;
        }
      });
    } else {
      _micActive = false;
    }
    _micPrerollTimer?.cancel();
    _micPrerollTimer = null;
    if (!released) {
      debugPrint(
        'Interview PTT: short tap discarded '
        'elapsedMs=${elapsed.inMilliseconds} bytes=$_micBytesCaptured '
        'chunks=$_micChunkCount rawPeak=$_micPeakAbs '
        'sentPeak=$_micSendPeakAbs',
      );
      _pendingMicChunks.clear();
    } else {
      _releaseMicPrerollIfReady(force: true);
      debugPrint(
        'Interview PTT: mic OFF (waiting for examiner response) '
        'elapsedMs=${elapsed.inMilliseconds} bytes=$_micBytesCaptured '
        'chunks=$_micChunkCount rawPeak=$_micPeakAbs '
        'sentPeak=$_micSendPeakAbs '
        'micGain=${_outboundMicGain().toStringAsFixed(1)}',
      );
      if (waitForAgent) {
        _beginUserTurnLatencyTrace(
          elapsed: elapsed,
          capturedBytes: _micBytesCaptured,
        );
      }
      if (shouldSendInterviewVadTrailingSilence(
        micPrerollReleased: released,
        waitForAgent: waitForAgent,
      )) {
        _startVadTrailingSilence(interviewVadInitialSilenceDuration);
        _scheduleVadRecoverySilence();
      }
      if (waitForAgent) _scheduleAgentWaitTimeout();
    }
    final sub = _micSub;
    _micSub = null;
    try {
      await sub?.cancel().timeout(const Duration(seconds: 1));
    } catch (err) {
      debugPrint('PTT mic sub cancel timeout: $err');
    }
    try {
      await _recorder.stop().timeout(const Duration(seconds: 2));
    } catch (err) {
      debugPrint('PTT recorder stop timeout: $err');
    }
    if (released && waitForAgent && !_useSimliAudio && mounted && !_ending) {
      try {
        await _configureExaminerPlaybackAudioSession();
      } catch (err) {
        debugPrint('Interview playback audio session configure failed: $err');
      }
    }
    _micStartedAt = null;
    _micBytesCaptured = 0;
    _micChunkCount = 0;
    _micPeakAbs = 0;
    _micSendPeakAbs = 0;
    _micPrerollReleased = false;
    if (mounted) setState(() => _micTransitioning = false);
  }

  void _beginUserTurnLatencyTrace({
    required Duration elapsed,
    required int capturedBytes,
  }) {
    _lastUserTurnStoppedAt = DateTime.now();
    _userTurnLatencyIndex += 1;
    _loggedLearnerTranscriptLatency = false;
    _loggedExaminerTranscriptLatency = false;
    _loggedAgentAudioLatency = false;
    _loggedSimliSpeakLatency = false;
    _loggedAgentCompleteLatency = false;
    debugPrint(
      'Interview latency turn=$_userTurnLatencyIndex event=user_stop '
      'elapsedMs=${elapsed.inMilliseconds} bytes=$capturedBytes',
    );
  }

  void _logUserTurnLatency(String event) {
    final latencyMs = interviewTurnLatencyMs(
      startedAt: _lastUserTurnStoppedAt,
      now: DateTime.now(),
    );
    if (latencyMs == null || _userTurnLatencyIndex == 0) return;
    debugPrint(
      'Interview latency turn=$_userTurnLatencyIndex event=$event '
      'afterMs=$latencyMs',
    );
  }

  double _outboundMicGain() {
    return _useSimliAudio ? 1.0 : interviewSoundWaveMicSendGain;
  }

  String _userTurnVadScoreSummary() {
    if (!_userTurnVadScoreSeen) return 'none';
    return _userTurnVadScoreMax.toStringAsFixed(2);
  }

  Future<void> _endSession() async {
    if (_ending) return;

    final simli = _simli;
    setState(() {
      _ending = true;
      _simli = null;
      _simliConnected = false;
      _useSimliAudio = false;
    });
    debugPrint('Interview end requested for attempt ${widget.attemptId}');
    _agentWaitTimer?.cancel();
    _micPrerollTimer?.cancel();
    _autoEndTimer?.cancel();
    _cancelVadSilenceTimers();
    _agentAudioFlushTimer?.cancel();
    _audioPlayer.clearBuffer();
    _disposeSimliAfterFrame(simli);
    unawaited(_stopRealtimeSession());

    try {
      final durationSec =
          _conversationStarted
              ? (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
                  _sessionStartSec
              : 0;
      final turns = _turns.map((t) => t.toJson()).toList();
      debugPrint(
        'Interview submit started for attempt ${widget.attemptId} turns=${turns.length}',
      );
      await widget.client
          .submitInterview(
            widget.attemptId,
            turns: turns,
            durationSec: durationSec,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => InterviewResultScreen(
                client: widget.client,
                attemptId: widget.attemptId,
                turns: _turns,
              ),
        ),
      );
    } catch (err, stack) {
      debugPrint(
        'Interview submit failed for attempt ${widget.attemptId}: $err',
      );
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() {
        _ending = false;
        _autoEndScheduled = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).interviewConnectError),
        ),
      );
    }
  }

  Future<void> _stopRealtimeSession() async {
    _agentWaitTimer?.cancel();
    _micPrerollTimer?.cancel();
    _autoEndTimer?.cancel();
    _cancelVadSilenceTimers();
    if (_micActive) {
      await _stopMicStreaming(waitForAgent: false);
    } else {
      final micSub = _micSub;
      _micSub = null;
      try {
        await micSub?.cancel().timeout(const Duration(seconds: 1));
      } catch (err) {
        debugPrint('Interview mic stream cancel timed out: $err');
      }
      try {
        await _recorder.stop().timeout(const Duration(seconds: 2));
      } catch (err) {
        debugPrint('Interview recorder stop failed or timed out: $err');
      }
    }
    await _wsClient.disconnect(timeout: const Duration(seconds: 2));
  }

  void _disposeSimliAfterFrame(SimliSessionManager? simli) {
    if (simli == null) return;
    simli.onConnection = null;
    simli.onDisconnected = null;
    simli.onFailed = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(simli.dispose(notify: false));
    });
  }

  void _advancePrepareStep(int step) {
    if (!mounted || step <= _prepareStep) return;
    setState(() => _prepareStep = step);
  }

  /// V16: fires 1.5s after the most recent agent audio chunk. Acts as a
  /// safety net when ElevenLabs drops or never sends agent_response_complete.
  void _onAgentSilenceTimeout() {
    if (!mounted || _ending || _micActive) return;
    if (_state != InterviewSessionState.speaking) return;
    if (!_useSimliAudio) {
      debugPrint(
        'Agent silence detected — waiting for local audio playback to finish',
      );
      _scheduleAgentAudioFlush(
        delay: const Duration(milliseconds: 120),
        completeTurnAfterPlayback: true,
      );
      return;
    }
    debugPrint('Agent silence detected — forcing state to ready');
    setState(() => _state = InterviewSessionState.ready);
    _startConversation();
    _promptCardKey.currentState?.onAgentResponseComplete();
  }

  void _handleMicChunk(Uint8List chunk) {
    _micBytesCaptured += chunk.length;
    _micChunkCount += 1;
    final rawPeak = interviewPcm16PeakAbs(chunk);
    if (rawPeak > _micPeakAbs) _micPeakAbs = rawPeak;
    final outboundGain = _outboundMicGain();
    final outboundChunk = applyInterviewPcm16Gain(chunk, outboundGain);
    final sentPeak =
        outboundGain == 1.0 ? rawPeak : interviewPcm16PeakAbs(outboundChunk);
    if (sentPeak > _micSendPeakAbs) _micSendPeakAbs = sentPeak;
    if (!_micPrerollReleased) {
      _pendingMicChunks.add(outboundChunk);
      _releaseMicPrerollIfReady();
      return;
    }
    _wsClient.sendAudioChunk(outboundChunk);
  }

  void _releaseMicPrerollIfReady({bool force = false}) {
    if (!_micActive && !force) return;
    if (_micPrerollReleased && _pendingMicChunks.isEmpty) return;
    final startedAt = _micStartedAt;
    final elapsed =
        startedAt == null
            ? Duration.zero
            : DateTime.now().difference(startedAt);
    if (!force &&
        !shouldReleaseInterviewMicPreroll(
          elapsed: elapsed,
          capturedBytes: _micBytesCaptured,
        )) {
      return;
    }
    _micPrerollReleased = true;
    _micPrerollTimer?.cancel();
    _micPrerollTimer = null;
    for (final chunk in _pendingMicChunks) {
      _wsClient.sendAudioChunk(chunk);
    }
    if (_pendingMicChunks.isNotEmpty) {
      debugPrint(
        'Interview PTT: released preroll chunks=${_pendingMicChunks.length} '
        'elapsedMs=${elapsed.inMilliseconds}',
      );
    }
    _pendingMicChunks.clear();
  }

  void _scheduleAgentWaitTimeout() {
    _agentWaitTimer?.cancel();
    _agentWaitTimer = Timer(interviewAgentWaitTimeout, () {
      if (!mounted || _ending || !_waitingForAgentAfterUserTurn) return;
      debugPrint(
        'Interview PTT: still waiting for examiner response — mic remains locked '
        'vadMax=${_userTurnVadScoreSummary()}',
      );
      _startVadTrailingSilence(interviewVadRecoverySilenceDuration);
      setState(() {
        if (!_micActive && _state == InterviewSessionState.thinking) {
          _state = InterviewSessionState.thinking;
        }
      });
    });
  }

  void _scheduleVadRecoverySilence() {
    _vadRecoveryTimer?.cancel();
    _vadRecoveryTimer = Timer(interviewVadRecoveryDelay, () {
      if (!mounted || _ending || !_waitingForAgentAfterUserTurn) return;
      debugPrint(
        'Interview PTT: recovery silence after ${interviewVadRecoveryDelay.inMilliseconds}ms',
      );
      _startVadTrailingSilence(interviewVadRecoverySilenceDuration);
    });
  }

  void _startVadTrailingSilence(Duration duration) {
    _vadSilenceTimer?.cancel();
    _vadSilenceTimer = null;
    if (!_waitingForAgentAfterUserTurn || _ending || _micActive) return;

    final chunkCount = interviewVadSilenceChunkCount(
      totalDuration: duration,
      chunkDuration: interviewVadSilenceChunkDuration,
    );
    if (chunkCount <= 0) return;

    var sentChunks = 0;
    void sendNextChunk() {
      if (!_waitingForAgentAfterUserTurn ||
          _ending ||
          _micActive ||
          _autoEndScheduled) {
        _cancelVadSilenceTimers();
        return;
      }
      _wsClient.sendSilence(
        duration: interviewVadSilenceChunkDuration,
        chunkDuration: interviewVadSilenceChunkDuration,
      );
      sentChunks++;
      if (sentChunks >= chunkCount) {
        _vadSilenceTimer?.cancel();
        _vadSilenceTimer = null;
      }
    }

    final totalBytes = ElevenLabsWsClient.pcm16SilenceByteLength(duration);
    debugPrint(
      'Interview PTT: streaming trailing silence '
      'durationMs=${duration.inMilliseconds} '
      'chunkMs=${interviewVadSilenceChunkDuration.inMilliseconds} '
      'chunks=$chunkCount bytes=$totalBytes',
    );
    sendNextChunk();
    if (sentChunks < chunkCount) {
      _vadSilenceTimer = Timer.periodic(
        interviewVadSilenceChunkDuration,
        (_) => sendNextChunk(),
      );
    }
  }

  void _cancelVadSilenceTimers() {
    _vadSilenceTimer?.cancel();
    _vadSilenceTimer = null;
    _vadRecoveryTimer?.cancel();
    _vadRecoveryTimer = null;
  }

  void _scheduleAutoEndAfterMaxTurns() {
    if (_autoEndScheduled || _ending) return;
    debugPrint(
      'Interview auto-ending after max_turns=${widget.detail.interviewMaxTurns} '
      'examinerTurns=$_examinerTurnCount learnerTurns=$_learnerTurnCount',
    );
    _agentWaitTimer?.cancel();
    _agentWaitTimer = null;
    _micPrerollTimer?.cancel();
    _micPrerollTimer = null;
    _cancelVadSilenceTimers();
    _pendingMicChunks.clear();
    _micChunkCount = 0;
    _micPeakAbs = 0;
    _micSendPeakAbs = 0;
    if (mounted) {
      setState(() {
        _autoEndScheduled = true;
        _waitingForAgentAfterUserTurn = true;
        if (!_micActive) _state = InterviewSessionState.thinking;
      });
    } else {
      _autoEndScheduled = true;
      _waitingForAgentAfterUserTurn = true;
    }
    _autoEndTimer?.cancel();
    _autoEndTimer = Timer(interviewAutoEndDelay, () {
      if (!mounted || _ending) return;
      unawaited(_endSession());
    });
  }

  void _markAgentTurnStarted({bool updateState = true}) {
    _agentWaitTimer?.cancel();
    _agentWaitTimer = null;
    _cancelVadSilenceTimers();
    if (!_waitingForAgentAfterUserTurn) return;
    _waitingForAgentAfterUserTurn = false;
    if (updateState && mounted && !_micActive) {
      setState(() => _state = InterviewSessionState.speaking);
    }
  }

  /// V16: returns true if the transcript text contains at least one
  /// alphanumeric character. Used to filter out ElevenLabs placeholder
  /// turns ("...", "  ", ".") that come from echo/noise.
  static bool _isMeaningfulTranscript(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    return RegExp(r'\p{L}|\p{N}', unicode: true).hasMatch(t);
  }

  /// V16: gate the mic button + session timer until the examiner has finished
  /// their first turn. Subsequent calls are no-ops. Cancels the safety timer.
  /// Mic is NOT auto-started — learner taps the mic button (push-to-talk).
  void _startConversation() {
    if (_conversationStarted || !mounted) return;
    _firstTurnSafetyTimer?.cancel();
    _firstTurnSafetyTimer = null;
    setState(() {
      _conversationStarted = true;
      _sessionStartSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Flip the visual state so the mic button enables — if we were called
      // from the safety timer (because agent_response_complete never came),
      // _state would otherwise still be "speaking" from the first audio
      // chunk and the mic would stay disabled.
      if (_state == InterviewSessionState.speaking && !_micActive) {
        _state = InterviewSessionState.ready;
      }
    });
    debugPrint(
      'Interview conversation started — mic button enabled, timer reset',
    );
  }

  String? _choiceTitle() {
    final selected = widget.selectedOption;
    if (selected == null || selected.isEmpty) return null;
    final option = interviewSelectedOptionForLearner(widget.detail, selected);
    if (option == null) return selected;
    return '${option.id} — ${option.label}';
  }

  String? _choiceContent() {
    // Reserved for V16 follow-up. The current InterviewOptionView model only
    // exposes label + image, so falls back to using the body alone.
    return null;
  }

  String _pttHint(AppLocalizations l) {
    if (!_conversationStarted) return l.interviewStatusConnecting;
    if (_waitingForAgentAfterUserTurn) return l.interviewStatusThinking;
    if (_state == InterviewSessionState.speaking && !_micActive) {
      return l.interviewStatusSpeaking;
    }
    if (_micActive) return l.interviewPttSendHint;
    return l.interviewPttIdleHint;
  }

  String _timerText() {
    if (!_conversationStarted) return '00:00';
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStartSec;
    final min = elapsed ~/ 60;
    final sec = elapsed % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final showTranscript = widget.detail.interviewShowTranscript;
    final promptBody = interviewPromptBodyForLearner(widget.detail);
    final promptTips = interviewPromptTipsForLearner(
      widget.detail,
      selectedOption: widget.selectedOption,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final topSafe = media.padding.top;
          final bottomSafe = media.padding.bottom;
          final isCompactHeight = constraints.maxHeight < 760;
          final sidePadding = constraints.maxWidth < 390 ? 16.0 : 24.0;
          final panelMaxWidth =
              constraints.maxWidth > 720 ? 720.0 : constraints.maxWidth;
          final panelMaxHeight =
              (constraints.maxHeight - topSafe - (isCompactHeight ? 70 : 86))
                  .clamp(330.0, constraints.maxHeight)
                  .toDouble();
          final promptCardMaxHeight = isCompactHeight ? 220.0 : 320.0;
          final bottomGap = isCompactHeight ? 8.0 : 12.0;

          final contextCards = <Widget>[
            if (showTranscript && _lastTranscriptText != null)
              Padding(
                padding: EdgeInsets.only(bottom: bottomGap),
                child: _TranscriptBubble(
                  speakerLabel:
                      _lastSpeakerIsExaminer
                          ? l.interviewExaminer
                          : l.interviewYou,
                  speakerIsExaminer: _lastSpeakerIsExaminer,
                  text: _lastTranscriptText!,
                ),
              ),
            if (promptBody.isNotEmpty || promptTips.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: bottomGap),
                child: InterviewPromptCard(
                  key: _promptCardKey,
                  body: promptBody,
                  tips: promptTips,
                  choiceTitle: _choiceTitle(),
                  choiceContent: _choiceContent(),
                  maxExpandedHeight: promptCardMaxHeight,
                ),
              ),
          ];

          return Stack(
            children: [
              Positioned.fill(
                child: AvatarVideoContainer(
                  videoRenderer: _simli?.videoRenderer,
                  isConnected: _simliConnected,
                  isSpeaking: _state == InterviewSessionState.speaking,
                  useAvatar: _useSimliAudio || _simli != null,
                  fullBleed: true,
                ),
              ),

              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xCC06101D),
                        ],
                        stops: [0, 0.28, 0.58, 1],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Status pill ─────────────────────────────────────────────
              Positioned(
                top: topSafe + 14,
                left: 0,
                right: 0,
                child: Center(child: SessionStatusPill(state: _state)),
              ),

              // ── Selected option chip (choice type) ───────────────────────
              if (widget.selectedOption != null &&
                  widget.selectedOption!.isNotEmpty)
                Positioned(
                  top: topSafe + 14,
                  right: sidePadding,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.36,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(217),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.selectedOption} ✓',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              // ── Preparing overlay (V16) ──────────────────────────────────
              // Rendered BEFORE the bottom panel so the End button stays
              // tappable. Width-stretched but reserves bottomReserved space at
              // the bottom for the controls.
              IgnorePointer(
                ignoring: _prepareStep >= 4,
                child: AnimatedOpacity(
                  opacity: _prepareStep >= 4 ? 0 : 1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  child: _PreparingOverlay(
                    step: _prepareStep,
                    useSimli: _useSimliAudio || _simli != null,
                    bottomReserved: bottomSafe + (isCompactHeight ? 210 : 240),
                  ),
                ),
              ),

              // ── Bottom panel (V16) ────────────────────────────────────────
              // Transcript/task content gets a scrollable lane, while mic
              // controls keep a fixed lane. This prevents compact screens from
              // squeezing the cards into the timer/name/mic area.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x0006111F),
                        Color(0x9906111F),
                        Color(0xFA06111F),
                      ],
                      stops: [0, 0.35, 1],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    isCompactHeight ? 10 : 16,
                    sidePadding,
                    bottomSafe + (isCompactHeight ? 8 : 12),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: panelMaxWidth,
                        maxHeight: panelMaxHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (contextCards.isNotEmpty)
                            Flexible(
                              fit: FlexFit.loose,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(bottom: bottomGap),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: contextCards,
                                ),
                              ),
                            ),
                          Text(
                            _timerText(),
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 6 : 10),
                          _PttMicButton(
                            compact: isCompactHeight,
                            enabled:
                                _micActive ||
                                canStartInterviewMic(
                                  conversationStarted: _conversationStarted,
                                  ending: _ending,
                                  micActive: _micActive,
                                  micTransitioning: _micTransitioning,
                                  waitingForAgentAfterUserTurn:
                                      _waitingForAgentAfterUserTurn,
                                  autoEndScheduled: _autoEndScheduled,
                                  state: _state,
                                ),
                            active: _micActive,
                            onTap: _toggleMic,
                          ),
                          SizedBox(height: isCompactHeight ? 4 : 6),
                          Text(
                            _pttHint(l),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 2 : 8),
                          TextButton.icon(
                            onPressed: _ending ? null : _endSession,
                            icon:
                                _ending
                                    ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white70,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.call_end_rounded,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                            label: Text(
                              l.interviewEndBtn,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// V16 preparing overlay shown while Simli + ElevenLabs handshake. Fades out
/// once [step] reaches 4 (first agent audio chunk received).
class _PreparingOverlay extends StatelessWidget {
  const _PreparingOverlay({
    required this.step,
    required this.useSimli,
    required this.bottomReserved,
  });

  final int step;
  final bool useSimli;
  final double bottomReserved;

  @override
  Widget build(BuildContext context) {
    final steps = <(String, IconData)>[
      ('Khởi tạo phiên phỏng vấn', Icons.power_settings_new_rounded),
      if (useSimli)
        ('Kết nối với avatar', Icons.face_retouching_natural_rounded)
      else
        ('Chuẩn bị âm thanh', Icons.graphic_eq_rounded),
      ('Đang gọi giám khảo', Icons.support_agent_rounded),
      ('Sẵn sàng nói chuyện', Icons.check_circle_rounded),
    ];

    return Container(
      color: const Color(0xFF06111F),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, bottomReserved),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Đang chuẩn bị buổi phỏng vấn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mất khoảng 3 giây',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 28),
                for (var i = 0; i < steps.length; i++)
                  _PrepareStepRow(
                    label: steps[i].$1,
                    icon: steps[i].$2,
                    state: _stepStateAt(i),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Tip: nói rõ, nhìn vào camera khi giám khảo hỏi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // [step] = number of completed steps. Row at [index] is done when its
  // index sits below [step], active when it equals [step].
  _StepState _stepStateAt(int index) {
    if (step > index) return _StepState.done;
    if (step == index) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { pending, active, done }

class _PrepareStepRow extends StatelessWidget {
  const _PrepareStepRow({
    required this.label,
    required this.icon,
    required this.state,
  });

  final String label;
  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final isDone = state == _StepState.done;
    final isActive = state == _StepState.active;
    final color =
        isDone
            ? AppColors.success
            : isActive
            ? AppColors.primary
            : Colors.white24;
    final textColor = isDone || isActive ? Colors.white : Colors.white54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child:
                isActive
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                    : Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: color,
                    ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          Icon(icon, size: 18, color: color),
        ],
      ),
    );
  }
}

/// V16 push-to-talk mic button. Disabled while the examiner is speaking
/// or the conversation has not yet started. Pulses red when actively
/// recording.
class _PttMicButton extends StatefulWidget {
  const _PttMicButton({
    required this.enabled,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  final bool enabled;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_PttMicButton> createState() => _PttMicButtonState();
}

class _PttMicButtonState extends State<_PttMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _PttMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill =
        widget.active
            ? const Color(0xFFE2530A)
            : widget.enabled
            ? AppColors.primary
            : Colors.white24;
    final glow =
        widget.active
            ? const Color(0xFFE2530A)
            : widget.enabled
            ? AppColors.primary
            : Colors.transparent;
    final outerSize = widget.compact ? 82.0 : 96.0;
    final buttonSize = widget.compact ? 70.0 : 84.0;
    final iconSize = widget.compact ? 31.0 : 36.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.active ? 'Mic recording' : 'Tap to speak',
        child: SizedBox(
          width: outerSize,
          height: outerSize,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              final ring = widget.active ? 7 + 10 * (1 - t) : 0.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.active)
                    Container(
                      width: outerSize + ring * 2,
                      height: outerSize + ring * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glow.withValues(alpha: 0.25 * (1 - t)),
                      ),
                    ),
                  Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      boxShadow:
                          widget.enabled
                              ? [
                                BoxShadow(
                                  color: glow.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      widget.active ? Icons.send_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// V16 transcript bubble shown above the prompt card / mic. Aligns left for
/// the examiner, right for the learner so the "who is talking" cue is clear
/// at a glance even before the small label is read.
class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({
    required this.speakerLabel,
    required this.speakerIsExaminer,
    required this.text,
  });

  final String speakerLabel;
  final bool speakerIsExaminer;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          speakerIsExaminer ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speakerLabel.toUpperCase(),
                style: TextStyle(
                  color: speakerIsExaminer ? Colors.white60 : AppColors.primary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
