import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/question_model.dart';

/// Fill-in-the-blank exercise.
/// The [Question.prompt] contains `{blank}` tokens that are replaced with
/// inline text-field inputs. Multiple blanks are supported.
class FillBlankExercise extends StatefulWidget {
  const FillBlankExercise({
    super.key,
    required this.question,
    this.initialAnswer,
    this.isSubmitted = false,
    this.onChanged,
  });

  final Question question;
  final String? initialAnswer; // comma-joined multi-blank answers
  final bool isSubmitted;
  final ValueChanged<String>? onChanged; // comma-joined blanks on change

  @override
  State<FillBlankExercise> createState() => _FillBlankExerciseState();
}

class _FillBlankExerciseState extends State<FillBlankExercise> {
  late final List<TextEditingController> _controllers;
  late final List<String> _segments; // text between {blank} tokens
  late int _blankCount;

  @override
  void initState() {
    super.initState();
    final parts = widget.question.prompt.split('{blank}');
    _blankCount = parts.length - 1;
    _segments = parts;

    final initialParts = (widget.initialAnswer ?? '').split(',');
    _controllers = List.generate(
      _blankCount,
      (i) => TextEditingController(
        text: i < initialParts.length ? initialParts[i] : '',
      ),
    );

    for (final c in _controllers) {
      c.addListener(_onAnyChange);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAnyChange() {
    widget.onChanged?.call(
      _controllers.map((c) => c.text.trim()).join(','),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Correct answers (comma-joined) from question
    final correctParts =
        (widget.question.correctAnswer ?? '').split(',');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inline sentence with blank inputs
        _SegmentedPrompt(
          segments: _segments,
          controllers: _controllers,
          blankCount: _blankCount,
          isSubmitted: widget.isSubmitted,
          correctParts: correctParts,
          cs: cs,
        ),

        // Hint row (if submitted: show correct answer)
        if (widget.isSubmitted && widget.question.correctAnswer != null) ...[
          const SizedBox(height: AppSpacing.x4),
          _CorrectAnswerRow(correctAnswer: widget.question.correctAnswer!),
        ],
      ],
    );
  }
}

// ── Segmented prompt with inline blank fields ─────────────────────────────────

class _SegmentedPrompt extends StatelessWidget {
  const _SegmentedPrompt({
    required this.segments,
    required this.controllers,
    required this.blankCount,
    required this.isSubmitted,
    required this.correctParts,
    required this.cs,
  });

  final List<String> segments;
  final List<TextEditingController> controllers;
  final int blankCount;
  final bool isSubmitted;
  final List<String> correctParts;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final children = <InlineSpan>[];

    for (int i = 0; i < segments.length; i++) {
      if (segments[i].isNotEmpty) {
        children.add(TextSpan(
          text: segments[i],
          style: AppTypography.bodyLarge.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ));
      }

      if (i < blankCount) {
        final userAnswer = controllers[i].text.trim();
        final correct =
            i < correctParts.length ? correctParts[i].trim() : '';
        final isCorrect = userAnswer.toLowerCase() == correct.toLowerCase();

        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _BlankField(
            controller: controllers[i],
            isSubmitted: isSubmitted,
            isCorrect: isSubmitted ? isCorrect : null,
          ),
        ));
      }
    }

    return Text.rich(
      TextSpan(children: children),
      style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _BlankField extends StatelessWidget {
  const _BlankField({
    required this.controller,
    required this.isSubmitted,
    this.isCorrect,
  });

  final TextEditingController controller;
  final bool isSubmitted;
  final bool? isCorrect; // null = not submitted

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color? textColor;

    if (!isSubmitted) {
      borderColor = AppColors.primary.withValues(alpha: 0.5);
      textColor = null;
    } else if (isCorrect == true) {
      borderColor = AppColors.scoreExcellent;
      textColor = AppColors.scoreExcellent;
    } else {
      borderColor = AppColors.error;
      textColor = AppColors.error;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 160),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IntrinsicWidth(
        child: TextField(
          controller: controller,
          enabled: !isSubmitted,
          style: AppTypography.bodyLarge.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2, vertical: AppSpacing.x2),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: AppColors.primary, width: 2),
            ),
            disabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: borderColor, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _CorrectAnswerRow extends StatelessWidget {
  const _CorrectAnswerRow({required this.correctAnswer});
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final parts = correctAnswer.split(',');
    final display = parts.length == 1
        ? correctAnswer
        : parts.asMap().entries.map((e) => '${e.key + 1}. ${e.value.trim()}').join('  ');

    return Row(
      children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 16, color: AppColors.scoreExcellent),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            'Đáp án đúng: $display',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.scoreExcellent),
          ),
        ),
      ],
    );
  }
}
