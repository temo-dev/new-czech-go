import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Shown when the user has no exam results yet.
/// CTA navigates to the free mock test intro.
class EmptyResultBanner extends StatelessWidget {
  const EmptyResultBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.primaryFixedDim),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Làm bài thi thử đầu tiên',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'Kiểm tra trình độ của bạn và nhận lộ trình học phù hợp.',
                  style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          FilledButton(
            onPressed: () => context.push(AppRoutes.mockTestIntro),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x2,
              ),
              textStyle: AppTypography.labelLarge,
            ),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }
}
