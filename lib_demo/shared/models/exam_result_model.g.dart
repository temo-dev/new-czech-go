// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_result_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExamResultImpl _$$ExamResultImplFromJson(Map<String, dynamic> json) =>
    _$ExamResultImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: $enumDecode(_$ExamTypeEnumMap, json['type']),
      totalScore: (json['totalScore'] as num).toInt(),
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      correctAnswers: (json['correctAnswers'] as num).toInt(),
      sectionScores: Map<String, int>.from(json['sectionScores'] as Map),
      sectionTotals: Map<String, int>.from(json['sectionTotals'] as Map),
      answers: (json['answers'] as List<dynamic>)
          .map((e) => QuestionAnswer.fromJson(e as Map<String, dynamic>))
          .toList(),
      completedAt: DateTime.parse(json['completedAt'] as String),
      passThreshold: (json['passThreshold'] as num?)?.toInt() ?? 60,
      weakSkills: (json['weakSkills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      passed: json['passed'] as bool? ?? false,
      writtenScore: (json['writtenScore'] as num?)?.toInt() ?? 0,
      writtenTotal: (json['writtenTotal'] as num?)?.toInt() ?? 70,
      writtenPassThreshold:
          (json['writtenPassThreshold'] as num?)?.toInt() ?? 42,
      speakingScore: (json['speakingScore'] as num?)?.toInt() ?? 0,
      speakingTotal: (json['speakingTotal'] as num?)?.toInt() ?? 40,
      speakingPassThreshold:
          (json['speakingPassThreshold'] as num?)?.toInt() ?? 24,
      recommendation: json['recommendation'] as String?,
      totalTimeSeconds: (json['totalTimeSeconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$ExamResultImplToJson(_$ExamResultImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'type': _$ExamTypeEnumMap[instance.type]!,
      'totalScore': instance.totalScore,
      'totalQuestions': instance.totalQuestions,
      'correctAnswers': instance.correctAnswers,
      'sectionScores': instance.sectionScores,
      'sectionTotals': instance.sectionTotals,
      'answers': instance.answers,
      'completedAt': instance.completedAt.toIso8601String(),
      'passThreshold': instance.passThreshold,
      'weakSkills': instance.weakSkills,
      'passed': instance.passed,
      'writtenScore': instance.writtenScore,
      'writtenTotal': instance.writtenTotal,
      'writtenPassThreshold': instance.writtenPassThreshold,
      'speakingScore': instance.speakingScore,
      'speakingTotal': instance.speakingTotal,
      'speakingPassThreshold': instance.speakingPassThreshold,
      'recommendation': instance.recommendation,
      'totalTimeSeconds': instance.totalTimeSeconds,
    };

const _$ExamTypeEnumMap = {
  ExamType.mockTest: 'mockTest',
  ExamType.fullSimulator: 'fullSimulator',
  ExamType.practiceSet: 'practiceSet',
};
