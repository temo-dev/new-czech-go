import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';

class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.file,
    required this.onCancel,
    this.isUploading = false,
  });

  final PlatformFile file;
  final VoidCallback onCancel;
  final bool isUploading;

  bool get _isImage {
    final ext = file.extension?.toLowerCase() ?? '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          _thumbnail(),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatSize(file.size),
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                if (isUploading) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    backgroundColor: AppColors.outlineVariant,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          if (!isUploading)
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              color: AppColors.onSurfaceVariant,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }

  Widget _thumbnail() {
    if (_isImage && file.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          file.bytes!,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.insert_drive_file_outlined,
        color: AppColors.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}
