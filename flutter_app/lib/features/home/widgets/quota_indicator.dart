import 'package:flutter/material.dart';

import '../../../core/streak/streak_models.dart';
import '../../../core/theme/app_colors.dart';

/// Quota indicator pill for free-tier learners. Pro learners (or any
/// learner whose limit is effectively unlimited) get an empty widget
/// — pass `proHide=true` from the caller and the build returns
/// SizedBox.shrink so the layout collapses cleanly.
///
/// Visual:
///   [3 / 7 lượt luyện hôm nay]
class QuotaIndicator extends StatelessWidget {
  const QuotaIndicator({
    super.key,
    required this.usage,
    this.proHide = false,
    this.onTapWhenFull,
  });

  final DailyUsageSummary usage;
  final bool proHide;
  final VoidCallback? onTapWhenFull;

  bool get _isFull => usage.attempts >= usage.attemptsLimit;

  @override
  Widget build(BuildContext context) {
    if (proHide) return const SizedBox.shrink();
    final color = _isFull ? AppColors.error : AppColors.onSurfaceVariant;
    return Material(
      color: _isFull ? AppColors.errorContainer : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: _isFull ? onTapWhenFull : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFull ? Icons.lock_outline : Icons.bolt_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                '${usage.attempts} / ${usage.attemptsLimit} lượt luyện hôm nay',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
