import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Flashcard with flip animation.
/// Front: optional image + Czech term + V37 optional Polly TTS mic. Back: Vietnamese definition + optional example.
/// After flip: [Đã biết ✓] and [Ôn lại ↺] buttons.
class QuizcardWidget extends StatefulWidget {
  const QuizcardWidget({
    super.key,
    required this.front,
    required this.back,
    this.example,
    this.exampleTranslation,
    this.imageUrl,
    this.audioUrl,
    this.authHeaders,
    required this.submitting,
    required this.onChoice,
  });

  final String front;
  final String back;
  final String? example;
  final String? exampleTranslation;
  /// Storage key URL for the flashcard image. Null = no image.
  final String? imageUrl;
  /// V37: signed URL for the Polly Czech audio of `front`. Null = no audio
  /// (admin has not generated TTS for this vocab item yet).
  final String? audioUrl;
  final Map<String, String>? authHeaders;
  final bool submitting;
  final void Function(String choice) onChoice; // "known" | "review"

  @override
  State<QuizcardWidget> createState() => _QuizcardWidgetState();
}

class _QuizcardWidgetState extends State<QuizcardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipped) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() => _flipped = !_flipped);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        // Card
        GestureDetector(
          onTap: _flip,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final angle = _animation.value * math.pi;
              final isFront = angle < math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isFront ? _FrontFace(text: widget.front, hint: l.vocabFlip, imageUrl: widget.imageUrl, audioUrl: widget.audioUrl, authHeaders: widget.authHeaders) : _BackFace(
                  back: widget.back,
                  example: widget.example,
                  exampleTranslation: widget.exampleTranslation,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.x5),

        // Hint before flip
        if (!_flipped)
          Text(l.vocabFlip, style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),

        // Buttons after flip
        if (_flipped) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.submitting ? null : () => widget.onChoice('review'),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.vocabReview),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.submitting ? null : () => widget.onChoice('known'),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l.vocabKnown),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF1F8A4D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FrontFace extends StatefulWidget {
  const _FrontFace({
    required this.text,
    required this.hint,
    this.imageUrl,
    this.audioUrl,
    this.authHeaders,
  });
  final String text;
  final String hint;
  final String? imageUrl;
  final String? audioUrl;
  final Map<String, String>? authHeaders;

  @override
  State<_FrontFace> createState() => _FrontFaceState();
}

class _FrontFaceState extends State<_FrontFace> {
  AudioPlayer? _player;
  bool _playing = false;

  bool get _hasAudio => widget.audioUrl != null && widget.audioUrl!.isNotEmpty;

  Future<void> _play() async {
    if (!_hasAudio || _playing) return;
    final p = _player ??= AudioPlayer();
    setState(() => _playing = true);
    try {
      await p.setAudioSource(AudioSource.uri(
        Uri.parse(widget.audioUrl!),
        headers: widget.authHeaders ?? const {},
      ));
      await p.play();
    } catch (_) {
      // swallow — UI shows the static mic icon either way.
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    final card = Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: hasImage ? 280 : 220),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x14141410), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                widget.imageUrl!,
                headers: widget.authHeaders ?? const {},
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(height: 160, color: const Color(0xFFF5F0EA),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.text, style: AppTypography.titleLarge.copyWith(fontSize: 32, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.x3),
                const Icon(Icons.touch_app_outlined, size: 20, color: Color(0xFFBCB2A6)),
              ],
            ),
          ),
        ],
      ),
    );
    if (!_hasAudio) return card;
    return Stack(
      children: [
        card,
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: AppColors.interviewContainer,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('quizcard_audio_button'),
              customBorder: const CircleBorder(),
              onTap: _play,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  _playing ? Icons.graphic_eq : Icons.volume_up_outlined,
                  size: 20,
                  color: AppColors.interview,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackFace extends StatelessWidget {
  const _BackFace({required this.back, this.example, this.exampleTranslation});
  final String back;
  final String? example;
  final String? exampleTranslation;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.secondary.withAlpha(20),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.secondary.withAlpha(80)),
          boxShadow: const [BoxShadow(color: Color(0x14141410), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(back, style: AppTypography.titleLarge.copyWith(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.secondary), textAlign: TextAlign.center),
            if (example != null && example!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(example!, style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
              if (exampleTranslation != null && exampleTranslation!.isNotEmpty)
                Text(exampleTranslation!, style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
