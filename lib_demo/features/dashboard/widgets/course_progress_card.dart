import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/widgets/progress_ring.dart';
import 'package:app_czech/features/dashboard/models/dashboard_models.dart';

/// Shows active course title + lesson progress ring.
/// Stub for Day 8 — Day 9 wires real progress from [courseDetailProvider].
class CourseProgressCard extends StatelessWidget {
  const CourseProgressCard({super.key, required this.course});

  final CourseProgress course;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = course.progressFraction;
    final completedLabel = '${course.completedLessons}/${course.totalLessons}';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.courseDetailPath(course.courseId)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            ProgressRing(
              value: pct,
              size: 52,
              strokeWidth: 5,
              color: AppColors.primary,
              label: pct == 0 ? '' : '${(pct * 100).round()}%',
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
                  Text(
                    course.courseTitle,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$completedLabel bài hoàn thành',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
