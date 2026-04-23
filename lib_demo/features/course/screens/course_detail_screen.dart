import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/models/course_models.dart';
import 'package:app_czech/features/course/providers/course_providers.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Course overview screen — matches course_overview.html Stitch design.
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: courseAsync.when(
        loading: () => const ShimmerBentoGrid(),
        error: (e, _) => ErrorState(
          message: 'Không tải được khóa học.',
          onRetry: () => ref.refresh(courseDetailProvider(courseId)),
        ),
        data: (course) => _CourseBody(course: course, courseId: courseId),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _CourseBody extends StatelessWidget {
  const _CourseBody({required this.course, required this.courseId});

  final CourseDetail course;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePageContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroSection(course: course),
              const SizedBox(height: 48),
              _BentoGrid(course: course, courseId: courseId),
              const SizedBox(height: 24),
              _ModuleList(course: course, courseId: courseId),
              const SizedBox(height: 80),
              _InstructorSection(course: course),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.course});
  final CourseDetail course;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 8,
            child: _HeroText(course: course),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 4,
            child: _ProgressCard(course: course),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroText(course: course),
        const SizedBox(height: 24),
        _ProgressCard(course: course),
      ],
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.course});
  final CourseDetail course;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Row(
          children: [
            Text(
              'COURSES',
              style: AppTypography.labelUppercase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.onSurfaceVariant),
            Text(
              course.skill.toUpperCase(),
              style: AppTypography.labelUppercase.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          course.title,
          style: AppTypography.headlineLarge.copyWith(
            fontSize: 48,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          course.description,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.course});
  final CourseDetail course;

  @override
  Widget build(BuildContext context) {
    final pct = (course.overallProgress * 100).round();
    final completedLessons =
        course.modules.fold(0, (sum, m) => sum + m.completedCount);
    final totalLessons =
        course.modules.fold(0, (sum, m) => sum + m.lessonCount);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TIẾN ĐỘ CỦA BẠN',
                style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                '$pct%',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.primary,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: course.overallProgress,
              backgroundColor: AppColors.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedLessons / $totalLessons Bài học',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(course.durationDays - course.overallProgress * course.durationDays).round()} ngày còn lại',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bento Grid ────────────────────────────────────────────────────────────────

class _BentoGrid extends StatelessWidget {
  const _BentoGrid({required this.course, required this.courseId});
  final CourseDetail course;
  final String courseId;

  ModuleSummary? get _activeModule {
    for (final m in course.modules) {
      if (!m.isLocked && m.status == ModuleStatus.inProgress) return m;
    }
    for (final m in course.modules) {
      if (!m.isLocked && m.status != ModuleStatus.completed) return m;
    }
    for (final m in course.modules) {
      if (!m.isLocked) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final active = _activeModule;

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: _CtaCard(
              activeModule: active,
              courseId: courseId,
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 200,
            child: _GoalCard(course: course),
          ),
        ],
      );
    }

    return Column(
      children: [
        _CtaCard(activeModule: active, courseId: courseId),
        const SizedBox(height: 16),
        _GoalCard(course: course),
      ],
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.activeModule, required this.courseId});
  final ModuleSummary? activeModule;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final moduleNum = activeModule != null ? activeModule!.orderIndex + 1 : 1;
    final moduleTitle = activeModule?.title ?? 'Bắt đầu học';
    final isInProgress = activeModule?.status == ModuleStatus.inProgress;
    final badgeLabel = isInProgress
        ? 'ĐANG HỌC: MODULE $moduleNum'
        : 'SẴN SÀNG: MODULE $moduleNum';
    final headline = isInProgress
        ? 'Tiếp tục học: $moduleTitle'
        : 'Bắt đầu học: $moduleTitle';
    final actionLabel = isInProgress ? 'Tiếp tục học ngay' : 'Bắt đầu học ngay';
    final statusText = isInProgress
        ? 'Bạn đã hoàn thành ${(activeModule?.progressFraction ?? 0) * 100 ~/ 1}% module này. Tiếp tục để mở rộng tiến độ thật của khóa học.'
        : 'Module này chưa có tiến độ. Bạn có thể bắt đầu từ bài đầu tiên bất cứ lúc nào.';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative icon
          Positioned(
            top: -8,
            right: -8,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 100,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  badgeLabel,
                  style: AppTypography.labelUppercase.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                headline,
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: activeModule != null
                    ? () => context.push(
                          AppRoutes.moduleDetailPath(
                              courseId, activeModule!.id),
                        )
                    : null,
                child: AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.onBackground,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.surface,
                          size: 18,
                        ),
                      ],
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.course});
  final CourseDetail course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mục tiêu hôm nay',
            style: AppTypography.headlineSmall.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Học mỗi ngày để hoàn thành trong ${course.durationDays} ngày',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  )),
              const SizedBox(width: 8),
              Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  )),
              const SizedBox(width: 8),
              Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Module List ───────────────────────────────────────────────────────────────

