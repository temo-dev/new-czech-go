// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mock_test_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SectionResultImpl _$$SectionResultImplFromJson(Map<String, dynamic> json) =>
    _$SectionResultImpl(
      score: (json['score'] as num).toInt(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$$SectionResultImplToJson(_$SectionResultImpl instance) =>
    <String, dynamic>{
      'score': instance.score,
      'total': instance.total,
    };

_$MockTestResultImpl _$$MockTestResultImplFromJson(Map<String, dynamic> json) =>
    _$MockTestResultImpl(
      id: json['id'] as String,
      attemptId: json['attemptId'] as String,
      userId: json['userId'] as String?,
      totalScore: (json['totalScore'] as num).toInt(),
      passThreshold: (json['passThreshold'] as num).toInt(),
      sectionScores: (json['sectionScores'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, SectionResult.fromJson(e as Map<String, dynamic>)),
          ) ??
          const {},
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
      aiGradingPending: json['aiGradingPending'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$MockTestResultImplToJson(
        _$MockTestResultImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'attemptId': instance.attemptId,
      'userId': instance.userId,
      'totalScore': instance.totalScore,
      'passThreshold': instance.passThreshold,
      'sectionScores': instance.sectionScores,
      'weakSkills': instance.weakSkills,
      'passed': instance.passed,
      'writtenScore': instance.writtenScore,
      'writtenTotal': instance.writtenTotal,
      'writtenPassThreshold': instance.writtenPassThreshold,
      'speakingScore': instance.speakingScore,
      'speakingTotal': instance.speakingTotal,
      'speakingPassThreshold': instance.speakingPassThreshold,
      'aiGradingPending': instance.aiGradingPending,
      'createdAt': instance.createdAt.toIso8601String(),
    };
