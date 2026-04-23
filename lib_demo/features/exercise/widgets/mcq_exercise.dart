import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'mcq_option_tile.dart';

class McqExercise extends StatelessWidget {
  const McqExercise({
    super.key,
    required this.question,
    this.selectedOptionId,
    this.isSubmitted = false,
    this.onSelect,
  });

  final Question question;
  final String? selectedOptionId;
  final bool isSubmitted;
  final ValueChanged<String>? onSelect;

  OptionState _stateFor(QuestionOption opt) {
    if (!isSubmitted) {
      return selectedOptionId == opt.id
          ? OptionState.selected
          : OptionState.idle;
    }
    // After submit: show correct/incorrect
    if (opt.isCorrect) return OptionState.correct;
    if (opt.id == selectedOptionId && !opt.isCorrect) {
      return OptionState.incorrect;
    }
    return OptionState.idle;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question image
        if (question.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.network(
              question.imageUrl!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
        ],
        // Prompt
        Text(
          question.prompt,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.x5),
        // Options
        ...question.options.asMap().entries.map(
              (e) => McqOptionTile(
                key: ValueKey('mcq_option_${question.id}_${e.key}'),
                option: e.value,
                optionState: _stateFor(e.value),
                index: e.key,
                onTap: isSubmitted ? null : () => onSelect?.call(e.value.id),
              ),
            ),
      ],
    );
  }
}
