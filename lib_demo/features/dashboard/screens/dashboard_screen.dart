import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/circular_progress_ring.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/features/dashboard/models/dashboard_models.dart';
import 'package:app_czech/features/dashboard/providers/dashboard_provider.dart';
import 'package:app_czech/features/dashboard/widgets/recommended_lesson_card.dart';
import 'package:app_czech/features/mock_test/providers/exam_result_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);

    return Scaffold(
      key: const Key('dashboard_screen'),
      primary: false,
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Expanded(
            child: dashAsync.when(
              loading: () => const _DashboardSkeleton(),
              error: (e, _) => ErrorState(
                message: 'Không tải được dữ liệu',
                onRetry: () => ref.refresh(dashboardProvider),
              ),
              data: (data) => _DashboardBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  const _DashboardAppBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const SizedBox(width: 44),
              Expanded(
                child: Center(
                  child: Text(
                    'CzechGo',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 30,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-load examId so it's ready when user taps "Thi thử lại"
    if (data.latestResult?.attemptId != null) {
      ref.watch(attemptExamIdProvider(data.latestResult!.attemptId));
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Greeting + streak ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chào bạn, ${data.user.displayName?.split(' ').first ?? ''}',
                              style: AppTypography.headlineLarge.copyWith(
                                color: AppColors.onBackground,
                                fontSize: 32,
                                height: 1.2,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sẵn sàng cho 15 phút học hôm nay?',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Streak badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${data.user.currentStreakDays}',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Bento grid ─────────────────────────────────────────
                  // Row 1: Recommended Lesson (full width)
                  if (data.recommendation != null) ...[
                    RecommendedLessonCard(lesson: data.recommendation!),
                    const SizedBox(height: 16),
                  ],

                  // Row 2: Daily Goal + Latest Test (2-col)
                  Row(
                    children: [
                      // Daily Goal circular progress
                      Expanded(
                        child: _DailyGoalCard(
                          progress: data.activeCourse != null
                              ? (data.activeCourse!.progressFraction * 1.0)
                              : 0.7,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Latest test result
                      Expanded(
                        child: _LatestTestCard(
                          score: data.latestResult?.totalScore,
                          isPending:
                              data.latestResult?.aiGradingPending ?? false,
                          onTap: () {
                            final attemptId = data.latestResult?.attemptId;
                            if (attemptId != null) {
                              final examId = ref
                                  .read(attemptExamIdProvider(attemptId))
                                  .valueOrNull;
                              final path = examId != null
                                  ? '${AppRoutes.mockTestIntro}?examId=$examId'
                                  : AppRoutes.mockTestIntro;
                              context.push(path);
                            } else {
                              context.push(AppRoutes.mockTestIntro);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Quick stats (2-col) ────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _QuickStatCard(
                          iconBg: const Color(0xFFFEF3C7), // amber-100
                          iconColor: const Color(0xFF92400E), // amber-800
                          icon: Icons.payments_rounded,
                          label: 'ĐIỂM THƯỞNG',
                          value: _formatXp(data.user.totalXp),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _QuickStatCard(
                          iconBg: const Color(0xFFFEF3C7), // blue-100
                          iconColor: const Color(0xFF92400E), // blue-800
                          icon: Icons.leaderboard_rounded,
                          label: 'HẠNG TUẦN',
                          value:
                              data.ownRank != null ? '#${data.ownRank}' : '--',
                          onTap: () => context.push(AppRoutes.leaderboard),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Course progress ────────────────────────────────────
                  if (data.activeCourse != null)
                    _CourseProgressCard(course: data.activeCourse!),
                  const SizedBox(height: 32),

                  // ── Primary CTAs ───────────────────────────────────────
                  AppButton(
                    label: 'Tiếp tục học',
                    icon: Icons.directions_run,
                    onPressed: () => context.go(AppRoutes.courses),
                    size: AppButtonSize.lg,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Luyện đề mới',
                    icon: Icons.book,
                    onPressed: () => context.push(AppRoutes.mockTestIntro),
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.lg,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatXp(int xp) {
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(1)}k';
    return '$xp XP';
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.onSecond,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Column(
        children: [
          Text(
            'HÔM NAY',
            style: AppTypography.labelUppercase.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          CircularProgressRing(
            value: progress,
            size: 100,
            strokeWidth: 8,
            color: AppColors.primary,
            bgColor: AppColors.surfaceContainerHighest,
            child: Text(
              '${(progress * 100).round()}%',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.primary,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            progress >= 1.0 ? 'Hoàn thành!' : 'Tiếp tục cố lên!',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LatestTestCard extends StatelessWidget {
  const _LatestTestCard({this.score, this.isPending = false, this.onTap});
  final int? score;
  final bool isPending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.onSecond,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'THI THỬ GẦN NHẤT',
                  style: AppTypography.labelUppercase.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.history_rounded,
                  color: AppColors.tertiary, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isPending
                ? '...'
                : score != null
                    ? '$score%'
                    : '--',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.tertiary,
              fontSize: 36,
            ),
          ),
          Text(
            isPending
                ? 'AI đang hoàn tất chấm bài'
                : score != null
                    ? (score! >= 70 ? 'Đạt yêu cầu' : 'Cần cố gắng thêm')
                    : 'Chưa có dữ liệu',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.tertiary),
                foregroundColor: AppColors.tertiary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Thi thử lại',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.onSecond,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelUppercase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({required this.course});
  final CourseProgress course;

  @override
  Widget build(BuildContext context) {
    final progress = course.progressFraction;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A302A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course.courseTitle,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.onBackground,
                    fontSize: 22,
                    fontStyle: FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CẦN CẢI THIỆN',
            style: AppTypography.labelUppercase.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SkillChip(icon: Icons.spellcheck_rounded, label: 'Ngữ pháp'),
              _SkillChip(icon: Icons.hearing_rounded, label: 'Nghe'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onTertiaryFixed),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onTertiaryFixed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block({double h = 16, double? w}) => LoadingShimmer(
          child: Container(
            height: h,
            width: w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(h: 36, w: 220),
          const SizedBox(height: 8),
          block(h: 18, w: 280),
          const SizedBox(height: 32),
          LoadingShimmer(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LoadingShimmer(
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LoadingShimmer(
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
