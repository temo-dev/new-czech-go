import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Top section on both SpeakingFeedbackScreen and WritingFeedbackScreen.
class AIFeedbackHeader extends StatelessWidget {
  const AIFeedbackHeader({
    super.key,
    required this.skill,
    required this.overallScore,
    required this.type,
    this.subtitle,
  });

  /// e.g. 'Nói' or 'Viết'
  final String skill;
  final int overallScore;

  /// 'speaking' or 'writing'
  final String type;
  final String? subtitle;

  Color _scoreColor() {
    if (overallScore >= 85) return AppColors.scoreExcellent;
    if (overallScore >= 70) return AppColors.scoreGood;
    if (overallScore >= 50) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor();
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: overallScore / 100,
                  strokeWidth: 6,
                  backgroundColor: cs.outlineVariant,
                  color: color,
                ),
                Text(
                  '$overallScore',
                  style: AppTypography.titleLarge
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kết quả luyện $skill',
                    style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  subtitle ?? _defaultSubtitle(),
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _defaultSubtitle() {
    if (overallScore >= 70) {
      return 'Bạn đang làm rất tốt! Hãy xem phân tích chi tiết.';
    }
    return 'Hãy xem các điểm cần cải thiện bên dưới.';
  }
}
