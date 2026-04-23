import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/models/question_model.dart';

import '../models/exam_question_answer.dart';
import '../models/exam_meta.dart';

enum QuestionNavStatus { unanswered, answered, current, flagged }

class QuestionNavItem {
  const QuestionNavItem({
    required this.sectionIndex,
    required this.questionIndex,
    required this.globalIndex,
    required this.status,
  });
  final int sectionIndex;
  final int questionIndex;
  final int globalIndex;
  final QuestionNavStatus status;
}

/// Shows as a bottom sheet on mobile, right-side panel on web.
/// Caller decides which presentation to use.
class QuestionNavPanel extends StatelessWidget {
  const QuestionNavPanel({
    super.key,
    required this.sections,
    required this.items,
    required this.currentGlobalIndex,
    required this.onTap,
    this.onClose,
  });

  final List<SectionMeta> sections;
  final List<QuestionNavItem> items;
  final int currentGlobalIndex;
  final void Function(int sectionIndex, int questionIndex) onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    int offset = 0;

    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4, AppSpacing.x4, AppSpacing.x2, AppSpacing.x2),
            child: Row(
              children: [
                Text('Danh sách câu hỏi', style: AppTypography.titleSmall),
                const Spacer(),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: Wrap(
              spacing: AppSpacing.x4,
              children: const [
                _LegendItem(color: AppColors.primary, label: 'Đang làm'),
                _LegendItem(color: AppColors.primary, label: 'Đã trả lời'),
                _LegendItem(
                    color: AppColors.onSurfaceMutedLight,
                    label: 'Chưa trả lời'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          const Divider(height: 1),
          // Sections
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.x4),
              itemCount: sections.length,
              itemBuilder: (context, si) {
                final section = sections[si];
                final sectionItems =
                    items.skip(offset).take(section.questionCount).toList();
                offset += section.questionCount;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (si > 0) const SizedBox(height: AppSpacing.x4),
                    Text(section.label,
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.x2),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: sectionItems.length,
                      itemBuilder: (ctx, qi) {
                        final item = sectionItems[qi];
                        return _QuestionDot(
                          number: item.globalIndex + 1,
                          status: item.globalIndex == currentGlobalIndex
                              ? QuestionNavStatus.current
                              : item.status,
                          onTap: () =>
                              onTap(item.sectionIndex, item.questionIndex),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionDot extends StatelessWidget {
  const _QuestionDot({
    required this.number,
    required this.status,
    required this.onTap,
  });
  final int number;
  final QuestionNavStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAnswered = status == QuestionNavStatus.answered ||
        status == QuestionNavStatus.flagged;
    final isCurrent = status == QuestionNavStatus.current;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isAnswered
              ? AppColors.primary
              : isCurrent
                  ? AppColors.surfaceContainerLowest
                  : AppColors.surfaceContainerLowest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isCurrent
                ? AppColors.primary
                : isAnswered
                    ? AppColors.primary
                    : AppColors.outlineVariant.withOpacity(0.6),
            width: isCurrent ? 2.0 : 1.0,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: AppTypography.labelSmall.copyWith(
            color: isAnswered
                ? Colors.white
                : isCurrent
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.labelSmall),
      ],
    );
  }
}

/// Helper to build [QuestionNavItem] list from session state.
List<QuestionNavItem> buildNavItems({
  required List<SectionMeta> sections,
  required Map<String, ExamQuestionAnswer> answers,
  List<Question>? questions,
}) {
  final items = <QuestionNavItem>[];
  int global = 0;
  for (var si = 0; si < sections.length; si++) {
    for (var qi = 0; qi < sections[si].questionCount; qi++) {
      final questionId = questions != null && global < questions.length
          ? questions[global].id
          : null;
      items.add(QuestionNavItem(
        sectionIndex: si,
        questionIndex: qi,
        globalIndex: global,
        status: questionId != null &&
                answers[questionId] != null &&
                answers[questionId]!.isAnswered
            ? QuestionNavStatus.answered
            : QuestionNavStatus.unanswered,
      ));
      global++;
    }
  }
  return items;
}
