import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_meta.freezed.dart';
part 'exam_meta.g.dart';

/// Top-level exam descriptor fetched before starting a session.
@freezed
class ExamMeta with _$ExamMeta {
  const factory ExamMeta({
    required String id,
    required String title,
    required int durationMinutes,
    @Default([]) List<SectionMeta> sections,
  }) = _ExamMeta;

  factory ExamMeta.fromJson(Map<String, dynamic> json) =>
      _$ExamMetaFromJson(json);
}

extension ExamMetaX on ExamMeta {
  int get totalQuestions =>
      sections.fold(0, (sum, s) => sum + s.questionCount);
}

/// One skill section within an exam.
@freezed
class SectionMeta with _$SectionMeta {
  const factory SectionMeta({
    required String id,
    required String skill,   // 'reading' | 'listening' | 'writing' | 'speaking'
    required String label,
    required int questionCount,
    int? sectionDurationMinutes, // null = uses global exam timer
    @Default(0) int orderIndex,
  }) = _SectionMeta;

  factory SectionMeta.fromJson(Map<String, dynamic> json) =>
      _$SectionMetaFromJson(json);
}

extension SectionMetaX on SectionMeta {
  IconName get icon => switch (skill) {
        'reading'   => IconName.menuBook,
        'listening' => IconName.headphones,
        'writing'   => IconName.editNote,
        'speaking'  => IconName.mic,
        _           => IconName.quiz,
      };
}

/// Thin enum for icon names — avoids importing flutter/material in a model file.
enum IconName { menuBook, headphones, editNote, mic, quiz }
