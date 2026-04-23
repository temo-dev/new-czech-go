import 'package:app_czech/features/ai_teacher/models/ai_teacher_review.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_analysis.freezed.dart';
part 'exam_analysis.g.dart';

enum ExamAnalysisStatus { processing, ready, error }

@freezed
class MatchingAnalysisFeedbackItem with _$MatchingAnalysisFeedbackItem {
  const factory MatchingAnalysisFeedbackItem({
    @Default('') String item,
    @Default('') String issue,
  }) = _MatchingAnalysisFeedbackItem;

  factory MatchingAnalysisFeedbackItem.fromJson(Map<String, dynamic> json) =>
      _$MatchingAnalysisFeedbackItemFromJson(json);
}

@freezed
class QuestionAnalysisCriterion with _$QuestionAnalysisCriterion {
  const factory QuestionAnalysisCriterion({
    @Default('') String label,
    double? score,
    @JsonKey(name: 'max_score') double? maxScore,
    @Default('') String feedback,
    @Default('') String tip,
  }) = _QuestionAnalysisCriterion;

  factory QuestionAnalysisCriterion.fromJson(Map<String, dynamic> json) =>
      _$QuestionAnalysisCriterionFromJson(json);
}

@freezed
class QuestionAnalysisFeedback with _$QuestionAnalysisFeedback {
  const factory QuestionAnalysisFeedback({
    @Default('incorrect') String verdict,
    @JsonKey(name: 'error_analysis') @Default('') String errorAnalysis,
    @JsonKey(name: 'correct_explanation')
    @Default('')
    String correctExplanation,
    @JsonKey(name: 'short_tip') @Default('') String shortTip,
    @JsonKey(name: 'key_concept') @Default('') String keyConceptLabel,
    @JsonKey(name: 'matching_feedback')
    @Default([])
    List<MatchingAnalysisFeedbackItem> matchingFeedback,
    @Default('') String summary,
    @Default([]) List<QuestionAnalysisCriterion> criteria,
    @JsonKey(name: 'short_tips') @Default([]) List<String> shortTips,
    @Default(false) bool skipped,
  }) = _QuestionAnalysisFeedback;

  factory QuestionAnalysisFeedback.fromJson(Map<String, dynamic> json) =>
      _$QuestionAnalysisFeedbackFromJson(json);
}

@freezed
class SkillInsight with _$SkillInsight {
  const factory SkillInsight({
    required String skill,
    @Default('') String summary,
    @JsonKey(name: 'main_issue') @Default('') String mainIssue,
  }) = _SkillInsight;

  factory SkillInsight.fromJson(Map<String, dynamic> json) =>
      _$SkillInsightFromJson(json);
}

@freezed
class OverallRecommendation with _$OverallRecommendation {
  const factory OverallRecommendation({
    @Default('') String title,
    @Default('') String detail,
  }) = _OverallRecommendation;

  factory OverallRecommendation.fromJson(Map<String, dynamic> json) =>
      _$OverallRecommendationFromJson(json);
}

@freezed
class ExamAnalysis with _$ExamAnalysis {
  const factory ExamAnalysis({
    required String id,
    @JsonKey(name: 'attempt_id') required String attemptId,
    required ExamAnalysisStatus status,
    @JsonKey(
      name: 'question_feedbacks',
      fromJson: _questionFeedbacksFromJson,
      toJson: _questionFeedbacksToJson,
    )
    @Default({})
    Map<String, QuestionAnalysisFeedback> questionFeedbacks,
    @JsonKey(
      name: 'skill_insights',
      fromJson: _skillInsightsFromJson,
      toJson: _skillInsightsToJson,
    )
    @Default([])
    List<SkillInsight> skillInsights,
    @JsonKey(name: 'overall_recommendations')
    @Default([])
    List<OverallRecommendation> overallRecommendations,
    @JsonKey(
      name: 'teacher_reviews_by_question',
      fromJson: _teacherReviewsByQuestionFromJson,
      toJson: _teacherReviewsByQuestionToJson,
    )
    @Default({})
    Map<String, Map<String, dynamic>> teacherReviewsByQuestion,
    @JsonKey(name: 'error_message') String? errorMessage,
  }) = _ExamAnalysis;

  factory ExamAnalysis.fromJson(Map<String, dynamic> json) =>
      _$ExamAnalysisFromJson(json);
}

extension ExamAnalysisX on ExamAnalysis {
  bool get isReady => status == ExamAnalysisStatus.ready;
  bool get isProcessing => status == ExamAnalysisStatus.processing;
  bool get isError => status == ExamAnalysisStatus.error;

  AiTeacherReview? teacherReviewForQuestion(String questionId) {
    final raw = teacherReviewsByQuestion[questionId];
    if (raw == null) return null;
    return AiTeacherReview.fromJson(raw);
  }
}

Map<String, QuestionAnalysisFeedback> _questionFeedbacksFromJson(
  Map<String, dynamic>? json,
) {
  if (json == null) return {};
  return json.map(
    (key, value) => MapEntry(
      key,
      QuestionAnalysisFeedback.fromJson(
        Map<String, dynamic>.from(value as Map),
      ),
    ),
  );
}

Map<String, dynamic> _questionFeedbacksToJson(
  Map<String, QuestionAnalysisFeedback> questionFeedbacks,
) {
  return questionFeedbacks.map(
    (key, value) => MapEntry(key, value.toJson()),
  );
}

Map<String, Map<String, dynamic>> _teacherReviewsByQuestionFromJson(
  Map<String, dynamic>? json,
) {
  if (json == null) return {};
  return json.map(
    (key, value) => MapEntry(
      key,
      Map<String, dynamic>.from(value as Map),
    ),
  );
}

Map<String, dynamic> _teacherReviewsByQuestionToJson(
  Map<String, Map<String, dynamic>> teacherReviewsByQuestion,
) {
  return teacherReviewsByQuestion.map(
    (key, value) => MapEntry(key, value),
  );
}

List<SkillInsight> _skillInsightsFromJson(Map<String, dynamic>? json) {
  if (json == null) return const [];
  return json.entries
      .map(
        (entry) => SkillInsight.fromJson({
          'skill': entry.key,
          ...Map<String, dynamic>.from(entry.value as Map),
        }),
      )
      .toList();
}

Map<String, dynamic> _skillInsightsToJson(List<SkillInsight> insights) {
  return {
    for (final insight in insights)
      insight.skill: {
        'summary': insight.summary,
        'main_issue': insight.mainIssue,
      },
  };
}
