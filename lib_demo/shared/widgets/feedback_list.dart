import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

enum _FeedbackListVariant { strength, improvement }

/// List of strength points (green check) or improvement points (orange arrow).
class StrengthList extends StatelessWidget {
  const StrengthList({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) => _FeedbackList(
        items: items,
        variant: _FeedbackListVariant.strength,
      );
}

class ImprovementList extends StatelessWidget {
  const ImprovementList({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) => _FeedbackList(
        items: items,
        variant: _FeedbackListVariant.improvement,
      );
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({required this.items, required this.variant});

  final List<String> items;
  final _FeedbackListVariant variant;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final isStrength = variant == _FeedbackListVariant.strength;
    final iconColor =
        isStrength ? AppColors.scoreExcellent : AppColors.warning;
    final icon = isStrength
        ? Icons.check_circle_outline_rounded
        : Icons.arrow_circle_up_outlined;

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(item, style: AppTypography.bodySmall),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
