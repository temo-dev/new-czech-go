import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Circular score badge coloured by performance band.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.score,    // 0–100
    this.size = 56,
    this.showPercent = true,
  });

  final int score;
  final double size;
  final bool showPercent;

  Color get _color {
    if (score >= 85) return AppColors.scoreExcellent;
    if (score >= 70) return AppColors.scoreGood;
    if (score >= 50) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color.withOpacity(0.12),
        border: Border.all(color: _color, width: 2),
      ),
      child: Center(
        child: Text(
          showPercent ? '$score%' : '$score',
          style: AppTypography.labelMedium.copyWith(
            color: _color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
