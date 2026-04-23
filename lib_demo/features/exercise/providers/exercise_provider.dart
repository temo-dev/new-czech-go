import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/shared/models/question_model.dart';

// ── Exercise provider ─────────────────────────────────────────────────────────

/// Fetches a single exercise by ID from the [exercises] table and parses
/// the content_json into a [Question] domain object.
final exerciseProvider =
    FutureProvider.autoDispose.family<Question, String>((ref, exerciseId) async {
  final row = await supabase
      .from('exercises')
      .select()
      .eq('id', exerciseId)
      .maybeSingle();

  if (row == null) throw Exception('Không tìm thấy bài tập.');

  return _parseExercise(Map<String, dynamic>.from(row as Map));
});

// ── Parser ────────────────────────────────────────────────────────────────────

Question _parseExercise(Map<String, dynamic> row) {
  final id = row['id'] as String;
  final typeStr = row['type'] as String? ?? 'mcq';
  final skillStr = row['skill'] as String? ?? 'reading';
  final diffStr = row['difficulty'] as String? ?? 'beginner';
  final points = row['points'] as int? ?? 10;

  // content_json holds all question content
  final content = row['content_json'] != null
      ? Map<String, dynamic>.from(row['content_json'] as Map)
      : <String, dynamic>{};

  final prompt = content['prompt'] as String? ?? '';
  final introText = content['intro_text'] as String?;
  final introImageUrl = content['intro_image_url'] as String?;
  final explanation = content['explanation'] as String? ?? '';
  final correctAnswer = content['correct_answer'] as String?;
  final audioUrl = content['audio_url'] as String?;
  final imageUrl = content['image_url'] as String?;

  // Parse MCQ options
  final optionsRaw = content['options'] as List<dynamic>? ?? [];
  final options = optionsRaw.map((o) {
    final om = Map<String, dynamic>.from(o as Map);
    return QuestionOption(
      id: om['id'] as String? ?? '',
      text: om['text'] as String? ?? '',
      imageUrl: om['image_url'] as String?,
      isCorrect: om['is_correct'] as bool? ?? false,
    );
  }).toList();

  return Question(
    id: id,
    type: _parseType(typeStr),
    skill: _parseSkill(skillStr),
    difficulty: _parseDifficulty(diffStr),
    introText: introText,
    introImageUrl: introImageUrl,
    prompt: prompt,
    explanation: explanation,
    correctAnswer: correctAnswer,
    audioUrl: audioUrl,
    imageUrl: imageUrl,
    options: options,
    points: points,
  );
}

QuestionType _parseType(String s) => switch (s.toLowerCase()) {
      'mcq' => QuestionType.mcq,
      'fill_blank' || 'fill-blank' => QuestionType.fillBlank,
      'matching' => QuestionType.matching,
      'ordering' => QuestionType.ordering,
      'speaking' => QuestionType.speaking,
      'writing' => QuestionType.writing,
      _ => QuestionType.mcq,
    };

SkillArea _parseSkill(String s) => switch (s.toLowerCase()) {
      'reading' => SkillArea.reading,
      'listening' => SkillArea.listening,
      'writing' => SkillArea.writing,
      'speaking' => SkillArea.speaking,
      'vocabulary' || 'vocab' => SkillArea.vocabulary,
      'grammar' => SkillArea.grammar,
      _ => SkillArea.reading,
    };

Difficulty _parseDifficulty(String s) => switch (s.toLowerCase()) {
      'intermediate' => Difficulty.intermediate,
      'advanced' => Difficulty.advanced,
      _ => Difficulty.beginner,
    };
