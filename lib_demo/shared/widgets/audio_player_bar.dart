import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// Custom audio player bar.
/// Matches Stitch HTML: rounded-xl card, primary play button (w-12 h-12 circular),
/// progress bar with draggable handle (primary dot), time display, volume button.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({
    super.key,
    required this.duration,
    this.position = Duration.zero,
    this.isPlaying = false,
    this.onPlayPause,
    this.onSeek,
    this.onRewind,
    this.onFastForward,
    this.showAlbumArt = false,
    this.title,
    this.subtitle,
    this.listenCount,
    this.maxListenCount,
  });

  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onRewind;
  final VoidCallback? onFastForward;
  final bool showAlbumArt;
  final String? title;
  final String? subtitle;
  final int? listenCount;
  final int? maxListenCount;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  double? _dragValue;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds.toDouble();
    final pos = _dragValue ??
        widget.position.inMilliseconds.toDouble().clamp(0, total);
    final progress = total > 0 ? pos / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (widget.showAlbumArt) ...[
            Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                size: 48,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: AppTypography.titleSmall,
              textAlign: TextAlign.center,
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
          ],
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.onRewind != null)
                _ControlButton(
                  icon: Icons.replay_10_rounded,
                  onTap: widget.onRewind,
                ),
              const SizedBox(width: 16),
              // Play/Pause — primary circular button
              GestureDetector(
                onTap: widget.onPlayPause,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              if (widget.onFastForward != null) ...[
                const SizedBox(width: 16),
                _ControlButton(
                  icon: Icons.forward_10_rounded,
                  onTap: widget.onFastForward,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar + time
          Row(
            children: [
              Text(
                _format(Duration(
                    milliseconds: pos.round())),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceContainerHighest,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: widget.onSeek != null
                        ? (v) {
                            setState(() =>
                                _dragValue = v * total);
                          }
                        : null,
                    onChangeEnd: (v) {
                      widget.onSeek?.call(
                          Duration(milliseconds: (v * total).round()));
                      setState(() => _dragValue = null);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _format(widget.duration),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // Listen count (for dictation)
          if (widget.listenCount != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Còn ${widget.maxListenCount! - widget.listenCount!} lần nghe',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
      ),
    );
  }
}
