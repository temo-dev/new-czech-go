import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// LockedCourseSheet is the bottom sheet shown when a learner taps a
/// locked CourseListTile. It surfaces the same coverage-delta the tile
/// already shows, plus dual CTAs:
///   - "Tiếp tục luyện ở cấp X" (primary)  — routes back to the
///     learner's current-level course so they can keep accruing mastery.
///   - "Xem demo →" (ghost) — when the locked course exposes a demo
///     exercise, this jumps straight into it. Hidden when no demo.
///
/// Pure presentation — navigation belongs to the caller.
class LockedCourseSheet extends StatelessWidget {
  const LockedCourseSheet({
    super.key,
    required this.title,
    required this.level,
    required this.coveragePct,
    required this.coverageThresholdPct,
    required this.hasDemoExercise,
    required this.onTapDemo,
    required this.onTapContinueLowerLevel,
  });

  final String title;
  final CefrLevel level;
  final double coveragePct;
  final double coverageThresholdPct;
  final bool hasDemoExercise;
  final VoidCallback onTapDemo;
  final VoidCallback onTapContinueLowerLevel;

  @override
  Widget build(BuildContext context) {
    final progress = (coveragePct / coverageThresholdPct).clamp(0.0, 1.0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4, AppSpacing.x4, AppSpacing.x4, AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 22, color: AppColors.onSurfaceVariant),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              'Cần đạt mastery + coverage trước khi mở khoá cấp này.',
              style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.x4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: AppColors.surfaceContainerHigh,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${coveragePct.toStringAsFixed(0)}% hoàn thành / cần ${coverageThresholdPct.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.x5),
            ElevatedButton(
              key: const Key('locked_course_sheet_continue_cta'),
              onPressed: () {
                Navigator.of(context).pop();
                onTapContinueLowerLevel();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.x3)),
              ),
              child: const Text(
                'Tiếp tục luyện',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            if (hasDemoExercise) ...[
              const SizedBox(height: AppSpacing.x2),
              TextButton(
                key: const Key('locked_course_sheet_demo_cta'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onTapDemo();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Xem demo →',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