class _ModuleList extends StatefulWidget {
  const _ModuleList({required this.course, required this.courseId});
  final CourseDetail course;
  final String courseId;

  @override
  State<_ModuleList> createState() => _ModuleListState();
}

class _ModuleListState extends State<_ModuleList> {
  late int _expandedIndex;

  @override
  void initState() {
    super.initState();
    // Auto-expand the first in-progress module
    _expandedIndex = -1;
    for (var i = 0; i < widget.course.modules.length; i++) {
      final m = widget.course.modules[i];
      if (!m.isLocked && m.status == ModuleStatus.inProgress) {
        _expandedIndex = i;
        break;
      }
    }
    if (_expandedIndex < 0) {
      for (var i = 0; i < widget.course.modules.length; i++) {
        if (!widget.course.modules[i].isLocked &&
            widget.course.modules[i].status != ModuleStatus.completed) {
          _expandedIndex = i;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nội dung khóa học',
                style: AppTypography.headlineMedium.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.outlineVariant),
            ],
          ),
        ),
        ...widget.course.modules.asMap().entries.map((entry) {
          final i = entry.key;
          final module = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ModuleCard(
              module: module,
              index: i,
              courseId: widget.courseId,
              isExpanded: _expandedIndex == i,
              onTap: () {
                if (module.isLocked) return;
                setState(() {
                  _expandedIndex = _expandedIndex == i ? -1 : i;
                });
              },
            ),
          );
        }),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.index,
    required this.courseId,
    required this.isExpanded,
    required this.onTap,
  });

  final ModuleSummary module;
  final int index;
  final String courseId;
  final bool isExpanded;
  final VoidCallback onTap;

  bool get _isCompleted => module.status == ModuleStatus.completed;
  bool get _isActive => module.status == ModuleStatus.inProgress;

  @override
  Widget build(BuildContext context) {
    final status = module.isLocked
        ? 'Đang khóa'
        : switch (module.status) {
            ModuleStatus.completed => 'Hoàn thành',
            ModuleStatus.inProgress => 'Đang học',
            ModuleStatus.notStarted => 'Chưa bắt đầu',
            ModuleStatus.locked => 'Đang khóa',
          };

    return Opacity(
      opacity: module.isLocked ? 0.7 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: _isActive
              ? Colors.white
              : AppColors.surfaceContainerLow
                  .withOpacity(module.isLocked ? 0.5 : 1.0),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _isActive
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.outlineVariant
                    .withOpacity(module.isLocked ? 0.2 : 0.3),
            width: _isActive ? 2.0 : 1.0,
          ),
          boxShadow: _isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // Header row
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(24),
                color: _isActive
                    ? AppColors.primary.withOpacity(0.05)
                    : Colors.transparent,
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: module.isLocked
                            ? AppColors.surfaceContainerHighest
                            : _isCompleted
                                ? const Color(0xFFDCFCE7) // green-100
                                : _isActive
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        module.isLocked
                            ? Icons.lock_rounded
                            : _isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.play_circle_filled_rounded,
                        color: module.isLocked
                            ? AppColors.onSurfaceVariant
                            : _isCompleted
                                ? const Color(0xFF166534) // green-700
                                : _isActive
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${module.title}',
                            style: AppTypography.titleSmall.copyWith(
                              fontSize: 17,
                              color: module.isLocked
                                  ? AppColors.onSurfaceVariant.withOpacity(0.6)
                                  : AppColors.onBackground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${module.completedCount}/${module.lessonCount} bài học • $status',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.onSurfaceVariant
                                  .withOpacity(module.isLocked ? 0.4 : 1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!module.isLocked)
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: _isActive
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),

            // Expanded lesson tiles (placeholder — real lessons from provider)
            if (isExpanded && !module.isLocked) ...[
              const Divider(
                height: 1,
                color: AppColors.outlineVariant,
                indent: 24,
                endIndent: 24,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: _LessonTileList(
                  module: module,
                  courseId: courseId,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonTileList extends StatelessWidget {
  const _LessonTileList({required this.module, required this.courseId});
  final ModuleSummary module;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    // Show placeholder lesson tiles based on lesson count
    return Column(
      children: List.generate(module.lessonCount, (i) {
        final isCompleted = i < module.completedCount;
        final isActive = module.status == ModuleStatus.inProgress &&
            i == module.completedCount;

        return _LessonTile(
          number: i + 1,
          isCompleted: isCompleted,
          isActive: isActive,
          onTap: isCompleted || isActive
              ? () => context.push(
                    AppRoutes.moduleDetailPath(courseId, module.id),
                  )
              : null,
        );
      }),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.number,
    required this.isCompleted,
    required this.isActive,
    this.onTap,
  });

  final int number;
  final bool isCompleted;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: isActive
            ? const EdgeInsets.symmetric(vertical: 2)
            : EdgeInsets.zero,
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                border: const Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
              )
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(isActive ? 12 : 0, 14, 0, 14),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  number.toString().padLeft(2, '0'),
                  style: AppTypography.labelSmall.copyWith(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant.withOpacity(0.4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Bài $number',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isActive
                        ? AppColors.onBackground
                        : isCompleted
                            ? AppColors.onBackground
                            : AppColors.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'ĐANG HỌC',
                    style: AppTypography.labelUppercase.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                )
              else if (isCompleted)
                const Icon(Icons.task_alt_rounded,
                    color: Color(0xFF16A34A), size: 20)
              else
                Icon(Icons.play_arrow_rounded,
                    color: AppColors.onSurfaceVariant.withOpacity(0.4),
                    size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Instructor Section ────────────────────────────────────────────────────────

class _InstructorSection extends StatelessWidget {
  const _InstructorSection({required this.course});
  final CourseDetail course;

  @override
  Widget build(BuildContext context) {
    if (course.instructorName == null && course.instructorBio == null) {
      return const SizedBox.shrink();
    }
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Column(
      children: [
        const Divider(color: AppColors.outlineVariant),
        const SizedBox(height: 48),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _InstructorAvatar(),
              const SizedBox(width: 40),
              Expanded(child: _InstructorBio(course: course)),
            ],
          )
        else
          Column(
            children: [
              const _InstructorAvatar(),
              const SizedBox(height: 24),
              _InstructorBio(course: course),
            ],
          ),
      ],
    );
  }
}

class _InstructorAvatar extends StatelessWidget {
  const _InstructorAvatar();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.onBackground.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 64,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InstructorBio extends StatelessWidget {
  const _InstructorBio({required this.course});
  final CourseDetail course;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Giảng viên: ${course.instructorName ?? 'Giảng viên'}',
          style: AppTypography.headlineMedium.copyWith(fontSize: 24),
        ),
        if (course.instructorBio != null) ...[
          const SizedBox(height: 8),
          Text(
            course.instructorBio!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}
