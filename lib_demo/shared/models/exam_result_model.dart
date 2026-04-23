import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app_czech/shared/models/question_model.dart';

part 'exam_result_model.freezed.dart';
part 'exam_result_model.g.dart';

@freezed
class ExamResult with _$ExamResult {
  const factory ExamResult({
    required String id,
    required String userId,
    required ExamType type,
    required int totalScore, // 0–100
    required int totalQuestions,
    required int correctAnswers,
    required Map<String, int> sectionScores, // skill → score
    required Map<String, int> sectionTotals,
    required List<QuestionAnswer> answers,
    required DateTime completedAt,
    @Default(60) int passThreshold, // minimum passing score
    @Default([]) List<String> weakSkills, // skills below threshold
    @Default(false) bool passed,
    @Default(0) int writtenScore,
    @Default(70) int writtenTotal,
    @Default(42) int writtenPassThreshold,
    @Default(0) int speakingScore,
    @Default(40) int speakingTotal,
    @Default(24) int speakingPassThreshold,
    String? recommendation, // suggested next lesson/module
    int? totalTimeSeconds,
  }) = _ExamResult;

  factory ExamResult.fromJson(Map<String, dynamic> json) =>
      _$ExamResultFromJson(json);
}

enum ExamType { mockTest, fullSimulator, practiceSet }

extension ExamResultX on ExamResult {
  /// Score band for color-coding
  ScoreBand get band {
    if (totalScore >= 85) return ScoreBand.excellent;
    if (totalScore >= 70) return ScoreBand.good;
    if (totalScore >= 50) return ScoreBand.fair;
    return ScoreBand.poor;
  }

  double get accuracy =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0;
}

enum ScoreBand { excellent, good, fair, poor }
