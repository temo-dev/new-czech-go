import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/models/friend_models.dart';
import 'package:app_czech/features/chat/providers/friend_providers.dart';
import 'package:app_czech/features/chat/providers/chat_providers.dart';
import 'package:app_czech/features/chat/widgets/friend_tile.dart';
import 'package:app_czech/features/chat/widgets/friend_request_tile.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);

    return ColoredBox(
      color: AppColors.surface,
      child: ListView(
        children: [
          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Tìm người dùng...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.x6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
              ),
            ),
          ),

          // ── Search results ────────────────────────────────────────────
          if (_query.trim().length >= 2) ...[
            _SectionHeader(label: 'Kết quả tìm kiếm'),
            _SearchResults(query: _query.trim()),
            const SizedBox(height: AppSpacing.x6),
          ],

          // ── Pending requests ──────────────────────────────────────────
          pendingAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (pending) {
              if (pending.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(label: 'Lời mời kết bạn (${pending.length})'),
                  ...pending.map((p) => FriendRequestTile(
                        profile: p,
                        onAccept: () => _accept(p),
                        onDecline: () => _decline(p),
                      )),
                  const SizedBox(height: AppSpacing.x6),
                ],
              );
            },
          ),

          // ── Friends list ──────────────────────────────────────────────
          _SectionHeader(label: 'Bạn bè'),
          friendsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.x8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Text(
                'Không tải được danh sách bạn bè',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
            data: (friends) {
              if (friends.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.x8),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.x4),
                      Text(
                        'Chưa có bạn bè nào',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        'Tìm kiếm người dùng ở trên để kết bạn',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: friends
                    .map((f) => FriendTile(
                          profile: f,
                          onMessage: () => _openDm(f),
                          onUnfriend: () => _unfriend(f),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.x8),
        ],
      ),
    );
  }

  Future<void> _accept(UserProfile profile) async {
    if (profile.friendshipId == null) return;
    await ref
        .read(friendshipNotifierProvider.notifier)
        .accept(profile.friendshipId!);
  }

  Future<void> _decline(UserProfile profile) async {
    if (profile.friendshipId == null) return;
    await ref
        .read(friendshipNotifierProvider.notifier)
        .decline(profile.friendshipId!);
  }

  Future<void> _unfriend(UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa bạn'),
        content: Text('Xóa ${profile.displayName} khỏi danh sách bạn bè?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && profile.friendshipId != null) {
      await ref
          .read(friendshipNotifierProvider.notifier)
          .unfriend(profile.friendshipId!);
    }
  }

  Future<void> _openDm(UserProfile profile) async {
    final roomId =
        await ref.read(openDmNotifierProvider.notifier).open(profile.id);
    if (roomId != null && mounted) {
      context.push(
        AppRoutes.chatRoomPath(roomId),
        extra: {
          'peerName': profile.displayName,
          'peerAvatarUrl': profile.avatarUrl,
        },
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6, AppSpacing.x2, AppSpacing.x6, AppSpacing.x1),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(searchUsersProvider(query));

    return searchAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.x6),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Text('Lỗi tìm kiếm',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.onSurfaceVariant)),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: Text(
              'Không tìm thấy người dùng',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          );
        }
        return Column(
          children: users.map((u) => _SearchUserTile(profile: u)).toList(),
        );
      },
    );
  }
}

class _SearchUserTile extends ConsumerWidget {
  const _SearchUserTile({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x6, vertical: AppSpacing.x1),
      leading: CircleAvatar(
        radius: 21,
        backgroundImage:
            profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
        backgroundColor: AppColors.primaryFixed,
        child: profile.avatarUrl == null
            ? Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : '?',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.onPrimaryFixed),
              )
            : null,
      ),
      title: Text(
        profile.displayName,
        style: AppTypography.labelLarge.copyWith(color: AppColors.onSurface),
      ),
      subtitle: Text(
        '${profile.totalXp} XP',
        style: AppTypography.labelSmall
            .copyWith(color: AppColors.onSurfaceVariant),
      ),
      trailing: _FriendshipButton(profile: profile),
    );
  }
}

class _FriendshipButton extends ConsumerWidget {
  const _FriendshipButton({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = profile.friendshipStatus;

    if (status == FriendshipStatus.accepted) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Bạn bè'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      );
    }

    if (status == FriendshipStatus.pending) {
      if (profile.isRequester == true) {
        return OutlinedButton(
          onPressed: () => _cancel(ref, profile),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurfaceVariant,
            side: const BorderSide(color: AppColors.outlineVariant),
          ),
          child: const Text('Đã gửi'),
        );
      } else {
        return FilledButton(
          onPressed: () => _accept(ref, profile),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child: const Text('Chấp nhận'),
        );
      }
    }

    return FilledButton.icon(
      onPressed: () => _sendRequest(ref, profile),
      icon: const Icon(Icons.person_add_outlined, size: 16),
      label: const Text('Kết bạn'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
    );
  }

  Future<void> _sendRequest(WidgetRef ref, UserProfile profile) async {
    await ref.read(friendshipNotifierProvider.notifier).sendRequest(profile.id);
  }

  Future<void> _accept(WidgetRef ref, UserProfile profile) async {
    if (profile.friendshipId == null) return;
    await ref
        .read(friendshipNotifierProvider.notifier)
        .accept(profile.friendshipId!);
  }

  Future<void> _cancel(WidgetRef ref, UserProfile profile) async {
    if (profile.friendshipId == null) return;
    await ref
        .read(friendshipNotifierProvider.notifier)
        .cancelRequest(profile.friendshipId!);
  }
}
