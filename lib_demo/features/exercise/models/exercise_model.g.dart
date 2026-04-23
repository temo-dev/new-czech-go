// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExerciseImpl _$$ExerciseImplFromJson(Map<String, dynamic> json) =>
    _$ExerciseImpl(
      id: json['id'] as String,
      type: $enumDecode(_$QuestionTypeEnumMap, json['type']),
      skill: $enumDecode(_$SkillAreaEnumMap, json['skill']),
      difficulty: $enumDecode(_$DifficultyEnumMap, json['difficulty']),
      contentJson: json['contentJson'] as String,
      assetUrls: (json['assetUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 10,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ExerciseImplToJson(_$ExerciseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$QuestionTypeEnumMap[instance.type]!,
      'skill': _$SkillAreaEnumMap[instance.skill]!,
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'contentJson': instance.contentJson,
      'assetUrls': instance.assetUrls,
      'xpReward': instance.xpReward,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$QuestionTypeEnumMap = {
  QuestionType.mcq: 'mcq',
  QuestionType.fillBlank: 'fillBlank',
  QuestionType.matching: 'matching',
  QuestionType.ordering: 'ordering',
  QuestionType.speaking: 'speaking',
  QuestionType.writing: 'writing',
};

const _$SkillAreaEnumMap = {
  SkillArea.reading: 'reading',
  SkillArea.listening: 'listening',
  SkillArea.writing: 'writing',
  SkillArea.speaking: 'speaking',
  SkillArea.vocabulary: 'vocabulary',
  SkillArea.grammar: 'grammar',
};

const _$DifficultyEnumMap = {
  Difficulty.beginner: 'beginner',
  Difficulty.intermediate: 'intermediate',
  Difficulty.advanced: 'advanced',
};

_$ExerciseAttemptImpl _$$ExerciseAttemptImplFromJson(
        Map<String, dynamic> json) =>
    _$ExerciseAttemptImpl(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      userId: json['userId'] as String,
      answer: QuestionAnswer.fromJson(json['answer'] as Map<String, dynamic>),
      isCorrect: json['isCorrect'] as bool,
      xpAwarded: (json['xpAwarded'] as num?)?.toInt() ?? 0,
      attemptedAt: DateTime.parse(json['attemptedAt'] as String),
    );

Map<String, dynamic> _$$ExerciseAttemptImplToJson(
        _$ExerciseAttemptImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exerciseId': instance.exerciseId,
      'userId': instance.userId,
      'answer': instance.answer,
      'isCorrect': instance.isCorrect,
      'xpAwarded': instance.xpAwarded,
      'attemptedAt': instance.attemptedAt.toIso8601String(),
    };
