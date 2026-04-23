import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/shared/models/question_model.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class MatchingFeedbackItem {
  const MatchingFeedbackItem({required this.item, required this.issue});
  final String item;
  final String issue;
}

class QuestionAiFeedback {
  const QuestionAiFeedback({
    required this.errorAnalysis,
    required this.correctExplanation,
    required this.shortTip,
    required this.keyConceptLabel,
    this.matchingFeedback = const [],
  });

  final String errorAnalysis;
  final String correctExplanation;
  final String shortTip;
  final String keyConceptLabel;
  final List<MatchingFeedbackItem> matchingFeedback;
}

class QuestionFeedbackParams {
  const QuestionFeedbackParams({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.correctAnswerText,
    required this.userAnswerText,
    required this.sectionSkill,
    this.matchPairs = const [],
    this.correctOrder = const [],
  });

  final String questionId;
  final String questionText;
  final QuestionType questionType;
  final List<QuestionOption> options;
  final String correctAnswerText;
  final String userAnswerText;
  final String sectionSkill;
  final List<MatchPair> matchPairs;
  final List<String> correctOrder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionFeedbackParams &&
          questionId == other.questionId &&
          userAnswerText == other.userAnswerText;

  @override
  int get hashCode => Object.hash(questionId, userAnswerText);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class QuestionFeedbackNotifier
    extends AutoDisposeFamilyAsyncNotifier<QuestionAiFeedback?, QuestionFeedbackParams> {
  @override
  Future<QuestionAiFeedback?> build(QuestionFeedbackParams arg) async {
    // Auto-fetch immediately — cached in DB so repeated calls are cheap
    return _doFetch(arg);
  }

  Future<QuestionAiFeedback?> _doFetch(QuestionFeedbackParams params) async {
    try {
      final questionTypeStr = _questionTypeString(params.questionType);
      final optionsList = params.options
          .map((o) => {'id': o.id, 'text': o.text})
          .toList();

      final matchPairsList = params.matchPairs
          .map((p) => {
                'left_id': p.leftId,
                'left_text': p.leftText,
                'right_id': p.rightId,
                'right_text': p.rightText,
              })
          .toList();

      final response = await supabase.functions.invoke(
        'question-feedback',
        body: {
          'question_id': params.questionId,
          'question_text': params.questionText,
          'question_type': questionTypeStr,
          'options': optionsList,
          'correct_answer_text': params.correctAnswerText,
          'user_answer_text': params.userAnswerText,
          'section_skill': params.sectionSkill,
          if (matchPairsList.isNotEmpty) 'match_pairs': matchPairsList,
          if (params.correctOrder.isNotEmpty) 'correct_order': params.correctOrder,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) return null;

      final rawMatching = data['matching_feedback'] as List<dynamic>?;
      final matchingFeedback = rawMatching
              ?.map((m) {
                final mm = Map<String, dynamic>.from(m as Map);
                return MatchingFeedbackItem(
                  item: mm['item'] as String? ?? '',
                  issue: mm['issue'] as String? ?? '',
                );
              })
              .toList() ??
          [];

      return QuestionAiFeedback(
        errorAnalysis: data['error_analysis'] as String? ?? '',
        correctExplanation: data['correct_explanation'] as String? ?? '',
        shortTip: data['short_tip'] as String? ?? '',
        keyConceptLabel: data['key_concept'] as String? ?? '',
        matchingFeedback: matchingFeedback,
      );
    } catch (_) {
      return null;
    }
  }

  String _questionTypeString(QuestionType type) {
    switch (type) {
      case QuestionType.mcq:
        return 'mcq';
      case QuestionType.fillBlank:
        return 'fill_blank';
      case QuestionType.matching:
        return 'matching';
      case QuestionType.ordering:
        return 'ordering';
      default:
        return 'mcq';
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final questionFeedbackProvider = AsyncNotifierProvider.autoDispose
    .family<QuestionFeedbackNotifier, QuestionAiFeedback?, QuestionFeedbackParams>(
  QuestionFeedbackNotifier.new,
);
