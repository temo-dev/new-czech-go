import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/models/course_models.dart';

/// A single lesson block card. Shows block type icon, order, status, and CTA.
class LessonBlockCard extends StatelessWidget {
  const LessonBlockCard({
    super.key,
    required this.block,
    required this.onStart,
  });

  final LessonBlock block;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = block.status == BlockStatus.completed;
    final blockColor = _blockColor(block.type);
    final blockIcon = _blockIcon(block.type);
    final blockLabel = _blockLabel(block.type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.successContainer
            : cs.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          // Block number
          SizedBox(
            width: 28,
            child: Text(
              '${block.orderIndex}',
              style: AppTypography.titleSmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          // Type icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.success.withValues(alpha: 0.15)
                  : blockColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(
              blockIcon,
              color: isCompleted ? AppColors.success : blockColor,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          // Label
          Expanded(
            child: Text(
              blockLabel,
              style: AppTypography.bodyMedium.copyWith(
                color: isCompleted ? AppColors.success : cs.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Status / CTA
          if (isCompleted)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
            )
          else
            TextButton(
              onPressed: onStart,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x1,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Bắt đầu',
                  style: AppTypography.labelMedium),
            ),
        ],
      ),
    );
  }

  Color _blockColor(BlockType type) => switch (type) {
        BlockType.vocab => AppColors.tertiary,
        BlockType.grammar => AppColors.info,
        BlockType.reading => AppColors.info,
        BlockType.listening => AppColors.success,
        BlockType.speaking => AppColors.tertiary,
        BlockType.writing => AppColors.warning,
      };

  IconData _blockIcon(BlockType type) => switch (type) {
        BlockType.vocab => Icons.translate_rounded,
        BlockType.grammar => Icons.spellcheck_rounded,
        BlockType.reading => Icons.menu_book_rounded,
        BlockType.listening => Icons.headphones_rounded,
        BlockType.speaking => Icons.mic_rounded,
        BlockType.writing => Icons.edit_rounded,
      };

  String _blockLabel(BlockType type) => switch (type) {
        BlockType.vocab => 'Từ vựng',
        BlockType.grammar => 'Ngữ pháp',
        BlockType.reading => 'Đọc hiểu',
        BlockType.listening => 'Nghe hiểu',
        BlockType.speaking => 'Nói',
        BlockType.writing => 'Viết',
      };
}
