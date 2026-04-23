import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/models/chat_models.dart';

class ConversationCard extends StatelessWidget {
  const ConversationCard({
    super.key,
    required this.roomId,
    required this.peerName,
    this.peerAvatarUrl,
    this.lastMessage,
    required this.unreadCount,
    this.lastActivityAt,
    required this.onTap,
  });

  final String roomId;
  final String peerName;
  final String? peerAvatarUrl;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastActivityAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x6,
          vertical: AppSpacing.x4,
        ),
        child: Row(
          children: [
            _Avatar(name: peerName, avatarUrl: peerAvatarUrl),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peerName,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastActivityAt != null) ...[
                        const SizedBox(width: AppSpacing.x2),
                        Text(
                          _formatTime(lastActivityAt!),
                          style: AppTypography.labelSmall.copyWith(
                            color: hasUnread
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage?.previewText ?? 'Bắt đầu trò chuyện',
                          style: AppTypography.bodySmall.copyWith(
                            color: hasUnread
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: AppSpacing.x2),
                        _UnreadBadge(count: unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat.Hm().format(dt);
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return DateFormat('EEE', 'vi').format(dt);
    return DateFormat('dd/MM').format(dt);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
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
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.onPrimaryFixed,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
