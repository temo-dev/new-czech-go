import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';

enum TagChipVariant { skill, difficulty, status }

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.variant = TagChipVariant.skill,
    this.color,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final TagChipVariant variant;
  final Color? color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ??
        switch (variant) {
          TagChipVariant.skill => AppColors.secondary.withOpacity(0.1),
          TagChipVariant.difficulty => AppColors.tertiary.withValues(alpha: 0.15),
          TagChipVariant.status => cs.primaryContainer,
        };
    final fg = color != null
        ? Colors.white
        : switch (variant) {
            TagChipVariant.skill => AppColors.secondary,
            TagChipVariant.difficulty => AppColors.tertiary,
            TagChipVariant.status => cs.onPrimaryContainer,
          };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : bg,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: fg.withOpacity(0.3), width: 1),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? Colors.white : fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
