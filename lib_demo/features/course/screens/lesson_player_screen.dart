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

/// Lesson detail screen — matches lesson_detail.html Stitch design.
class LessonPlayerScreen extends ConsumerWidget {
  const LessonPlayerScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.lessonId,
  });

  final String courseId;
  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonDetailProvider(lessonId));

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
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Lesson Detail',
                    style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: lessonAsync.when(
        loading: () => const ShimmerCardList(count: 4),
        error: (e, _) => ErrorState(
          message: 'Không tải được bài học.',
          onRetry: () => ref.refresh(lessonDetailProvider(lessonId)),
        ),
        data: (detail) => _LessonBody(
          detail: detail,
          courseId: courseId,
          moduleId: moduleId,
          lessonId: lessonId,
          ref: ref,
        ),
      ),
    );
  }
}

class _LessonBody extends StatelessWidget {
  const _LessonBody({
    required this.detail,
    required this.courseId,
    required this.moduleId,
    required this.lessonId,
    required this.ref,
  });

  final LessonDetail detail;
  final String courseId;
  final String moduleId;
  final String lessonId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final blocks = detail.blocks;
    final completedCount = detail.completedBlockCount;
    final totalCount = blocks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 160),
          child: ResponsivePageContainer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero card
                  _HeroCard(
                    detail: detail,
                    progress: progress,
                    completedCount: completedCount,
                    totalCount: totalCount,
                  ),
                  const SizedBox(height: 24),

                  // Learning blocks grid
                  if (blocks.isNotEmpty) ...[
                    _LearningBlocksGrid(
                      blocks: blocks,
                      courseId: courseId,
                      moduleId: moduleId,
                      lessonId: lessonId,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Bonus section
                  _BonusSection(
                    lessonId: lessonId,
                    isUnlocked: detail.bonusUnlocked,
                    xpCost: detail.bonusXpCost,
                    courseId: courseId,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        // Fixed bottom CTA
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomCta(
            label: detail.isCompleted ? 'Học lại bài này' : 'Tiếp tục bài học',
            icon: detail.isCompleted
                ? Icons.refresh_rounded
                : Icons.play_arrow_rounded,
            onContinue: () async {
              if (detail.isCompleted) {
                final shouldReplay = await _showReplayDialog(context);
                if (shouldReplay != true) return;
                await resetLessonProgress(lessonId: lessonId);
                refreshCourseProgressProviders(
                  ref,
                  courseId: courseId,
                  moduleId: moduleId,
                  lessonId: lessonId,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Đã reset tiến độ bài học. Bạn có thể học lại từ đầu.'),
                    ),
                  );
                }
                return;
              }

              context.push(
                AppRoutes.moduleDetailPath(courseId, moduleId),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.detail,
    required this.progress,
    required this.completedCount,
    required this.totalCount,
  });

  final LessonDetail detail;
  final double progress;
  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background icon
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              _levelIcon(detail.lesson.skill),
              size: 160,
              color: AppColors.primary.withOpacity(0.05),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge + duration row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      detail.courseTitle.toUpperCase(),
                      style: AppTypography.labelUppercase.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${detail.lesson.durationMinutes} phút',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                detail.lesson.title,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 28,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),

              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$pct% Hoàn thành',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$completedCount/$totalCount blocks completed',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _levelIcon(String skill) {
    return switch (skill.toLowerCase()) {
      'listening' => Icons.headset_rounded,
      'speaking' => Icons.record_voice_over_rounded,
      'writing' => Icons.edit_note_rounded,
      'reading' => Icons.auto_stories_rounded,
      'grammar' => Icons.account_tree_rounded,
      _ => Icons.restaurant_rounded,
    };
  }
}

// ── Learning Blocks Grid ──────────────────────────────────────────────────────

class _LearningBlocksGrid extends StatelessWidget {
  const _LearningBlocksGrid({
    required this.blocks,
    required this.courseId,
    required this.moduleId,
    required this.lessonId,
  });

  final List<LessonBlock> blocks;
  final String courseId;
  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return isWide
        ? _TwoColGrid(
            blocks: blocks,
            courseId: courseId,
            moduleId: moduleId,
            lessonId: lessonId,
          )
        : Column(
            children: blocks
                .map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _BlockCard(
                        block: b,
                        courseId: courseId,
                        moduleId: moduleId,
                        lessonId: lessonId,
                      ),
                    ))
                .toList(),
          );
  }
}

