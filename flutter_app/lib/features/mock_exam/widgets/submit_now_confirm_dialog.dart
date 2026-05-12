import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// V39 — destructive confirm shown when the learner taps "Nộp bài ngay"
/// while some sections are still unanswered (status='pending'). Shows
/// the unanswered count so the learner can back out and finish them.
/// Returns true to commit the submission, false to dismiss.
///
/// When every section is either done or skipped, callers should skip
/// this dialog and submit directly — no point asking.
class SubmitNowConfirmDialog extends StatelessWidget {
  const SubmitNowConfirmDialog({
    super.key,
    required this.unansweredCount,
    required this.totalCount,
  });

  final int unansweredCount;
  final int totalCount;

  static Future<bool> show(
    BuildContext context, {
    required int unansweredCount,
    required int totalCount,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => SubmitNowConfirmDialog(
        unansweredCount: unansweredCount,
        totalCount: totalCount,
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.flag_rounded, color: AppColors.error),
      title: const Text('Nộp bài ngay?'),
      content: Text(
        'Còn $unansweredCount/$totalCount câu chưa làm. '
        'Các câu đó sẽ tính 0 điểm.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Nộp bài'),
        ),
      ],
    );
  }
}
