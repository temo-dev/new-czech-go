import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/speaking_ai/providers/speaking_provider.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Full recording UI — user records audio, reviews, then submits.
class SpeakingRecordingScreen extends ConsumerStatefulWidget {
  const SpeakingRecordingScreen({super.key});

  @override
  ConsumerState<SpeakingRecordingScreen> createState() =>
      _SpeakingRecordingScreenState();
}

class _SpeakingRecordingScreenState
    extends ConsumerState<SpeakingRecordingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  ProviderSubscription<SpeakingState>? _speakingSubscription;
  String _prompt = '';
  String _questionId = '';
  String _exerciseId = '';
  String _lessonId = '';
  String _lessonBlockId = '';
  String _courseId = '';
  String _moduleId = '';
  String _examAttemptId = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _speakingSubscription = ref.listenManual<SpeakingState>(
      speakingSessionProvider,
      (_, next) {
        if (!mounted || next.status != SpeakingStatus.uploaded) return;
        context.push(
          AppRoutes.speakingFeedback,
          extra: {
            'attemptId': next.attemptId,
            'questionId': _questionId,
            'exerciseId': _exerciseId,
            'lessonId': _lessonId,
            'lessonBlockId': _lessonBlockId,
            'courseId': _courseId,
            'moduleId': _moduleId,
            'source': _lessonId.isNotEmpty
                ? 'lesson'
                : (_examAttemptId.isNotEmpty ? 'mock_test' : 'practice'),
          },
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _prompt = extra?['prompt'] as String? ?? '';
    _questionId = extra?['questionId'] as String? ?? '';
    _exerciseId = extra?['exerciseId'] as String? ?? '';
    _lessonId = extra?['lessonId'] as String? ?? '';
    _lessonBlockId = extra?['lessonBlockId'] as String? ?? '';
    _courseId = extra?['courseId'] as String? ?? '';
    _moduleId = extra?['moduleId'] as String? ?? '';
    _examAttemptId = extra?['examAttemptId'] as String? ?? '';
  }

  @override
  void dispose() {
    _speakingSubscription?.close();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(speakingSessionProvider);
    final notifier = ref.read(speakingSessionProvider.notifier);

    // Sync pulse animation with recording state
    if (state.status == SpeakingStatus.recording) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi âm'),
        leading: BackButton(
          onPressed: () {
            notifier.reset();
            context.pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: ResponsivePageContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prompt reminder
                if (_prompt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(
                      _prompt,
                      style: AppTypography.bodyMedium.copyWith(height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: AppSpacing.x6),

                // Waveform
                _WaveformDisplay(
                  status: state.status,
                  amplitudes: state.amplitudes,
                  pulseController: _pulseController,
                ),
                const SizedBox(height: AppSpacing.x6),

                // Status label
                Center(
                  child: Text(
                    _statusLabel(state.status),
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),

                // Record button
                if (state.status != SpeakingStatus.uploading)
                  Center(
                    child: _RecordButton(
                      status: state.status,
                      pulseController: _pulseController,
                      onTap: () => _handleRecordTap(notifier, state.status),
                    ),
                  ),

                // Loading indicator while uploading
                if (state.status == SpeakingStatus.uploading)
                  const Center(child: CircularProgressIndicator()),

                const SizedBox(height: AppSpacing.x6),

                // Error message
                if (state.status == SpeakingStatus.error &&
                    state.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Action buttons when recorded
                if (state.status == SpeakingStatus.recorded ||
                    state.status == SpeakingStatus.error) ...[
                  const SizedBox(height: AppSpacing.x4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => notifier.discardRecording(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Ghi lại'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: AppButton(
                          label: 'Nộp bài',
                          icon: Icons.upload_rounded,
                          onPressed: state.status == SpeakingStatus.recorded
                              ? () => notifier.submitRecording(
                                    lessonId: _lessonId,
                                    questionId: _questionId,
                                    exerciseId: _exerciseId.isEmpty
                                        ? null
                                        : _exerciseId,
                                    examAttemptId: _examAttemptId.isEmpty
                                        ? null
                                        : _examAttemptId,
                                  )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

  String _statusLabel(SpeakingStatus status) => switch (status) {
        SpeakingStatus.idle => 'Nhấn nút micro để bắt đầu',
        SpeakingStatus.recording => 'Đang ghi âm... Nhấn lại để dừng',
        SpeakingStatus.recorded => 'Ghi âm hoàn thành',
        SpeakingStatus.uploading => 'Đang tải lên...',
        SpeakingStatus.uploaded => 'Đã tải lên thành công',
        SpeakingStatus.error => 'Có lỗi xảy ra',
      };
}

// ── Waveform display ──────────────────────────────────────────────────────────

class _WaveformDisplay extends StatelessWidget {
  const _WaveformDisplay({
    required this.status,
    required this.amplitudes,
    required this.pulseController,
  });

  final SpeakingStatus status;
  final List<double> amplitudes;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: switch (status) {
        SpeakingStatus.recording => _LiveWaveform(
            amplitudes: amplitudes,
            pulseController: pulseController,
          ),
        SpeakingStatus.recorded || SpeakingStatus.uploading => Center(
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 36,
              color: AppColors.scoreExcellent.withValues(alpha: 0.7),
            ),
          ),
        SpeakingStatus.uploaded => Center(
            child: Icon(
              Icons.check_circle_rounded,
              size: 36,
              color: AppColors.scoreExcellent,
            ),
          ),
        _ => Center(
            child: Icon(
              Icons.mic_none_rounded,
              size: 36,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
      },
    );
  }
}

class _LiveWaveform extends StatelessWidget {
  const _LiveWaveform({
    required this.amplitudes,
    required this.pulseController,
  });

  final List<double> amplitudes;
  final AnimationController pulseController;

  static const _barCount = 30;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _WaveformPainter(
            amplitudes: amplitudes,
            barCount: _barCount,
            color: AppColors.primary,
            animationValue: pulseController.value,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.barCount,
    required this.color,
    required this.animationValue,
  });

  final List<double> amplitudes;
  final int barCount;
  final Color color;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeCap = StrokeCap.round;

    final barWidth = 3.0;
    final gap = (size.width - barCount * barWidth) / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      final x = gap + i * (barWidth + gap) + barWidth / 2;

      double normalized;
      if (amplitudes.isNotEmpty) {
        // Map bar index to amplitude buffer
        final bufIdx = ((i / barCount) * amplitudes.length).floor().clamp(
              0,
              amplitudes.length - 1,
            );
        normalized = amplitudes[bufIdx];
      } else {
        // Animate placeholder bars
        final phase = (i / barCount) * math.pi * 2;
        normalized = 0.1 +
            0.2 *
                (0.5 +
                        0.5 *
                            math
                                .sin(animationValue * math.pi * 2 + phase)
                                .abs())
                    .abs();
      }

      final barHeight =
          (size.height * 0.8 * normalized).clamp(4.0, size.height * 0.9);
      final top = (size.height - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 2, top, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.amplitudes != amplitudes || old.animationValue != animationValue;
}

// ── Record button ─────────────────────────────────────────────────────────────

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.status,
    required this.pulseController,
    required this.onTap,
  });

  final SpeakingStatus status;
  final AnimationController pulseController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRecording = status == SpeakingStatus.recording;
    final isRecorded = status == SpeakingStatus.recorded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, _) {
          final scale = isRecording ? 1.0 + pulseController.value * 0.1 : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
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
                    blurRadius: isRecording ? 20 : 8,
                    spreadRadius: isRecording ? 6 : 0,
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
                size: 36,
              ),
            ),
          );
        },
      ),
    );
  }
}
