import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';

/// Shimmer skeleton for the course overview and module/lesson screens.
class CourseSkeleton extends StatelessWidget {
  const CourseSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner skeleton
          const _ShimmerBox(height: 110),
          const SizedBox(height: AppSpacing.x6),
          // Section label
          const _ShimmerBox(height: 18, width: 120),
          const SizedBox(height: AppSpacing.x3),
          // Item cards
          for (int i = 0; i < itemCount; i++) ...[
            const _ShimmerBox(height: 80),
            const SizedBox(height: AppSpacing.x3),
          ],
        ],
      ),
    );
  }
}

/// Skeleton for the lesson detail screen (6 blocks).
class LessonSkeleton extends StatelessWidget {
  const LessonSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ShimmerBox(height: 100),
          const SizedBox(height: AppSpacing.x4),
          const _ShimmerBox(height: 48),
          const SizedBox(height: AppSpacing.x6),
          for (int i = 0; i < 6; i++) ...[
            const _ShimmerBox(height: 60),
            const SizedBox(height: AppSpacing.x3),
          ],
          const SizedBox(height: AppSpacing.x4),
          const _ShimmerBox(height: 72),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({required this.height, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LoadingShimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: AppRadius.mdAll,
        ),
      ),
    );
  }
}
