import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/mock_test/models/exam_analysis.dart';
import 'package:app_czech/shared/utils/skill_labels.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';

class OverallInsightsCard extends StatelessWidget {
  const OverallInsightsCard({super.key, required this.analysis});

  final ExamAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (analysis == null || analysis!.isProcessing) {
      return const _OverallInsightsSkeleton();
    }

    if (analysis!.isError) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhận xét tổng quan từ AI', style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.x2),
            Text(
              analysis!.errorMessage ??
                  'AI chưa thể tổng hợp nhận xét cho bài thi này.',
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nhận xét tổng quan từ AI', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Tóm tắt điểm mạnh, điểm yếu và các bước nên ưu tiên tiếp theo.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          if (analysis!.skillInsights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Wrap(
              spacing: AppSpacing.x3,
              runSpacing: AppSpacing.x3,
              children: analysis!.skillInsights.map((insight) {
                return _SkillInsightTile(insight: insight);
              }).toList(),
            ),
          ],
          if (analysis!.overallRecommendations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            Text('Gợi ý tổng quan cải thiện', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.x3),
            ...analysis!.overallRecommendations.map((recommendation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: _RecommendationTile(recommendation: recommendation),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SkillInsightTile extends StatelessWidget {
  const _SkillInsightTile({required this.insight});

  final SkillInsight insight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SkillLabels.forKey(insight.skill),
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(insight.summary, style: AppTypography.bodySmall),
            if (insight.mainIssue.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                insight.mainIssue,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.recommendation});

  final OverallRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recommendation.title,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (recommendation.detail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(recommendation.detail, style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _OverallInsightsSkeleton extends StatelessWidget {
  const _OverallInsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nhận xét tổng quan từ AI', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Đang tổng hợp nhận xét AI...',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x4),
          const LoadingShimmer(child: _SkeletonBlock(height: 92)),
          const SizedBox(height: AppSpacing.x3),
          const LoadingShimmer(child: _SkeletonBlock(height: 92)),
          const SizedBox(height: AppSpacing.x3),
          const LoadingShimmer(child: _SkeletonBlock(height: 72)),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}
