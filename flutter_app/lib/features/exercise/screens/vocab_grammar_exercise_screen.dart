import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../widgets/matching_widget.dart';
import '../widgets/multiple_choice_widget.dart';
import '../widgets/objective_result_card.dart';
import '../widgets/quizcard_widget.dart';

/// Routes vocab/grammar exercises to the correct sub-widget.
///
/// Types: quizcard_basic → QuizcardWidget (self-assessed)
///        matching / fill_blank / choice_word → submit-answers flow + ObjectiveResultCard
class VocabGrammarExerciseScreen extends StatefulWidget {
  const VocabGrammarExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
    this.onOpenNext,
  });

  final ApiClient client;
  final ExerciseDetail detail;
  final VoidCallback? onOpenNext;

  @override
  State<VocabGrammarExerciseScreen> createState() => _VocabGrammarExerciseScreenState();
}

class _VocabGrammarExerciseScreenState extends State<VocabGrammarExerciseScreen> {
  final Map<String, String> _answers = {};
  bool _submitting = false;
  String? _submitError;
  AttemptResult? _result;

  // For fill_blank: single text controller
  final _fillController = TextEditingController();

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  // quizcard: always score 1/1, store known/review
  Future<void> _submitQuizcard(String choice) async {
    setState(() { _submitting = true; _submitError = null; });
    try {
      final attempt = await widget.client.createAttempt(widget.detail.id, locale: 'vi');
      final attemptId = attempt['id'] as String;
      final raw = await widget.client.submitAnswers(attemptId, {'1': choice});
      if (!mounted) return;
      setState(() => _result = AttemptResult.fromJson(raw));
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _submitError = e.toString(); });
    }
  }

  // matching / fill_blank / choice_word
  Future<void> _submit() async {
    if (_submitting) return;
    setState(() { _submitting = true; _submitError = null; });
    try {
      final attempt = await widget.client.createAttempt(widget.detail.id, locale: 'vi');
      final attemptId = attempt['id'] as String;
      final raw = await widget.client.submitAnswers(attemptId, _answers);
      if (!mounted) return;
      setState(() => _result = AttemptResult.fromJson(raw));
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _submitError = e.toString(); });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _canSubmit {
    final d = widget.detail;
    if (d.isMatching) {
      return _answers.length == d.matchingPairs.length &&
          _answers.values.every((v) => v.isNotEmpty);
    }
    if (d.isFillBlank) return _answers['1']?.isNotEmpty == true;
    if (d.isChoiceWord) return _answers['1']?.isNotEmpty == true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final l = AppLocalizations.of(context);

    // quizcard done screen
    if (_result != null && d.isQuizcard) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✓', style: TextStyle(fontSize: 64, color: Color(0xFF1F8A4D))),
              const SizedBox(height: 12),
              Text(l.vocabDone, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              if (widget.onOpenNext != null)
                FilledButton(
                  onPressed: widget.onOpenNext,
                  child: const Text('Bài tiếp theo →'),
                )
              else
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tiếp tục'),
                ),
            ],
          ),
        ),
      );
    }

    // other types: result screen
    if (_result != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(l.resultScreenTitle, style: AppTypography.titleMedium),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ObjectiveResultCard(
                  result: _result!,
                  onRetry: () => setState(() { _result = null; _answers.clear(); _fillController.clear(); }),
                ),
                // Show explanation if available
                if (d.fillBlankExplanation.isNotEmpty || d.choiceWordExplanation.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x4),
                  _ExplanationCard(
                    explanation: d.isFillBlank ? d.fillBlankExplanation : d.choiceWordExplanation,
                    note: d.isChoiceWord ? d.choiceWordGrammarNote : null,
                    l: l,
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                // Next exercise OR done button — always visible so user can exit
                SizedBox(
                  width: double.infinity,
                  child: widget.onOpenNext != null
                      ? FilledButton(
                          onPressed: widget.onOpenNext,
                          child: const Text('Bài tiếp theo →'),
                        )
                      : FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1F8A4D),
                          ),
                          child: const Text('Hoàn thành ✓'),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(d.title, style: AppTypography.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quizcard
              if (d.isQuizcard)
                QuizcardWidget(
                  front: d.flashcardFront,
                  back: d.flashcardBack,
                  example: d.flashcardExample.isNotEmpty ? d.flashcardExample : null,
                  exampleTranslation: d.flashcardExampleTranslation.isNotEmpty ? d.flashcardExampleTranslation : null,
                  submitting: _submitting,
                  onChoice: _submitQuizcard,
                ),

              // Matching
              if (d.isMatching) ...[
                Text(l.vocabMatchInstruction, style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.x4),
                MatchingWidget(
                  pairs: d.matchingPairs,
                  answers: _answers,
                  onChanged: (leftId, rightId) => setState(() => _answers[leftId] = rightId),
                ),
                const SizedBox(height: AppSpacing.x4),
                _SubmitButton(canSubmit: _canSubmit, submitting: _submitting, onSubmit: _submit),
              ],

              // Fill blank
              if (d.isFillBlank) ...[
                Text(l.vocabFillInstruction, style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.x3),
                _FillBlankInput(
                  sentence: d.fillBlankSentence,
                  hint: d.fillBlankHint,
                  onChanged: (v) => setState(() => _answers['1'] = v),
                ),
                const SizedBox(height: AppSpacing.x4),
                _SubmitButton(canSubmit: _canSubmit, submitting: _submitting, onSubmit: _submit),
              ],

              // Choice word
              if (d.isChoiceWord) ...[
                if (d.choiceWordGrammarNote.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    margin: const EdgeInsets.only(bottom: AppSpacing.x3),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.secondary.withAlpha(60)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d.choiceWordGrammarNote, style: AppTypography.bodySmall.copyWith(color: AppColors.secondary))),
                    ]),
                  ),
                Text(d.choiceWordStem.isNotEmpty ? d.choiceWordStem : l.vocabChoiceInstruction,
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.x4),
                MultipleChoiceWidget(
                  questionNo: 1,
                  options: d.poslechOptions,
                  selected: _answers['1'],
                  onSelect: (key) => setState(() => _answers['1'] = key),
                ),
                const SizedBox(height: AppSpacing.x4),
                _SubmitButton(canSubmit: _canSubmit, submitting: _submitting, onSubmit: _submit),
              ],

              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x3),
                  child: Text(_submitError!, style: const TextStyle(color: Color(0xFFC03A28), fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.canSubmit, required this.submitting, required this.onSubmit});
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: canSubmit && !submitting ? onSubmit : null,
        child: Text(submitting ? 'Đang nộp...' : AppLocalizations.of(context).submitAnswersCta),
      ),
    );
  }
}

class _FillBlankInput extends StatelessWidget {
  const _FillBlankInput({required this.sentence, required this.hint, required this.onChanged});
  final String sentence;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final parts = sentence.split('___');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.length > 1)
          RichText(
            text: TextSpan(
              style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
              children: [
                TextSpan(text: parts[0]),
                WidgetSpan(
                  child: Container(
                    width: 80, height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                ),
                if (parts.length > 1) TextSpan(text: parts[1]),
              ],
            ),
          )
        else
          Text(sentence, style: AppTypography.bodyLarge),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          autofocus: true,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint.isNotEmpty ? hint : 'Điền câu trả lời...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.explanation, this.note, required this.l});
  final String explanation;
  final String? note;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.vocabExplanation, style: AppTypography.labelUppercase.copyWith(color: AppColors.primary, fontSize: 10)),
          const SizedBox(height: 6),
          Text(explanation, style: AppTypography.bodyMedium),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note!, style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
