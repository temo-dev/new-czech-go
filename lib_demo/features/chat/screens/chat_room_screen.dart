import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/providers/chat_providers.dart';
import 'package:app_czech/features/chat/widgets/message_bubble.dart';
import 'package:app_czech/features/chat/widgets/message_input_bar.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.roomId,
    this.peerName,
    this.peerAvatarUrl,
  });

  final String roomId;
  final String? peerName;
  final String? peerAvatarUrl;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark messages as read when entering the room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatNotifierProvider(widget.roomId).notifier).markRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  String get _currentUserId => supabase.auth.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));

    // Auto-scroll when new messages arrive
    ref.listen(chatMessagesProvider(widget.roomId), (_, next) {
      next.whenData((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            _PeerAvatar(
              avatarUrl: widget.peerAvatarUrl,
              name: widget.peerName ?? 'Người dùng',
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                widget.peerName ?? 'Người dùng',
                style: AppTypography.titleMedium
                    .copyWith(color: AppColors.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Không tải được tin nhắn',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 48, color: AppColors.onSurfaceVariant),
                        const SizedBox(height: AppSpacing.x4),
                        Text(
                          'Chưa có tin nhắn nào',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Text(
                          'Hãy gửi tin nhắn đầu tiên!',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                final currentUserId = _currentUserId;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.x2,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == currentUserId;
                    final showAvatar = !isMine &&
                        (index == 0 ||
                            messages[index - 1].senderId != msg.senderId);

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == messages.length - 1
                            ? AppSpacing.x4
                            : 0,
                      ),
                      child: MessageBubble(
                        message: msg,
                        isMine: isMine,
                        peerAvatarUrl: showAvatar
                            ? (widget.peerAvatarUrl ??
                                msg.senderAvatarUrl)
                            : null,
                        peerName: showAvatar
                            ? (widget.peerName ?? msg.senderName)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input bar — handles keyboard insets internally
          MessageInputBar(roomId: widget.roomId),
        ],
      ),
    );
  }

}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({this.avatarUrl, required this.name});
  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: AppColors.primaryFixed,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryFixed,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.onPrimaryFixed,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
