import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';
import '../widgets/locale_selector.dart';
import '../widgets/plan_strip.dart';

/// Home tab: hero header + module/exercise list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.learnerName,
    required this.modules,
    required this.exercisesByModule,
    required this.onOpenExercise,
    this.plan,
    this.onOpenMockExam,
  });

  final String learnerName;
  final List<ModuleSummary> modules;
  final Map<String, List<ExerciseSummary>> exercisesByModule;
  final ValueChanged<ExerciseSummary> onOpenExercise;
  final LearningPlanView? plan;
  final VoidCallback? onOpenMockExam;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        _HeroCard(learnerName: learnerName),
        if (plan != null) ...[
          const SizedBox(height: AppSpacing.x5),
          PlanStrip(plan: plan!, onOpenMockExam: onOpenMockExam),
        ],
        const SizedBox(height: AppSpacing.x5),
        for (final module in modules) ...[
          _ModuleCard(
            module: module,
            exercises: exercisesByModule[module.id] ?? const [],
            onOpenExercise: onOpenExercise,
          ),
          const SizedBox(height: AppSpacing.x4),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.learnerName});
  final String learnerName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.xxlAll,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InfoPill(label: l.heroPill, tone: PillTone.primary),
              ),
              const LocaleSelector(),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            l.appTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            l.heroGreeting(learnerName),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x5),
          Wrap(
            spacing: AppSpacing.x3,
            runSpacing: AppSpacing.x3,
            children: [
              InfoPill(label: l.heroPillDays, tone: PillTone.primary),
              InfoPill(label: l.heroPillTask, tone: PillTone.neutral),
              InfoPill(label: l.heroPillFeedback, tone: PillTone.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.exercises,
    required this.onOpenExercise,
  });

  final ModuleSummary module;
  final List<ExerciseSummary> exercises;
  final ValueChanged<ExerciseSummary> onOpenExercise;

  @override
  Widget build(BuildContext context) {
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
          InfoPill(
            label: module.moduleKind.replaceAll('_', ' ').toUpperCase(),
            tone: PillTone.neutral,
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            module.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            AppLocalizations.of(context).moduleExerciseCount(exercises.length),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          for (final exercise in exercises) ...[
            _ExerciseTile(
              exercise: exercise,
              onTap: () => onOpenExercise(exercise),
            ),
            if (exercise != exercises.last)
              const SizedBox(height: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onTap});
  final ExerciseSummary exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.title, style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    exercise.shortInstruction,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  InfoPill(
                    label: exercise.exerciseType.toUpperCase(),
                    tone: PillTone.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
