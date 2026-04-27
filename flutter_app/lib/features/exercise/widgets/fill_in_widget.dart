import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';

/// Renders fill-in-the-blank input fields for poslech_5 / cteni_5.
class FillInWidget extends StatelessWidget {
  const FillInWidget({
    super.key,
    required this.questions,
    required this.answers,
    required this.onChanged,
  });

  final List<FillQuestionView> questions;
  final Map<String, String> answers;
  final void Function(String questionNo, String answer) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: questions.map((q) {
        final key = q.questionNo.toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (q.prompt.isNotEmpty)
                Text('${q.questionNo}. ${q.prompt}', style: AppTypography.labelMedium),
              const SizedBox(height: 4),
              TextField(
                onChanged: (v) => onChanged(key, v),
                decoration: InputDecoration(
                  hintText: 'Câu trả lời ${q.questionNo}...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
