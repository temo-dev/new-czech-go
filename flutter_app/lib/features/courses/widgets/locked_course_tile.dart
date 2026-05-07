import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// LockedCourseTile renders a course card that the learner has not yet
/// unlocked — shown in CourseListScreen alongside the unlocked tiles.
/// Padlock icon + level chip + a coverage-delta progress bar communicate
/// "you need ≥X% to open this course". When the course exposes a demo
/// exercise, a ghost CTA at the bottom routes the learner straight into
/// it (no mastery write happens — that is enforced server-side).
///
/// Tap on the body (anywhere outside the demo CTA) fires `onTap` so the
/// caller can open the LockedCourseSheet for the full delta breakdown.
class LockedCourseTile extends StatelessWidget {
  const LockedCourseTile({
    super.key,
    required this.title,
    required this.level,
    required this.coveragePct,
    required this.coverageThresholdPct,
    required this.hasDemoExercise,
    required this.onTap,
    required this.onTapDemo,
  });

  final String title;
  final CefrLevel level;
  final double coveragePct;
  final double coverageThresholdPct;
  final bool hasDemoExercise;
  final VoidCallback onTap;
  final VoidCallback onTapDemo;

  @override
  Widget build(BuildContext context) {
    final progress = (coveragePct / coverageThresholdPct).clamp(0.0, 1.0);
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.x3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.x3),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(AppSpacing.x3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 20, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cefrLevelLabel(level),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              const Text(
                'Hoàn thành mastery để mở khoá',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${coveragePct.toStringAsFixed(0)}% / ${coverageThresholdPct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (hasDemoExercise) ...[
                const SizedBox(height: AppSpacing.x3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('locked_course_tile_demo_cta'),
                    onPressed: onTapDemo,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Xem demo →',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
