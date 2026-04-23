import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/chat/providers/friend_providers.dart';
import 'package:app_czech/features/chat/providers/chat_providers.dart';
import 'package:app_czech/features/chat/models/friend_models.dart';
import 'package:app_czech/features/leaderboard/providers/leaderboard_provider.dart';

/// Bottom sheet shown when a leaderboard entry is tapped.
/// Shows user info + friend/chat actions.
class LeaderboardUserSheet extends ConsumerWidget {
  const LeaderboardUserSheet({super.key, required this.entry});

  final LeaderboardEntry entry;

  static Future<void> show(BuildContext context, LeaderboardEntry entry) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaderboardUserSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userFriendshipProvider(entry.userId));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x6 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          // Avatar
          _Avatar(entry: entry, radius: 36),
          const SizedBox(height: AppSpacing.x3),

          // Rank badge + name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RankBadge(rank: entry.rank),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  entry.displayName,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),

          // XP
          Text(
            '${entry.xp} XP tuần này',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          // Actions (hidden for own profile)
          if (!entry.isCurrentUser)
            profileAsync.when(
              loading: () => const SizedBox(
                height: 52,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (profile) => _ActionButtons(
                entry: entry,
                profile: profile,
                onDone: () => Navigator.of(context).pop(),
                onChat: (roomId) {
                  Navigator.of(context).pop();
                  context.push(
                    AppRoutes.chatRoomPath(roomId),
                    extra: {
                      'peerName': entry.displayName,
                      'peerAvatarUrl': entry.avatarUrl,
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Action buttons ─────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerStatefulWidget {
  const _ActionButtons({
    required this.entry,
    required this.profile,
    required this.onDone,
    required this.onChat,
  });

  final LeaderboardEntry entry;
  final UserProfile? profile;
  final VoidCallback onDone;
  final void Function(String roomId) onChat;

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  bool _loading = false;

  Future<void> _sendRequest() async {
    setState(() => _loading = true);
    await ref
        .read(friendshipNotifierProvider.notifier)
        .sendRequest(widget.entry.userId);
    if (mounted) {
      ref.invalidate(userFriendshipProvider(widget.entry.userId));
      setState(() => _loading = false);
    }
  }

  Future<void> _openChat() async {
    setState(() => _loading = true);
    final roomId = await ref
        .read(openDmNotifierProvider.notifier)
        .open(widget.entry.userId);
    if (mounted) {
      setState(() => _loading = false);
      if (roomId != null) widget.onChat(roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final status = profile?.friendshipStatus;
    final isRequester = profile?.isRequester ?? false;

    if (status == FriendshipStatus.accepted) {
      // Friends → show Chat button
      return _PrimaryButton(
        label: 'Nhắn tin',
        icon: Icons.chat_bubble_rounded,
        loading: _loading,
        onTap: _openChat,
      );
    }

    if (status == FriendshipStatus.pending) {
      if (isRequester) {
        // Current user already sent request
        return _PrimaryButton(
          label: 'Đã gửi lời mời',
          icon: Icons.hourglass_top_rounded,
          loading: false,
          onTap: null,
          muted: true,
        );
      } else {
        // Received a request from this user
        return _PrimaryButton(
          label: 'Chấp nhận kết bạn',
          icon: Icons.person_add_rounded,
          loading: _loading,
          onTap: () async {
            setState(() => _loading = true);
            await ref
                .read(friendshipNotifierProvider.notifier)
                .accept(profile!.friendshipId!);
            if (mounted) {
              ref.invalidate(userFriendshipProvider(widget.entry.userId));
              setState(() => _loading = false);
            }
          },
        );
      }
    }

    // No friendship → send request
    return _PrimaryButton(
      label: 'Kết bạn',
      icon: Icons.person_add_rounded,
      loading: _loading,
      onTap: _sendRequest,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: muted
              ? AppColors.surfaceContainerHighest
              : AppColors.primary,
          foregroundColor: muted ? AppColors.onSurfaceVariant : AppColors.onPrimary,
          disabledBackgroundColor: muted
              ? AppColors.surfaceContainerHighest
              : AppColors.primary.withOpacity(0.4),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.radius});
  final LeaderboardEntry entry;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryFixed,
      backgroundImage: entry.avatarUrl != null
          ? NetworkImage(entry.avatarUrl!)
          : null,
      child: entry.avatarUrl == null
          ? Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.primary,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '#$rank',
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
