import 'package:freezed_annotation/freezed_annotation.dart';

part 'mock_test_result.freezed.dart';
part 'mock_test_result.g.dart';

/// Per-section score stored inside [MockTestResult.sectionScores].
@freezed
class SectionResult with _$SectionResult {
  const factory SectionResult({
    required int score,
    required int total,
  }) = _SectionResult;

  factory SectionResult.fromJson(Map<String, dynamic> json) =>
      _$SectionResultFromJson(json);
}

extension SectionResultX on SectionResult {
  double get percentage => total > 0 ? score / total : 0;
}

/// Result row from `exam_results`.
@freezed
class MockTestResult with _$MockTestResult {
  const factory MockTestResult({
    required String id,
    required String attemptId,
    String? userId,
    required int totalScore, // 0–100
    required int passThreshold,
    @Default({}) Map<String, SectionResult> sectionScores,
    @Default([]) List<String> weakSkills,
    @Default(false) bool passed,
    @Default(0) int writtenScore,
    @Default(70) int writtenTotal,
    @Default(42) int writtenPassThreshold,
    @Default(0) int speakingScore,
    @Default(40) int speakingTotal,
    @Default(24) int speakingPassThreshold,
    @Default(false) bool aiGradingPending,
    required DateTime createdAt,
  }) = _MockTestResult;

  factory MockTestResult.fromJson(Map<String, dynamic> json) =>
      _$MockTestResultFromJson(json);
}

extension MockTestResultX on MockTestResult {
  bool get hasOfficialResult => !aiGradingPending;

  ScoreBand get band {
    if (totalScore >= 85) return ScoreBand.excellent;
    if (totalScore >= 70) return ScoreBand.good;
    if (totalScore >= 50) return ScoreBand.fair;
    return ScoreBand.poor;
  }
}

enum ScoreBand { excellent, good, fair, poor }
