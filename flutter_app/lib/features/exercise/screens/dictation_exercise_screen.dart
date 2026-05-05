import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../widgets/czech_keyboard_chips.dart';
import '../widgets/dictation_audio_card.dart';
import '../widgets/dictation_result_card.dart';
import '../widgets/exercise_context_image.dart';

/// V18 — Stepper screen for psani_3_dictation.
///
/// Flow per sentence: audio auto-plays once, learner types, taps Next.
/// Last sentence's Next becomes Submit. Submit → createAttempt →
/// submitDictation → push DictationResultPoller (poll → DictationResultCard).
class DictationExerciseScreen extends StatefulWidget {
  const DictationExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
    this.onAttemptCompleted,
    this.showResultOnCompletion = true,
  });

  final ApiClient client;
  final ExerciseDetail detail;
  final FutureOr<void> Function(String attemptId)? onAttemptCompleted;
  final bool showResultOnCompletion;

  @override
  State<DictationExerciseScreen> createState() =>
      _DictationExerciseScreenState();
}

class _DictationExerciseScreenState extends State<DictationExerciseScreen> {
  late final List<TextEditingController> _controllers;
  late final List<int> _replayCounts;
  int _currentIdx = 0;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = widget.detail.dictationSentences.length;
    _controllers = List.generate(n, (_) => TextEditingController());
    _replayCounts = List.filled(n, 0);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canAdvance =>
      _controllers[_currentIdx].text.trim().isNotEmpty && !_submitting;

  bool get _isLast => _currentIdx == widget.detail.dictationSentences.length - 1;

  void _goPrev() {
    if (_currentIdx == 0) return;
    setState(() => _currentIdx -= 1);
  }

  void _goNext() {
    if (!_canAdvance) return;
    if (_isLast) {
      _submit();
    } else {
      setState(() => _currentIdx += 1);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final locale = LocaleScope.of(context).code;
      final attempt = await widget.client.createAttempt(
        widget.detail.id,
        locale: locale,
      );
      final attemptId = attempt['id'] as String;

      final sentences = <DictationSentenceSubmission>[];
      for (int i = 0; i < _controllers.length; i++) {
        sentences.add(DictationSentenceSubmission(
          idx: i,
          text: _controllers[i].text.trim(),
          replayCount: _replayCounts[i],
        ));
      }
      await widget.client.submitDictation(attemptId, sentences: sentences);

      if (!mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _DictationResultPoller(
            client: widget.client,
            attemptId: attemptId,
            showResultOnCompletion: widget.showResultOnCompletion,
          ),
        ),
      );
      if (mounted && (completed ?? widget.showResultOnCompletion)) {
        await widget.onAttemptCompleted?.call(attemptId);
      }
      if (mounted && !widget.showResultOnCompletion && (completed ?? false)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = widget.detail;
    final total = d.dictationSentences.length;
    if (total == 0) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(d.title, style: AppTypography.titleMedium),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Text(
              'Bài này chưa có câu. Vui lòng quay lại sau.',
              style: AppTypography.bodyMedium,
            ),
          ),
        ),
      );
    }

    final sentence = d.dictationSentences[_currentIdx];
    final controller = _controllers[_currentIdx];
    final progress = (_currentIdx + 1) / total;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(d.title, style: AppTypography.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            ExerciseContextImage(detail: d, client: widget.client),
            Row(
              children: [
                Text(
                  l.dictationSentenceLabel(_currentIdx + 1, total),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.onSurface.withValues(alpha: 0.08),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            DictationAudioCard(
              key: ValueKey('audio-$_currentIdx'),
              client: widget.client,
              audioAssetId: sentence.audioAssetId,
              maxReplays: d.dictationMaxReplaysPerSentence,
              sentenceIdx: _currentIdx,
              totalSentences: total,
              initialReplayCount: _replayCounts[_currentIdx],
              onReplayCountChanged: (n) {
                setState(() => _replayCounts[_currentIdx] = n);
              },
            ),
            const SizedBox(height: AppSpacing.x3),
            _InputCard(
              controller: controller,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.x2),
            CzechKeyboardChips(controller: controller),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x3),
              Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.x6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _currentIdx == 0 || _submitting ? null : _goPrev,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: AppColors.onSurface.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(l.dictationPrevBtn),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: FilledButton(
                    onPressed: _canAdvance ? _goNext : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLast ? l.dictationSubmitBtn : l.dictationNextBtn,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.dictationListenInstruction,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            maxLines: 3,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DictationResultPoller extends StatefulWidget {
  const _DictationResultPoller({
    required this.client,
    required this.attemptId,
    required this.showResultOnCompletion,
  });
  final ApiClient client;
  final String attemptId;
  final bool showResultOnCompletion;

  @override
  State<_DictationResultPoller> createState() => _DictationResultPollerState();
}

class _DictationResultPollerState extends State<_DictationResultPoller> {
  AttemptResult? _result;
  String? _error;
  Timer? _timer;
  int _retries = 0;
  static const _maxRetries = 60;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _poll() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (++_retries > _maxRetries) {
        _timer?.cancel();
        if (mounted) {
          setState(() => _error = AppLocalizations.of(context).scoringTimeout);
        }
        return;
      }
      try {
        final raw = await widget.client.getAttempt(widget.attemptId);
        final attempt = AttemptResult.fromJson(raw);
        if (!mounted) return;
        if (attempt.status == 'completed' || attempt.status == 'failed') {
          _timer?.cancel();
          if (!widget.showResultOnCompletion) {
            Navigator.of(context).pop(attempt.status == 'completed');
            return;
          }
          setState(() => _result = attempt);
        }
      } catch (e) {
        _timer?.cancel();
        if (mounted) setState(() => _error = e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Text(
              _error!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final dict = _result?.feedback?.dictationResult;
    if (_result != null && _result!.status == 'completed' && dict != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(child: DictationResultCard(result: dict)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.x4),
            Text(
              AppLocalizations.of(context).scoringInProgress,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
