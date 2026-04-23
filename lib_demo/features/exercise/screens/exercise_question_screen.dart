import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/exercise/providers/exercise_provider.dart';
import 'package:app_czech/features/exercise/widgets/explanation_panel.dart';
import 'package:app_czech/features/exercise/widgets/question_shell.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/shared/providers/gamification_provider.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Practice question screen — navigated to with GoRouter extras containing
/// `exerciseId`. The `index` param is used for progress display.
///
/// extras: `{ 'exerciseId': String, 'totalCount': int }`
class ExerciseQuestionScreen extends ConsumerStatefulWidget {
  const ExerciseQuestionScreen({super.key, required this.index});

  final int index;

  @override
  ConsumerState<ExerciseQuestionScreen> createState() =>
      _ExerciseQuestionScreenState();
}

class _ExerciseQuestionScreenState
    extends ConsumerState<ExerciseQuestionScreen> {
  QuestionAnswer? _answer;
  bool _isSubmitted = false;
  bool _isCorrect = false;
  bool _isSubmitting = false;
  int _xpAwarded = 0;

  String? _resolveExerciseId(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      return extra['exerciseId'] as String?;
    }
    return null;
  }

  int _resolveTotalCount(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      return extra['totalCount'] as int? ?? 1;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final exerciseId = _resolveExerciseId(context);

    if (exerciseId == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: ErrorState(
          message: 'Không tìm thấy bài tập. Vui lòng quay lại.',
          onRetry: () => context.go(AppRoutes.practiceIntro),
        ),
      );
    }

    final exerciseAsync = ref.watch(exerciseProvider(exerciseId));
    final totalCount = _resolveTotalCount(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context, widget.index, totalCount),
      body: exerciseAsync.when(
        loading: () => const ShimmerCardList(count: 3),
        error: (e, _) => ErrorState(
          message: 'Không tải được bài tập.',
          onRetry: () => ref.refresh(exerciseProvider(exerciseId)),
        ),
        data: (question) => _QuestionBody(
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

  PreferredSizeWidget _buildAppBar(
      BuildContext context, int index, int total) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            bottom: BorderSide(color: AppColors.outlineVariant),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x2,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.onSurfaceVariant,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go(AppRoutes.practiceIntro),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu ${index + 1} / $total',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: total > 0 ? (index + 1) / total : 0,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                const Icon(Icons.eco_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(Question question) async {
    if (_answer == null || _isSubmitting) return;

    final correct = _evaluate(question, _answer!);
    setState(() {
      _isSubmitting = true;
      _isCorrect = correct;
    });

    if (correct) {
      final xp = question.points > 0 ? question.points : 10;
      await awardXp(ref, xp);
      if (mounted) setState(() => _xpAwarded = xp);
    }

    if (!mounted) return;
    setState(() {
      _isSubmitted = true;
      _isSubmitting = false;
    });

    await ExplanationPanel.show(
      context,
      question: question,
      isCorrect: _isCorrect,
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
      case QuestionType.speaking:
        return answer.writtenAnswer?.trim().isNotEmpty ?? false;
      default:
        return false;
    }
  }
}

// ── Question body ─────────────────────────────────────────────────────────────

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6,
                AppSpacing.x6,
                AppSpacing.x6,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isSubmitted && isCorrect && xpAwarded > 0)
                    _XpBadge(xp: xpAwarded),
                  QuestionShell(
                    question: question,
                    currentAnswer: answer,
                    isSubmitted: isSubmitted,
                    onAnswerChanged: isSubmitted ? null : onAnswerChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6, AppSpacing.x3, AppSpacing.x6, AppSpacing.x6),
            color: AppColors.surfaceContainerLowest,
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

// ── XP Badge ─────────────────────────────────────────────────────────────────

class _XpBadge extends StatelessWidget {
  const _XpBadge({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x4),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.x1),
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
                    strokeWidth: 2, color: Colors.white),
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
