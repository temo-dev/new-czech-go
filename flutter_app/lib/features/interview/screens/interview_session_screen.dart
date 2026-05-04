import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
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
import '../widgets/mic_waveform_widget.dart';
import '../widgets/session_status_pill.dart';
import 'interview_result_screen.dart';

bool shouldPlayInterviewAudioLocally({
  required bool useSimliAudio,
  required bool simliConnected,
}) {
  return !(useSimliAudio && simliConnected);
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

  @override
  void initState() {
    super.initState();
    _sessionStartSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _startSession();
  }

  @override
  void dispose() {
    _disposing = true;
    _micSub?.cancel();
    _sessionTimer?.cancel();
    _agentAudioFlushTimer?.cancel();
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

      await _configureDuplexAudioSession();

      // 2. Wait for Simli before opening ElevenLabs so the first examiner
      // message starts only after the avatar video/audio path is ready.
      _useSimliAudio = await _startSimliIfAvailable();
      if (!mounted || _disposing) return;

      // 3. Wire WS callbacks
      _wsClient.onReady = () {
        if (!mounted) return;
        setState(() => _state = InterviewSessionState.ready);
        _startMic();
      };
      _wsClient.onMetadata = ({
        String? agentOutputAudioFormat,
        String? userInputAudioFormat,
      }) {
        final _ = userInputAudioFormat;
        _audioPlayer.setOutputAudioFormat(agentOutputAudioFormat);
      };
      _wsClient.onAudioChunk = (Uint8List chunk) {
        if (!mounted || _ending) return;
        setState(() => _state = InterviewSessionState.speaking);
        final useLocalAudio = shouldPlayInterviewAudioLocally(
          useSimliAudio: _useSimliAudio,
          simliConnected: _simli?.isConnected == true,
        );
        if (useLocalAudio) {
          _audioPlayer.addChunk(chunk);
          _scheduleAgentAudioFlush();
        } else {
          _simli?.sendAudio(chunk);
        }
      };
      _wsClient.onInterruption = () {
        if (_useSimliAudio) {
          _simli?.clearBuffer();
        } else {
          _audioPlayer.clearBuffer();
        }
      };
      _wsClient.onTranscript = (speaker, text) {
        if (!mounted || _ending) return;
        final atSec =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStartSec;
        setState(() {
          _turns.add(
            InterviewTranscriptTurn(speaker: speaker, text: text, atSec: atSec),
          );
          _lastTranscriptText = text;
          _lastSpeakerIsExaminer = speaker == 'examiner';
          if (speaker == 'examiner') {
            _state = InterviewSessionState.speaking;
          } else {
            _state = InterviewSessionState.listening;
          }
        });
      };
      _wsClient.onAgentResponseComplete = () {
        if (!mounted) return;
        if (!_useSimliAudio) {
          _scheduleAgentAudioFlush(delay: const Duration(milliseconds: 120));
        }
      };
      _wsClient.onDisconnected = () {
        if (mounted) setState(() => _state = InterviewSessionState.connecting);
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
      if (mounted && !_disposing) {
        setState(() => _simliConnected = true);
      }
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
      setState(() {
        _state =
            isSpeaking
                ? InterviewSessionState.speaking
                : InterviewSessionState.listening;
      });
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
    await session.configure(
      const AudioSessionConfiguration.speech().copyWith(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowBluetoothA2dp,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      ),
    );
    await session.setActive(true);
  }

  void _scheduleAgentAudioFlush({
    Duration delay = const Duration(milliseconds: 450),
  }) {
    _agentAudioFlushTimer?.cancel();
    _agentAudioFlushTimer = Timer(delay, () async {
      await _audioPlayer.flushAndPlay();
      if (!mounted || _ending) return;
      setState(() => _state = InterviewSessionState.listening);
    });
  }

  Future<void> _startMic() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).interviewMicDenied),
          ),
        );
      }
      return;
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _micSub = stream.listen((chunk) {
      if (_ending) return;
      _wsClient.sendAudioChunk(Uint8List.fromList(chunk));
      if (mounted && _state == InterviewSessionState.ready) {
        setState(() => _state = InterviewSessionState.listening);
      }
    });
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
    _agentAudioFlushTimer?.cancel();
    _audioPlayer.clearBuffer();
    _disposeSimliAfterFrame(simli);
    unawaited(_stopRealtimeSession());

    try {
      final durationSec =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStartSec;
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

  String _timerText() {
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
    final isListening = _state == InterviewSessionState.listening;
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

          // ── Transcript overlay ────────────────────────────────────────
          if (showTranscript && _lastTranscriptText != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomSafe + 150,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _lastSpeakerIsExaminer
                          ? l.interviewExaminer
                          : l.interviewYou,
                      style: TextStyle(
                        color:
                            _lastSpeakerIsExaminer
                                ? Colors.white54
                                : AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _lastTranscriptText!,
                      style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 13,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          // ── Controls ─────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0006111F), Color(0xF006111F)],
                ),
              ),
              padding: EdgeInsets.fromLTRB(24, 34, 24, bottomSafe + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timerText(),
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  MicWaveformWidget(isActive: isListening),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _ending ? null : _endSession,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xD4C62828),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(178, 54),
                      shape: const StadiumBorder(),
                    ),
                    child:
                        _ending
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.call_end, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  l.interviewEndBtn,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
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
