// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_analysis.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MatchingAnalysisFeedbackItemImpl _$$MatchingAnalysisFeedbackItemImplFromJson(
        Map<String, dynamic> json) =>
    _$MatchingAnalysisFeedbackItemImpl(
      item: json['item'] as String? ?? '',
      issue: json['issue'] as String? ?? '',
    );

Map<String, dynamic> _$$MatchingAnalysisFeedbackItemImplToJson(
        _$MatchingAnalysisFeedbackItemImpl instance) =>
    <String, dynamic>{
      'item': instance.item,
      'issue': instance.issue,
    };

_$QuestionAnalysisCriterionImpl _$$QuestionAnalysisCriterionImplFromJson(
        Map<String, dynamic> json) =>
    _$QuestionAnalysisCriterionImpl(
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num?)?.toDouble(),
      feedback: json['feedback'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
    );

Map<String, dynamic> _$$QuestionAnalysisCriterionImplToJson(
        _$QuestionAnalysisCriterionImpl instance) =>
    <String, dynamic>{
      'label': instance.label,
      'score': instance.score,
      'max_score': instance.maxScore,
      'feedback': instance.feedback,
      'tip': instance.tip,
    };

_$QuestionAnalysisFeedbackImpl _$$QuestionAnalysisFeedbackImplFromJson(
        Map<String, dynamic> json) =>
    _$QuestionAnalysisFeedbackImpl(
      verdict: json['verdict'] as String? ?? 'incorrect',
      errorAnalysis: json['error_analysis'] as String? ?? '',
      correctExplanation: json['correct_explanation'] as String? ?? '',
      shortTip: json['short_tip'] as String? ?? '',
      keyConceptLabel: json['key_concept'] as String? ?? '',
      matchingFeedback: (json['matching_feedback'] as List<dynamic>?)
              ?.map((e) => MatchingAnalysisFeedbackItem.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          const [],
      summary: json['summary'] as String? ?? '',
      criteria: (json['criteria'] as List<dynamic>?)
              ?.map((e) =>
                  QuestionAnalysisCriterion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      shortTips: (json['short_tips'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      skipped: json['skipped'] as bool? ?? false,
    );

Map<String, dynamic> _$$QuestionAnalysisFeedbackImplToJson(
        _$QuestionAnalysisFeedbackImpl instance) =>
    <String, dynamic>{
      'verdict': instance.verdict,
      'error_analysis': instance.errorAnalysis,
      'correct_explanation': instance.correctExplanation,
      'short_tip': instance.shortTip,
      'key_concept': instance.keyConceptLabel,
      'matching_feedback': instance.matchingFeedback,
      'summary': instance.summary,
      'criteria': instance.criteria,
      'short_tips': instance.shortTips,
      'skipped': instance.skipped,
    };

_$SkillInsightImpl _$$SkillInsightImplFromJson(Map<String, dynamic> json) =>
    _$SkillInsightImpl(
      skill: json['skill'] as String,
      summary: json['summary'] as String? ?? '',
      mainIssue: json['main_issue'] as String? ?? '',
    );

Map<String, dynamic> _$$SkillInsightImplToJson(_$SkillInsightImpl instance) =>
    <String, dynamic>{
      'skill': instance.skill,
      'summary': instance.summary,
      'main_issue': instance.mainIssue,
    };

_$OverallRecommendationImpl _$$OverallRecommendationImplFromJson(
        Map<String, dynamic> json) =>
    _$OverallRecommendationImpl(
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );

Map<String, dynamic> _$$OverallRecommendationImplToJson(
        _$OverallRecommendationImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'detail': instance.detail,
    };

_$ExamAnalysisImpl _$$ExamAnalysisImplFromJson(Map<String, dynamic> json) =>
    _$ExamAnalysisImpl(
      id: json['id'] as String,
      attemptId: json['attempt_id'] as String,
      status: $enumDecode(_$ExamAnalysisStatusEnumMap, json['status']),
      questionFeedbacks: json['question_feedbacks'] == null
          ? const {}
          : _questionFeedbacksFromJson(
              json['question_feedbacks'] as Map<String, dynamic>?),
      skillInsights: json['skill_insights'] == null
          ? const []
          : _skillInsightsFromJson(
              json['skill_insights'] as Map<String, dynamic>?),
      overallRecommendations:
          (json['overall_recommendations'] as List<dynamic>?)
                  ?.map((e) =>
                      OverallRecommendation.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              const [],
      teacherReviewsByQuestion: json['teacher_reviews_by_question'] == null
          ? const {}
          : _teacherReviewsByQuestionFromJson(
              json['teacher_reviews_by_question'] as Map<String, dynamic>?),
      errorMessage: json['error_message'] as String?,
    );

Map<String, dynamic> _$$ExamAnalysisImplToJson(_$ExamAnalysisImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'attempt_id': instance.attemptId,
      'status': _$ExamAnalysisStatusEnumMap[instance.status]!,
      'question_feedbacks':
          _questionFeedbacksToJson(instance.questionFeedbacks),
      'skill_insights': _skillInsightsToJson(instance.skillInsights),
      'overall_recommendations': instance.overallRecommendations,
      'teacher_reviews_by_question':
          _teacherReviewsByQuestionToJson(instance.teacherReviewsByQuestion),
      'error_message': instance.errorMessage,
    };

const _$ExamAnalysisStatusEnumMap = {
  ExamAnalysisStatus.processing: 'processing',
  ExamAnalysisStatus.ready: 'ready',
  ExamAnalysisStatus.error: 'error',
};
