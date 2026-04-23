import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Confirmation dialog shown before submitting.
/// Warns about unanswered questions.
class ConfirmSubmitDialog extends StatelessWidget {
  const ConfirmSubmitDialog({
    super.key,
    required this.unansweredCount,
    required this.onConfirm,
  });

  final int unansweredCount;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final hasUnanswered = unansweredCount > 0;

    return AlertDialog(
      title: const Text('Nộp bài thi?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUnanswered) ...[
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    'Bạn còn $unansweredCount câu chưa trả lời.',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
          ],
          Text(
            hasUnanswered
                ? 'Sau khi nộp bài, bạn không thể chỉnh sửa câu trả lời.'
                : 'Bạn đã trả lời tất cả câu hỏi. Xác nhận nộp bài?',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Xem lại'),
        ),
        FilledButton(
          key: const Key('confirm_submit_button'),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Nộp bài'),
        ),
      ],
    );
  }

  static Future<void> show({
    required BuildContext context,
    required int unansweredCount,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ConfirmSubmitDialog(
        unansweredCount: unansweredCount,
        onConfirm: onConfirm,
      ),
    );
  }
}

/// Confirm exit dialog (back button during exam).
class ConfirmExitDialog extends StatelessWidget {
  const ConfirmExitDialog({super.key, required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thoát bài thi?'),
      content: Text(
        'Tiến độ của bạn đã được lưu. Bạn có thể tiếp tục sau.',
        style: AppTypography.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tiếp tục thi'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Thoát'),
        ),
      ],
    );
  }

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ConfirmExitDialog(onConfirm: onConfirm),
    );
  }
}
