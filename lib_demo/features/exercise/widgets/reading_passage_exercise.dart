import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/exercise/widgets/mcq_exercise.dart';
import 'package:app_czech/shared/models/question_model.dart';

/// Reading comprehension exercise.
/// - Web (≥900px): passage on left, MCQ on right (side-by-side)
/// - Mobile (<900px): passage collapsed/expandable above MCQ
class ReadingPassageExercise extends StatefulWidget {
  const ReadingPassageExercise({
    super.key,
    required this.question,
    this.selectedOptionId,
    this.isSubmitted = false,
    this.onSelect,
  });

  final Question question;
  final String? selectedOptionId;
  final bool isSubmitted;
  final ValueChanged<String>? onSelect;

  @override
  State<ReadingPassageExercise> createState() => _ReadingPassageExerciseState();
}

class _ReadingPassageExerciseState extends State<ReadingPassageExercise> {
  bool _passageExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    if (isWide) {
      return _WideLayout(
          question: widget.question,
          selectedOptionId: widget.selectedOptionId,
          isSubmitted: widget.isSubmitted,
          onSelect: widget.onSelect);
    }

    return _NarrowLayout(
      question: widget.question,
      selectedOptionId: widget.selectedOptionId,
      isSubmitted: widget.isSubmitted,
      passageExpanded: _passageExpanded,
      onTogglePassage: () =>
          setState(() => _passageExpanded = !_passageExpanded),
      onSelect: widget.onSelect,
    );
  }
}

// ── Wide layout (side-by-side) ────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.question,
    this.selectedOptionId,
    required this.isSubmitted,
    this.onSelect,
  });

  final Question question;
  final String? selectedOptionId;
  final bool isSubmitted;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passage panel
          Expanded(
            flex: 3,
            child: _PassageCard(
              passage: question.passageText ?? question.introText ?? '',
            ),
          ),
          const SizedBox(width: AppSpacing.x5),
          // MCQ panel
          Expanded(
            flex: 2,
            child: McqExercise(
              question: question,
              selectedOptionId: selectedOptionId,
              isSubmitted: isSubmitted,
              onSelect: onSelect,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Narrow layout (stacked with collapsible passage) ──────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.question,
    this.selectedOptionId,
    required this.isSubmitted,
    required this.passageExpanded,
    required this.onTogglePassage,
    this.onSelect,
  });

  final Question question;
  final String? selectedOptionId;
  final bool isSubmitted;
  final bool passageExpanded;
  final VoidCallback onTogglePassage;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final passage = question.passageText ?? question.introText ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Collapsible passage
        GestureDetector(
          onTap: onTogglePassage,
          child: _PassageToggleHeader(expanded: passageExpanded),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: passageExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x4),
            child: _PassageCard(
              passage: passage,
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),

        // MCQ
        McqExercise(
          question: question,
          selectedOptionId: selectedOptionId,
          isSubmitted: isSubmitted,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _PassageToggleHeader extends StatelessWidget {
  const _PassageToggleHeader({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x3),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              'Đoạn văn',
              style:
                  AppTypography.labelMedium.copyWith(color: AppColors.primary),
            ),
          ),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard({
    required this.passage,
  });

  final String passage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        passage,
        style: AppTypography.bodyMedium.copyWith(
          height: 1.7,
          color: cs.onSurface,
        ),
      ),
    );
  }
}
