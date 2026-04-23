import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/teacher_feedback/providers/teacher_feedback_provider.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

class TeacherInboxScreen extends ConsumerWidget {
  const TeacherInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherInboxProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _AppBar(),
          Expanded(
            child: async.when(
              loading: () => const ShimmerCardList(count: 4),
              error: (e, _) => ErrorState(
                message: 'Không tải được hộp thư.',
                onRetry: () => ref.refresh(teacherInboxProvider),
              ),
              data: (reviews) => reviews.isEmpty
                  ? _EmptyInbox()
                  : _InboxList(reviews: reviews),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
              color: AppColors.outlineVariant.withOpacity(0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Phản hồi giáo viên',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.reviews});
  final List<TeacherReview> reviews;

  @override
  Widget build(BuildContext context) {
    return ResponsivePageContainer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        itemCount: reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ReviewCard(review: reviews[i]),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final TeacherReview review;

  String get _skillLabel => switch (review.skill) {
        'writing' => 'Viết',
        'speaking' => 'Nói',
        _ => review.skill,
      };

  Color get _statusColor => switch (review.status) {
        'reviewed' => const Color(0xFF16A34A),
        'pending' => AppColors.onSurfaceVariant,
        'closed' => AppColors.outline,
        _ => AppColors.onSurfaceVariant,
      };

  String get _statusLabel => switch (review.status) {
        'reviewed' => 'Đã chấm',
        'pending' => 'Đang chờ',
        'closed' => 'Đã đóng',
        _ => review.status,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.teacherThreadPath(review.id)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.outlineVariant.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.onBackground.withOpacity(0.04),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          children: [
            // Skill icon circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                review.skill == 'speaking'
                    ? Icons.record_voice_over_rounded
                    : Icons.edit_note_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          _skillLabel.toUpperCase(),
                          style: AppTypography.labelUppercase.copyWith(
                            color: AppColors.primary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (review.unreadCount > 0)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${review.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.previewText ?? 'Bài nộp ${review.id.substring(0, 6)}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy')
                            .format(review.createdAt),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _statusLabel,
                        style: AppTypography.labelUppercase.copyWith(
                          color: _statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có phản hồi',
              style: AppTypography.headlineSmall.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Nộp bài viết hoặc bài nói để nhận phản hồi từ giáo viên.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