class _TwoColGrid extends StatelessWidget {
  const _TwoColGrid(
      {required this.blocks,
      required this.courseId,
      required this.moduleId,
      required this.lessonId});
  final List<LessonBlock> blocks;
  final String courseId;
  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < blocks.length; i += 2) {
      final left = blocks[i];
      final right = i + 1 < blocks.length ? blocks[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                  child: _BlockCard(
                      block: left,
                      courseId: courseId,
                      moduleId: moduleId,
                      lessonId: lessonId)),
              if (right != null) ...[
                const SizedBox(width: 16),
                Expanded(
                    child: _BlockCard(
                        block: right,
                        courseId: courseId,
                        moduleId: moduleId,
                        lessonId: lessonId)),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard(
      {required this.block,
      required this.courseId,
      required this.moduleId,
      required this.lessonId});

  final LessonBlock block;
  final String courseId;
  final String moduleId;
  final String lessonId;

  bool get _isCompleted => block.status == BlockStatus.completed;

  IconData get _icon => switch (block.type) {
        BlockType.vocab => Icons.menu_book_rounded,
        BlockType.grammar => Icons.account_tree_rounded,
        BlockType.listening => Icons.headset_rounded,
        BlockType.speaking => Icons.record_voice_over_rounded,
        BlockType.reading => Icons.auto_stories_rounded,
        BlockType.writing => Icons.edit_note_rounded,
      };

  String get _label => switch (block.type) {
        BlockType.vocab => 'Vocabulary',
        BlockType.grammar => 'Grammar',
        BlockType.listening => 'Listening',
        BlockType.speaking => 'Speaking',
        BlockType.reading => 'Reading',
        BlockType.writing => 'Writing',
      };

  String get _sublabel => switch (block.type) {
        BlockType.vocab => 'Từ vựng',
        BlockType.grammar => 'Ngữ pháp',
        BlockType.listening => 'Nghe',
        BlockType.speaking => 'Nói',
        BlockType.reading => 'Đọc',
        BlockType.writing => 'Viết',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!block.hasExercises) return;
        final firstExerciseId = block.exerciseIds.first;

        // Speaking and writing blocks route to AI screens with exercise context
        if (block.type == BlockType.speaking) {
          context.push(
            AppRoutes.speakingPrompt,
            extra: {
              'prompt': block.prompt ?? '',
              'questionId': firstExerciseId,
              'exerciseId': firstExerciseId,
              'lessonId': block.lessonId,
              'lessonBlockId': block.id,
              'courseId': courseId,
              'moduleId': moduleId,
            },
          );
          return;
        }
        if (block.type == BlockType.writing) {
          context.push(
            AppRoutes.writingPrompt,
            extra: {
              'prompt': block.prompt ?? '',
              'questionId': '',
              'exerciseId': firstExerciseId,
              'lessonId': block.lessonId,
              'lessonBlockId': block.id,
              'courseId': courseId,
              'moduleId': moduleId,
            },
          );
          return;
        }
        // All other types go to PracticeScreen
        final route = switch (block.type) {
          BlockType.grammar => AppRoutes.grammarPracticePath(firstExerciseId),
          BlockType.listening =>
            AppRoutes.listeningPracticePath(firstExerciseId),
          BlockType.reading => AppRoutes.readingPracticePath(firstExerciseId),
          BlockType.vocab => AppRoutes.flashcardPracticePath(firstExerciseId),
          _ => AppRoutes.practiceExercisePath(firstExerciseId),
        };
        context.push(
          route,
          extra: {
            'lessonId': lessonId,
            'lessonBlockId': block.id,
            'courseId': courseId,
            'moduleId': moduleId,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isCompleted
              ? AppColors.surfaceContainerLowest
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: _isCompleted
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.outlineVariant.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onBackground.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isCompleted
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                _icon,
                color: _isCompleted
                    ? AppColors.primary
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
                    _label,
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 16,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _sublabel,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_isCompleted)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              )
            else
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.onSurfaceVariant,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Bonus Section ─────────────────────────────────────────────────────────────

class _BonusSection extends StatelessWidget {
  const _BonusSection({
    required this.lessonId,
    required this.isUnlocked,
    required this.xpCost,
    required this.courseId,
  });

  final String lessonId;
  final bool isUnlocked;
  final int xpCost;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bonus Practice',
          style: AppTypography.headlineMedium.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              // Content (blurred if locked)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.2),
                  ),
                ),
                child: Opacity(
                  opacity: isUnlocked ? 1.0 : 0.4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bài tập nâng cao',
                        style: AppTypography.titleSmall.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nội dung luyện tập chuyên sâu mô phỏng tình huống thực tế',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Lock overlay
              if (!isUnlocked)
                Positioned.fill(
                  child: Container(
                    color: AppColors.surfaceContainer.withOpacity(0.6),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => context.push(
                          AppRoutes.unlockBonusPath(lessonId),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.onBackground,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_rounded,
                                  color: AppColors.surface, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Mở khóa bằng $xpCost điểm',
                                style: AppTypography.labelUppercase.copyWith(
                                  color: AppColors.surface,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bottom CTA ────────────────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.onContinue,
    required this.label,
    required this.icon,
  });

  final VoidCallback onContinue;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface.withOpacity(0),
            AppColors.surface,
            AppColors.surface,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: onContinue,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> _showReplayDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Học lại bài này?'),
      content: const Text(
        'Tiến độ hoàn thành của bài sẽ được reset để bạn làm lại từ đầu. XP đã nhận trước đó vẫn được giữ nguyên.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reset và học lại'),
        ),
      ],
    ),
  );
}
