import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/api/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/models.dart';

/// Audio playback card for a submitted attempt.
/// Streams from a backend-signed URL — no full download.
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
    _errSub = _player.errorStream.listen((e) async {
      if (!mounted) return;
      if (!_refreshedOnError) {
        _refreshedOnError = true;
        try {
          final info = await widget.client.getAttemptAudioUrl(widget.attemptId);
          _stream = info;
          await _player.setUrl(info.url.toString());
          return;
        } catch (_) {
          // fall through to show error
        }
      }
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() => _error = l.attemptAudioOpenError(e.message ?? ''));
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

  AudioStreamInfo? _stream;
  bool _refreshedOnError = false;

  Future<void> _prepare() async {
    try {
      final info = await widget.client.getAttemptAudioUrl(widget.attemptId);
      _stream = info;
      final dur = await _player.setUrl(info.url.toString());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _duration = dur ?? _player.duration;
        _position = Duration.zero;
      });
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = l.attemptAudioLoadError;
      });
    }
  }

  Future<void> _refreshStreamOnError() async {
    if (_refreshedOnError) return;
    _refreshedOnError = true;
    try {
      final info = await widget.client.getAttemptAudioUrl(widget.attemptId);
      _stream = info;
      await _player.setUrl(info.url.toString());
    } catch (_) {
      // leave _error as-is
    }
  }

  Future<void> _toggle() async {
    if (_loading || _error != null) return;
    final dur = _duration ?? _player.duration;
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_stream != null && _stream!.isExpiringSoon) {
      await _refreshStreamOnError();
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
          Text(
            AppLocalizations.of(context).attemptAudioTitle,
            style: AppTypography.titleSmall,
          ),
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

/// Audio playback card for the TTS model-answer audio in a review artifact.
class ReviewAudioPlaybackCard extends StatefulWidget {
  const ReviewAudioPlaybackCard({
    super.key,
    required this.client,
    required this.attemptId,
    required this.audio,
  });

  final ApiClient client;
  final String attemptId;
  final ReviewArtifactAudioView audio;

  @override
  State<ReviewAudioPlaybackCard> createState() => _ReviewAudioPlaybackCardState();
}

class _ReviewAudioPlaybackCardState extends State<ReviewAudioPlaybackCard> {
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
    _errSub = _player.errorStream.listen((e) async {
      if (!mounted) return;
      if (!_refreshedOnError) {
        _refreshedOnError = true;
        try {
          final info =
              await widget.client.getAttemptReviewAudioUrl(widget.attemptId);
          _stream = info;
          await _player.setUrl(info.url.toString());
          return;
        } catch (_) {
          // fall through
        }
      }
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() => _error = l.reviewAudioOpenError(e.message ?? ''));
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

  AudioStreamInfo? _stream;
  bool _refreshedOnError = false;

  Future<void> _prepare() async {
    try {
      final info =
          await widget.client.getAttemptReviewAudioUrl(widget.attemptId);
      _stream = info;
      final dur = await _player.setUrl(info.url.toString());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _duration = dur ?? _player.duration;
        _position = Duration.zero;
      });
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = l.reviewAudioLoadError;
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
    if (_stream != null && _stream!.isExpiringSoon) {
      try {
        final info =
            await widget.client.getAttemptReviewAudioUrl(widget.attemptId);
        _stream = info;
        await _player.setUrl(info.url.toString());
      } catch (_) {}
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
        color: AppColors.primaryFixed,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).reviewAudioTitle,
            style: AppTypography.titleSmall,
          ),
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

