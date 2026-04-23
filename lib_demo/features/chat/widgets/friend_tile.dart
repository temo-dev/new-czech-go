import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/models/friend_models.dart';

class FriendTile extends StatelessWidget {
  const FriendTile({
    super.key,
    required this.profile,
    required this.onMessage,
    required this.onUnfriend,
  });

  final UserProfile profile;
  final VoidCallback onMessage;
  final VoidCallback onUnfriend;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x6,
        vertical: AppSpacing.x1,
      ),
      leading: _Avatar(
        name: profile.displayName,
        avatarUrl: profile.avatarUrl,
      ),
      title: Text(
        profile.displayName,
        style:
            AppTypography.labelLarge.copyWith(color: AppColors.onSurface),
      ),
      subtitle: Row(
        children: [
          const Icon(Icons.star_rounded,
              size: 14, color: AppColors.primaryContainer),
          const SizedBox(width: 3),
          Text(
            '${profile.totalXp} XP',
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Nhắn tin'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: AppTypography.labelMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.x1),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'unfriend') onUnfriend();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'unfriend',
                child: Text('Xóa bạn'),
              ),
            ],
            child: const Icon(Icons.more_vert,
                color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    const size = 42.0;
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
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.onPrimaryFixed,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
