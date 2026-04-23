import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/features/chat/providers/chat_providers.dart';
import 'package:app_czech/features/chat/screens/friends_screen.dart';
import 'package:app_czech/features/chat/widgets/conversation_card.dart';
import 'package:app_czech/shared/widgets/app_top_bar.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(
          title: 'Tin nhắn',
          showBack: false,
          bottom: TabBar(
            labelStyle:
                AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTypography.labelMedium,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Hộp thư'),
                    if (unread > 0) ...[
                      const SizedBox(width: AppSpacing.x1),
                      _UnreadBadge(count: unread),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Bạn bè'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _InboxTab(),
            FriendsScreen(),
          ],
        ),
      ),
    );
  }
}

class _InboxTab extends ConsumerWidget {
  const _InboxTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(conversationsProvider);

    return convsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Không tải được tin nhắn',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.x4),
            FilledButton(
              onPressed: () => ref.refresh(conversationsProvider),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (convs) {
        if (convs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 56,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.x6),
                Text(
                  'Chưa có cuộc trò chuyện nào',
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Kết bạn và bắt đầu nhắn tin với\nngười dùng khác',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x8),
                OutlinedButton.icon(
                  onPressed: () {
                    DefaultTabController.of(context).animateTo(1);
                  },
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Tìm bạn bè'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: convs.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: AppSpacing.x6 + 48 + AppSpacing.x4,
            color: AppColors.outlineVariant,
          ),
          itemBuilder: (context, index) {
            final conv = convs[index];
            return ConversationCard(
              roomId: conv.roomId,
              peerName: conv.peerName,
              peerAvatarUrl: conv.peerAvatarUrl,
              lastMessage: conv.lastMessage,
              unreadCount: conv.unreadCount,
              lastActivityAt: conv.lastActivityAt,
              onTap: () => context.push(
                AppRoutes.chatRoomPath(conv.roomId),
                extra: {
                  'peerName': conv.peerName,
                  'peerAvatarUrl': conv.peerAvatarUrl,
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
