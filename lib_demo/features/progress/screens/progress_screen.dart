import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/progress/providers/progress_provider.dart';
import 'package:app_czech/shared/widgets/circular_progress_ring.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _AppBar(),
          Expanded(
            child: async.when(
              loading: () => const ShimmerCardList(count: 4),
              error: (e, _) => ErrorState(
                message: 'Không tải được tiến độ.',
                onRetry: () => ref.refresh(progressProvider),
              ),
              data: (data) => _ProgressBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

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
                const Icon(Icons.menu_rounded,
                    color: AppColors.primary, size: 24),
                const Spacer(),
                Text(
                  'Tiến độ học tập',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.outlineVariant),
                    color: AppColors.surfaceContainerLow,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.onSurfaceVariant, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.data});
  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: ResponsivePageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroGrid(data: data),
            const SizedBox(height: 32),
            _ChartsRow(data: data),
            const SizedBox(height: 32),
            _ExamHistoryCard(history: data.examHistory),
          ],
        ),
      ),
    );
  }
}

// ── Hero Grid ─────────────────────────────────────────────────────────────────

class _HeroGrid extends StatelessWidget {
  const _HeroGrid({required this.data});
  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 768;
    final progress = data.completedLessons / 52.0;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _CourseProgressCard(data: data, progress: progress)),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _StreakCard(streak: data.currentStreak),
                const SizedBox(height: 24),
                _XpCard(xp: data.totalXp),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _CourseProgressCard(data: data, progress: progress),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StreakCard(streak: data.currentStreak)),
            const SizedBox(width: 16),
            Expanded(child: _XpCard(xp: data.totalXp)),
          ],
        ),
      ],
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({required this.data, required this.progress});
  final ProgressData data;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          ScoreHeroRing(
            size: 140,
            score: pct,
            maxScore: 100,
            label: '',
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KHÓA HỌC HIỆN TẠI',
                  style: AppTypography.labelUppercase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trvalý Cấp tốc (A2)',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn đang đi đúng hướng! Hãy hoàn thành thêm bài học nữa.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.completedLessons} / 52',
                          style: AppTypography.headlineSmall.copyWith(
                              fontSize: 20),
                        ),
                        Text(
                          'LESSONS',
                          style: AppTypography.labelUppercase.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Container(
                        width: 1, height: 32,
                        color: AppColors.outlineVariant),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.totalXp}',
                          style: AppTypography.headlineSmall.copyWith(
                              fontSize: 20),
                        ),
                        Text(
                          'TỔNG ĐIỂM XP',
                          style: AppTypography.labelUppercase.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chuỗi ngày học',
                style: AppTypography.headlineSmall.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$streak',
                    style: AppTypography.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ngày liên tiếp',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tuyệt vời! Đừng để chuỗi này kết thúc.',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  const _XpCard({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.diamond_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ĐIỂM TÍCH LŨY',
                style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$xp XP',
                style: AppTypography.headlineSmall.copyWith(fontSize: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Charts Row ────────────────────────────────────────────────────────────────

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({required this.data});
  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    final skillsCard = _SkillsCard(skillScores: data.skillScores);
    final activityCard = _RecentActivityCard(
        activityDates: data.activityDates.toList());

    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: skillsCard),
            const SizedBox(width: 32),
            Expanded(child: activityCard),
          ],
        ),
      );
    }

    return Column(
      children: [
        skillsCard,
        const SizedBox(height: 32),
        activityCard,
      ],
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.skillScores});
  final List<SkillScore> skillScores;

  static const _skillOrder = ['listening', 'speaking', 'reading', 'writing'];
  static const _skillLabels = {
    'listening': 'Nghe (Listening)',
    'speaking': 'Nói (Speaking)',
    'reading': 'Đọc (Reading)',
    'writing': 'Viết (Writing)',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Đánh giá kỹ năng',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 22)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius:
                      BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'Dữ liệu tuần này',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ..._skillOrder.map((skill) {
            final entry = skillScores
                .where((s) => s.skill == skill)
                .firstOrNull;
            final pct = entry?.score.round() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _SkillBar(
                label: _skillLabels[skill] ?? skill,
                pct: pct,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.label, required this.pct});
  final String label;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label,
                style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('$pct%',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: pct / 100.0,
            backgroundColor: AppColors.surfaceContainer,
            valueColor:
                const AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activityDates});
  final List<DateTime> activityDates;

  @override
  Widget build(BuildContext context) {
    // Use last 3 activity dates for display
    final recent = activityDates.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Hoạt động gần đây',
                  style:
                      AppTypography.headlineSmall.copyWith(fontSize: 22)),
              const Spacer(),
              Text(
                'Xem tất cả',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (recent.isEmpty)
            Text(
              'Chưa có hoạt động nào.',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant),
            )
          else
            ...recent.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isFirst
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Luyện tập',
                            style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy')
                                .format(e.value),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isFirst ? '10 min ago' : 'Hôm qua',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Exam History Card ─────────────────────────────────────────────────────────

class _ExamHistoryCard extends StatelessWidget {
  const _ExamHistoryCard({required this.history});
  final List<ExamHistoryItem> history;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lịch sử thi thử',
              style: AppTypography.headlineSmall.copyWith(fontSize: 22)),
          const SizedBox(height: 24),
          // Header row
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'KỲ THI',
                    style: AppTypography.labelUppercase.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'KẾT QUẢ',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelUppercase.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'NGÀY',
                    style: AppTypography.labelUppercase.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 80),
              ],
            ),
          ),
          Container(
              height: 1, color: AppColors.outlineVariant),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Chưa có kết quả thi thử nào.',
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant),
              ),
            )
          else
            ...history.asMap().entries.map((e) {
              final item = e.value;
              final idx = e.key + 1;
              return _ExamRow(item: item, label: 'Mock Test #$idx');
            }),
        ],
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.item, required this.label});
  final ExamHistoryItem item;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pct = item.totalScore;
    final passed = item.passed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$pct%',
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: passed
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd/MM/yyyy').format(item.createdAt),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: passed
                  ? const Color(0xFFDCFCE7) // green-100
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              passed ? 'Vượt qua' : 'Cần cố gắng',
              style: AppTypography.labelUppercase.copyWith(
                color: passed
                    ? const Color(0xFF166534) // green-800
                    : AppColors.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
