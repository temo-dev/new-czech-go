import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/features/mock_test/providers/question_feedback_provider.dart';

export 'package:app_czech/features/mock_test/providers/question_feedback_provider.dart'
    show QuestionAiFeedback, MatchingFeedbackItem;

class LessonFeedbackParams {
  const LessonFeedbackParams({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctAnswerText,
    required this.userAnswerText,
    required this.sectionSkill,
  });

  final String questionId;
  final String questionText;
  final QuestionType questionType;
  final List<QuestionOption> options;
  final String correctAnswerText;
  final String userAnswerText;
  final String sectionSkill;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LessonFeedbackParams &&
          questionId == other.questionId &&
          userAnswerText == other.userAnswerText;

  @override
  int get hashCode => Object.hash(questionId, userAnswerText);
}

/// Fetches AI feedback for a wrong lesson answer.
/// Delegates to the same question-feedback edge function (with DB cache).
/// Returns null for correct answers or non-objective question types.
final lessonQuestionFeedbackProvider = FutureProvider.autoDispose
    .family<QuestionAiFeedback?, LessonFeedbackParams>((ref, params) async {
  final isObjective = params.questionType == QuestionType.mcq ||
      params.questionType == QuestionType.fillBlank;
  if (!isObjective) return null;

  try {
    final response = await supabase.functions.invoke(
      'question-feedback',
      body: {
        'question_id': params.questionId,
        'question_text': params.questionText,
        'question_type': params.questionType == QuestionType.mcq
            ? 'mcq'
            : 'fill_blank',
        'options': params.options.map((o) => {'id': o.id, 'text': o.text}).toList(),
        'correct_answer_text': params.correctAnswerText,
        'user_answer_text': params.userAnswerText,
        'section_skill': params.sectionSkill,
      },
    );

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['error'] != null) return null;

    return QuestionAiFeedback(
      errorAnalysis: data['error_analysis'] as String? ?? '',
      correctExplanation: data['correct_explanation'] as String? ?? '',
      shortTip: data['short_tip'] as String? ?? '',
      keyConceptLabel: data['key_concept'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
});
