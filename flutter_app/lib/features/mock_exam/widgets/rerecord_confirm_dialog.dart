import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// V39 — destructive confirm shown before the learner re-records a
/// speaking section that already has an attempt attached. Pressing
/// "Ghi đè" returns true; "Huỷ" / dismiss returns false.
///
/// Used only for `uloha_1..4` (skill_kind=='noi'). Interview sections
/// have a different lifecycle and skip this prompt.
class RerecordConfirmDialog extends StatelessWidget {
  const RerecordConfirmDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const RerecordConfirmDialog(),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.mic_rounded, color: AppColors.error),
      title: const Text('Ghi đè recording cũ?'),
      content: const Text(
        'Bản ghi âm hiện tại của câu này sẽ bị thay bằng bản mới. '
        'Hành động không thể hoàn tác.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ghi đè'),
        ),
      ],
    );
  }
}
