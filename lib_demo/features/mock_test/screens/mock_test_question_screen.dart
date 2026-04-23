import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/exercise/widgets/question_shell.dart';
import 'package:app_czech/features/mock_test/providers/exam_questions_provider.dart';
import 'package:app_czech/features/mock_test/providers/exam_session_notifier.dart';
import 'package:app_czech/features/mock_test/widgets/confirm_submit_dialog.dart';
import 'package:app_czech/features/mock_test/widgets/exam_top_bar.dart';
import 'package:app_czech/features/mock_test/widgets/question_nav_panel.dart';
import 'package:app_czech/features/mock_test/widgets/section_transition_card.dart';
import 'package:app_czech/features/speaking_ai/providers/speaking_provider.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';

class MockTestQuestionScreen extends ConsumerStatefulWidget {
  const MockTestQuestionScreen({super.key, required this.attemptId});

  final String attemptId;

  @override
  ConsumerState<MockTestQuestionScreen> createState() =>
      _MockTestQuestionScreenState();
}

class _MockTestQuestionScreenState extends ConsumerState<MockTestQuestionScreen>
    with WidgetsBindingObserver {
  bool _navPanelOpen = false;
  bool _timerStarted = false;
  int? _lastVisibleTimer;
  int? _lastKnownRemainingSeconds;
  int? _lastSyncedTimer;
  late final ExamSessionNotifier _sessionNotifier;
  ProviderSubscription<AsyncValue<ExamSessionState>>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionNotifier =
        ref.read(examSessionNotifierProvider(widget.attemptId).notifier);
    _sessionSubscription = ref.listenManual<AsyncValue<ExamSessionState>>(
      examSessionNotifierProvider(widget.attemptId),
      (prev, next) {
        if (_timerStarted) return;
        final s = next.valueOrNull;
        if (s == null) return;
        _timerStarted = true;
        final remaining = s.attempt.remainingSeconds ?? 0;
        _lastKnownRemainingSeconds = s.attempt.remainingSeconds;
        final seconds = remaining > 0 ? remaining : s.totalExamSeconds;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(examTimerNotifierProvider(seconds).notifier).start(
                _onTimerExpired,
              );
        });
      },
    );
  }

  @override
  void dispose() {
    _sessionSubscription?.close();
    _persistTimerCheckpoint();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _persistTimerCheckpoint();
    }
  }

  void _persistTimerCheckpoint() {
    final remaining = _lastVisibleTimer ?? _lastKnownRemainingSeconds;
    if (remaining == null) return;
    _lastSyncedTimer = remaining;
    _sessionNotifier.persistCheckpoint(remaining);
  }

  void _trackTimer(ExamSessionState session, int timerSeconds) {
    if (_lastVisibleTimer == timerSeconds) return;

    _lastVisibleTimer = timerSeconds;
    _lastKnownRemainingSeconds = timerSeconds;
    final shouldSync = _lastSyncedTimer == null ||
        (_lastSyncedTimer! - timerSeconds).abs() >= 15 ||
        timerSeconds <= 5;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier =
          ref.read(examSessionNotifierProvider(widget.attemptId).notifier);
      notifier.updateRemainingSeconds(timerSeconds);
      notifier.syncSectionFromRemainingSeconds(timerSeconds);
      if (!shouldSync) return;
      _lastSyncedTimer = timerSeconds;
      notifier.syncProgress(remainingSeconds: timerSeconds);
    });
  }

  void _onTimerExpired() {
    _submit();
  }

  Future<void> _submit() async {
    final id = await ref
        .read(examSessionNotifierProvider(widget.attemptId).notifier)
        .submit();
    if (id != null && mounted) {
      context.pushReplacement(AppRoutes.mockTestResultPath(id));
      return;
    }
    if (!mounted) return;

    final message = ref
            .read(examSessionNotifierProvider(widget.attemptId))
            .valueOrNull
            ?.errorMessage ??
        'Nộp bài thất bại. Vui lòng thử lại.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showNavPanel(BuildContext ctx) {
    final isWide = MediaQuery.sizeOf(ctx).width >= 900;
    if (isWide) {
      setState(() => _navPanelOpen = !_navPanelOpen);
    } else {
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, controller) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _buildNavPanel(ctx),
          ),
        ),
      );
    }
  }

  Widget _buildNavPanel(BuildContext ctx) {
    final sessionState =
        ref.read(examSessionNotifierProvider(widget.attemptId)).valueOrNull;
    if (sessionState == null) return const SizedBox.shrink();
    final questions =
        ref.read(examQuestionsProvider(sessionState.meta.id)).valueOrNull;

    final navItems = buildNavItems(
      sections: sessionState.meta.sections,
      answers: sessionState.currentAnswers,
      questions: questions,
    );

    return QuestionNavPanel(
      sections: sessionState.meta.sections,
      items: navItems,
      currentGlobalIndex: sessionState.globalQuestionIndex,
      onClose: () => Navigator.of(ctx).pop(),
      onTap: (si, qi) {
        if (sessionState.usesSectionTimers &&
            si != sessionState.currentSectionIndex) {
          return;
        }
        Navigator.of(ctx).pop();
        ref
            .read(examSessionNotifierProvider(widget.attemptId).notifier)
            .goToQuestion(si, qi);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync =
        ref.watch(examSessionNotifierProvider(widget.attemptId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        await ConfirmExitDialog.show(
          context: context,
          onConfirm: () => context.go(AppRoutes.landing),
        );
      },
      child: sessionAsync.when(
        loading: () => const _SessionLoadingScreen(),
        error: (e, st) {
          return ErrorState(
            message: 'Lỗi session: $e',
            onRetry: () =>
                ref.invalidate(examSessionNotifierProvider(widget.attemptId)),
          );
        },
        data: (session) {
          // Always watch the timer first — even during section transitions.
          // If ref.watch is skipped (early return), autoDispose kills the
          // provider and cancels Timer.periodic, causing a reset.
          final remaining = session.attempt.remainingSeconds ?? 0;
          final timerSeconds = ref.watch(
            examTimerNotifierProvider(
              remaining > 0 ? remaining : session.totalExamSeconds,
            ),
          );
          _trackTimer(session, timerSeconds);

          // Show section transition overlay.
          // currentSectionIndex still points to the completed section here;
          // advanceSection() will increment it.
          if (session.showSectionTransition) {
            final completedIdx = session.currentSectionIndex;
            final nextIdx = completedIdx + 1;
            return SectionTransitionCard(
              completedSection: session.meta.sections[completedIdx],
              nextSection: session.meta.sections[nextIdx],
              onContinue: () => ref
                  .read(examSessionNotifierProvider(widget.attemptId).notifier)
                  .advanceSection(),
            );
          }

          final isWide = MediaQuery.sizeOf(context).width >= 900;

          return Scaffold(
            appBar: ExamTopBar(
              sectionLabel: session.currentSection.label,
              questionLabel:
                  'CÂU HỎI ${session.globalQuestionIndex + 1} / ${session.totalQuestions}',
              remainingSeconds: session.sectionRemainingSeconds(timerSeconds),
              autosaveStatus: session.autosaveStatus,
              onNavTap: () => _showNavPanel(context),
              onExit: () => ConfirmExitDialog.show(
                context: context,
                onConfirm: () => context.go(AppRoutes.landing),
              ),
            ),
            body: Row(
              children: [
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress bar
                      _ProgressBar(
                        answered: session.answeredCount,
                        total: session.totalQuestions,
                      ),
                      // Question renderer
                      Expanded(
                        child: _QuestionBody(
                          attemptId: widget.attemptId,
                          examId: session.meta.id,
                          session: session,
                        ),
                      ),
                      // Bottom nav row
                      _BottomBar(
                        session: session,
                        onPrev: () {
                          // simplified prev: go back in questions
                          final qi = session.currentQuestionIndex;
                          final si = session.currentSectionIndex;
                          if (qi > 0) {
                            ref
                                .read(examSessionNotifierProvider(
                                        widget.attemptId)
                                    .notifier)
                                .goToQuestion(si, qi - 1);
                          } else if (!session.usesSectionTimers && si > 0) {
                            final prevSection = session.meta.sections[si - 1];
                            ref
                                .read(examSessionNotifierProvider(
                                        widget.attemptId)
                                    .notifier)
                                .goToQuestion(
                                    si - 1, prevSection.questionCount - 1);
                          }
                        },
                        onNext: () => ref
                            .read(examSessionNotifierProvider(widget.attemptId)
                                .notifier)
                            .nextQuestion(),
                        onSubmit: () => ConfirmSubmitDialog.show(
                          context: context,
                          unansweredCount: session.unansweredCount,
                          onConfirm: _submit,
                        ),
                        isSubmitting:
                            session.status == ExamSessionStatus.submitting,
                        isSpeakingUploading:
                            ref.watch(speakingSessionProvider).status ==
                                SpeakingStatus.uploading,
                      ),
                    ],
                  ),
                ),
                // Side nav panel (web only)
                if (isWide && _navPanelOpen)
                  SizedBox(
                    width: 260,
                    child: _buildNavPanel(context),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.answered, required this.total});
  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : answered / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Theme.of(context).colorScheme.outlineVariant,
          color: AppColors.primary,
          minHeight: 3,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x1),
          child: Text(
            'Đã hoàn thành: $answered / $total (${(progress * 100).round()}%)',
            style: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.session,
    required this.onPrev,
    required this.onNext,
    required this.onSubmit,
    required this.isSubmitting,
    required this.isSpeakingUploading,
  });

  final ExamSessionState session;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final bool isSpeakingUploading;

  bool get _isFirst =>
      session.currentSectionIndex == 0 && session.currentQuestionIndex == 0;

  bool get _isLast =>
      session.currentSectionIndex == session.meta.sections.length - 1 &&
      session.currentQuestionIndex == session.currentSection.questionCount - 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x3 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSpeakingUploading)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    'Đang nộp bài ghi âm, vui lòng chờ...',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isFirst ? null : onPrev,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                ),
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                label: const Text('Trước'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isLast
                    ? AppButton(
                        key: const Key('mock_exam_submit_button'),
                        label: 'Nộp bài',
                        loading: isSubmitting,
                        onPressed: (isSubmitting || isSpeakingUploading)
                            ? null
                            : onSubmit,
                        fullWidth: true,
                        icon: Icons.check_rounded,
                        size: AppButtonSize.md,
                      )
                    : AppButton(
                        key: const Key('mock_exam_next_button'),
                        label: 'Tiếp',
                        onPressed: isSpeakingUploading ? null : onNext,
                        fullWidth: true,
                        trailingIcon: Icons.chevron_right_rounded,
                        size: AppButtonSize.md,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Question body — fetch real questions from DB ───────────────────────────────

class _QuestionBody extends ConsumerWidget {
  const _QuestionBody({
    required this.attemptId,
    required this.examId,
    required this.session,
  });

  final String attemptId;
  final String examId;
  final ExamSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(examQuestionsProvider(examId));

    return questionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        message: 'Không thể tải câu hỏi. Vui lòng thử lại.',
        onRetry: () => ref.invalidate(examQuestionsProvider(examId)),
      ),
      data: (questions) {
        final globalIdx = session.globalQuestionIndex;
        if (questions.isEmpty || globalIdx >= questions.length) {
          return const Center(
            child: Text(
              'Không tìm thấy câu hỏi.',
              style: AppTypography.bodyMedium,
            ),
          );
        }
        final question = questions[globalIdx];
        final storedAnswer = session.currentAnswers[question.id];
        final currentAnswer = storedAnswer == null
            ? QuestionAnswer(questionId: question.id)
            : storedAnswer.toQuestionAnswer(question);

        // Pre-read the notifier so the closure does not capture [ref].
        // Capturing ref is unsafe: async callbacks (e.g. speaking upload
        // completing after navigation) may fire after this widget disposes,
        // at which point ref.read throws "Cannot use ref after disposal".
        final sessionNotifier =
            ref.read(examSessionNotifierProvider(attemptId).notifier);

        return SingleChildScrollView(
          // Key by question.id so StatefulWidget descendants (e.g.
          // WritingInputExercise's TextEditingController) are fully
          // recreated when the question changes, not reused.
          key: ValueKey(question.id),
          child: QuestionShell(
            question: question,
            currentAnswer: currentAnswer,
            isSubmitted: false,
            examAttemptId: attemptId,
            onAnswerChanged: (qa) => sessionNotifier.answerQuestion(
              question: question,
              answer: qa,
            ),
          ),
        );
      },
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget block({double h = 16, double? w}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x2),
          child: LoadingShimmer(
            child: Container(
              height: h,
              width: w ?? double.infinity,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Đang tải...')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            block(h: 8, w: double.infinity), // progress bar
            const SizedBox(height: AppSpacing.x4),
            block(h: 14, w: 120),
            const SizedBox(height: AppSpacing.x3),
            block(h: 120),
            const SizedBox(height: AppSpacing.x4),
            block(h: 52),
            block(h: 52),
            block(h: 52),
            block(h: 52),
          ],
        ),
      ),
    );
  }
}
