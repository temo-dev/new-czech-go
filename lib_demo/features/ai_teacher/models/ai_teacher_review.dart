import 'package:app_czech/shared/models/question_model.dart';

enum AiTeacherReviewStatus { pending, ready, error }

enum AiTeacherReviewModality { objective, writing, speaking }

enum AiTeacherReviewVerdict { correct, incorrect, needsRetry, partial }

class AiTeacherCriterion {
  const AiTeacherCriterion({
    required this.title,
    this.score,
    this.maxScore,
    this.feedback = '',
    this.tip = '',
  });

  final String title;
  final double? score;
  final double? maxScore;
  final String feedback;
  final String tip;

  double? get fraction {
    if (score == null || maxScore == null || maxScore == 0) return null;
    return (score! / maxScore!).clamp(0.0, 1.0);
  }

  factory AiTeacherCriterion.fromJson(Map<String, dynamic> json) {
    return AiTeacherCriterion(
      title: json['title'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num?)?.toDouble(),
      feedback: json['feedback'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
    );
  }
}

class AiTeacherMistake {
  const AiTeacherMistake({
    required this.title,
    required this.explanation,
    this.correction = '',
    this.tip = '',
  });

  final String title;
  final String explanation;
  final String correction;
  final String tip;

  factory AiTeacherMistake.fromJson(Map<String, dynamic> json) {
    return AiTeacherMistake(
      title: json['title'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      correction: json['correction'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
    );
  }
}

class AiTeacherSuggestion {
  const AiTeacherSuggestion({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  factory AiTeacherSuggestion.fromJson(Map<String, dynamic> json) {
    return AiTeacherSuggestion(
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

class AiTeacherAnnotatedSpan {
  const AiTeacherAnnotatedSpan({
    required this.text,
    this.issueType,
    this.correction,
    this.explanation,
    this.tip,
  });

  final String text;
  final String? issueType;
  final String? correction;
  final String? explanation;
  final String? tip;

  bool get hasIssue => issueType != null && issueType!.isNotEmpty;

  factory AiTeacherAnnotatedSpan.fromJson(Map<String, dynamic> json) {
    return AiTeacherAnnotatedSpan(
      text: json['text'] as String? ?? '',
      issueType: json['issue_type'] as String?,
      correction: json['correction'] as String?,
      explanation: json['explanation'] as String?,
      tip: json['tip'] as String?,
    );
  }
}

class AiTeacherTranscriptIssue {
  const AiTeacherTranscriptIssue({
    required this.token,
    this.issue,
    this.suggestion,
  });

  final String token;
  final String? issue;
  final String? suggestion;

  factory AiTeacherTranscriptIssue.fromJson(Map<String, dynamic> json) {
    return AiTeacherTranscriptIssue(
      token: json['token'] as String? ?? json['word'] as String? ?? '',
      issue: json['issue'] as String? ?? json['type'] as String?,
      suggestion: json['suggestion'] as String?,
    );
  }
}

class AiTeacherArtifacts {
  const AiTeacherArtifacts({
    this.transcript = '',
    this.annotatedSpans = const [],
    this.transcriptIssues = const [],
    this.shortTips = const [],
  });

  final String transcript;
  final List<AiTeacherAnnotatedSpan> annotatedSpans;
  final List<AiTeacherTranscriptIssue> transcriptIssues;
  final List<String> shortTips;

  factory AiTeacherArtifacts.fromJson(Map<String, dynamic> json) {
    final spansRaw = json['annotated_spans'] as List<dynamic>? ?? const [];
    final issuesRaw = json['transcript_issues'] as List<dynamic>? ?? const [];
    final shortTipsRaw = json['short_tips'] as List<dynamic>? ?? const [];

    return AiTeacherArtifacts(
      transcript: json['transcript'] as String? ?? '',
      annotatedSpans: spansRaw
          .map((raw) => AiTeacherAnnotatedSpan.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList(),
      transcriptIssues: issuesRaw
          .map((raw) => AiTeacherTranscriptIssue.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList(),
      shortTips: shortTipsRaw.map((raw) => raw as String).toList(),
    );
  }
}

class AiTeacherReview {
  const AiTeacherReview({
    required this.reviewId,
    required this.status,
    required this.modality,
    required this.source,
    required this.verdict,
    required this.summary,
    required this.reinforcement,
    required this.criteria,
    required this.mistakes,
    required this.suggestions,
    required this.correctedAnswer,
    required this.artifacts,
    required this.isPremium,
  });

  final String reviewId;
  final AiTeacherReviewStatus status;
  final AiTeacherReviewModality modality;
  final String source;
  final AiTeacherReviewVerdict verdict;
  final String summary;
  final String reinforcement;
  final List<AiTeacherCriterion> criteria;
  final List<AiTeacherMistake> mistakes;
  final List<AiTeacherSuggestion> suggestions;
  final String correctedAnswer;
  final AiTeacherArtifacts artifacts;
  final bool isPremium;

  bool get isReady => status == AiTeacherReviewStatus.ready;

  int? get overallScore {
    final scored = criteria.where((criterion) => criterion.score != null);
    if (scored.isEmpty) return null;
    final values = scored.map((criterion) => criterion.fraction ?? 0).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    return (avg * 100).round();
  }

  factory AiTeacherReview.fromJson(Map<String, dynamic> json) {
    final criteriaRaw = json['criteria'] as List<dynamic>? ?? const [];
    final mistakesRaw = json['mistakes'] as List<dynamic>? ?? const [];
    final suggestionsRaw = json['suggestions'] as List<dynamic>? ?? const [];

    return AiTeacherReview(
      reviewId: json['review_id'] as String? ?? '',
      status: _parseStatus(json['status'] as String?),
      modality: _parseModality(json['modality'] as String?),
      source: json['source'] as String? ?? '',
      verdict: _parseVerdict(json['verdict'] as String?),
      summary: json['summary'] as String? ?? '',
      reinforcement: json['reinforcement'] as String? ?? '',
      criteria: criteriaRaw
          .map((raw) => AiTeacherCriterion.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList(),
      mistakes: mistakesRaw
          .map((raw) => AiTeacherMistake.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList(),
      suggestions: suggestionsRaw
          .map((raw) => AiTeacherSuggestion.fromJson(
                Map<String, dynamic>.from(raw as Map),
              ))
          .toList(),
      correctedAnswer: json['corrected_answer'] as String? ?? '',
      artifacts: AiTeacherArtifacts.fromJson(
        (json['artifacts'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }
}

class AiTeacherReviewResponse {
  const AiTeacherReviewResponse({
    required this.status,
    required this.reviewId,
    this.review,
    this.message,
    this.processingStage,
  });

  final AiTeacherReviewStatus status;
  final String? reviewId;
  final AiTeacherReview? review;
  final String? message;
  final String? processingStage;

  bool get isPending => status == AiTeacherReviewStatus.pending;
  bool get isReady => status == AiTeacherReviewStatus.ready && review != null;
  bool get isError => status == AiTeacherReviewStatus.error;

  factory AiTeacherReviewResponse.fromJson(Map<String, dynamic> json) {
    final status = _parseStatus(json['status'] as String?);
    final reviewId = json['review_id'] as String?;
    final review = status == AiTeacherReviewStatus.ready
        ? AiTeacherReview.fromJson(json)
        : null;

    return AiTeacherReviewResponse(
      status: status,
      reviewId: reviewId,
      review: review,
      message: json['message'] as String?,
      processingStage: json['processing_stage'] as String?,
    );
  }
}

class AiTeacherReviewRequest {
  const AiTeacherReviewRequest({
    required this.source,
    required this.questionId,
    this.exerciseId,
    this.lessonId,
    this.examAttemptId,
    this.selectedOptionId,
    this.writtenAnswer,
    this.aiAttemptId,
    this.questionType,
  });

  final String source;
  final String questionId;
  final String? exerciseId;
  final String? lessonId;
  final String? examAttemptId;
  final String? selectedOptionId;
  final String? writtenAnswer;
  final String? aiAttemptId;
  final QuestionType? questionType;

  bool get hasAnswer =>
      (selectedOptionId?.isNotEmpty ?? false) ||
      (writtenAnswer?.trim().isNotEmpty ?? false) ||
      (aiAttemptId?.isNotEmpty ?? false);

  bool get isSubjective =>
      (aiAttemptId?.isNotEmpty ?? false) ||
      questionType == QuestionType.speaking ||
      questionType == QuestionType.writing;

  Map<String, dynamic> toBody() {
    return {
      'source': source,
      if (_hasText(questionId)) 'question_id': questionId,
      if (_hasText(exerciseId)) 'exercise_id': exerciseId,
      if (_hasText(lessonId)) 'lesson_id': lessonId,
      if (_hasText(examAttemptId)) 'exam_attempt_id': examAttemptId,
      if (_hasText(selectedOptionId)) 'selected_option_id': selectedOptionId,
      if (_hasText(writtenAnswer)) 'written_answer': writtenAnswer,
      if (_hasText(aiAttemptId)) 'ai_attempt_id': aiAttemptId,
    };
  }

  factory AiTeacherReviewRequest.objective({
    required String source,
    required Question question,
    required QuestionAnswer answer,
    String? exerciseId,
    String? lessonId,
    String? examAttemptId,
  }) {
    return AiTeacherReviewRequest(
      source: source,
      questionId: question.id,
      exerciseId: exerciseId,
      lessonId: lessonId,
      examAttemptId: examAttemptId,
      selectedOptionId: answer.selectedOptionId,
      writtenAnswer: answer.writtenAnswer,
      questionType: question.type,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AiTeacherReviewRequest &&
            source == other.source &&
            questionId == other.questionId &&
            exerciseId == other.exerciseId &&
            lessonId == other.lessonId &&
            examAttemptId == other.examAttemptId &&
            selectedOptionId == other.selectedOptionId &&
            writtenAnswer == other.writtenAnswer &&
            aiAttemptId == other.aiAttemptId &&
            questionType == other.questionType;
  }

  @override
  int get hashCode => Object.hash(
        source,
        questionId,
        exerciseId,
        lessonId,
        examAttemptId,
        selectedOptionId,
        writtenAnswer,
        aiAttemptId,
        questionType,
      );
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

AiTeacherReviewStatus _parseStatus(String? raw) {
  switch (raw) {
    case 'ready':
      return AiTeacherReviewStatus.ready;
    case 'error':
      return AiTeacherReviewStatus.error;
    default:
      return AiTeacherReviewStatus.pending;
  }
}

AiTeacherReviewModality _parseModality(String? raw) {
  switch (raw) {
    case 'writing':
      return AiTeacherReviewModality.writing;
    case 'speaking':
      return AiTeacherReviewModality.speaking;
    default:
      return AiTeacherReviewModality.objective;
  }
}

AiTeacherReviewVerdict _parseVerdict(String? raw) {
  switch (raw) {
    case 'correct':
      return AiTeacherReviewVerdict.correct;
    case 'needs_retry':
      return AiTeacherReviewVerdict.needsRetry;
    case 'partial':
      return AiTeacherReviewVerdict.partial;
    default:
      return AiTeacherReviewVerdict.incorrect;
  }
}
