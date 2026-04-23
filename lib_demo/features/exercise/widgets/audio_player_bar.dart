import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

enum AudioPlayerState { idle, loading, playing, paused, error }

/// Lightweight inline audio player for listening questions.
///
/// This widget owns its own `just_audio` player so listening prompts work in
/// the exercise/mock-test flow without any extra controller wiring.
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({
    super.key,
    required this.audioUrl,
    this.onPlayPause,
    this.maxPlays,
  });

  final String audioUrl;
  final VoidCallback? onPlayPause;
  final int? maxPlays;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  late final AudioPlayer _player;
  AudioPlayerState _state = AudioPlayerState.idle;
  int _playCount = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Object? _loadError;

  bool get _canPlay => widget.maxPlays == null || _playCount < widget.maxPlays!;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _bindPlayer();
  }

  void _bindPlayer() {
    _player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });

    _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });

    _player.playerStateStream.listen((playerState) {
      if (!mounted) return;
      setState(() {
        if (playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering) {
          _state = AudioPlayerState.loading;
          return;
        }

        if (playerState.processingState == ProcessingState.completed) {
          _state = AudioPlayerState.paused;
          _position = _duration;
          _player.seek(Duration.zero);
          return;
        }

        _state = playerState.playing
            ? AudioPlayerState.playing
            : (_position > Duration.zero
                ? AudioPlayerState.paused
                : AudioPlayerState.idle);
      });
    });

    _player.playbackEventStream.listen((_) {}, onError: (Object error, _) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _state = AudioPlayerState.error;
      });
    });
  }

  Future<void> _toggle() async {
    if (!_canPlay) return;

    widget.onPlayPause?.call();

    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }

      if (_duration == Duration.zero || _loadError != null) {
        setState(() {
          _state = AudioPlayerState.loading;
          _loadError = null;
        });
        await _player.setUrl(widget.audioUrl);
      }

      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }

      setState(() {
        _playCount++;
      });
      await _player.play();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _state = AudioPlayerState.error;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPlaying = _state == AudioPlayerState.playing;
    final remainingCount = widget.maxPlays == null
        ? null
        : (widget.maxPlays! - _playCount).clamp(0, widget.maxPlays!);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _canPlay ? _toggle : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _canPlay ? AppColors.primary : cs.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stateLabel(),
                      style: AppTypography.labelSmall.copyWith(
                        color: _state == AudioPlayerState.error
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _duration.inMilliseconds > 0
                            ? (_position.inMilliseconds /
                                    _duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : (_state == AudioPlayerState.loading ? null : 0.0),
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        color: _state == AudioPlayerState.error
                            ? AppColors.error
                            : AppColors.primary,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              if (remainingCount != null) ...[
                const SizedBox(width: AppSpacing.x3),
                Text(
                  'Còn $remainingCount lần',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ],
          ),
          if (_state == AudioPlayerState.error && _loadError != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Không mở được audio từ nguồn này.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _stateLabel() => switch (_state) {
        AudioPlayerState.idle => 'Nhấn để nghe',
        AudioPlayerState.loading => 'Đang tải...',
        AudioPlayerState.playing => 'Đang phát...',
        AudioPlayerState.paused => 'Tạm dừng',
        AudioPlayerState.error => 'Lỗi phát âm thanh',
      };
}
