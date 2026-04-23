import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Multi-line text input with live word counter.
/// Shows a warning when [wordCount] exceeds [maxWords].
class WritingTextArea extends StatelessWidget {
  const WritingTextArea({
    super.key,
    required this.controller,
    required this.wordCount,
    this.minLines = 6,
    this.maxWords = 250,
    this.hint = 'Viết câu trả lời của bạn ở đây...',
    this.onChanged,
  });

  final TextEditingController controller;
  final int wordCount;
  final int minLines;
  final int maxWords;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOverLimit = wordCount > maxWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: null,
          onChanged: onChanged,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.all(AppSpacing.x4),
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$wordCount / $maxWords từ',
            style: AppTypography.labelSmall.copyWith(
              color: isOverLimit ? AppColors.error : cs.onSurfaceVariant,
              fontWeight:
                  isOverLimit ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
