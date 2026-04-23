import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';

/// Shimmer skeleton for the full dashboard while [dashboardProvider] is loading.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ShimmerBox(height: 28, width: 220),
          const SizedBox(height: AppSpacing.x2),
          const _ShimmerBox(height: 16, width: 180),
          const SizedBox(height: AppSpacing.x6),
          const _ShimmerBox(height: 140),
          const SizedBox(height: AppSpacing.x4),
          if (isWide) ...[
            const Row(
              children: [
                Expanded(child: _ShimmerBox(height: 100)),
                SizedBox(width: AppSpacing.x4),
                Expanded(child: _ShimmerBox(height: 100)),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
            const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _ShimmerBox(height: 140),
                ),
                SizedBox(width: AppSpacing.x4),
                Expanded(
                  flex: 2,
                  child: _ShimmerBox(height: 140),
                ),
              ],
            ),
          ] else ...[
            const _ShimmerBox(height: 100),
            const SizedBox(height: AppSpacing.x4),
            const _ShimmerBox(height: 100),
            const SizedBox(height: AppSpacing.x4),
            const _ShimmerBox(height: 140),
            const SizedBox(height: AppSpacing.x4),
            const _ShimmerBox(height: 120),
          ],
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
