import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/models/friend_models.dart';

class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.profile,
    required this.onAccept,
    required this.onDecline,
  });

  final UserProfile profile;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: AppTypography.labelMedium,
            ),
            child: const Text('Chấp nhận'),
          ),
          const SizedBox(width: AppSpacing.x1),
          OutlinedButton(
            onPressed: onDecline,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurfaceVariant,
              side: const BorderSide(color: AppColors.outlineVariant),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: AppTypography.labelMedium,
            ),
            child: const Text('Từ chối'),
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
