import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app_czech/shared/models/question_model.dart';

part 'exercise_model.freezed.dart';
part 'exercise_model.g.dart';

@freezed
class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required QuestionType type,
    required SkillArea skill,
    required Difficulty difficulty,
    required String contentJson,    // raw JSON stored in Supabase
    @Default([]) List<String> assetUrls,
    @Default(10) int xpReward,
    DateTime? createdAt,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);
}

@freezed
class ExerciseAttempt with _$ExerciseAttempt {
  const factory ExerciseAttempt({
    required String id,
    required String exerciseId,
    required String userId,
    required QuestionAnswer answer,
    required bool isCorrect,
    @Default(0) int xpAwarded,
    required DateTime attemptedAt,
  }) = _ExerciseAttempt;

  factory ExerciseAttempt.fromJson(Map<String, dynamic> json) =>
      _$ExerciseAttemptFromJson(json);
}
