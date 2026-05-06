import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// V20: error placeholder for the progress card / detail screen.
///
/// Strings are passed in by the caller (UI-4 / UI-5) so the widget keeps no
/// hardcoded copy. `onRetry` is optional — omit it on permanent failures
/// where retrying makes no sense.
class ProgressErrorState extends StatelessWidget {
  const ProgressErrorState({
    super.key,
    required this.title,
    this.message,
    this.retryLabel,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;
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
          if (message != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              message!,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null && retryLabel != null) ...[
            const SizedBox(height: AppSpacing.x4),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(retryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
