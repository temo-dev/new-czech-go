import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/models/course_models.dart';

/// Tile representing a single lesson in the module lesson list.
/// Status determines icon: lock / circle-outline / check.
class LessonListTile extends StatelessWidget {
  const LessonListTile({
    super.key,
    required this.lesson,
    required this.onTap,
  });

  final LessonSummary lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLocked = lesson.status == LessonStatus.locked;

    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x3,
        ),
        child: Row(
          children: [
            _StatusIcon(status: lesson.status),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bài ${lesson.orderIndex + 1}',
                    style: AppTypography.labelSmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    lesson.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isLocked ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLocked)
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final LessonStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      LessonStatus.completed => const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 24,
        ),
      LessonStatus.inProgress => const Icon(
          Icons.play_circle_outline_rounded,
          color: AppColors.primary,
          size: 24,
        ),
      LessonStatus.available => Icon(
          Icons.radio_button_unchecked_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 24,
        ),
      LessonStatus.locked => Icon(
          Icons.lock_outline_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
    };
  }
}
