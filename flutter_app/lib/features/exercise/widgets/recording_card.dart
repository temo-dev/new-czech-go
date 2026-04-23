import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/info_pill.dart';

/// Recording state card: status badge + timer + progress bar + play/stop CTAs.
/// Local playback (after recording) is included in the same card.
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
  bool get _isProcessing =>
      status == 'uploading' || status == 'processing';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
          Row(
            children: [
              InfoPill(
                label: _statusLabel(l, status),
                tone: _statusTone(status),
              ),
              if (_isRecording) ...[
                const SizedBox(width: AppSpacing.x3),
                _RecordingDot(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            '${seconds}s',
            style: AppTypography.scoreDisplay.copyWith(
              color: _isRecording ? AppColors.primary : AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          LinearProgressIndicator(
            value: (seconds / 45).clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: AppRadius.fullAll,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(
              _isRecording ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            _statusCopy(l, status),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x5),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else if (_isStopped)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onAnalyze,
                    child: Text(l.recordCtaAnalyze),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRerecord,
                    child: Text(l.recordCtaRerecord),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _canStart ? onStart : null,
                    child: Text(l.recordCtaStart),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRecording ? onStop : null,
                    child: Text(l.recordCtaStop),
                  ),
                ),
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              error!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          if (playbackPath != null) ...[
            const SizedBox(height: AppSpacing.x5),
            const Divider(),
            const SizedBox(height: AppSpacing.x4),
            Text(l.playbackTitle, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.x3),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: playbackError == null ? onTogglePlayback : null,
                  child: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: AppSpacing.x3),
                Text(
                  '${_fmt(playbackPosition)} / ${_fmt(playbackDuration ?? Duration.zero)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Slider(
              min: 0,
              max: ((playbackDuration ?? Duration.zero).inMilliseconds.toDouble())
                  .clamp(1, double.infinity),
              value: playbackDuration == null
                  ? 0
                  : playbackPosition.inMilliseconds
                      .clamp(0, playbackDuration!.inMilliseconds)
                      .toDouble(),
              onChanged: playbackDuration == null
                  ? null
                  : (v) => onSeek(v),
            ),
            if (playbackError != null)
              Text(
                playbackError!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
          ],
        ],
      ),
    );
  }
}

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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

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

PillTone _statusTone(String status) => switch (status) {
      'recording'  => PillTone.error,
      'stopped'    => PillTone.info,
      'completed'  => PillTone.success,
      'failed'     => PillTone.error,
      'uploading' || 'processing' => PillTone.warning,
      _            => PillTone.neutral,
    };

String _statusCopy(AppLocalizations l, String status) => switch (status) {
      'ready'      => l.recordHintReady,
      'recording'  => l.recordHintRecording,
      'stopped'    => l.recordHintStopped,
      'uploading'  => l.recordHintUploading,
      'processing' => l.recordHintProcessing,
      'completed'  => l.recordHintCompleted,
      'failed'     => l.recordHintFailed,
      _            => '',
    };

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
