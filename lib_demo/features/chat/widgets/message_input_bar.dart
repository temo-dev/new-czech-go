import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/providers/chat_providers.dart';
import 'package:app_czech/features/chat/widgets/attachment_preview.dart';

class MessageInputBar extends ConsumerStatefulWidget {
  const MessageInputBar({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<MessageInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmoji = false;
  PlatformFile? _pendingFile;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  void _onEmojiSelected(Emoji emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final newText = text.replaceRange(
      sel.start < 0 ? text.length : sel.start,
      sel.end < 0 ? text.length : sel.end,
      emoji.emoji,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: sel.start + emoji.emoji.length),
    );
    setState(() {});
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pendingFile = result.files.first;
        _showEmoji = false;
      });
    }
  }

  Future<void> _send() async {
    final file = _pendingFile;
    final text = _controller.text.trim();

    if (file != null) {
      setState(() => _pendingFile = null);
      await ref
          .read(attachmentUploadNotifierProvider(widget.roomId).notifier)
          .upload(file);
      return;
    }

    if (text.isEmpty) return;

    await ref
        .read(chatNotifierProvider(widget.roomId).notifier)
        .sendMessage(text);

    if (ref.read(chatNotifierProvider(widget.roomId)).hasError) return;
    _controller.clear();
    setState(() {});
  }

  bool get _canSend =>
      _pendingFile != null || _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isUploading = ref
        .watch(attachmentUploadNotifierProvider(widget.roomId))
        .isLoading;

    ref.listen(chatNotifierProvider(widget.roomId), (_, next) {
      next.whenOrNull(
        error: (_, __) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gửi tin nhắn thất bại. Thử lại.')),
          );
        },
      );
    });
    ref.listen(attachmentUploadNotifierProvider(widget.roomId), (_, next) {
      next.whenOrNull(
        error: (_, __) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tải file thất bại. Thử lại.')),
          );
        },
      );
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pendingFile != null)
          AttachmentPreview(
            file: _pendingFile!,
            onCancel: () => setState(() => _pendingFile = null),
            isUploading: isUploading,
          ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
              top: BorderSide(color: AppColors.outlineVariant),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Emoji toggle
              _IconBtn(
                icon: _showEmoji
                    ? Icons.keyboard_rounded
                    : Icons.emoji_emotions_outlined,
                onTap: _toggleEmoji,
              ),
              // File picker
              _IconBtn(
                icon: Icons.attach_file_rounded,
                onTap: _pickFile,
              ),
              const SizedBox(width: AppSpacing.x1),
              // Text field
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.onSurface),
                    onChanged: (_) => setState(() {}),
                    onTap: () {
                      if (_showEmoji) setState(() => _showEmoji = false);
                    },
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: AppTypography.bodyMedium
                          .copyWith(color: AppColors.onSurfaceVariant),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2,
                        vertical: AppSpacing.x2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x1),
              // Send button
              AnimatedOpacity(
                opacity: _canSend ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 150),
                child: _SendBtn(
                  onTap: _canSend && !isUploading ? _send : null,
                ),
              ),
            ],
          ),
        ),
        // Emoji panel
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _showEmoji
              ? SizedBox(
                  height: 256,
                  child: EmojiPicker(
                    onEmojiSelected: (_, emoji) => _onEmojiSelected(emoji),
                    config: Config(
                      height: 256,
                      emojiViewConfig: EmojiViewConfig(
                        emojiSizeMax: 28,
                        backgroundColor: AppColors.surfaceContainerLowest,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: AppColors.surfaceContainerLowest,
                        buttonIconColor: AppColors.onSurfaceVariant,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        backgroundColor: AppColors.surfaceContainerLowest,
                        indicatorColor: AppColors.primary,
                        iconColorSelected: AppColors.primary,
                        iconColor: AppColors.onSurfaceVariant,
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        showBackspaceButton: true,
                        backgroundColor: AppColors.surfaceContainerLowest,
                        buttonColor: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: AppColors.onSurfaceVariant,
      iconSize: 22,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _SendBtn extends StatelessWidget {
  const _SendBtn({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.send_rounded,
          color: AppColors.onPrimary,
          size: 18,
        ),
      ),
    );
  }
}
