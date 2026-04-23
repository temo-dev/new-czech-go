import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/providers/course_providers.dart';
import 'package:app_czech/features/exercise/providers/exercise_provider.dart';
import 'package:app_czech/features/exercise/widgets/explanation_panel.dart';
import 'package:app_czech/features/exercise/widgets/question_shell.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/shared/providers/gamification_provider.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Single-exercise practice screen — matches grammar_practice.html Stitch design.
/// Route params (via GoRouter extra):
///   exerciseId    — required
///   lessonId      — optional; needed to mark block complete
///   lessonBlockId — optional; needed to mark block complete
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({
    super.key,
    required this.exerciseId,
    this.lessonId,
    this.lessonBlockId,
    this.courseId,
    this.moduleId,
  });

  final String exerciseId;
  final String? lessonId;
  final String? lessonBlockId;
  final String? courseId;
  final String? moduleId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  QuestionAnswer? _answer;
  bool _isSubmitted = false;
  bool _isCorrect = false;
  bool _isSubmitting = false;
  int _xpAwarded = 0;

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(exerciseProvider(widget.exerciseId));

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
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.onSurfaceVariant,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    exerciseAsync.maybeWhen(
                      data: (q) => _skillLabel(q.skill),
                      orElse: () => 'Luyện tập',
                    ),
                    style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                  ),
                  const Spacer(),
                  const Icon(Icons.eco_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
      body: exerciseAsync.when(
        loading: () => const ShimmerCardList(count: 3),
        error: (e, _) => ErrorState(
          message: 'Không tải được bài tập.',
          onRetry: () => ref.refresh(exerciseProvider(widget.exerciseId)),
        ),
        data: (question) => _PracticeBody(
          question: question,
          answer: _answer,
          isSubmitted: _isSubmitted,
          isCorrect: _isCorrect,
          isSubmitting: _isSubmitting,
          xpAwarded: _xpAwarded,
          onAnswerChanged: (a) => setState(() => _answer = a),
          onSubmit: () => _submit(question),
          onContinue: () => context.pop(),
        ),
      ),
    );
  }

  String _skillLabel(SkillArea? skill) => switch (skill) {
        SkillArea.grammar => 'Luyện tập Ngữ pháp',
        SkillArea.listening => 'Luyện tập Nghe',
        SkillArea.reading => 'Luyện tập Đọc',
        SkillArea.speaking => 'Luyện tập Nói',
        SkillArea.writing => 'Luyện tập Viết',
        _ => 'Luyện tập',
      };

  Future<void> _submit(Question question) async {
    if (_answer == null || _isSubmitting) return;

    final correct = _evaluate(question, _answer!);
    final xpAwarded =
        correct ? (question.points > 0 ? question.points : 10) : 0;

    setState(() {
      _isSubmitting = true;
      _isCorrect = correct;
    });

    await Future.wait([
      _handleXp(xpAwarded),
      _recordAttempt(correct, xpAwarded),
      _markComplete(),
    ]);

    if (!mounted) return;
    setState(() {
      _isSubmitted = true;
      _isSubmitting = false;
    });

    await ExplanationPanel.show(
      context,
      question: question,
      isCorrect: _isCorrect,
      submittedAnswer: _answer,
      source: widget.lessonId != null ? 'lesson' : 'practice',
      exerciseId: widget.exerciseId,
      lessonId: widget.lessonId,
      onContinue: () {},
    );
  }

  bool _evaluate(Question question, QuestionAnswer answer) {
    switch (question.type) {
      case QuestionType.mcq:
        final correctOption =
            question.options.where((o) => o.isCorrect).firstOrNull;
        if (correctOption == null) return false;
        return answer.selectedOptionId == correctOption.id;

      case QuestionType.fillBlank:
        final written = answer.writtenAnswer?.trim().toLowerCase() ?? '';
        final correct = question.correctAnswer?.trim().toLowerCase() ?? '';
        return written == correct && written.isNotEmpty;

      case QuestionType.writing:
        return answer.writtenAnswer?.trim().isNotEmpty ?? false;

      case QuestionType.speaking:
        return answer.writtenAnswer?.trim().isNotEmpty ?? false;

      default:
        return false;
    }
  }

  Future<void> _handleXp(int xpAwarded) async {
    if (xpAwarded <= 0) return;
    await awardXp(ref, xpAwarded);
    if (mounted) setState(() => _xpAwarded = xpAwarded);
  }

  Future<void> _recordAttempt(bool correct, int xpAwarded) async {
    final userId = supabase.auth.currentUser?.id;
    final answer = _answer;
    if (userId == null || answer == null) return;

    await supabase.from('exercise_attempts').insert({
      'exercise_id': widget.exerciseId,
      'user_id': userId,
      'lesson_block_id': widget.lessonBlockId,
      'answer': answer.toJson(),
      'is_correct': correct,
      'xp_awarded': xpAwarded,
      'attempted_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _markComplete() async {
    final lessonId = widget.lessonId;
    final blockId = widget.lessonBlockId;
    final courseId = widget.courseId;
    final moduleId = widget.moduleId;
    if (lessonId == null ||
        blockId == null ||
        courseId == null ||
        moduleId == null) {
      return;
    }

    await markBlockComplete(lessonId: lessonId, lessonBlockId: blockId);
    await updateActivityStreak(ref);
    refreshCourseProgressProviders(
      ref,
      courseId: courseId,
      moduleId: moduleId,
      lessonId: lessonId,
    );
  }
}

// ── Practice body ─────────────────────────────────────────────────────────────

class _PracticeBody extends StatelessWidget {
  const _PracticeBody({
    required this.question,
    required this.answer,
    required this.isSubmitted,
    required this.isCorrect,
    required this.isSubmitting,
    required this.xpAwarded,
    required this.onAnswerChanged,
    required this.onSubmit,
    required this.onContinue,
  });

  final Question question;
  final QuestionAnswer? answer;
  final bool isSubmitted;
  final bool isCorrect;
  final bool isSubmitting;
  final int xpAwarded;
  final ValueChanged<QuestionAnswer> onAnswerChanged;
  final VoidCallback onSubmit;
  final VoidCallback onContinue;

  bool get _hasAnswer {
    if (answer == null) return false;
    return switch (question.type) {
      QuestionType.mcq => answer!.selectedOptionId != null,
      QuestionType.fillBlank ||
      QuestionType.writing ||
      QuestionType.speaking =>
        answer!.writtenAnswer?.trim().isNotEmpty ?? false,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: ResponsivePageContainer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress
                  _ProgressBar(current: 8, total: 15),
                  const SizedBox(height: 24),

                  // XP badge
                  if (isSubmitted && isCorrect && xpAwarded > 0)
                    _XpBadge(xp: xpAwarded),

                  // Question
                  QuestionShell(
                    question: question,
                    currentAnswer: answer,
                    isSubmitted: isSubmitted,
                    onAnswerChanged: isSubmitted ? null : onAnswerChanged,
                  ),

                  // Inline feedback for correct answer
                  if (isSubmitted) ...[
                    const SizedBox(height: 16),
                    _FeedbackCard(isCorrect: isCorrect, question: question),
                  ],
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: _CtaButton(
                isSubmitted: isSubmitted,
                hasAnswer: _hasAnswer,
                isSubmitting: isSubmitting,
                onSubmit: onSubmit,
                onContinue: onContinue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Progress Bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TIẾN ĐỘ BÀI HỌC',
              style: AppTypography.labelUppercase.copyWith(
                color: AppColors.primary,
              ),
            ),
            Text(
              '$current / $total',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ── Feedback Card ─────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.isCorrect, required this.question});
  final bool isCorrect;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final explanation = question.explanation;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isCorrect
            ? const Color(0xFFECFDF5) // emerald-50
            : AppColors.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFFD1FAE5) // emerald-100
              : AppColors.error.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.verified_rounded : Icons.cancel_rounded,
                color: isCorrect
                    ? const Color(0xFF059669) // emerald-700
                    : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Chính xác!' : 'Chưa đúng',
                style: AppTypography.labelSmall.copyWith(
                  color: isCorrect ? const Color(0xFF059669) : AppColors.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: AppTypography.bodySmall.copyWith(
                color: isCorrect
                    ? const Color(0xFF065F46) // emerald-900
                    : AppColors.error,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── XP Badge ─────────────────────────────────────────────────────────────────

class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 4),
          Text(
            '+$xp XP',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── CTA Button ────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.isSubmitted,
    required this.hasAnswer,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onContinue,
  });

  final bool isSubmitted;
  final bool hasAnswer;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final canTap = isSubmitted || (hasAnswer && !isSubmitting);

    return GestureDetector(
      onTap: canTap ? (isSubmitted ? onContinue : onSubmit) : null,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: canTap ? AppColors.primary : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: canTap
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                isSubmitted ? 'Tiếp tục' : 'Kiểm tra',
                style: AppTypography.labelMedium.copyWith(
                  color: canTap ? Colors.white : AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
