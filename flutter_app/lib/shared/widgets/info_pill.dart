import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_radius.dart';

enum PillTone { primary, info, neutral, success, warning, error }

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.label, this.tone = PillTone.neutral});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.primary => (AppColors.primaryFixed, AppColors.onPrimaryFixed),
      PillTone.info    => (AppColors.infoContainer, AppColors.info),
      PillTone.success => (AppColors.successContainer, AppColors.success),
      PillTone.warning => (AppColors.warningContainer, AppColors.warning),
      PillTone.error   => (AppColors.errorContainer, AppColors.onErrorContainer),
      PillTone.neutral => (AppColors.surfaceContainerLow, AppColors.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        label,
        style: AppTypography.labelUppercase.copyWith(color: fg),
      ),
    );
  }
}
