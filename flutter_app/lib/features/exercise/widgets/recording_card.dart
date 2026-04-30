import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';


/// Recording state card — Stitch-inspired layout.
/// Large timer, animated waveform, prominent stop/analyze actions.
class RecordingCard extends StatelessWidget {
  const RecordingCard({
    super.key,
    required this.status,
    required this.seconds,
    required this.player,
    required this.playbackPath,
    required this.playbackPosition,
    required this.playbackDuration,
    required this.playbackError,
    required this.error,
    required this.onStart,
    required this.onStop,
    required this.onAnalyze,
    required this.onRerecord,
    required this.onTogglePlayback,
    required this.onSeek,
  });

  final String status;
  final int seconds;
  final AudioPlayer player;
  final String? playbackPath;
  final Duration playbackPosition;
  final Duration? playbackDuration;
  final String? playbackError;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onAnalyze;
  final VoidCallback onRerecord;
  final VoidCallback onTogglePlayback;
  final ValueChanged<double> onSeek;

  bool get _canStart => status == 'ready';
  bool get _isRecording => status == 'recording';
  bool get _isStopped => status == 'stopped';
  bool get _isProcessing => status == 'uploading' || status == 'processing';

  String _timerText() {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Column(
      children: [
        // ── Timer area ────────────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.x6),
        Text(
          _timerText(),
          style: AppTypography.scoreDisplay.copyWith(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: _isRecording ? AppColors.onSurface : AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        if (_isRecording)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _RecordingDot(),
            const SizedBox(width: 6),
            Text('NAHRÁVÁNÍ',
                style: AppTypography.labelUppercase.copyWith(
                    color: AppColors.rec, fontSize: 11, letterSpacing: 1.5)),
          ])
        else
          Text(
            _statusLabel(l, status),
            style: AppTypography.labelUppercase.copyWith(
                color: AppColors.onSurfaceVariant, fontSize: 11, letterSpacing: 1.2),
          ),

        // ── Waveform ──────────────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.x6),
        SizedBox(
          height: 64,
          child: _isRecording
              ? const _AnimatedWaveform()
              : _StaticWaveform(filled: _isStopped),
        ),
        const SizedBox(height: AppSpacing.x6),

        // ── Main action ───────────────────────────────────────────────────────
        if (_isProcessing) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.x3),
          Text(l.recordHintUploading,
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
        ] else if (_canStart) ...[
          // Start recording button
          _BigRoundButton(
            color: AppColors.primary,
            icon: Icons.mic_rounded,
            onTap: onStart,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(l.recordHintTapToStart,
              style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onSurfaceVariant, fontSize: 10, letterSpacing: 1.2)),
        ] else if (_isRecording) ...[
          // Stop button
          _BigRoundButton(
            color: AppColors.rec,
            icon: Icons.stop_rounded,
            onTap: onStop,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(l.recordHintTapToStop,
              style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onSurfaceVariant, fontSize: 10, letterSpacing: 1.2)),
        ],

        if (error != null) ...[
          const SizedBox(height: AppSpacing.x3),
          Text(error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              textAlign: TextAlign.center),
        ],

        // ── Stopped actions ───────────────────────────────────────────────────
        if (_isStopped) ...[
          const SizedBox(height: AppSpacing.x5),
          _CoachTip(text: l.recordHintStopped),
          const SizedBox(height: AppSpacing.x5),
          // Bottom action bar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.lgAll,
            ),
            child: Column(
              children: [
                Row(children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('NAHRÁVKA PŘIPRAVENA',
                      style: AppTypography.labelUppercase.copyWith(
                          fontSize: 10, color: AppColors.success, letterSpacing: 1)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onRerecord,
                    child: Text(l.recordCtaRerecord,
                        style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: AppSpacing.x3),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: playbackPath != null && playbackError == null
                          ? onTogglePlayback
                          : null,
                      icon: Icon(
                          player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 18),
                      label: Text(l.playbackTitle),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAnalyze,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(l.recordCtaAnalyze),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Playback slider
          if (playbackPath != null && playbackDuration != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Row(children: [
              Text(_fmt(playbackPosition),
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    min: 0,
                    max: playbackDuration!.inMilliseconds.toDouble().clamp(1, double.infinity),
                    value: playbackPosition.inMilliseconds
                        .clamp(0, playbackDuration!.inMilliseconds)
                        .toDouble(),
                    onChanged: (v) => onSeek(v),
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.outlineVariant,
                  ),
                ),
              ),
              Text(_fmt(playbackDuration!),
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant, fontSize: 11)),
            ]),
          ],
        ],

        const SizedBox(height: AppSpacing.x4),
      ],
    );
  }
}

// ── Big round action button ──────────────────────────────────────────────────

class _BigRoundButton extends StatelessWidget {
  const _BigRoundButton({required this.color, required this.icon, required this.onTap});
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withAlpha(60), blurRadius: 20, spreadRadius: 4)],
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }
}

// ── Animated waveform bars ───────────────────────────────────────────────────

class _AnimatedWaveform extends StatefulWidget {
  const _AnimatedWaveform();

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const int _bars = 24;
  final _rng = math.Random(42);
  late List<double> _phases;

  @override
  void initState() {
    super.initState();
    _phases = List.generate(_bars, (i) => _rng.nextDouble() * math.pi * 2);
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_bars, (i) {
            final t = _ctrl.value * math.pi * 2;
            final h = (math.sin(t + _phases[i]) * 0.5 + 0.5);
            final height = 8 + h * 48;
            final isCenter = i > _bars * 0.3 && i < _bars * 0.7;
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isCenter
                    ? AppColors.primary
                    : AppColors.primary.withAlpha(120),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _StaticWaveform extends StatelessWidget {
  const _StaticWaveform({required this.filled});
  final bool filled;

  static const _heights = [
    0.3, 0.5, 0.8, 0.6, 0.9, 0.7, 0.4, 0.8, 1.0, 0.7, 0.5, 0.9,
    0.6, 0.8, 0.4, 0.7, 1.0, 0.6, 0.8, 0.5, 0.9, 0.6, 0.4, 0.3,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(_heights.length, (i) {
        final h = _heights[i];
        return Container(
          width: 3,
          height: 8 + h * 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: filled
                ? AppColors.outlineVariant
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ── Coach tip ────────────────────────────────────────────────────────────────

class _CoachTip extends StatelessWidget {
  const _CoachTip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.x2),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).recordingCoachTip,
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(text,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.onPrimaryFixed)),
            ],
          )),
        ],
      ),
    );
  }
}

// ── Blinking recording dot ────────────────────────────────────────────────────

class _RecordingDot extends StatefulWidget {
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(color: AppColors.rec, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _statusLabel(AppLocalizations l, String status) => switch (status) {
  'ready'      => l.recordStatusReady,
  'recording'  => l.recordStatusRecording,
  'stopped'    => l.recordStatusStopped,
  'uploading'  => l.recordStatusUploading,
  'processing' => l.recordStatusProcessing,
  'completed'  => l.recordStatusCompleted,
  'failed'     => l.recordStatusFailed,
  _            => status.toUpperCase(),
};


String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
