import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';

class PlanStrip extends StatelessWidget {
  const PlanStrip({super.key, required this.plan, this.onOpenMockExam});

  final LearningPlanView plan;
  final VoidCallback? onOpenMockExam;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.planSectionTitle, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.x1),
          Text(
            l.planSectionSubtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: plan.days.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.x2),
              itemBuilder: (context, index) => _DayChip(
                day: plan.days[index],
                onTap: plan.days[index].isMockExam ? onOpenMockExam : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, this.onTap});

  final PlanDay day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = _palette(context, day);
    final statusLabel = _statusLabel(l, day);

    final child = Container(
      width: 168,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: palette.border, width: day.isCurrent ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPill(label: statusLabel, tone: palette.pillTone),
          const SizedBox(height: AppSpacing.x2),
          Text(
            day.isMockExam ? l.planMockExamLabel : l.planDayLabel(day.day),
            style: AppTypography.labelLarge.copyWith(color: palette.foreground),
          ),
          const SizedBox(height: AppSpacing.x1),
          Expanded(
            child: Text(
              day.label,
              style: AppTypography.bodySmall.copyWith(
                color: palette.foreground,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: child,
    );
  }

  String _statusLabel(AppLocalizations l, PlanDay day) {
    if (day.isDone) return l.planStatusDone;
    if (day.isCurrent) return l.planStatusCurrent;
    return l.planStatusUpcoming;
  }

  _DayPalette _palette(BuildContext context, PlanDay day) {
    if (day.isCurrent) {
      return _DayPalette(
        background: AppColors.primaryContainer,
        border: AppColors.primary,
        foreground: AppColors.onPrimaryContainer,
        pillTone: PillTone.primary,
      );
    }
    if (day.isDone) {
      return _DayPalette(
        background: AppColors.surfaceContainerLow,
        border: AppColors.outlineVariant,
        foreground: AppColors.onSurfaceVariant,
        pillTone: PillTone.info,
      );
    }
    return _DayPalette(
      background: AppColors.surfaceContainerLow,
      border: AppColors.outlineVariant,
      foreground: AppColors.onSurface,
      pillTone: PillTone.neutral,
    );
  }
}

class _DayPalette {
  const _DayPalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.pillTone,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final PillTone pillTone;
}
