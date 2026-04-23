// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ExamMetaImpl _$$ExamMetaImplFromJson(Map<String, dynamic> json) =>
    _$ExamMetaImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => SectionMeta.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ExamMetaImplToJson(_$ExamMetaImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'durationMinutes': instance.durationMinutes,
      'sections': instance.sections,
    };

_$SectionMetaImpl _$$SectionMetaImplFromJson(Map<String, dynamic> json) =>
    _$SectionMetaImpl(
      id: json['id'] as String,
      skill: json['skill'] as String,
      label: json['label'] as String,
      questionCount: (json['questionCount'] as num).toInt(),
      sectionDurationMinutes: (json['sectionDurationMinutes'] as num?)?.toInt(),
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$SectionMetaImplToJson(_$SectionMetaImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'skill': instance.skill,
      'label': instance.label,
      'questionCount': instance.questionCount,
      'sectionDurationMinutes': instance.sectionDurationMinutes,
      'orderIndex': instance.orderIndex,
    };
