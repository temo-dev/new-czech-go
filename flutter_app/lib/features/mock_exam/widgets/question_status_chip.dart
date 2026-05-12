import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/exam_section_state.dart';

/// V39 — 64×64 pt cell rendered inside the answer sheet (S6) and
/// progress strip. Pairs colour with an icon so the UI never relies on
/// colour alone (WCAG color-not-only). Tap is wired by the parent.
class QuestionStatusChip extends StatelessWidget {
  const QuestionStatusChip({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
  });

  /// Display order, formatted by the caller (e.g. "1", "12").
  final String label;
  final SectionState state;
  final VoidCallback? onTap;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(state);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: palette.borderColor,
        width: palette.borderWidth,
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: palette.bg,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  label,
                  style: AppTypography.titleMedium.copyWith(
                    color: palette.fg,
                    fontWeight: palette.fontWeight,
                  ),
                ),
              ),
              if (palette.icon != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(palette.icon, size: 14, color: palette.iconColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipPalette {
  const _ChipPalette({
    required this.bg,
    required this.fg,
    required this.borderColor,
    required this.borderWidth,
    required this.fontWeight,
    this.icon,
    this.iconColor,
  });
  final Color bg;
  final Color fg;
  final Color borderColor;
  final double borderWidth;
  final FontWeight fontWeight;
  final IconData? icon;
  final Color? iconColor;
}

_ChipPalette _palette(SectionState state) {
  switch (state) {
    case SectionState.done:
      return _ChipPalette(
        bg: AppColors.successContainer,
        fg: AppColors.success,
        borderColor: AppColors.success,
        borderWidth: 1.5,
        fontWeight: FontWeight.w600,
        icon: Icons.check_rounded,
        iconColor: AppColors.success,
      );
    case SectionState.skipped:
      return _ChipPalette(
        bg: AppColors.surfaceContainer,
        fg: AppColors.onSurfaceVariant,
        borderColor: AppColors.outline,
        borderWidth: 1.5,
        fontWeight: FontWeight.w500,
        icon: Icons.block_rounded,
        iconColor: AppColors.onSurfaceVariant,
      );
    case SectionState.current:
      return _ChipPalette(
        bg: AppColors.primary,
        fg: AppColors.onPrimary,
        borderColor: AppColors.primary,
        borderWidth: 2,
        fontWeight: FontWeight.w700,
        icon: Icons.circle,
        iconColor: AppColors.onPrimary,
      );
    case SectionState.empty:
      return _ChipPalette(
        bg: AppColors.surfaceContainerLowest,
        fg: AppColors.onSurface,
        borderColor: AppColors.outlineVariant,
        borderWidth: 1,
        fontWeight: FontWeight.w500,
      );
  }
}
