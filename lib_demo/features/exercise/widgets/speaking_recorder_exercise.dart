import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/speaking_ai/providers/speaking_provider.dart';
import 'package:app_czech/shared/models/question_model.dart';

/// Speaking exercise embedded in the lesson practice / mock test flow.
///
/// [existingAudioPath] — if non-null, the user already recorded an answer for
/// this question; the widget restores the "recorded" state so they can listen
/// back or re-record.
class SpeakingRecorderExercise extends ConsumerStatefulWidget {
  const SpeakingRecorderExercise({
    super.key,
    required this.question,
    this.isSubmitted = false,
    this.lessonId,
    this.examAttemptId,
    this.existingAudioPath,
    this.onRecordingComplete,
  });

  final Question question;
  final bool isSubmitted;
  final String? lessonId;
  final String? examAttemptId;
  final String? existingAudioPath;
  final ValueChanged<String>? onRecordingComplete;

  @override
  ConsumerState<SpeakingRecorderExercise> createState() =>
      _SpeakingRecorderExerciseState();
}

class _SpeakingRecorderExerciseState
    extends ConsumerState<SpeakingRecorderExercise>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late AudioPlayer _audioPlayer;
  late SpeakingSessionNotifier _speakingNotifier;
  ProviderSubscription<SpeakingState>? _speakingSubscription;
  bool _isPlayingBack = false;
  String? _loadedAudioPath;
  SpeakingStatus _lastStatus = SpeakingStatus.idle;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _audioPlayer = AudioPlayer();
    _speakingNotifier = ref.read(speakingSessionProvider.notifier);

    // Listen for playback completion to reset the play button.
    // Must call stop() — not seek() — to clear the internal playing=true flag;
    // seek(Duration.zero) on a completed player restarts audio automatically.
    _audioPlayer.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed && mounted) {
        setState(() => _isPlayingBack = false);
        _audioPlayer.stop();
        // stop() clears the loaded source; reset the path so the next play
        // call reloads it via setAudioSource.
        _loadedAudioPath = null;
      }
    });

    // Restore recorded state when returning to a previously answered question.
    // Only restore — never reset here; reset happens in dispose() below so
    // the upload can finish even after the user navigates away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.existingAudioPath != null) {
        ref
            .read(speakingSessionProvider.notifier)
            .restoreRecording(widget.existingAudioPath!);
      }
    });

    _speakingSubscription = ref.listenManual<SpeakingState>(
      speakingSessionProvider,
      (prev, next) {
        _lastStatus = next.status;
        if (next.status == SpeakingStatus.recorded &&
            prev?.status != SpeakingStatus.recorded &&
            next.audioPath != null) {
          _speakingNotifier.submitRecording(
            lessonId: widget.lessonId ?? '',
            examAttemptId: widget.examAttemptId,
            questionId: widget.question.id,
          );
        }
        if (next.status == SpeakingStatus.uploaded &&
            prev?.status != SpeakingStatus.uploaded &&
            next.attemptId != null) {
          widget.onRecordingComplete?.call(next.attemptId!);
          Future.delayed(
            const Duration(seconds: 2),
            _speakingNotifier.resetToIdle,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _speakingSubscription?.close();
    _pulseController.dispose();
    _audioPlayer.dispose();
    // Defer state update past finalizeTree — provider mutations are forbidden
    // during the unmount phase (would throw "Tried to modify provider while
    // widget tree was building").
    if (_lastStatus != SpeakingStatus.uploading) {
      Future(() => _speakingNotifier.resetToIdle());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speakingState = ref.watch(speakingSessionProvider);
    final notifier = _speakingNotifier;
    final cs = Theme.of(context).colorScheme;

    // Sync pulse animation with recording state.
    if (speakingState.status == SpeakingStatus.recording) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      if (_pulseController.isAnimating) _pulseController.stop();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prompt
        Text(widget.question.prompt, style: AppTypography.bodyLarge),
        const SizedBox(height: AppSpacing.x6),

        // Waveform area
        _WaveformArea(
          status: speakingState.status,
          amplitudes: speakingState.amplitudes,
          pulseController: _pulseController,
          cs: cs,
          isSubmitted: widget.isSubmitted,
        ),
        const SizedBox(height: AppSpacing.x6),

        if (!widget.isSubmitted) ...[
          // Record button + state label
          Center(
            child: Column(
              children: [
                _RecordButton(
                  status: speakingState.status,
                  onTap: () => _handleRecordTap(notifier, speakingState.status),
                  pulseController: _pulseController,
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  _stateLabel(speakingState.status),
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),

                // Hint after recording
                if (speakingState.status == SpeakingStatus.recorded) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Nhấn "Tiếp" bên dưới để chuyển câu',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ],

                // Re-record option
                if (speakingState.status == SpeakingStatus.recorded ||
                    speakingState.status == SpeakingStatus.error) ...[
                  const SizedBox(height: AppSpacing.x2),
                  TextButton.icon(
                    onPressed: () async {
                      setState(() {
                        _isPlayingBack = false;
                        _loadedAudioPath = null;
                      });
                      await _audioPlayer.stop();
                      notifier.discardRecording();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Ghi lại'),
                    style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),

          // ── Playback bar (shown after recording / during upload) ──────────
          if ((speakingState.status == SpeakingStatus.recorded ||
                  speakingState.status == SpeakingStatus.uploading) &&
              speakingState.audioPath != null) ...[
            const SizedBox(height: AppSpacing.x4),
            _PlaybackBar(
              isPlaying: _isPlayingBack,
              onToggle: () => _togglePlayback(speakingState.audioPath!),
            ),
          ],

          // Error message
          if (speakingState.status == SpeakingStatus.error &&
              speakingState.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.x3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.x3),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                speakingState.errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // Open full recording screen
          const SizedBox(height: AppSpacing.x3),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push(
                AppRoutes.speakingRecording,
                extra: {
                  'prompt': widget.question.prompt,
                  'questionId': widget.question.id,
                  'lessonId': widget.lessonId ?? '',
                  'examAttemptId': widget.examAttemptId,
                },
              ),
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('Mở chế độ ghi âm đầy đủ'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],

        if (widget.isSubmitted)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.scoreExcellent, size: 18),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  'Đã nộp bài ghi âm',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.scoreExcellent),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _handleRecordTap(
      SpeakingSessionNotifier notifier, SpeakingStatus status) {
    switch (status) {
      case SpeakingStatus.idle:
      case SpeakingStatus.error:
        notifier.startRecording();
      case SpeakingStatus.recording:
        notifier.stopRecording();
      default:
        break;
    }
  }

  Future<void> _togglePlayback(String audioPath) async {
    if (_isPlayingBack) {
      await _audioPlayer.pause();
      setState(() => _isPlayingBack = false);
      return;
    }
    try {
      // Web produces a blob URL; native produces a file path.
      // Uri.file() adds the required file:// scheme on iOS/Android.
      final uri = kIsWeb ? Uri.parse(audioPath) : Uri.file(audioPath);

      if (_loadedAudioPath != audioPath) {
        await _audioPlayer.setAudioSource(AudioSource.uri(uri));
        _loadedAudioPath = audioPath;
      }
      // After stop() the position is already 0, no seek needed.
      setState(() => _isPlayingBack = true);
      await _audioPlayer.play();
    } catch (_) {
      // Playback failed (e.g. blob URL expired) — ignore silently.
      setState(() => _isPlayingBack = false);
    }
  }

  String _stateLabel(SpeakingStatus status) => switch (status) {
        SpeakingStatus.idle => 'Nhấn để bắt đầu ghi âm',
        SpeakingStatus.recording => 'Đang ghi... Nhấn để dừng',
        SpeakingStatus.recorded => 'Đã ghi xong ✓',
        SpeakingStatus.uploading => 'Đang tải lên...',
        SpeakingStatus.uploaded => 'Đã nộp thành công',
        SpeakingStatus.error => 'Có lỗi — thử lại',
      };
}

// ── Playback bar ──────────────────────────────────────────────────────────────

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({required this.isPlaying, required this.onToggle});

  final bool isPlaying;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlaying ? 'Đang phát...' : 'Nghe lại bài ghi âm',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.x1),
                LinearProgressIndicator(
                  value: isPlaying ? null : 0,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  color: AppColors.primary,
                  minHeight: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waveform area ─────────────────────────────────────────────────────────────

class _WaveformArea extends StatelessWidget {
  const _WaveformArea({
    required this.status,
    required this.amplitudes,
    required this.pulseController,
    required this.cs,
    required this.isSubmitted,
  });

  final SpeakingStatus status;
  final List<double> amplitudes;
  final AnimationController pulseController;
  final ColorScheme cs;
  final bool isSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: status == SpeakingStatus.recording
          ? _AnimatedBars(
              controller: pulseController,
              amplitudes: amplitudes,
            )
          : Center(
              child: Icon(
                status == SpeakingStatus.recorded ||
                        status == SpeakingStatus.uploaded ||
                        isSubmitted
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_none_rounded,
                size: 28,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
    );
  }
}

class _AnimatedBars extends StatelessWidget {
  const _AnimatedBars({required this.controller, required this.amplitudes});
  final AnimationController controller;
  final List<double> amplitudes;

  static const _barCount = 20;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            double normalized;
            if (amplitudes.isNotEmpty) {
              final idx = ((i / _barCount) * amplitudes.length)
                  .floor()
                  .clamp(0, amplitudes.length - 1);
              normalized = amplitudes[idx];
            } else {
              final phase = (i / _barCount) * math.pi * 2;
              normalized = 0.2 +
                  0.6 *
                      (0.5 +
                              0.5 *
                                  math
                                      .sin(controller.value * math.pi * 2 +
                                          phase)
                                      .abs())
                          .abs();
            }
            return Container(
              width: 3,
              height: 8 + 36 * normalized,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Record button ─────────────────────────────────────────────────────────────

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.status,
    required this.onTap,
    required this.pulseController,
  });

  final SpeakingStatus status;
  final VoidCallback onTap;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final isRecording = status == SpeakingStatus.recording;
    final isRecorded =
        status == SpeakingStatus.recorded || status == SpeakingStatus.uploaded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final scale = isRecording ? 1.0 + pulseController.value * 0.12 : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? AppColors.error
                    : isRecorded
                        ? AppColors.scoreExcellent
                        : AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? AppColors.error : AppColors.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: isRecording ? 16 : 8,
                    spreadRadius: isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                isRecording
                    ? Icons.stop_rounded
                    : isRecorded
                        ? Icons.check_rounded
                        : Icons.mic_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}
