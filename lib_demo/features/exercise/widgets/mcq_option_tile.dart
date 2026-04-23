import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/question_model.dart';

enum OptionState { idle, selected, correct, incorrect }

/// MCQ option tile — matches grammar_practice.html Stitch design.
/// Letter circle (rounded-full) + text + trailing check/cancel icon.
class McqOptionTile extends StatelessWidget {
  const McqOptionTile({
    super.key,
    required this.option,
    required this.optionState,
    required this.index,
    this.onTap,
  });

  final QuestionOption option;
  final OptionState optionState;
  final int index; // 0-based, used for A/B/C/D label
  final VoidCallback? onTap;

  static const _labels = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final isIdle = optionState == OptionState.idle;
    final isSelected = optionState == OptionState.selected;
    final isCorrect = optionState == OptionState.correct;
    final isIncorrect = optionState == OptionState.incorrect;

    final bgColor = isSelected
        ? AppColors.primary.withOpacity(0.05)
        : isCorrect
            ? const Color(0xFFECFDF5) // emerald-50
            : isIncorrect
                ? AppColors.errorContainer.withOpacity(0.3)
                : Colors.white;

    final borderColor = isSelected
        ? AppColors.primary
        : isCorrect
            ? const Color(0xFF16A34A) // green-600
            : isIncorrect
                ? AppColors.error
                : AppColors.outlineVariant;

    final borderWidth = isSelected || isCorrect || isIncorrect ? 2.0 : 1.0;

    final letterBg = isSelected
        ? AppColors.primary
        : isCorrect
            ? const Color(0xFF16A34A)
            : isIncorrect
                ? AppColors.error
                : Colors.white;

    final letterBorder = isIdle ? AppColors.outlineVariant : Colors.transparent;

    final letterColor = isIdle ? AppColors.onSurfaceVariant : Colors.white;

    final textColor = isSelected
        ? AppColors.onBackground
        : isCorrect
            ? const Color(0xFF14532D) // green-900
            : isIncorrect
                ? AppColors.error
                : AppColors.onSurfaceVariant;

    final label = index < _labels.length ? _labels[index] : '${index + 1}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Letter circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: letterBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: letterBorder,
                  width: isIdle ? 1.0 : 0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: letterColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Option content (text + optional image)
            Expanded(
              child: option.imageUrl != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (option.text.isNotEmpty) ...[
                          Text(
                            option.text,
                            style: AppTypography.bodyMedium.copyWith(
                              color: textColor,
                              fontWeight: isSelected || isCorrect || isIncorrect
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Image.network(
                            option.imageUrl!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      option.text,
                      style: AppTypography.bodyMedium.copyWith(
                        color: textColor,
                        fontWeight: isSelected || isCorrect || isIncorrect
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 17,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // Trailing icon
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 22)
            else if (isCorrect)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 22)
            else if (isIncorrect)
              const Icon(Icons.cancel_rounded,
                  color: AppColors.error, size: 22),
          ],
        ),
      ),
    );
  }
}
