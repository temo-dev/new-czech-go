// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_attempt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExamAttemptImpl _$$ExamAttemptImplFromJson(Map<String, dynamic> json) =>
    _$ExamAttemptImpl(
      id: json['id'] as String,
      examId: json['examId'] as String,
      userId: json['userId'] as String?,
      status: json['status'] as String,
      answers: json['answers'] as Map<String, dynamic>? ?? const {},
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt(),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      submittedAt: json['submittedAt'] == null
          ? null
          : DateTime.parse(json['submittedAt'] as String),
    );

Map<String, dynamic> _$$ExamAttemptImplToJson(_$ExamAttemptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'examId': instance.examId,
      'userId': instance.userId,
      'status': instance.status,
      'answers': instance.answers,
      'remainingSeconds': instance.remainingSeconds,
      'startedAt': instance.startedAt?.toIso8601String(),
      'submittedAt': instance.submittedAt?.toIso8601String(),
    };
