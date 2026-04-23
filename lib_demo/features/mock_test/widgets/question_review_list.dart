import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/exercise/widgets/question_shell.dart';
import 'package:app_czech/features/mock_test/models/exam_analysis.dart';
import 'package:app_czech/features/mock_test/providers/exam_result_provider.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class QuestionReviewList extends ConsumerStatefulWidget {
  const QuestionReviewList({
    super.key,
    required this.attemptId,
    this.analysis,
  });
  final String attemptId;
  final ExamAnalysis? analysis;

  @override
  ConsumerState<QuestionReviewList> createState() => _QuestionReviewListState();
}

class _QuestionReviewListState extends ConsumerState<QuestionReviewList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewToggleHeader(
          expanded: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.x3),
          _ReviewBody(
            attemptId: widget.attemptId,
            analysis: widget.analysis,
          ),
        ],
      ],
    );
  }
}

// ── Toggle header ─────────────────────────────────────────────────────────────

class _ReviewToggleHeader extends StatelessWidget {
  const _ReviewToggleHeader({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.rate_review_outlined, size: 20),
            const SizedBox(width: AppSpacing.x2),
            const Expanded(
              child: Text(
                'Xem lại chi tiết bài thi',
                style: AppTypography.titleSmall,
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body (loads data) ─────────────────────────────────────────────────────────

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({
    required this.attemptId,
    required this.analysis,
  });
  final String attemptId;
  final ExamAnalysis? analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(examReviewProvider(attemptId));

    return reviewAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.x6),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.all(AppSpacing.x4),
        child: Text(
          'Không thể tải chi tiết bài thi.',
          style: AppTypography.bodySmall,
        ),
      ),
      data: (items) {
        final objectiveItems = items
            .where((i) =>
                i.question.type == QuestionType.mcq ||
                i.question.type == QuestionType.fillBlank ||
                i.question.type == QuestionType.matching ||
                i.question.type == QuestionType.ordering)
            .toList();
        final correct = objectiveItems
            .where((item) => _objectiveVerdict(item, analysis) == 'correct')
            .length;
        final total = objectiveItems.length;

        // Group into sections by sectionSkill order
        final groups = _groupBySections(items);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryBar(correct: correct, total: total, totalAll: items.length),
            const SizedBox(height: AppSpacing.x4),
            ...groups.map((group) => _SectionGroup(
                  skill: group.skill,
                  label: group.label,
                  items: group.items,
                  analysis: analysis,
                )),
          ],
        );
      },
    );
  }

  List<_SectionGroupData> _groupBySections(List<QuestionReviewItem> items) {
    final result = <_SectionGroupData>[];
    final seen = <String>[];

    for (final item in items) {
      final key = item.sectionSkill;
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(_SectionGroupData(
            skill: item.sectionSkill, label: item.sectionLabel, items: []));
      }
      result.last.items.add(item);
    }
    return result;
  }
}

class _SectionGroupData {
  _SectionGroupData(
      {required this.skill, required this.label, required this.items});
  final String skill;
  final String label;
  final List<QuestionReviewItem> items;
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar(
      {required this.correct, required this.total, required this.totalAll});
  final int correct;
  final int total;
  final int totalAll;

