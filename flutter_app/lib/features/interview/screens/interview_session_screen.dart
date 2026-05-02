import 'dart:async';
import 'dart:typed_data';

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

  final _wsClient = ElevenLabsWsClient();
  final _audioPlayer = PcmAudioPlayer();
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  Timer? _sessionTimer;

  // Sprint 2: Simli avatar. Only active when SIMLI_API_KEY is configured.
  SimliSessionManager? _simli;
  bool _simliConnected = false;

  @override
  void initState() {
    super.initState();
    _sessionStartSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _startSession();
  }

  @override
  void dispose() {
    _micSub?.cancel();
    _sessionTimer?.cancel();
    _wsClient.disconnect();
    _audioPlayer.dispose();
    _recorder.dispose();
    _simli?.dispose();
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
      if (signedUrl.isEmpty || !mounted) return;

      // 2. Start Simli avatar if API key is configured (Sprint 2)
      if (SimliConfig.apiKey.isNotEmpty) {
        _simli = SimliSessionManager(
          apiKey: SimliConfig.apiKey,
          faceId: SimliConfig.faceId,
        );
        _simli!.onConnection = () {
          if (mounted) setState(() => _simliConnected = true);
        };
        _simli!.onDisconnected = () {
          if (mounted) setState(() => _simliConnected = false);
        };
        // Start Simli concurrently — don't await (non-blocking)
        _simli!.start().catchError((_) {}); // failure is non-fatal
      }

      // 3. Wire WS callbacks
      _wsClient.onReady = () {
        if (!mounted) return;
        setState(() => _state = InterviewSessionState.ready);
        _startMic();
      };
      _wsClient.onAudioChunk = (Uint8List chunk) {
        if (!mounted) return;
        setState(() => _state = InterviewSessionState.speaking);
        // Pipe to Simli for lip-sync (Sprint 2) + to audio player for sound
        _simli?.sendAudio(chunk);
        _audioPlayer.addChunk(chunk);
      };
      _wsClient.onTranscript = (speaker, text) {
        if (!mounted) return;
        final atSec = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStartSec;
        setState(() {
          _turns.add(InterviewTranscriptTurn(speaker: speaker, text: text, atSec: atSec));
          _lastTranscriptText = text;
          _lastSpeakerIsExaminer = speaker == 'examiner';
          if (speaker == 'examiner') {
            _state = InterviewSessionState.speaking;
            // Flush buffered audio after agent finishes speaking
            _audioPlayer.flushAndPlay();
          } else {
            _state = InterviewSessionState.listening;
          }
        });
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

      // 3. Connect
      await _wsClient.connect(signedUrl);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).interviewConnectError)),
      );
    }
  }

  Future<void> _startMic() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).interviewMicDenied)),
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
      _wsClient.sendAudioChunk(Uint8List.fromList(chunk));
      if (mounted && _state == InterviewSessionState.ready) {
        setState(() => _state = InterviewSessionState.listening);
      }
    });
  }

  Future<void> _endSession() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.interviewEndBtn),
        content: Text(l.interviewEndConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _ending = true);
    try {
      await _micSub?.cancel();
      await _recorder.stop();
      await _wsClient.disconnect();

      final durationSec = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStartSec;
      await widget.client.submitInterview(
        widget.attemptId,
        turns: _turns.map((t) => t.toJson()).toList(),
        durationSec: durationSec,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InterviewResultScreen(
            client: widget.client,
            attemptId: widget.attemptId,
            turns: _turns,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _ending = false);
    }
  }

  String _timerText() {
    final elapsed = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _sessionStartSec;
    final min = elapsed ~/ 60;
    final sec = elapsed % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final showTranscript = widget.detail.interviewShowTranscript;
    final isListening = _state == InterviewSessionState.listening;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          // ── Background gradient ─────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D2137), Color(0xFF071120)],
              ),
            ),
          ),

          // ── Status pill ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 0, right: 0,
            child: Center(child: SessionStatusPill(state: _state)),
          ),

          // ── Selected option chip (choice type) ───────────────────────
          if (widget.selectedOption != null && widget.selectedOption!.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(217),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${widget.selectedOption} ✓',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),

          // ── Avatar placeholder (Sprint 1: icon only; Sprint 2: RTCVideoView) ─
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarVideoContainer(
                  videoRenderer: _simli?.videoRenderer,
                  isConnected: _simliConnected,
                  isSpeaking: _state == InterviewSessionState.speaking,
                ),
              ],
            ),
          ),

          // ── Transcript overlay ────────────────────────────────────────
          if (showTranscript && _lastTranscriptText != null)
            Positioned(
              left: 16, right: 16,
              bottom: 120,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        color: _lastSpeakerIsExaminer ? Colors.white54 : AppColors.primary,
                        fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _lastTranscriptText!,
                      style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          // ── Controls ─────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: const Color(0xFF0A1628),
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
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
                      minimumSize: const Size(160, 44),
                      shape: const StadiumBorder(),
                    ),
                    child: _ending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l.interviewEndBtn, style: const TextStyle(fontWeight: FontWeight.w700)),
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
