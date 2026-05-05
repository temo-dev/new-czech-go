import 'package:flutter/material.dart';

import '../../../core/streak/streak_models.dart';
import '../../../core/theme/app_colors.dart';

/// Streak ring shown on the Home tab.
///
/// Visual:
///   ╭───────╮
///   │  🔥   │
///   │  12   │     <- current streak count, big numeral
///   │ ngày  │
///   ╰───────╯
///   ◯ ◯ ◯ ◉ ◉ ◉ ◉    <- last 7 days, ◉ = had completion / grace
///
/// Tapping the ring fires [onTap] (history navigation lives in the
/// caller so this widget stays presentation-only).
class StreakRingWidget extends StatelessWidget {
  const StreakRingWidget({
    super.key,
    required this.summary,
    this.last7DaysCompletion,
    this.onTap,
  });

  final StreakSummary summary;

  /// Seven booleans, oldest to newest (today is the last element).
  /// When null the ring renders with the dots all hollow — the data
  /// just has not been fetched yet.
  final List<bool>? last7DaysCompletion;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasStreak = summary.currentDays > 0;
    return Semantics(
      label: '${summary.currentDays} ngày liên tục',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasStreak ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
                  border: Border.all(
                    color: hasStreak ? AppColors.primary : AppColors.outlineVariant,
                    width: 4,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hasStreak ? '🔥' : '✨',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.currentDays}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: hasStreak ? AppColors.onPrimaryContainer : AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'ngày',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasStreak ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _LastSevenDots(completion: last7DaysCompletion ?? List.filled(7, false)),
              if (summary.gracePassesLeftThisWeek > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${summary.gracePassesLeftThisWeek} lượt grace pass còn lại tuần này',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
              if (summary.longestDays > summary.currentDays) ...[
                const SizedBox(height: 4),
                Text(
                  'Kỷ lục: ${summary.longestDays} ngày',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LastSevenDots extends StatelessWidget {
  const _LastSevenDots({required this.completion});

  final List<bool> completion;

  @override
  Widget build(BuildContext context) {
    final padded = completion.length == 7
        ? completion
        : List<bool>.generate(7, (i) => i < completion.length ? completion[i] : false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final hit in padded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hit ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: hit ? AppColors.primary : AppColors.outlineVariant,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
