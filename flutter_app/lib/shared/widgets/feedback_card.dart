import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum FeedbackTone { success, warning, primary, info }

/// Colored section card with title + bullet list. Used in feedback screens.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.title,
    required this.items,
    this.tone = FeedbackTone.primary,
  });

  final String title;
  final List<String> items;
  final FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      FeedbackTone.success => (AppColors.successContainer, AppColors.success),
      FeedbackTone.warning => (AppColors.warningContainer, AppColors.warning),
      FeedbackTone.primary => (AppColors.primaryFixed, AppColors.onPrimaryFixed),
      FeedbackTone.info    => (AppColors.infoContainer, AppColors.info),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(color: fg),
          ),
          const SizedBox(height: AppSpacing.x2),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: fg, height: 1.6)),
                Expanded(
                  child: Text(
                    item,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: AppSpacing.x1),
          ],
        ],
      ),
    );
  }
}
