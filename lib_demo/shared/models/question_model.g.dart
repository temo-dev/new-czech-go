// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QuestionImpl _$$QuestionImplFromJson(Map<String, dynamic> json) =>
    _$QuestionImpl(
      id: json['id'] as String,
      type: $enumDecode(_$QuestionTypeEnumMap, json['type']),
      skill: $enumDecode(_$SkillAreaEnumMap, json['skill']),
      difficulty: $enumDecode(_$DifficultyEnumMap, json['difficulty']),
      introText: json['introText'] as String?,
      introImageUrl: json['introImageUrl'] as String?,
      prompt: json['prompt'] as String,
      audioUrl: json['audioUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      passageText: json['passageText'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      matchPairs: (json['matchPairs'] as List<dynamic>?)
              ?.map((e) => MatchPair.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      orderItems: (json['orderItems'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      correctAnswer: json['correctAnswer'] as String?,
      acceptedAnswers: (json['acceptedAnswers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      explanation: json['explanation'] as String,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$QuestionImplToJson(_$QuestionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$QuestionTypeEnumMap[instance.type]!,
      'skill': _$SkillAreaEnumMap[instance.skill]!,
      'difficulty': _$DifficultyEnumMap[instance.difficulty]!,
      'introText': instance.introText,
      'introImageUrl': instance.introImageUrl,
      'prompt': instance.prompt,
      'audioUrl': instance.audioUrl,
      'imageUrl': instance.imageUrl,
      'passageText': instance.passageText,
      'options': instance.options,
      'matchPairs': instance.matchPairs,
      'orderItems': instance.orderItems,
      'correctAnswer': instance.correctAnswer,
      'acceptedAnswers': instance.acceptedAnswers,
      'explanation': instance.explanation,
      'points': instance.points,
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

_$QuestionOptionImpl _$$QuestionOptionImplFromJson(Map<String, dynamic> json) =>
    _$QuestionOptionImpl(
      id: json['id'] as String,
      text: json['text'] as String,
      imageUrl: json['imageUrl'] as String?,
      isCorrect: json['isCorrect'] as bool? ?? false,
    );

Map<String, dynamic> _$$QuestionOptionImplToJson(
        _$QuestionOptionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'imageUrl': instance.imageUrl,
      'isCorrect': instance.isCorrect,
    };

_$MatchPairImpl _$$MatchPairImplFromJson(Map<String, dynamic> json) =>
    _$MatchPairImpl(
      leftId: json['leftId'] as String,
      leftText: json['leftText'] as String,
      rightId: json['rightId'] as String,
      rightText: json['rightText'] as String,
    );

Map<String, dynamic> _$$MatchPairImplToJson(_$MatchPairImpl instance) =>
    <String, dynamic>{
      'leftId': instance.leftId,
      'leftText': instance.leftText,
      'rightId': instance.rightId,
      'rightText': instance.rightText,
    };

_$QuestionAnswerImpl _$$QuestionAnswerImplFromJson(Map<String, dynamic> json) =>
    _$QuestionAnswerImpl(
      questionId: json['questionId'] as String,
      selectedOptionId: json['selectedOptionId'] as String?,
      writtenAnswer: json['writtenAnswer'] as String?,
      audioKey: json['audioKey'] as String?,
      selectedOptionIds: (json['selectedOptionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      orderedIds: (json['orderedIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      matchedPairs: (json['matchedPairs'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      isFlagged: json['isFlagged'] as bool? ?? false,
      timeSpentSeconds: (json['timeSpentSeconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$QuestionAnswerImplToJson(
        _$QuestionAnswerImpl instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'selectedOptionId': instance.selectedOptionId,
      'writtenAnswer': instance.writtenAnswer,
      'audioKey': instance.audioKey,
      'selectedOptionIds': instance.selectedOptionIds,
      'orderedIds': instance.orderedIds,
      'matchedPairs': instance.matchedPairs,
      'isFlagged': instance.isFlagged,
      'timeSpentSeconds': instance.timeSpentSeconds,
    };
