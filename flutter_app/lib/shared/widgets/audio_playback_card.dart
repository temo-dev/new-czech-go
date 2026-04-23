import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/api/api_client.dart';
import '../../models/models.dart';

/// Audio playback card for a submitted attempt.
/// Downloads the audio from the backend then plays locally.
class AttemptAudioPlaybackCard extends StatefulWidget {
  const AttemptAudioPlaybackCard({
    super.key,
    required this.client,
    required this.attemptId,
    required this.audio,
  });

  final ApiClient client;
  final String attemptId;
  final AttemptAudioView audio;

  @override
  State<AttemptAudioPlaybackCard> createState() =>
      _AttemptAudioPlaybackCardState();
}

class _AttemptAudioPlaybackCardState
    extends State<AttemptAudioPlaybackCard> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _error;
  bool _loading = true;
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
        setState(() => _position = Duration.zero);
      } else {
        setState(() {});
      }
    });
    _posSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _durSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _errSub = _player.errorStream.listen((e) {
      if (!mounted) return;
      setState(() => _error = 'Không mở được audio: ${e.message}');
    });
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _errSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final tmp = await getTemporaryDirectory();
      final ext = _audioExtension(widget.audio.storageKey, widget.audio.mimeType);
      final file = await widget.client.downloadAttemptAudio(
        widget.attemptId,
        destinationPath: '${tmp.path}/attempt_${widget.attemptId}.$ext',
      );
      final dur = await _player.setFilePath(file.path);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _duration = dur ?? _player.duration;
        _position = Duration.zero;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được audio.';
      });
    }
  }

  Future<void> _toggle() async {
    if (_loading || _error != null) return;
    final dur = _duration ?? _player.duration;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (dur != null && _position >= dur) await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> _seek(double ms) async {
    final dur = _duration;
    if (dur == null) return;
    final target = Duration(milliseconds: ms.round());
    await _player.seek(target > dur ? dur : target);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nghe lại audio đã nộp', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.x3),
          if (_error != null)
            Text(_error!, style: TextStyle(color: AppColors.error))
          else ...[
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: _loading ? null : _toggle,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_player.playing ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: AppSpacing.x3),
                Text(
                  '${_fmt(_position)} / ${_fmt(_duration ?? Duration.zero)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            Slider(
              min: 0,
              max: ((_duration ?? Duration.zero).inMilliseconds.toDouble())
                  .clamp(1, double.infinity),
              value: _duration == null
                  ? 0
                  : _position.inMilliseconds
                      .clamp(0, _duration!.inMilliseconds)
                      .toDouble(),
              onChanged: (_duration == null || _loading)
                  ? null
                  : (v) => unawaited(_seek(v)),
            ),
          ],
        ],
      ),
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _audioExtension(String storageKey, String mimeType) {
  final dot = storageKey.lastIndexOf('.');
  if (dot >= 0 && dot < storageKey.length - 1) return storageKey.substring(dot + 1);
  return switch (mimeType.toLowerCase()) {
    'audio/m4a' || 'audio/x-m4a' || 'audio/mp4a-latm' => 'm4a',
    'audio/mp4'  => 'mp4',
    'audio/mpeg' => 'mp3',
    'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
    _ => 'bin',
  };
}
