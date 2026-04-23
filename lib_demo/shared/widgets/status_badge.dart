import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// Pill badge — "CẦN CẢI THIỆN", "ĐANG HỌC", "XONG", "PASS", etc.
/// Matches Stitch HTML: inline-block, px-2 py-0.5, rounded-full, text-xs uppercase tracking.
enum StatusBadgeVariant {
  pass,         // green — 85%+ / đậu
  good,         // blue — khá tốt
  needsWork,    // tertiary/red — cần cải thiện
  inProgress,   // primary — đang học
  completed,    // green — xong
  locked,       // gray — locked
  pending,      // secondary — chờ
  custom,       // arbitrary colors
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = StatusBadgeVariant.pass,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  final String label;
  final StatusBadgeVariant variant;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      StatusBadgeVariant.pass => (
          const Color(0xFFDCFCE7), // green-100
          const Color(0xFF166534), // green-800
        ),
      StatusBadgeVariant.good => (
          const Color(0xFFDBEAFE), // blue-100
          const Color(0xFF1E40AF), // blue-800
        ),
      StatusBadgeVariant.needsWork => (
          AppColors.tertiaryFixed,
          AppColors.onTertiaryFixed,
        ),
      StatusBadgeVariant.inProgress => (
          AppColors.primaryFixed,
          AppColors.onPrimaryFixed,
        ),
      StatusBadgeVariant.completed => (
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
        ),
      StatusBadgeVariant.locked => (
          AppColors.surfaceContainerHighest,
          AppColors.onSurfaceVariant,
        ),
      StatusBadgeVariant.pending => (
          AppColors.secondaryContainer,
          AppColors.secondary,
        ),
      StatusBadgeVariant.custom => (
          backgroundColor ?? AppColors.primaryFixed,
          textColor ?? AppColors.onPrimaryFixed,
        ),
    };

    final resolvedBg = variant == StatusBadgeVariant.custom
        ? (backgroundColor ?? bg)
        : bg;
    final resolvedFg = variant == StatusBadgeVariant.custom
        ? (textColor ?? fg)
        : fg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: resolvedFg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.labelUppercase.copyWith(color: resolvedFg),
          ),
        ],
      ),
    );
  }
}

/// Absolute-positioned badge for card corners.
/// Used in ExamResult (Mạnh nhất / Cần cải thiện).
class CornerBadge extends StatelessWidget {
  const CornerBadge({
    super.key,
    required this.label,
    this.variant = StatusBadgeVariant.pass,
  });

  final String label;
  final StatusBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: switch (variant) {
            StatusBadgeVariant.pass => AppColors.primary,
            StatusBadgeVariant.needsWork => AppColors.tertiary,
            _ => AppColors.primary,
          },
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelUppercase.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
