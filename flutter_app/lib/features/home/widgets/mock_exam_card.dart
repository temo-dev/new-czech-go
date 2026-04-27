import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/info_pill.dart';

class MockExamCard extends StatelessWidget {
  const MockExamCard({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoPill(label: l.mockExamCardPill, tone: PillTone.primary),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  l.mockExamCardTitle,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  l.mockExamCardSubtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          FilledButton(
            onPressed: onStart,
            child: Text(l.mockExamOpenCta),
          ),
        ],
      ),
    );
  }
}
