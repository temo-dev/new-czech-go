import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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
  final VoidCallback onTogglePlayback;
  final ValueChanged<double> onSeek;

  bool get _canStart => status == 'ready';
  bool get _isRecording => status == 'recording';
  bool get _isProcessing =>
      status == 'uploading' || status == 'processing';

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
          Row(
            children: [
              InfoPill(
                label: _statusLabel(status),
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
            _statusCopy(status),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x5),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _canStart ? onStart : null,
                    child: const Text('Bắt đầu luyện'),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRecording ? onStop : null,
                    child: const Text('Dừng & phân tích'),
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
            Text('Nghe lại bản ghi', style: AppTypography.titleSmall),
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

String _statusLabel(String status) => switch (status) {
      'ready'      => 'SẴN SÀNG',
      'recording'  => 'ĐANG GHI',
      'uploading'  => 'ĐANG TẢI LÊN',
      'processing' => 'ĐANG XỬ LÝ',
      'completed'  => 'HOÀN THÀNH',
      'failed'     => 'LỖI',
      _            => status.toUpperCase(),
    };

PillTone _statusTone(String status) => switch (status) {
      'recording'  => PillTone.error,
      'completed'  => PillTone.success,
      'failed'     => PillTone.error,
      'uploading' || 'processing' => PillTone.warning,
      _            => PillTone.neutral,
    };

String _statusCopy(String status) => switch (status) {
      'ready'      => 'Nhấn "Bắt đầu luyện" khi sẵn sàng.',
      'recording'  => 'Tập trung vào sự rõ ràng và trả lời đúng ý chính.',
      'uploading'  => 'Đang đóng gói bản ghi để gửi lên pipeline.',
      'processing' => 'Hệ thống đang transcript và tổng hợp feedback.',
      'completed'  => 'Feedback đã sẵn sàng. Hãy đọc kết quả và thử lại.',
      'failed'     => 'Attempt gặp lỗi. Thử lại với một lần ghi mới.',
      _            => '',
    };

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
