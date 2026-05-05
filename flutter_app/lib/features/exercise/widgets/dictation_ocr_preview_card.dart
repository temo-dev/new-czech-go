// V18.1 — Preview-confirm card for dictation OCR submissions.
//
// After the learner taps "📷 Chụp ảnh" and the backend returns the OCR'd text,
// this widget renders the photo thumbnail + an editable TextField pre-filled
// with the recognized text. The learner edits as needed and taps "Dùng văn
// bản này" to lock the sentence for Submit. "Chụp lại" discards both the
// photo and the OCR result.
//
// `isUploading` swaps the buttons + TextField for a centered spinner so the
// caller can keep the same widget mounted while the network call is in flight.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class DictationOCRPreviewCard extends StatefulWidget {
  const DictationOCRPreviewCard({
    super.key,
    required this.photoUrl,
    required this.ocrText,
    required this.onRetake,
    required this.onConfirm,
    this.isUploading = false,
    this.uploadingHint = 'Đang nhận diện…',
    this.previewTitle = 'Kiểm tra văn bản đã đọc',
    this.previewHint = 'Sửa lại nếu cần, rồi xác nhận',
    this.confirmLabel = 'Dùng văn bản này',
    this.retakeLabel = 'Chụp lại',
    this.failedBanner,
  });

  final String photoUrl;
  final String ocrText;
  final VoidCallback onRetake;
  final ValueChanged<String> onConfirm;
  final bool isUploading;
  final String uploadingHint;
  final String previewTitle;
  final String previewHint;
  final String confirmLabel;
  final String retakeLabel;
  // Optional banner shown above the editable text when OCR returned empty
  // or otherwise could not be trusted. Caller decides the copy + visibility.
  final String? failedBanner;

  @override
  State<DictationOCRPreviewCard> createState() =>
      _DictationOCRPreviewCardState();
}

class _DictationOCRPreviewCardState extends State<DictationOCRPreviewCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.ocrText);
  }

  @override
  void didUpdateWidget(covariant DictationOCRPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh the field when a new OCR result arrives (e.g. after Retake).
    if (oldWidget.ocrText != widget.ocrText) {
      _controller.text = widget.ocrText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.photoUrl.isEmpty
                    ? Container(color: AppColors.outlineVariant)
                    : Image.network(widget.photoUrl, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          if (widget.isUploading) ...[
            const SizedBox(height: AppSpacing.x2),
            Center(
              child: Column(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(widget.uploadingHint, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
          ] else ...[
            Text(widget.previewTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.x1),
            Text(widget.previewHint, style: theme.textTheme.bodySmall),
            if (widget.failedBanner != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.failedBanner!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onRetake,
                  child: Text(widget.retakeLabel),
                ),
                const SizedBox(width: AppSpacing.x2),
                FilledButton(
                  onPressed: () => widget.onConfirm(_controller.text),
                  child: Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }
}
