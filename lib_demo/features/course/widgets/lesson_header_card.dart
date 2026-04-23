import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/models/course_models.dart';

/// Header shown at the top of [LessonPlayerScreen].
class LessonHeaderCard extends StatelessWidget {
  const LessonHeaderCard({
    super.key,
    required this.lesson,
    required this.moduleTitle,
  });

  final LessonInfo lesson;
  final String moduleTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skillColor = _skillColor(lesson.skill);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkillChip(skill: lesson.skill, color: skillColor),
              const Spacer(),
              Text(
                moduleTitle,
                style: AppTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            lesson.title,
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Bài ${lesson.orderIndex + 1} · 6 bài tập',
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _skillColor(String skill) => switch (skill) {
        'reading' => AppColors.info,
        'listening' => AppColors.success,
        'writing' => AppColors.warning,
        'speaking' => AppColors.tertiary,
        _ => AppColors.primary,
      };
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill, required this.color});
  final String skill;
  final Color color;

  static const _labels = {
    'reading': 'Đọc hiểu',
    'listening': 'Nghe hiểu',
    'writing': 'Viết',
    'speaking': 'Nói',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _labels[skill] ?? skill,
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}
