import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/models/course_models.dart';
import 'package:app_czech/features/course/providers/course_providers.dart';
import 'package:app_czech/shared/widgets/circular_progress_ring.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Module detail screen — matches module_detail.html Stitch design.
class ModuleDetailScreen extends ConsumerWidget {
  const ModuleDetailScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
  });

  final String courseId;
  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleAsync = ref.watch(moduleDetailProvider(moduleId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.6),
              ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.primary,
                    onPressed: () => context.pop(),
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Module Details',
                    style: AppTypography.headlineSmall.copyWith(
                      fontSize: 22,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: moduleAsync.when(
        loading: () => const ShimmerCardList(count: 6),
        error: (e, _) => ErrorState(
          message: 'Không tải được module.',
          onRetry: () => ref.refresh(moduleDetailProvider(moduleId)),
        ),
        data: (detail) => _ModuleBody(
          detail: detail,
          courseId: courseId,
          moduleId: moduleId,
        ),
      ),
    );
  }
}

class _ModuleBody extends StatelessWidget {
  const _ModuleBody({
    required this.detail,
    required this.courseId,
    required this.moduleId,
  });

  final ModuleDetail detail;
  final String courseId;
  final String moduleId;

  @override
  Widget build(BuildContext context) {
    final module = detail.module;
    final lessons = detail.lessons;

    return SingleChildScrollView(
      child: ResponsivePageContainer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero image card
              _HeroCard(module: module),
              const SizedBox(height: 24),

              // Description
              if (module.description != null && module.description!.isNotEmpty)
                Text(
                  module.description!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
              const SizedBox(height: 24),

              // Progress card
              _ProgressCard(module: module),
              const SizedBox(height: 40),

              // Lesson list
              Text(
                'Danh sách bài học',
                style: AppTypography.headlineMedium.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),

              if (lessons.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Bài học đang được cập nhật.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Column(
                  children: lessons.map((lesson) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _LessonCard(
                        lesson: lesson,
                        onTap: lesson.status == LessonStatus.locked
                            ? null
                            : () => context.push(
                                  AppRoutes.lessonPlayerPath(
                                    courseId,
                                    moduleId,
                                    lesson.id,
                                  ),
                                ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.module});
  final ModuleSummary module;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: 192,
        child: Stack(
          children: [
            // Background color placeholder
            Container(
              color: AppColors.primaryContainer,
              child: const Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 80,
                  color: Colors.white24,
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x993A302A)],
                ),
              ),
            ),
            // Bottom content
            Positioned(
              bottom: 16,
              left: 24,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'MODUL ${module.orderIndex + 1}',
                      style: AppTypography.labelUppercase.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    module.title,
                    style: AppTypography.headlineMedium.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                      fontStyle: FontStyle.normal,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress Card ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.module});
  final ModuleSummary module;

  @override
  Widget build(BuildContext context) {
    final pct = (module.progressFraction * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: ScoreHeroRing(
              score: pct,
              maxScore: 100,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiến độ module',
                style: AppTypography.titleSmall.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn đã hoàn thành ${module.completedCount} trên ${module.lessonCount} bài học.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lesson Card ───────────────────────────────────────────────────────────────

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    this.onTap,
  });

  final LessonSummary lesson;
  final VoidCallback? onTap;

  bool get _isCompleted => lesson.status == LessonStatus.completed;
  bool get _isInProgress => lesson.status == LessonStatus.inProgress;
  bool get _isLocked => lesson.status == LessonStatus.locked;
  bool get _canReplay => lesson.canReplay;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isLocked ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isLocked
                ? AppColors.surfaceContainer.withOpacity(0.3)
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: _isInProgress
                  ? AppColors.primary
                  : _isLocked
                      ? AppColors.outlineVariant.withOpacity(0.2)
                      : Colors.transparent,
              width: _isInProgress ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.onBackground
                    .withOpacity(_isInProgress ? 0.08 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isLocked
                      ? AppColors.surfaceContainerHighest.withOpacity(0.5)
                      : _isCompleted
                          ? AppColors.primary.withOpacity(0.1)
                          : _isInProgress
                              ? AppColors.primary
                              : AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLocked
                      ? Icons.lock_rounded
                      : _isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.play_arrow_rounded,
                  color: _isLocked
                      ? AppColors.outline
                      : _isCompleted
                          ? AppColors.primary
                          : _isInProgress
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lesson.orderIndex + 1}. ${lesson.title}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight:
                            _isInProgress ? FontWeight.w700 : FontWeight.w600,
                        color: _isLocked
                            ? AppColors.onBackground.withOpacity(0.7)
                            : AppColors.onBackground,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.onSurfaceVariant
                              .withOpacity(_isLocked ? 0.7 : 1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lesson.durationMinutes} phút',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant
                                .withOpacity(_isLocked ? 0.7 : 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${lesson.completedBlockCount}/${lesson.totalBlockCount} blocks',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant
                                .withOpacity(_isLocked ? 0.7 : 1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing
              if (_isCompleted && _canReplay)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'HỌC LẠI',
                    style: AppTypography.labelUppercase.copyWith(
                      color: AppColors.primary,
                      fontSize: 9,
                    ),
                  ),
                )
              else if (_isInProgress)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'ĐANG HỌC',
                    style: AppTypography.labelUppercase.copyWith(
                      color: AppColors.onBackground,
                      fontSize: 9,
                    ),
                  ),
                )
              else if (!_isLocked)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.outline,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
