import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/mock_test/models/mock_test_result.dart';
import 'package:app_czech/shared/utils/skill_labels.dart';
import 'package:app_czech/shared/widgets/progress_ring.dart';

/// Card showing the user's most recent exam result.
class LatestResultCard extends StatelessWidget {
  const LatestResultCard({super.key, required this.result});

  final MockTestResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPending = result.aiGradingPending;
    final scoreColor = isPending ? AppColors.primary : _scoreColor(result.band);
    final passed = result.passed;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.mockTestResultPath(result.attemptId),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            // Score ring
            ProgressRing(
              value: isPending ? 0 : result.totalScore / 100,
              size: 64,
              strokeWidth: 6,
              color: scoreColor,
              label: isPending ? '...' : '${result.totalScore}',
              labelStyle: AppTypography.titleMedium.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Kết quả thi thử',
                        style: AppTypography.titleSmall,
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      isPending
                          ? const _PendingBadge()
                          : _PassBadge(passed: passed),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    isPending
                        ? 'AI đang hoàn tất chấm bài thi'
                        : _formatDate(result.createdAt),
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (!isPending && result.sectionScores.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x2),
                    _SectionMiniBar(sectionScores: result.sectionScores),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(ScoreBand band) => switch (band) {
        ScoreBand.excellent => AppColors.scoreExcellent,
        ScoreBand.good => AppColors.scoreGood,
        ScoreBand.fair => AppColors.scoreFair,
        ScoreBand.poor => AppColors.scorePoor,
      };

  String _formatDate(DateTime dt) {
    final months = [
      'tháng 1',
      'tháng 2',
      'tháng 3',
      'tháng 4',
      'tháng 5',
      'tháng 6',
      'tháng 7',
      'tháng 8',
      'tháng 9',
      'tháng 10',
      'tháng 11',
      'tháng 12',
    ];
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        'Đang chấm',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _PassBadge extends StatelessWidget {
  const _PassBadge({required this.passed});
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final bg = passed ? AppColors.successContainer : AppColors.errorContainer;
    final fg = passed ? AppColors.success : AppColors.error;
    final label = passed ? 'Đạt' : 'Chưa đạt';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: fg)),
    );
  }
}

class _SectionMiniBar extends StatelessWidget {
  const _SectionMiniBar({required this.sectionScores});
  final Map<String, SectionResult> sectionScores;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = sectionScores.entries.take(4).toList();

    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x1,
      children: entries.map((e) {
        final pct = e.value.percentage * 100;
        return Text(
          '${SkillLabels.forKey(e.key)}: ${pct.round()}%',
          style: AppTypography.labelSmall.copyWith(
            color: cs.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }
}
