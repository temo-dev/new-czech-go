import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// PreExamScreen lays out the rules + retake policy before a learner
/// commits to a promotion exam attempt. Tapping confirm fires onConfirm
/// (caller invokes `LevelApi.createPromotionAttempt` and routes to the
/// exam runner); cancel fires onCancel (caller pops back to home).
///
/// Pure presentation — the screen never calls the API directly.
class PreExamScreen extends StatelessWidget {
  const PreExamScreen({
    super.key,
    required this.targetLevel,
    required this.durationMinutes,
    required this.passThresholdPct,
    required this.cooldownHours,
    required this.onConfirm,
    required this.onCancel,
  });

  final CefrLevel targetLevel;
  final int durationMinutes;
  final int passThresholdPct;
  final int cooldownHours;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final levelLabel = cefrLevelLabel(targetLevel);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Thi nâng cấp $levelLabel'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x6,
            vertical: AppSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bạn sắp làm đề thi nâng cấp lên $levelLabel.',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              _RuleRow(
                icon: Icons.timer_outlined,
                label: 'Thời gian',
                value: '$durationMinutes phút',
              ),
              const SizedBox(height: AppSpacing.x3),
              _RuleRow(
                icon: Icons.flag_outlined,
                label: 'Điểm pass',
                value: '$passThresholdPct% mỗi phần',
              ),
              const SizedBox(height: AppSpacing.x3),
              _RuleRow(
                icon: Icons.replay_outlined,
                label: 'Thi lại',
                value: 'Sau $cooldownHours giờ nếu không đạt',
              ),
              const SizedBox(height: AppSpacing.x5),
              const Text(
                'Nếu chưa đạt, mastery hiện tại không bị giảm — bạn chỉ '
                'cần đợi cooldown rồi thử lại.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                key: const Key('pre_exam_confirm_cta'),
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.x3)),
                ),
                child: const Text(
                  'Bắt đầu thi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              TextButton(
                key: const Key('pre_exam_cancel_cta'),
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Để sau',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
