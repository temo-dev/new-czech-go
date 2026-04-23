import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/shared/models/question_model.dart';

/// Fetches all questions (with options) for a given exam, ordered by section
/// then by question order_index. Returns a flat list matching the global index
/// used by ExamSessionNotifier (q_0, q_1, ...).
final examQuestionsProvider =
    FutureProvider.family<List<Question>, String>((ref, examId) async {
  // 1. Lấy section IDs theo thứ tự order_index
  final sectionsData = await supabase
      .from('exam_sections')
      .select('id')
      .eq('exam_id', examId)
      .order('order_index');

  final sectionIds =
      (sectionsData as List).map((s) => s['id'] as String).toList();

  if (sectionIds.isEmpty) return [];

  // 2. Fetch tất cả câu hỏi kèm options
  final questionsData = await supabase
      .from('questions')
      .select('*, question_options(*)')
      .inFilter('section_id', sectionIds)
      .order('order_index');

  // 3. Group by section_id
  final bySection = <String, List<Map<String, dynamic>>>{};
  for (final q in questionsData as List) {
    final sid = q['section_id'] as String;
    bySection.putIfAbsent(sid, () => []).add(q as Map<String, dynamic>);
  }

  // 4. Flatten theo thứ tự section
  final allQuestions = <Question>[];
  for (final sectionId in sectionIds) {
    final sqs = bySection[sectionId] ?? [];
    allQuestions.addAll(sqs.map(_questionFromSupabase));
  }
  return allQuestions;
});

Question _questionFromSupabase(Map<String, dynamic> q) {
  final optionsRaw = List<Map<String, dynamic>>.from(
    (q['question_options'] as List? ?? []).cast<Map<String, dynamic>>(),
  )..sort((a, b) => ((a['order_index'] as num?)?.toInt() ?? 0)
      .compareTo((b['order_index'] as num?)?.toInt() ?? 0));

  final options = optionsRaw
      .map((o) => QuestionOption(
            id: o['id'] as String,
            text: o['text'] as String,
            imageUrl: o['image_url'] as String?,
            isCorrect: o['is_correct'] as bool? ?? false,
          ))
      .toList();

  return Question(
    id: q['id'] as String,
    type: _parseQuestionType(q['type'] as String? ?? 'mcq'),
    skill: _parseSkillArea(q['skill'] as String? ?? 'reading'),
    difficulty: Difficulty.intermediate,
    introText: q['intro_text'] as String?,
    introImageUrl: q['intro_image_url'] as String?,
    prompt: q['prompt'] as String? ?? '',
    audioUrl: q['audio_url'] as String?,
    imageUrl: q['image_url'] as String?,
    passageText: q['passage_text'] as String?,
    options: options,
    correctAnswer: q['correct_answer'] as String?,
    acceptedAnswers: ((q['accepted_answers'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList(),
    explanation: q['explanation'] as String? ?? '',
    points: (q['points'] as num?)?.toInt() ?? 1,
  );
}

QuestionType _parseQuestionType(String type) => switch (type) {
      'fill_blank' || 'fillBlank' => QuestionType.fillBlank,
      'matching' => QuestionType.matching,
      'ordering' => QuestionType.ordering,
      'speaking' => QuestionType.speaking,
      'writing' => QuestionType.writing,
      _ => QuestionType.mcq,
    };

SkillArea _parseSkillArea(String skill) => switch (skill) {
      'listening' => SkillArea.listening,
      'writing' => SkillArea.writing,
      'speaking' => SkillArea.speaking,
      'vocabulary' => SkillArea.vocabulary,
      'grammar' => SkillArea.grammar,
      _ => SkillArea.reading,
    };
