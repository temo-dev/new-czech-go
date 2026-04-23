import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// Skeleton placeholder with warm Sahara shimmer.
/// Wrap any shape widget with this to animate it.
///
/// Usage:
/// ```dart
/// LoadingShimmer(child: Container(height: 80, decoration: ...))
/// ```
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainerHighest,
      highlightColor: AppColors.surfaceContainerLowest,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Pre-built shimmer for a list of card-shaped skeletons.
class ShimmerCardList extends StatelessWidget {
  const ShimmerCardList({
    super.key,
    this.count = 4,
    this.itemHeight = 80,
    this.spacing = 12.0,
  });

  final int count;
  final double itemHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count * 2 - 1, (i) {
        if (i.isOdd) return SizedBox(height: spacing);
        return LoadingShimmer(
          child: Container(
            height: itemHeight,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        );
      }),
    );
  }
}

/// Shimmer for a 2×2 bento grid (metric cards, etc).
class ShimmerBentoGrid extends StatelessWidget {
  const ShimmerBentoGrid({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: List.generate(
        4,
        (_) => LoadingShimmer(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashboard hero card shimmer.
class ShimmerHeroCard extends StatelessWidget {
  const ShimmerHeroCard({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),
    );
  }
}

/// Row of shimmer stat chips.
class ShimmerStatRow extends StatelessWidget {
  const ShimmerStatRow({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(width: 12);
        return Expanded(
          child: LoadingShimmer(
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        );
      }),
    );
  }
}
