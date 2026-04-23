import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_attempt.freezed.dart';
part 'exam_attempt.g.dart';

/// Represents a single exam session (anonymous or authenticated).
@freezed
class ExamAttempt with _$ExamAttempt {
  const factory ExamAttempt({
    required String id,
    required String examId,
    String? userId,           // null = anonymous guest
    required String status,   // 'in_progress' | 'submitted'
    @Default({}) Map<String, dynamic> answers,
    int? remainingSeconds,
    DateTime? startedAt,
    DateTime? submittedAt,
  }) = _ExamAttempt;

  factory ExamAttempt.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptFromJson(json);
}
