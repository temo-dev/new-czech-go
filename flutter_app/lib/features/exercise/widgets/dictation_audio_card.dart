import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// V18 — DictationAudioCard plays one sentence MP3 at a time and tracks
/// learner-initiated replays.
///
/// Auto-plays once on mount (the first auto-play does NOT count toward the
/// replay cap). Subsequent taps on the play button each increment
/// [_replayCount] and emit it via [onReplayCountChanged]. When
/// [maxReplays] > 0 and [_replayCount] >= [maxReplays], the play button
/// disables and a red "Hết lượt" pill replaces the orange counter.
class DictationAudioCard extends StatefulWidget {
  const DictationAudioCard({
    super.key,
    required this.client,
    required this.audioAssetId,
    required this.maxReplays,
    required this.sentenceIdx,
    required this.totalSentences,
    this.initialReplayCount = 0,
    this.onReplayCountChanged,
  });

  final ApiClient client;
  final String audioAssetId;
  final int maxReplays; // 0 = unlimited
  final int sentenceIdx; // 0-based
  final int totalSentences;
  final int initialReplayCount;
  final ValueChanged<int>? onReplayCountChanged;

  @override
  State<DictationAudioCard> createState() => _DictationAudioCardState();
}

class _DictationAudioCardState extends State<DictationAudioCard> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  bool _loading = true;
  bool _error = false;
  bool _playing = false;
  bool _autoPlayed = false;
  late int _replayCount;

  @override
  void initState() {
    super.initState();
    _replayCount = widget.initialReplayCount;
    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = dictationAudioShowsPause(s));
    });
    _load();
  }

  @override
  void didUpdateWidget(covariant DictationAudioCard old) {
    super.didUpdateWidget(old);
    if (old.audioAssetId != widget.audioAssetId ||
        old.sentenceIdx != widget.sentenceIdx) {
      _autoPlayed = false;
      _replayCount = widget.initialReplayCount;
      _load();
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.audioAssetId.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          widget.client.mediaUri(widget.audioAssetId),
          headers: widget.client.authHeaders,
        ),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (!_autoPlayed) {
        _autoPlayed = true;
        await _player.seek(Duration.zero);
        await _player.play();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  bool get _isCapped =>
      widget.maxReplays > 0 && _replayCount >= widget.maxReplays;

  Future<void> _onReplay() async {
    if (_loading || _error || _isCapped) return;
    setState(() => _replayCount += 1);
    widget.onReplayCountChanged?.call(_replayCount);
    await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pillBg =
        _isCapped
            ? AppColors.error.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.12);
    final pillColor = _isCapped ? AppColors.error : AppColors.primary;
    final pillText =
        _isCapped
            ? l.dictationRepeatExhausted
            : widget.maxReplays > 0
            ? l.dictationRepeatRemaining(widget.maxReplays - _replayCount)
            : '∞';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surface, width: 0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _PlayButton(
            playing: _playing,
            disabled: _loading || _error || _isCapped,
            onTap: _onReplay,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dictationSentenceLabel(
                    widget.sentenceIdx + 1,
                    widget.totalSentences,
                  ),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _error
                      ? l.audioError
                      : _loading
                      ? l.audioLoading
                      : l.dictationListenInstruction,
                  style: AppTypography.bodySmall.copyWith(
                    color: _error ? AppColors.error : AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pillText,
              style: AppTypography.labelMedium.copyWith(
                color: pillColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
bool dictationAudioShowsPause(PlayerState state) {
  return state.playing && state.processingState != ProcessingState.completed;
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.disabled,
    required this.onTap,
  });
  final bool playing;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Phát lại câu',
      button: true,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color:
                disabled
                    ? AppColors.onSurface.withValues(alpha: 0.16)
                    : AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
