import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';
import '../widgets/uloha_prompt.dart';
import '../widgets/recording_card.dart';
import '../widgets/result_card.dart';

/// Full exercise flow: prompt → record → feedback.
/// Works for all 4 Uloha types — prompt section adapts via UlohaPrompt.
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
  });

  final ApiClient client;
  final ExerciseDetail detail;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String _status = 'ready';
  String? _attemptId;
  String? _recordingPath;
  int _seconds = 0;
  Timer? _ticker;
  Timer? _poller;
  AttemptResult? _result;
  String? _error;
  String? _playbackPath;
  String? _playbackError;
  Duration _playbackPosition = Duration.zero;
  Duration? _playbackDuration;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerException>? _errSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        setState(() => _playbackPosition = Duration.zero);
      } else {
        setState(() {});
      }
    });
    _posSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _playbackPosition = p);
    });
    _durSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _playbackDuration = d);
    });
    _errSub = _player.errorStream.listen((e) {
      if (!mounted) return;
      setState(() => _playbackError = 'Playback gặp lỗi: ${e.message}');
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poller?.cancel();
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _errSub?.cancel();
    _recorder.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _result = null;
      _seconds = 0;
      _status = 'starting';
      _playbackError = null;
    });
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const FileSystemException('Microphone permission was not granted.');
      }
      final attempt = await widget.client.createAttempt(widget.detail.id);
      _attemptId = attempt['id'] as String;
      _recordingPath = await _buildRecordingPath(_attemptId!);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _recordingPath!,
      );
      await widget.client.markRecordingStarted(_attemptId!);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds += 1);
      });
      setState(() => _status = 'recording');
    } catch (err) {
      setState(() {
        _status = 'ready';
        _error = err.toString();
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_attemptId == null) return;
    _ticker?.cancel();
    setState(() => _status = 'uploading');
    try {
      final recordedPath = await _recorder.stop();
      final audioPath = recordedPath ?? _recordingPath;
      if (audioPath == null) {
        throw const FileSystemException('Recording file was not created.');
      }
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw FileSystemException('Recording file not found.', audioPath);
      }
      final fileSizeBytes = await audioFile.length();
      await _prepareLocalPlayback(audioPath);
      await widget.client.submitRecordedAudio(
        _attemptId!,
        audioPath: audioPath,
        mimeType: 'audio/m4a',
        fileSizeBytes: fileSizeBytes,
        durationMs: _seconds * 1000,
      );
      setState(() {
        _status = 'processing';
        _recordingPath = audioPath;
      });
      _poller?.cancel();
      _poller = Timer.periodic(const Duration(seconds: 2), (_) async {
        final attempt = AttemptResult.fromJson(
          await widget.client.getAttempt(_attemptId!),
        );
        if (!mounted) return;
        setState(() {
          _result = attempt;
          _status = attempt.status;
        });
        if (attempt.status == 'completed' || attempt.status == 'failed') {
          _poller?.cancel();
        }
      });
    } catch (err) {
      setState(() {
        _status = 'ready';
        _error = err.toString();
      });
    }
  }

  // ── Local playback ─────────────────────────────────────────────────────────

  Future<void> _prepareLocalPlayback(String audioPath) async {
    try {
      await _player.setFilePath(audioPath);
      if (!mounted) return;
      setState(() {
        _playbackPath = audioPath;
        _playbackError = null;
        _playbackPosition = Duration.zero;
        _playbackDuration = _player.duration;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _playbackPath = audioPath;
        _playbackError = 'Không mở được bản ghi để nghe lại.';
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_playbackPath == null) return;
    final dur = _playbackDuration ?? _player.duration;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (dur != null && _playbackPosition >= dur) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<void> _seekPlayback(double ms) async {
    final dur = _playbackDuration;
    if (dur == null) return;
    final target = Duration(milliseconds: ms.round());
    await _player.seek(target > dur ? dur : target);
  }

  // ── Retry ──────────────────────────────────────────────────────────────────

  Future<void> _reset() async {
    _ticker?.cancel();
    _poller?.cancel();
    await _player.stop();
    await _player.seek(Duration.zero);
    if (!mounted) return;
    setState(() {
      _status = 'ready';
      _attemptId = null;
      _recordingPath = null;
      _seconds = 0;
      _result = null;
      _error = null;
      _playbackPath = null;
      _playbackError = null;
      _playbackPosition = Duration.zero;
      _playbackDuration = null;
    });
  }

  Future<String> _buildRecordingPath(String attemptId) async {
    final tmp = await getTemporaryDirectory();
    return '${tmp.path}/attempt_$attemptId.m4a';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.detail.title),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH(context),
          vertical: AppSpacing.x5,
        ),
        children: [
          _PromptCard(detail: widget.detail, client: widget.client),
          const SizedBox(height: AppSpacing.x4),
          _CoachNoteCard(exerciseType: widget.detail.exerciseType),
          const SizedBox(height: AppSpacing.x4),
          RecordingCard(
            status: _status,
            seconds: _seconds,
            player: _player,
            playbackPath: _playbackPath,
            playbackPosition: _playbackPosition,
            playbackDuration: _playbackDuration,
            playbackError: _playbackError,
            error: _error,
            onStart: _startRecording,
            onStop: _stopRecording,
            onTogglePlayback: _togglePlayback,
            onSeek: (v) => unawaited(_seekPlayback(v)),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.x4),
            ResultCard(
              client: widget.client,
              result: _result!,
              onRetry: _reset,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Prompt card shell ──────────────────────────────────────────────────────────

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.detail, required this.client});
  final ExerciseDetail detail;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPill(
            label: _exerciseTypeLabel(detail.exerciseType),
            tone: PillTone.primary,
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(detail.learnerInstruction, style: AppTypography.bodyLarge),
          const SizedBox(height: AppSpacing.x4),
          UlohaPrompt(detail: detail, client: client),
        ],
      ),
    );
  }
}

// ── Coach note ─────────────────────────────────────────────────────────────────

class _CoachNoteCard extends StatelessWidget {
  const _CoachNoteCard({required this.exerciseType});
  final String exerciseType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coach note',
            style: AppTypography.titleSmall.copyWith(color: AppColors.info),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            _coachNote(exerciseType),
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _exerciseTypeLabel(String type) => switch (type) {
      'uloha_2_dialogue_questions' => 'ÚLOHA 2 · HỘI THOẠI',
      'uloha_3_story_narration'   => 'ÚLOHA 3 · KỂ CHUYỆN',
      'uloha_4_choice_reasoning'  => 'ÚLOHA 4 · CHỌN & GIẢI THÍCH',
      _                           => 'ÚLOHA 1 · TRẢ LỜI CHỦ ĐỀ',
    };

String _coachNote(String type) => switch (type) {
      'uloha_2_dialogue_questions' =>
        'Hỏi đủ thông tin trong scenario. Dùng câu hỏi đơn giản, rõ ràng.',
      'uloha_3_story_narration' =>
        'Kể theo thứ tự: nejdřív, pak, nakonec. Không cần câu hoàn hảo — cần đủ mốc.',
      'uloha_4_choice_reasoning' =>
        'Chọn một phương án và giải thích lý do. Dùng "protože" hoặc "protože mi líbí".',
      _ =>
        'Nói ngắn, rõ ý, dùng câu đơn giản trước. Ưu tiên trả lời đúng task hơn là cố nói phức tạp.',
    };
