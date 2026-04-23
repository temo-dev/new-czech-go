import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/models.dart';

/// Diff visualization for transcript correction. Shows inserted/replaced/deleted chunks.
class DiffBlock extends StatelessWidget {
  const DiffBlock({super.key, required this.chunks});

  final List<DiffChunkView> chunks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chỉnh sửa nhanh', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.x3),
          for (final chunk in chunks) ...[
            _DiffChunkTile(chunk: chunk),
            if (chunk != chunks.last) const SizedBox(height: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}

class _DiffChunkTile extends StatelessWidget {
  const _DiffChunkTile({required this.chunk});

  final DiffChunkView chunk;

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (chunk.kind) {
      'inserted' => (AppColors.successContainer, 'Thêm'),
      'replaced' => (AppColors.primaryFixed, 'Sửa'),
      'deleted'  => (AppColors.tertiaryFixed, 'Bỏ'),
      _          => (AppColors.surfaceContainerLow, 'Giữ nguyên'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelMedium),
          if (chunk.sourceText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Bạn nói: ${chunk.sourceText}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          if (chunk.targetText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Nên nói: ${chunk.targetText}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
