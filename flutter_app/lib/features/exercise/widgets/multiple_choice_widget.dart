import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';

/// Renders A-D (or A-G) multiple-choice options for a single question.
class MultipleChoiceWidget extends StatelessWidget {
  const MultipleChoiceWidget({
    super.key,
    required this.questionNo,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final int questionNo;
  final List<PoslechOptionView> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$questionNo.', style: AppTypography.labelLarge),
        const SizedBox(height: 6),
        ...options.map((opt) {
          final isSelected = selected == opt.key;
          return GestureDetector(
            onTap: () => onSelect(opt.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    opt.key,
                    style: AppTypography.labelLarge.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      opt.text.isNotEmpty
                          ? opt.text
                          : opt.label.isNotEmpty
                              ? opt.label
                              : opt.assetId,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
