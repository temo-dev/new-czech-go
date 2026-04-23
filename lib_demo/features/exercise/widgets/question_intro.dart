import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/question_model.dart';

/// Renders the optional intro block shown above a question prompt.
/// Displays [Question.introImageUrl] (if any) above [Question.introText]
/// (if any), inside a warm-tinted container that visually separates
/// context from the actual question.
class QuestionIntro extends StatelessWidget {
  const QuestionIntro({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final hasImage = question.introImageUrl != null;
    final hasText = question.introText != null && question.introText!.isNotEmpty;

    if (!hasImage && !hasText) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceContainerHigh, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            Image.network(
              question.introImageUrl!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          if (hasText)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x4,
                hasImage ? AppSpacing.x3 : AppSpacing.x4,
                AppSpacing.x4,
                AppSpacing.x4,
              ),
              child: Text(
                question.introText!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
