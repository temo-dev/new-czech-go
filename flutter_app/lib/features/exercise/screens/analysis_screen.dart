import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/voice/voice_preference_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../widgets/result_card.dart';

/// Full-screen analysis flow: uploads the recorded attempt, polls until the
/// backend finishes processing, then renders the final ResultCard.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.client,
    required this.attemptId,
    required this.audioPath,
    required this.fileSizeBytes,
    required this.durationMs,
    this.onOpenNext,
  });

  final ApiClient client;
  final String attemptId;
  final String audioPath;
  final int fileSizeBytes;
  final int durationMs;
  final VoidCallback? onOpenNext;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String _status = 'uploading';
  String? _error;
  AttemptResult? _result;
  Timer? _poller;
  // Local step progression: 0=uploading, 1=processing, 2=analysing
  int _localStep = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final voiceId = await VoicePreferenceService.readCurrent();
      await widget.client.submitRecordedAudio(
        widget.attemptId,
        audioPath: widget.audioPath,
        mimeType: 'audio/m4a',
        fileSizeBytes: widget.fileSizeBytes,
        durationMs: widget.durationMs,
        preferredVoiceId: voiceId.isNotEmpty ? voiceId : null,
      );
      if (!mounted) return;
      setState(() {
        _status = 'processing';
        _localStep = 1;
      });
      // After 2.5s in processing, advance to step 2 (analysing)
      _stepTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && _status == 'processing') {
          setState(() => _localStep = 2);
        }
      });
      _poller = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final attempt = AttemptResult.fromJson(
            await widget.client.getAttempt(widget.attemptId),
          );
          if (!mounted) return;
          setState(() {
            _result = attempt;
            _status = attempt.status;
          });
          if (attempt.status == 'completed' || attempt.status == 'failed') {
            _poller?.cancel();
            _stepTimer?.cancel();
          }
        } catch (err) {
          if (!mounted) return;
          setState(() {
            _status = 'failed';
            _error = err.toString();
          });
          _poller?.cancel();
          _stepTimer?.cancel();
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = 'failed';
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final result = _result;
    final showResult = result != null && result.status == 'completed';
    final showFailure = _status == 'failed';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: showResult || showFailure ? const BackButton() : null,
        title: showResult ? Text(l.analysisScreenTitle) : null,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH(context),
          vertical: AppSpacing.x5,
        ),
        children: [
          if (showResult)
            ResultCard(
              client: widget.client,
              result: result,
              onRetry: () => Navigator.of(context).pop(),
              onNext: widget.onOpenNext == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onOpenNext!();
                    },
            )
          else if (showFailure)
            _FailureBlock(
              title: l.analysisFailedTitle,
              body: _error ?? l.statusCopyFailed,
              retryLabel: l.analysisRetryCta,
              onRetry: () => Navigator.of(context).pop(),
            )
          else
            _ProgressView(localStep: _localStep),
        ],
      ),
    );
  }
}

// ── Progress view ─────────────────────────────────────────────────────────────

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.localStep});
  final int localStep; // 0=uploading, 1=processing, 2=analysing

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
      child: Column(
        children: [
          const _OrbitingRing(),
          const SizedBox(height: AppSpacing.x6),
          Text(
            'AI đang phân tích...',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.x5),
          _StepList(localStep: localStep),
        ],
      ),
    );
  }
}

// ── Orbiting ring animation ───────────────────────────────────────────────────

class _OrbitingRing extends StatefulWidget {
  const _OrbitingRing();

  @override
  State<_OrbitingRing> createState() => _OrbitingRingState();
}

class _OrbitingRingState extends State<_OrbitingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _RingPainter(rotation: _ctrl.value * 2 * math.pi),
          child: Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.rotation});
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Static background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0x14281C10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Animated brand arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      rotation - math.pi / 2,
      math.pi * 1.3, // ~234 degrees
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.rotation != rotation;
}

// ── Step list ─────────────────────────────────────────────────────────────────

enum _StepState { pending, active, done }

class _StepList extends StatelessWidget {
  const _StepList({required this.localStep});
  final int localStep;

  @override
  Widget build(BuildContext context) {
    _StepState stateFor(int idx) {
      if (idx < localStep) return _StepState.done;
      if (idx == localStep) return _StepState.active;
      return _StepState.pending;
    }

    return Column(
      children: [
        _StepRow(label: 'Tải lên', state: stateFor(0)),
        const SizedBox(height: AppSpacing.x3),
        _StepRow(label: 'Chuyển đổi âm thanh', state: stateFor(1)),
        const SizedBox(height: AppSpacing.x3),
        _StepRow(label: 'Phân tích AI', state: stateFor(2)),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepIcon(state: state),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: state == _StepState.pending
                  ? AppColors.outline
                  : AppColors.onSurface,
            ),
          ),
        ),
        Text(
          _statusText(state),
          style: AppTypography.bodySmall.copyWith(color: _statusColor(state)),
        ),
      ],
    );
  }

  String _statusText(_StepState s) => switch (s) {
    _StepState.done    => 'Hoàn tất',
    _StepState.active  => 'Đang xử lý...',
    _StepState.pending => 'Chờ',
  };

  Color _statusColor(_StepState s) => switch (s) {
    _StepState.done    => AppColors.success,
    _StepState.active  => AppColors.primary,
    _StepState.pending => AppColors.outline,
  };
}

// ── Step icon with animation ──────────────────────────────────────────────────

class _StepIcon extends StatefulWidget {
  const _StepIcon({required this.state});
  final _StepState state;

  @override
  State<_StepIcon> createState() => _StepIconState();
}

class _StepIconState extends State<_StepIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_StepIcon old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.state == _StepState.active) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == _StepState.done) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
      );
    }
    if (widget.state == _StepState.active) {
      return ScaleTransition(
        scale: _scale,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    // pending
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.outlineVariant,
          width: 1.5,
        ),
      ),
    );
  }
}

// ── Failure block ─────────────────────────────────────────────────────────────

class _FailureBlock extends StatelessWidget {
  const _FailureBlock({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
  });
  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTypography.titleLarge.copyWith(color: AppColors.error)),
        const SizedBox(height: AppSpacing.x3),
        Text(body, style: AppTypography.bodyMedium),
        const SizedBox(height: AppSpacing.x5),
        PrimaryButton(
          label: retryLabel,
          icon: Icons.arrow_back,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
