import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/user_model.dart';

/// Greeting row: "Chào [name]" + optional exam countdown chip.
class DailyGreetingHeader extends StatelessWidget {
  const DailyGreetingHeader({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = user.displayName?.split(' ').first ?? '';
    final greeting = name.isNotEmpty ? 'Chào $name!' : 'Xin chào!';

    final daysUntilExam =
        user.examDate?.difference(DateTime.now()).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(greeting, style: AppTypography.headlineSmall),
            ),
            if (daysUntilExam != null && daysUntilExam >= 0) ...[
              const SizedBox(width: AppSpacing.x3),
              _ExamCountdownChip(daysUntilExam: daysUntilExam),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          'Sẵn sàng cho 15 phút học hôm nay?',
          style: AppTypography.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ExamCountdownChip extends StatelessWidget {
  const _ExamCountdownChip({required this.daysUntilExam});
  final int daysUntilExam;

  @override
  Widget build(BuildContext context) {
    final isUrgent = daysUntilExam <= 14;
    final bg = isUrgent ? AppColors.warningContainer : AppColors.primaryFixed;
    final fg = isUrgent ? AppColors.warning : AppColors.primary;
    final label = daysUntilExam == 0
        ? 'Thi hôm nay!'
        : 'Còn $daysUntilExam ngày';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
