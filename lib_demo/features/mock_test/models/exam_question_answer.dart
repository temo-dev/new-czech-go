import 'dart:convert';

import 'package:app_czech/shared/models/question_model.dart';

class ExamQuestionAnswer {
  const ExamQuestionAnswer({
    required this.questionId,
    this.selectedOptionId,
    this.writtenAnswer,
    this.aiAttemptId,
  });

  final String questionId;
  final String? selectedOptionId;
  final String? writtenAnswer;
  final String? aiAttemptId;

  bool get isAnswered =>
      selectedOptionId != null || writtenAnswer != null || aiAttemptId != null;

  String? get primaryValue => writtenAnswer ?? selectedOptionId ?? aiAttemptId;

  ExamQuestionAnswer copyWith({
    String? selectedOptionId,
    String? writtenAnswer,
    String? aiAttemptId,
    bool clearSelectedOptionId = false,
    bool clearWrittenAnswer = false,
    bool clearAiAttemptId = false,
  }) {
    return ExamQuestionAnswer(
      questionId: questionId,
      selectedOptionId: clearSelectedOptionId
          ? null
          : selectedOptionId ?? this.selectedOptionId,
      writtenAnswer:
          clearWrittenAnswer ? null : writtenAnswer ?? this.writtenAnswer,
      aiAttemptId: clearAiAttemptId ? null : aiAttemptId ?? this.aiAttemptId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      if (selectedOptionId != null) 'selected_option_id': selectedOptionId,
      if (writtenAnswer != null) 'written_answer': writtenAnswer,
      if (aiAttemptId != null) 'ai_attempt_id': aiAttemptId,
    };
  }

  factory ExamQuestionAnswer.fromStoredJson(
    String questionId,
    dynamic raw,
  ) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw as Map);
      return ExamQuestionAnswer(
        questionId: (map['question_id'] as String?) ?? questionId,
        selectedOptionId: _nonEmpty(
          map['selected_option_id'] ?? map['selectedOptionId'],
        ),
        writtenAnswer: _nonEmpty(
          map['written_answer'] ?? map['writtenAnswer'],
        ),
        aiAttemptId: _nonEmpty(
          map['ai_attempt_id'] ?? map['aiAttemptId'],
        ),
      );
    }

    if (raw is String) {
      final value = _nonEmpty(raw);
      return ExamQuestionAnswer(
        questionId: questionId,
        writtenAnswer: value,
      );
    }

    return ExamQuestionAnswer(questionId: questionId);
  }

  factory ExamQuestionAnswer.fromQuestionAnswer({
    required Question question,
    required QuestionAnswer answer,
    String? existingAiAttemptId,
  }) {
    switch (question.type) {
      case QuestionType.mcq:
        return ExamQuestionAnswer(
          questionId: question.id,
          selectedOptionId: _nonEmpty(answer.selectedOptionId),
        );
      case QuestionType.fillBlank:
      case QuestionType.writing:
        return ExamQuestionAnswer(
          questionId: question.id,
          writtenAnswer: _nonEmpty(answer.writtenAnswer),
          aiAttemptId: existingAiAttemptId,
        );
      case QuestionType.speaking:
        return ExamQuestionAnswer(
          questionId: question.id,
          aiAttemptId: _nonEmpty(answer.writtenAnswer) ?? existingAiAttemptId,
        );
      case QuestionType.matching:
        final matchingJson = answer.matchedPairs.isEmpty
            ? null
            : jsonEncode(answer.matchedPairs);
        return ExamQuestionAnswer(
          questionId: question.id,
          writtenAnswer: matchingJson,
        );
      case QuestionType.ordering:
        final orderingJson =
            answer.orderedIds.isEmpty ? null : jsonEncode(answer.orderedIds);
        return ExamQuestionAnswer(
          questionId: question.id,
          writtenAnswer: orderingJson,
        );
    }
  }

  QuestionAnswer toQuestionAnswer(Question question) {
    switch (question.type) {
      case QuestionType.mcq:
        return QuestionAnswer(
          questionId: question.id,
          selectedOptionId: selectedOptionId,
        );
      case QuestionType.fillBlank:
      case QuestionType.writing:
        return QuestionAnswer(
          questionId: question.id,
          writtenAnswer: writtenAnswer,
        );
      case QuestionType.speaking:
        return QuestionAnswer(
          questionId: question.id,
          writtenAnswer: aiAttemptId,
        );
      case QuestionType.matching:
      case QuestionType.ordering:
        return QuestionAnswer(
          questionId: question.id,
          writtenAnswer: writtenAnswer,
        );
    }
  }
}

String? _nonEmpty(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
