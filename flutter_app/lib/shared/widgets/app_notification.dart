import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum AppNotificationTone { error, warning, info, success }

class AppNotification extends StatelessWidget {
  const AppNotification({
    super.key,
    required this.message,
    this.title,
    this.tone = AppNotificationTone.info,
    this.actionLabel,
    this.onAction,
  });

  const AppNotification.error({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  }) : tone = AppNotificationTone.error;

  const AppNotification.warning({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  }) : tone = AppNotificationTone.warning;

  const AppNotification.info({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  }) : tone = AppNotificationTone.info;

  const AppNotification.success({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  }) : tone = AppNotificationTone.success;

  final String message;
  final String? title;
  final AppNotificationTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final spec = _NotificationSpec.forTone(tone);
    final hasTitle = title?.trim().isNotEmpty == true;
    final hasAction =
        actionLabel?.trim().isNotEmpty == true && onAction != null;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: spec.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: spec.iconBackground,
                borderRadius: AppRadius.fullAll,
              ),
              child: Icon(spec.icon, size: 18, color: spec.iconColor),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle) ...[
                    Text(
                      title!,
                      style: AppTypography.titleSmall.copyWith(
                        color: spec.titleColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                  ],
                  Text(
                    message,
                    style: AppTypography.bodySmall.copyWith(
                      color: spec.bodyColor,
                    ),
                  ),
                  if (hasAction) ...[
                    const SizedBox(height: AppSpacing.x2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: spec.titleColor,
                          minimumSize: const Size(44, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2,
                            vertical: AppSpacing.x1,
                          ),
                          textStyle: AppTypography.labelMedium,
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSpec {
  const _NotificationSpec({
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.titleColor,
    required this.bodyColor,
    required this.iconColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color iconBackground;
  final Color titleColor;
  final Color bodyColor;
  final Color iconColor;
  final IconData icon;

  static _NotificationSpec forTone(AppNotificationTone tone) {
    return switch (tone) {
      AppNotificationTone.error => _NotificationSpec(
        background: AppColors.errorContainer,
        border: AppColors.error.withValues(alpha: 0.28),
        iconBackground: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        titleColor: AppColors.onErrorContainer,
        bodyColor: AppColors.onErrorContainer,
        iconColor: AppColors.error,
        icon: Icons.error_outline_rounded,
      ),
      AppNotificationTone.warning => _NotificationSpec(
        background: AppColors.warningContainer,
        border: AppColors.warning.withValues(alpha: 0.34),
        iconBackground: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        titleColor: AppColors.warning,
        bodyColor: AppColors.onSurface,
        iconColor: AppColors.warning,
        icon: Icons.warning_amber_rounded,
      ),
      AppNotificationTone.info => _NotificationSpec(
        background: AppColors.infoContainer,
        border: AppColors.info.withValues(alpha: 0.28),
        iconBackground: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        titleColor: AppColors.info,
        bodyColor: AppColors.onSurface,
        iconColor: AppColors.info,
        icon: Icons.info_outline_rounded,
      ),
      AppNotificationTone.success => _NotificationSpec(
        background: AppColors.successContainer,
        border: AppColors.success.withValues(alpha: 0.28),
        iconBackground: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        titleColor: AppColors.success,
        bodyColor: AppColors.onSurface,
        iconColor: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      ),
    };
  }
}
