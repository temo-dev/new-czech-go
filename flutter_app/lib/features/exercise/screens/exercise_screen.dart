import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';
import '../widgets/uloha_prompt.dart';
import '../widgets/recording_card.dart';
import 'analysis_screen.dart';

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
      final l = AppLocalizations.of(context);
      setState(() => _playbackError = l.playbackErrorPrefix(e.message ?? ''));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
      _seconds = 0;
      _status = 'starting';
      _playbackError = null;
      _playbackPath = null;
    });
    final locale = LocaleScope.of(context).code;
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const FileSystemException('Microphone permission was not granted.');
      }
      final attempt = await widget.client.createAttempt(
        widget.detail.id,
        locale: locale,
      );
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
      await _prepareLocalPlayback(audioPath);
      if (!mounted) return;
      setState(() {
        _status = 'stopped';
        _recordingPath = audioPath;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = 'ready';
        _error = err.toString();
      });
    }
  }

  Future<void> _analyze() async {
    final attemptId = _attemptId;
    final audioPath = _recordingPath;
    if (attemptId == null || audioPath == null) return;
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) return;
    final fileSizeBytes = await audioFile.length();
    final durationMs = _seconds * 1000;

    await _player.stop();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => AnalysisScreen(
          client: widget.client,
          attemptId: attemptId,
          audioPath: audioPath,
          fileSizeBytes: fileSizeBytes,
          durationMs: durationMs,
        ),
      ),
    );
    if (!mounted) return;
    await _reset();
  }

  Future<void> _rerecord() async {
    await _reset();
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
      final l = AppLocalizations.of(context);
      setState(() {
        _playbackPath = audioPath;
        _playbackError = l.playbackOpenError;
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
    await _player.stop();
    await _player.seek(Duration.zero);
    if (!mounted) return;
    setState(() {
      _status = 'ready';
      _attemptId = null;
      _recordingPath = null;
      _seconds = 0;
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
            onAnalyze: _analyze,
            onRerecord: _rerecord,
            onTogglePlayback: _togglePlayback,
            onSeek: (v) => unawaited(_seekPlayback(v)),
          ),
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
            label: _exerciseTypeLabel(AppLocalizations.of(context), detail.exerciseType),
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
    final l = AppLocalizations.of(context);
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
            l.coachNoteTitle,
            style: AppTypography.titleSmall.copyWith(color: AppColors.info),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            _coachNote(l, exerciseType),
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _exerciseTypeLabel(AppLocalizations l, String type) => switch (type) {
      'uloha_2_dialogue_questions' => l.exerciseUloha2Label,
      'uloha_3_story_narration'   => l.exerciseUloha3Label,
      'uloha_4_choice_reasoning'  => l.exerciseUloha4Label,
      _                           => l.exerciseUloha1Label,
    };

String _coachNote(AppLocalizations l, String type) => switch (type) {
      'uloha_2_dialogue_questions' => l.coachNoteUloha2,
      'uloha_3_story_narration'   => l.coachNoteUloha3,
      'uloha_4_choice_reasoning'  => l.coachNoteUloha4,
      _                           => l.coachNoteUloha1,
    };
