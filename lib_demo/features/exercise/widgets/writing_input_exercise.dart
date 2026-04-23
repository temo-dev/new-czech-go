import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/shared/widgets/writing_text_area.dart';

/// Writing exercise: displays the prompt and a multi-line text area.
class WritingInputExercise extends StatefulWidget {
  const WritingInputExercise({
    super.key,
    required this.question,
    this.initialAnswer,
    this.isSubmitted = false,
    this.maxWords = 250,
    this.onChanged,
  });

  final Question question;
  final String? initialAnswer;
  final bool isSubmitted;
  final int maxWords;
  final ValueChanged<String>? onChanged;

  @override
  State<WritingInputExercise> createState() =>
      _WritingInputExerciseState();
}

class _WritingInputExerciseState extends State<WritingInputExercise> {
  late final TextEditingController _controller;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialAnswer ?? '');
    _wordCount = _countWords(_controller.text);
  }

  @override
  void didUpdateWidget(WritingInputExercise oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller when the saved answer changes (e.g. restored from session).
    if (widget.initialAnswer != oldWidget.initialAnswer) {
      final text = widget.initialAnswer ?? '';
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      setState(() => _wordCount = _countWords(text));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prompt
        Text(widget.question.prompt, style: AppTypography.bodyLarge),
        const SizedBox(height: AppSpacing.x5),

        // Submitted: show what was written (read-only) + no word counter clutter
        if (widget.isSubmitted) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              _controller.text.isEmpty
                  ? '(Không có câu trả lời)'
                  : _controller.text,
              style: AppTypography.bodyMedium.copyWith(
                color: _controller.text.isEmpty
                    ? cs.onSurfaceVariant
                    : cs.onSurface,
                height: 1.6,
              ),
            ),
          ),
        ] else ...[
          WritingTextArea(
            controller: _controller,
            wordCount: _wordCount,
            maxWords: widget.maxWords,
            onChanged: (text) {
              setState(() => _wordCount = _countWords(text));
              widget.onChanged?.call(text);
            },
          ),
        ],
      ],
    );
  }
}
