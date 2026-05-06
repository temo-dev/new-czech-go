import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// V20: zero-state for the progress card / detail screen.
///
/// Strings are injected by the caller (UI-4 / UI-5) so the widget itself
/// stays free of hardcoded VI/EN copy and the ARB keys land in UI-6.
class ProgressEmptyState extends StatelessWidget {
  const ProgressEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
    this.icon = Icons.flag_outlined,
  });

  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: AppSpacing.x3),
          Text(
            title,
            style: AppTypography.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            message,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onCta != null && ctaLabel != null) ...[
            const SizedBox(height: AppSpacing.x4),
            FilledButton(
              onPressed: onCta,
              child: Text(ctaLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
