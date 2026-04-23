import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:app_czech/core/storage/prefs_storage.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import '../models/exam_meta.dart';

part 'mock_exam_meta_provider.g.dart';

// Supabase trả về snake_case, nhưng fromJson expect camelCase
Map<String, dynamic> _mapExamJson(Map<String, dynamic> e) => {
      'id': e['id'],
      'title': e['title'],
      'durationMinutes': e['duration_minutes'] ?? e['durationMinutes'] ?? 0,
    };

Map<String, dynamic> _mapSectionJson(Map<String, dynamic> s) => {
      'id': s['id'],
      'skill': s['skill'],
      'label': s['label'],
      'questionCount': s['question_count'] ?? s['questionCount'] ?? 0,
      'sectionDurationMinutes':
          s['section_duration_minutes'] ?? s['sectionDurationMinutes'],
      'orderIndex': s['order_index'] ?? s['orderIndex'] ?? 0,
    };

/// Fetches the active exam meta (first active exam + its sections).
/// Used by MockTestIntroScreen before an attempt is created.
@riverpod
Future<ExamMeta> mockExamMeta(MockExamMetaRef ref) async {
  // Fetch the active exam
  final examData = await supabase
      .from('exams')
      .select()
      .eq('is_active', true)
      .order('created_at')
      .limit(1)
      .single();

  // Fetch its sections ordered by order_index
  final sectionsData = await supabase
      .from('exam_sections')
      .select()
      .eq('exam_id', examData['id'] as String)
      .order('order_index');

  final sections = (sectionsData as List)
      .map((s) =>
          SectionMeta.fromJson(_mapSectionJson(s as Map<String, dynamic>)))
      .toList();

  return ExamMeta.fromJson({
    ..._mapExamJson(examData),
    'sections': sections.map((s) => s.toJson()).toList(),
  });
}

/// Fetches a specific exam by ID (or first active if examId is null),
/// including its sections. Used by MockTestIntroScreen when launched
/// from the authenticated ExamCatalogScreen with a known examId.
@riverpod
Future<ExamMeta> examMeta(ExamMetaRef ref, String? examId) async {
  final Map<String, dynamic> examData;
  if (examId != null) {
    examData = await supabase.from('exams').select().eq('id', examId).single();
  } else {
    examData = await supabase
        .from('exams')
        .select()
        .eq('is_active', true)
        .order('created_at')
        .limit(1)
        .single();
  }

  final sectionsData = await supabase
      .from('exam_sections')
      .select()
      .eq('exam_id', examData['id'] as String)
      .order('order_index');

  final sections = (sectionsData as List)
      .map((s) =>
          SectionMeta.fromJson(_mapSectionJson(s as Map<String, dynamic>)))
      .toList();

  return ExamMeta.fromJson({
    ..._mapExamJson(examData),
    'sections': sections.map((s) => s.toJson()).toList(),
  });
}

/// Creates an exam attempt row and returns its ID.
/// Called when the user taps "Bắt đầu" on MockTestIntroScreen.
@riverpod
class ExamAttemptCreator extends _$ExamAttemptCreator {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<String?> create(String examId, int durationMinutes) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = supabase.auth.currentUser?.id;
      final row = await supabase
          .from('exam_attempts')
          .insert({
            'exam_id': examId,
            if (userId != null) 'user_id': userId,
            if (userId == null)
              'guest_token': PrefsStorage.instance.guestAccessToken,
            'remaining_seconds': durationMinutes * 60,
          })
          .select()
          .single();
      return row['id'] as String;
    });
    return state.valueOrNull;
  }
}