  @override
  Widget build(BuildContext context) {
    final wrong = total - correct;
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        _Chip(
          icon: Icons.check_circle_outline,
          label: '$correct / $total câu đúng',
          color: AppColors.success,
        ),
        _Chip(
          icon: Icons.cancel_outlined,
          label: '$wrong câu sai',
          color: AppColors.error,
        ),
        if (totalAll > total)
          _Chip(
            icon: Icons.edit_outlined,
            label: '${totalAll - total} câu tự luận',
            color: AppColors.primary,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3, vertical: AppSpacing.x1 + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Section group ─────────────────────────────────────────────────────────────

class _SectionGroup extends StatelessWidget {
  const _SectionGroup(
      {required this.skill,
      required this.label,
      required this.items,
      required this.analysis});
  final String skill;
  final String label;
  final List<QuestionReviewItem> items;
  final ExamAnalysis? analysis;

  static const _skillMeta = {
    'reading': (
      icon: Icons.menu_book_outlined,
      name: 'Đọc hiểu',
      color: Color(0xFF1565C0),
    ),
    'listening': (
      icon: Icons.headphones_outlined,
      name: 'Nghe hiểu',
      color: Color(0xFF6A1B9A),
    ),
    'writing': (
      icon: Icons.edit_note_outlined,
      name: 'Viết',
      color: Color(0xFF2E7D32),
    ),
    'speaking': (
      icon: Icons.mic_none_outlined,
      name: 'Nói',
      color: Color(0xFFE65100),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _skillMeta[skill];
    final skillName = meta?.name ?? label;
    final skillColor = meta?.color ?? AppColors.primary;
    final skillIcon = meta?.icon ?? Icons.quiz_outlined;

    final objectiveItems = items
        .where((i) =>
            i.question.type == QuestionType.mcq ||
            i.question.type == QuestionType.fillBlank ||
            i.question.type == QuestionType.matching ||
            i.question.type == QuestionType.ordering)
        .toList();
    final sectionCorrect = objectiveItems
        .where((item) => _objectiveVerdict(item, analysis) == 'correct')
        .length;
    final sectionTotal = objectiveItems.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3, vertical: AppSpacing.x2 + 2),
            decoration: BoxDecoration(
              color: skillColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: skillColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(skillIcon, size: 18, color: skillColor),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    label.isNotEmpty ? label : skillName,
                    style: AppTypography.titleSmall.copyWith(color: skillColor),
                  ),
                ),
                if (sectionTotal > 0)
                  Text(
                    '$sectionCorrect/$sectionTotal đúng',
                    style: AppTypography.labelSmall.copyWith(
                      color: skillColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),

          // Question cards
          ...items.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                child: _QuestionCard(
                  item: e.value,
                  sectionColor: skillColor,
                  analysis: analysis,
                ),
              )),
        ],
      ),
    );
  }
}

// ── Individual question card ──────────────────────────────────────────────────

