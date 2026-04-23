import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/models/course_models.dart';
import 'package:app_czech/shared/widgets/progress_ring.dart';

/// Banner at the top of the course overview screen.
/// Shows title, description, skill chip, and overall progress ring.
class CourseHeaderBanner extends StatelessWidget {
  const CourseHeaderBanner({super.key, required this.course});

  final CourseDetail course;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skillColor = _skillColor(course.skill);
    final pct = course.overallProgress;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress ring
          ProgressRing(
            value: pct,
            size: 64,
            strokeWidth: 6,
            color: AppColors.primary,
            label: '${(pct * 100).round()}%',
            labelStyle: AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Skill chip
                _SkillChip(skill: course.skill, color: skillColor),
                const SizedBox(height: AppSpacing.x2),
                Text(course.title, style: AppTypography.titleLarge),
                if (course.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    course.description,
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.x2),
                Text(
                  '${course.modules.length} module · '
                  '${course.modules.fold<int>(0, (s, m) => s + m.lessonCount)} bài học',
                  style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
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
    final label = _labels[skill] ?? skill;
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
        label,
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}
