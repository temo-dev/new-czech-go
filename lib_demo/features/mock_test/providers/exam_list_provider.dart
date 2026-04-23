import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import '../models/exam_meta.dart';

part 'exam_list_provider.g.dart';

Map<String, dynamic> _mapExamJson(Map<String, dynamic> e) => {
      'id': e['id'],
      'title': e['title'],
      'durationMinutes': e['duration_minutes'] ?? e['durationMinutes'] ?? 0,
    };

/// Fetches all active exams for the catalog (no sections — catalog view only).
@riverpod
Future<List<ExamMeta>> examList(ExamListRef ref) async {
  final rows = await supabase
      .from('exams')
      .select()
      .eq('is_active', true)
      .order('created_at');

  return (rows as List)
      .map((e) => ExamMeta.fromJson(_mapExamJson(e as Map<String, dynamic>)))
      .toList();
}