class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.item,
    required this.sectionColor,
    required this.analysis,
  });
  final QuestionReviewItem item;
  final Color sectionColor;
  final ExamAnalysis? analysis;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _expanded = false;

  QuestionReviewItem get item => widget.item;

  bool get _isSubjective =>
      item.question.type == QuestionType.writing ||
      item.question.type == QuestionType.speaking;

  String? get _verdict => _objectiveVerdict(item, widget.analysis);

  Color get _statusColor {
    if (_isSubjective) return AppColors.primary;
    if (_verdict == 'correct') return AppColors.success;
    if (_verdict == 'partial') return AppColors.primary;
    return AppColors.error;
  }

  IconData get _statusIcon {
    if (!item.isAnswered) return Icons.radio_button_unchecked;
    if (_isSubjective) return Icons.check_circle_outline;
    if (_verdict == 'correct') return Icons.check_circle;
    if (_verdict == 'partial') return Icons.adjust_rounded;
    return Icons.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final borderColor = item.isAnswered
        ? _statusColor.withValues(alpha: 0.3)
        : cs.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Number badge
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${item.number}',
                      style: AppTypography.labelSmall.copyWith(
                          color: _statusColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  // Prompt preview
                  Expanded(
                    child: Text(
                      item.question.prompt,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Icon(_statusIcon, size: 18, color: _statusColor),
                  const SizedBox(width: AppSpacing.x1),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) ...[
            Divider(height: 1, color: cs.outlineVariant),
            _ExpandedContent(
              item: item,
              analysis: widget.analysis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Expanded content dispatcher ───────────────────────────────────────────────

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.item,
    required this.analysis,
  });
  final QuestionReviewItem item;
  final ExamAnalysis? analysis;

  bool get _isSubjective =>
      item.question.type == QuestionType.writing ||
      item.question.type == QuestionType.speaking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!item.isAnswered) ...[
            _UnansweredNotice(),
            const SizedBox(height: AppSpacing.x3),
          ],

          // Question renderer — reuse exercise widgets with isSubmitted: true
          _QuestionRenderer(
            item: item,
            analysis: analysis,
          ),

          // Writing questions: custom review panel (no "Đúng/Sai" framing)
          if (item.question.type == QuestionType.writing) ...[
            const SizedBox(height: AppSpacing.x4),
            _WritingReviewPanel(
              item: item,
              analysis: analysis,
            ),
          ] else if (!_isSubjective) ...[
            const SizedBox(height: AppSpacing.x4),
            _PreloadedQuestionFeedback(
              feedback: analysis?.questionFeedbacks[item.question.id],
              isCorrect: _objectiveVerdict(item, analysis) == 'correct',
              questionType: item.question.type,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Question renderer per type ────────────────────────────────────────────────

class _QuestionRenderer extends StatelessWidget {
  const _QuestionRenderer({
    required this.item,
    required this.analysis,
  });
  final QuestionReviewItem item;
  final ExamAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final q = item.question;

    // Speaking: custom read-only panel (avoid SpeakingRecorderExercise
    // which mutates shared speakingSessionProvider and doesn't support
    // multi-instance in the same widget tree)
    if (q.type == QuestionType.speaking) {
      return _SpeakingReviewPanel(
        item: item,
        analysis: analysis,
      );
    }

    // All other types: reuse QuestionShell with isSubmitted: true
    // MCQ → shows options highlighted (correct=green, user wrong=red)
    // Listening MCQ → audio player (Supabase URL) + highlighted options
    // Reading MCQ → passage + highlighted options
    // FillBlank → read-only submitted text
    // Writing → read-only submitted text
    final currentAnswer = _buildAnswer(q, item.userAnswer);
    return QuestionShell(
      question: q,
      currentAnswer: currentAnswer,
      isSubmitted: true,
    );
  }

  QuestionAnswer _buildAnswer(Question q, String? userAnswer) {
    if (userAnswer == null || userAnswer.isEmpty) {
      return QuestionAnswer(questionId: q.id);
    }
    final isTextType =
        q.type == QuestionType.writing || q.type == QuestionType.fillBlank;
    if (isTextType) {
      return QuestionAnswer(questionId: q.id, writtenAnswer: userAnswer);
    }
    return QuestionAnswer(questionId: q.id, selectedOptionId: userAnswer);
  }
}

// ── Speaking review panel ─────────────────────────────────────────────────────

class _SpeakingReviewPanel extends StatelessWidget {
  const _SpeakingReviewPanel({
    required this.item,
    required this.analysis,
  });
  final QuestionReviewItem item;
  final ExamAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prompt
        Text(item.question.prompt, style: AppTypography.bodyLarge),
        const SizedBox(height: AppSpacing.x4),

        // Submission status
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
          decoration: BoxDecoration(
            color: item.isAnswered
                ? AppColors.success.withValues(alpha: 0.08)
                : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: item.isAnswered
                  ? AppColors.success.withValues(alpha: 0.3)
                  : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.isAnswered ? Icons.mic_rounded : Icons.mic_off_rounded,
                size: 20,
                color:
                    item.isAnswered ? AppColors.success : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.x3),
              Text(
                item.isAnswered ? 'Đã ghi âm và nộp bài' : 'Chưa ghi âm',
                style: AppTypography.bodySmall.copyWith(
                  color:
                      item.isAnswered ? AppColors.success : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // AI feedback section
        if (item.isAnswered) ...[
          const SizedBox(height: AppSpacing.x3),
          _SubjectiveExamFeedbackCard(
            item: item,
            analysis: analysis,
            pendingLabel:
                'AI đang chấm toàn bộ bài thi và chuẩn bị nhận xét cho bài nói...',
            emptyMessage: 'Chưa có nhận xét chi tiết cho bài nói này.',
          ),
        ],

        // Model answer
        if (item.question.correctAnswer != null &&
            item.question.correctAnswer!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x3),
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      'Câu trả lời gợi ý',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(item.question.correctAnswer!,
                    style: AppTypography.bodySmall.copyWith(height: 1.6)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Writing review panel ──────────────────────────────────────────────────────

class _WritingReviewPanel extends StatelessWidget {
  const _WritingReviewPanel({
    required this.item,
    required this.analysis,
  });
  final QuestionReviewItem item;
  final ExamAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = this.item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Submission status banner
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
          decoration: BoxDecoration(
            color: item.isAnswered
                ? AppColors.primary.withValues(alpha: 0.06)
                : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: item.isAnswered
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.isAnswered
                    ? Icons.edit_note_rounded
                    : Icons.edit_off_outlined,
                size: 20,
                color:
                    item.isAnswered ? AppColors.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isAnswered ? 'Đã nộp bài viết' : 'Chưa làm bài',
                      style: AppTypography.labelSmall.copyWith(
                        color: item.isAnswered
                            ? AppColors.primary
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Bài tự luận — chấm điểm theo tiêu chí bên dưới',
                      style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // AI feedback section
        if (item.isAnswered) ...[
          const SizedBox(height: AppSpacing.x3),
          _SubjectiveExamFeedbackCard(
            item: item,
            analysis: analysis,
            pendingLabel:
                'AI đang chấm toàn bộ bài thi và chuẩn bị nhận xét cho bài viết...',
            emptyMessage: 'Chưa có nhận xét chi tiết cho bài viết này.',
          ),
        ],

        // Tiêu chí chấm điểm
        if (item.question.explanation.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x3),
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      'Tiêu chí chấm điểm',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  item.question.explanation,
                  style: AppTypography.bodySmall.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],

        // Model answer (if available)
        if (item.question.correctAnswer != null &&
            item.question.correctAnswer!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x3),
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      'Bài mẫu tham khảo',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  item.question.correctAnswer!,
                  style: AppTypography.bodySmall.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SubjectiveExamFeedbackCard extends StatelessWidget {
  const _SubjectiveExamFeedbackCard({
    required this.item,
    required this.analysis,
    required this.pendingLabel,
    required this.emptyMessage,
  });

  final QuestionReviewItem item;
  final ExamAnalysis? analysis;
  final String pendingLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (analysis == null || analysis!.isProcessing) {
      return _ExamAnalysisPendingCard(label: pendingLabel);
    }

    final feedback = analysis!.questionFeedbacks[item.question.id];
    final review = analysis!.teacherReviewForQuestion(item.question.id);

    if (feedback == null) {
      return _AiUnavailableCard(message: emptyMessage);
    }

    if (feedback.skipped && review == null) {
      return _AiUnavailableCard(
        message: feedback.summary.isNotEmpty ? feedback.summary : emptyMessage,
      );
    }

    final accent = switch (feedback.verdict) {
      'correct' => AppColors.success,
      'partial' => AppColors.primary,
      'needs_retry' => AppColors.warning,
      _ => AppColors.primary,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  'AI Teacher đã chấm xong câu này',
                  style: AppTypography.labelSmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (review?.overallScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${review!.overallScore}/100',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (feedback.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              feedback.summary,
              style: AppTypography.bodySmall.copyWith(height: 1.55),
            ),
          ],
          if (feedback.criteria.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            ...feedback.criteria.take(2).map(
                  (criterion) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        Expanded(
                          child: Text(
                            criterion.tip.isNotEmpty
                                ? '${criterion.label}: ${criterion.tip}'
                                : '${criterion.label}: ${criterion.feedback}',
                            style: AppTypography.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          if (feedback.shortTips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: feedback.shortTips
                  .take(3)
                  .map(
                    (tip) => _FeedbackChip(
                      icon: Icons.flash_on_outlined,
                      label: tip,
                      color: accent,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (review != null) ...[
            const SizedBox(height: AppSpacing.x3),
            TextButton.icon(
              onPressed: () => context.push(
                AppRoutes.mockTestSubjectiveReviewPath(
                  item.attemptId,
                  item.question.id,
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Xem nhận xét chi tiết'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamAnalysisPendingCard extends StatelessWidget {
  const _ExamAnalysisPendingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreloadedQuestionFeedback extends StatelessWidget {
  const _PreloadedQuestionFeedback({
    required this.feedback,
    required this.isCorrect,
    required this.questionType,
  });

  final QuestionAnalysisFeedback? feedback;
  final bool isCorrect;
  final QuestionType questionType;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (feedback == null) {
      return const LoadingShimmer(child: _FeedbackSkeleton());
    }

    if (feedback!.skipped) {
      return const _AiUnavailableCard(
        message: 'AI chưa phân tích được câu này.',
      );
    }

    final positive = isCorrect || feedback!.verdict == 'correct';
    final accent = positive ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: positive
            ? AppColors.success.withValues(alpha: 0.08)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: positive
              ? AppColors.success.withValues(alpha: 0.18)
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positive
                    ? Icons.auto_awesome_rounded
                    : Icons.tips_and_updates_outlined,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  positive
                      ? 'AI Teacher củng cố đáp án đúng'
                      : 'AI Teacher giải thích câu trả lời',
                  style: AppTypography.labelSmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!positive && feedback!.errorAnalysis.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(feedback!.errorAnalysis, style: AppTypography.bodySmall),
          ],
          if (feedback!.correctExplanation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              feedback!.correctExplanation,
              style: AppTypography.bodySmall.copyWith(height: 1.55),
            ),
          ],
          if (feedback!.matchingFeedback.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            ...feedback!.matchingFeedback.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child:
                          Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        '${item.item}: ${item.issue}',
                        style: AppTypography.labelSmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (!positive &&
              (feedback!.shortTip.isNotEmpty ||
                  feedback!.keyConceptLabel.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.x3),
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                if (feedback!.shortTip.isNotEmpty)
                  _FeedbackChip(
                    icon: Icons.flash_on_outlined,
                    label: feedback!.shortTip,
                    color: AppColors.primary,
                  ),
                if (feedback!.keyConceptLabel.isNotEmpty)
                  _FeedbackChip(
                    icon: Icons.book_outlined,
                    label: feedback!.keyConceptLabel,
                    color: AppColors.onSurface,
                  ),
              ],
            ),
          ],
          if ((questionType == QuestionType.matching ||
                  questionType == QuestionType.ordering) &&
              feedback!.matchingFeedback.isEmpty &&
              !positive &&
              feedback!.shortTip.isEmpty &&
              feedback!.keyConceptLabel.isEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Xem lại thứ tự/cặp ghép đúng và so sánh từng vị trí.',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.x1),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSkeleton extends StatelessWidget {
  const _FeedbackSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}

// ── AI unavailable notice ─────────────────────────────────────────────────────

class _AiUnavailableCard extends StatelessWidget {
  const _AiUnavailableCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              message,
              style:
                  AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Unanswered notice ─────────────────────────────────────────────────────────

class _UnansweredNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 15,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.x2),
          Text('Bạn chưa trả lời câu hỏi này',
              style: AppTypography.labelSmall.copyWith(color: AppColors.error)),
        ],
      ),
    );
  }
}

String? _objectiveVerdict(QuestionReviewItem item, ExamAnalysis? analysis) {
  if (item.question.type == QuestionType.writing ||
      item.question.type == QuestionType.speaking) {
    return null;
  }

  return analysis?.questionFeedbacks[item.question.id]?.verdict ??
      (item.isCorrect ? 'correct' : 'incorrect');
}
