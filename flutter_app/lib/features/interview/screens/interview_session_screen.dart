import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../core/api/api_client.dart';
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
const Duration interviewMicPrerollDuration = Duration(milliseconds: 550);

@visibleForTesting
const Duration interviewAgentWaitTimeout = Duration(seconds: 8);

@visibleForTesting
const int interviewMinMicPrerollBytes = 1600;

@visibleForTesting
bool canStartInterviewMic({
  required bool conversationStarted,
  required bool ending,
  required bool micActive,
  required bool micTransitioning,
  required bool waitingForAgentAfterUserTurn,
  required InterviewSessionState state,
}) {
  return conversationStarted &&
      !ending &&
      !micActive &&
      !micTransitioning &&
      !waitingForAgentAfterUserTurn &&
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
  final List<Uint8List> _pendingMicChunks = [];
  Timer? _micPrerollTimer;
  Timer? _agentWaitTimer;

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
      await _configureDuplexAudioSession();

      // 2. Wait for Simli before opening ElevenLabs so the first examiner
      // message starts only after the avatar video/audio path is ready.
      _useSimliAudio = await _startSimliIfAvailable();
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
          debugPrint('Interview dropping empty learner turn: ${text.trim()}');
          return;
        }
        final atSec =
            _conversationStarted
                ? (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
                    _sessionStartSec
                : 0;
        setState(() {
          if (speaker == 'examiner') {
            _markAgentTurnStarted(updateState: false);
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
      };
      _wsClient.onAgentResponseComplete = () {
        if (!mounted) return;
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
          _scheduleAgentAudioFlush(delay: const Duration(milliseconds: 120));
        }
        // V16: force visual state to "ready" only on the local-audio path.
        // When Simli is active, its SPEAK/SILENT WS messages are the
        // authoritative "is the avatar talking" signal — flipping state
        // here would be premature because Simli still has buffered audio
        // to play out after the EL agent_response_complete event fires.
        if (!_useSimliAudio && !_micActive) {
          setState(() => _state = InterviewSessionState.ready);
        }
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
      if (_waitingForAgentAfterUserTurn && !isSpeaking) {
        return;
      }
      if (isSpeaking) _markAgentTurnStarted();
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
  }) {
    _agentAudioFlushTimer?.cancel();
    _agentAudioFlushTimer = Timer(delay, () async {
      await _audioPlayer.flushAndPlay();
      if (!mounted || _ending) return;
      setState(
        () =>
            _state =
                _micActive
                    ? InterviewSessionState.listening
                    : InterviewSessionState.ready,
      );
    });
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
      _pendingMicChunks.clear();
      _micBytesCaptured = 0;
      _micPrerollReleased = false;
      _micStartedAt = DateTime.now();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _micSub = stream.listen((chunk) {
        if (_ending || !_micActive) return;
        _handleMicChunk(Uint8List.fromList(chunk));
      });
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
        'elapsedMs=${elapsed.inMilliseconds} bytes=$_micBytesCaptured',
      );
      _pendingMicChunks.clear();
    } else {
      _releaseMicPrerollIfReady(force: true);
      debugPrint(
        'Interview PTT: mic OFF (waiting for examiner response) '
        'elapsedMs=${elapsed.inMilliseconds} bytes=$_micBytesCaptured',
      );
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
    _micStartedAt = null;
    _micBytesCaptured = 0;
    _micPrerollReleased = false;
    if (mounted) setState(() => _micTransitioning = false);
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
      setState(() => _ending = false);
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
    debugPrint('Agent silence detected — forcing state to ready');
    setState(() => _state = InterviewSessionState.ready);
    _startConversation();
    _promptCardKey.currentState?.onAgentResponseComplete();
  }

  void _handleMicChunk(Uint8List chunk) {
    _micBytesCaptured += chunk.length;
    if (!_micPrerollReleased) {
      _pendingMicChunks.add(chunk);
      _releaseMicPrerollIfReady();
      return;
    }
    _wsClient.sendAudioChunk(chunk);
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
        'Interview PTT: no examiner response after user turn — mic re-enabled',
      );
      setState(() {
        _waitingForAgentAfterUserTurn = false;
        if (!_micActive && _state == InterviewSessionState.thinking) {
          _state = InterviewSessionState.ready;
        }
      });
    });
  }

  void _markAgentTurnStarted({bool updateState = true}) {
    _agentWaitTimer?.cancel();
    _agentWaitTimer = null;
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
    final option = widget.detail.interviewOptions.firstWhere(
      (o) => o.id == selected,
      orElse: () => const InterviewOptionView(id: '', label: ''),
    );
    if (option.id.isEmpty) return selected;
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
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          Positioned.fill(
            child: AvatarVideoContainer(
              videoRenderer: _simli?.videoRenderer,
              isConnected: _simliConnected,
              isSpeaking: _state == InterviewSessionState.speaking,
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
            top: MediaQuery.of(context).padding.top + 14,
            left: 0,
            right: 0,
            child: Center(child: SessionStatusPill(state: _state)),
          ),

          // ── Selected option chip (choice type) ───────────────────────
          if (widget.selectedOption != null &&
              widget.selectedOption!.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              right: 16,
              child: Container(
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
                bottomReserved: bottomSafe + 240,
              ),
            ),
          ),

          // ── Bottom panel (V16) ────────────────────────────────────────
          // Single Column anchored at the bottom containing transcript +
          // prompt card + PTT controls so they stack naturally and never
          // overlap regardless of screen size. Avatar still fills the
          // top portion of the screen behind everything.
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
              padding: EdgeInsets.fromLTRB(16, 18, 16, bottomSafe + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTranscript && _lastTranscriptText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TranscriptBubble(
                        speakerLabel:
                            _lastSpeakerIsExaminer
                                ? l.interviewExaminer
                                : l.interviewYou,
                        speakerIsExaminer: _lastSpeakerIsExaminer,
                        text: _lastTranscriptText!,
                      ),
                    ),
                  if (widget.detail.interviewDisplayPrompt.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InterviewPromptCard(
                        key: _promptCardKey,
                        body: widget.detail.interviewDisplayPrompt,
                        choiceTitle: _choiceTitle(),
                        choiceContent: _choiceContent(),
                      ),
                    ),
                  Text(
                    _timerText(),
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  _PttMicButton(
                    enabled:
                        _micActive ||
                        canStartInterviewMic(
                          conversationStarted: _conversationStarted,
                          ending: _ending,
                          micActive: _micActive,
                          micTransitioning: _micTransitioning,
                          waitingForAgentAfterUserTurn:
                              _waitingForAgentAfterUserTurn,
                          state: _state,
                        ),
                    active: _micActive,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pttHint(l),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
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
        ],
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
  });

  final bool enabled;
  final bool active;
  final VoidCallback onTap;

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.active ? 'Mic recording' : 'Tap to speak',
        child: SizedBox(
          width: 96,
          height: 96,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              final ring = widget.active ? 8 + 12 * (1 - t) : 0.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.active)
                    Container(
                      width: 96 + ring * 2,
                      height: 96 + ring * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glow.withValues(alpha: 0.25 * (1 - t)),
                      ),
                    ),
                  Container(
                    width: 84,
                    height: 84,
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
                      size: 36,
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
