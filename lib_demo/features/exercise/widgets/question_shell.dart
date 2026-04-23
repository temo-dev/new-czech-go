import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/features/exercise/widgets/audio_player_bar.dart';
import 'package:app_czech/features/exercise/widgets/fill_blank_exercise.dart';
import 'package:app_czech/features/exercise/widgets/listening_exercise.dart';
import 'package:app_czech/features/exercise/widgets/mcq_exercise.dart';
import 'package:app_czech/features/exercise/widgets/question_intro.dart';
import 'package:app_czech/features/exercise/widgets/reading_passage_exercise.dart';
import 'package:app_czech/features/exercise/widgets/speaking_recorder_exercise.dart';
import 'package:app_czech/features/exercise/widgets/writing_input_exercise.dart';

/// Dispatches the correct exercise widget based on [question.type].
///
/// Handles:
/// - MCQ (standalone)
/// - Fill-blank
/// - Listening (audio + MCQ)
/// - Reading (passage + MCQ, responsive)
/// - Writing (text area)
/// - Speaking (recorder)
///
/// State is kept outside: pass [selectedOptionId] / [writtenAnswer] etc.
/// in and emit changes via [onAnswerChanged].
class QuestionShell extends StatelessWidget {
  const QuestionShell({
    super.key,
    required this.question,
    this.currentAnswer,
    this.isSubmitted = false,
    this.lessonId,
    this.examAttemptId,
    this.onAnswerChanged,
  });

  final Question question;

  /// The current answer payload for this question (matches [QuestionAnswer]).
  final QuestionAnswer? currentAnswer;

  final bool isSubmitted;

  /// Optional lessonId — forwarded to SpeakingRecorderExercise for upload context.
  final String? lessonId;
  final String? examAttemptId;

  /// Called whenever the user changes their answer.
  final ValueChanged<QuestionAnswer>? onAnswerChanged;

  void _updateOption(String optionId) {
    final updated = (currentAnswer ?? QuestionAnswer(questionId: question.id))
        .copyWith(selectedOptionId: optionId);
    onAnswerChanged?.call(updated);
  }

  void _updateText(String text) {
    final updated = (currentAnswer ?? QuestionAnswer(questionId: question.id))
        .copyWith(writtenAnswer: text);
    onAnswerChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final hasIntro =
        question.introText != null || question.introImageUrl != null;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4, vertical: AppSpacing.x4),
      child: hasIntro
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuestionIntro(question: question),
                const SizedBox(height: AppSpacing.x4),
                _buildRenderer(),
              ],
            )
          : _buildRenderer(),
    );
  }

  Widget _buildRenderer() {
    final selectedOptionId = currentAnswer?.selectedOptionId;
    final writtenAnswer = currentAnswer?.writtenAnswer;
    final hasReadingPassage = question.skill == SkillArea.reading &&
        ((question.passageText?.isNotEmpty ?? false) ||
            (question.introText?.isNotEmpty ?? false));

    switch (question.type) {
      case QuestionType.mcq:
        // Listening questions embed their own audio + MCQ.
        // ListeningExercise shows a placeholder when audioUrl is null.
        if (question.skill == SkillArea.listening) {
          return ListeningExercise(
            question: question,
            selectedOptionId: selectedOptionId,
            isSubmitted: isSubmitted,
            onSelect: _updateOption,
          );
        }
        // Reading questions show a passage panel
        if (hasReadingPassage) {
          return ReadingPassageExercise(
            question: question,
            selectedOptionId: selectedOptionId,
            isSubmitted: isSubmitted,
            onSelect: _updateOption,
          );
        }
        return McqExercise(
          question: question,
          selectedOptionId: selectedOptionId,
          isSubmitted: isSubmitted,
          onSelect: _updateOption,
        );

      case QuestionType.fillBlank:
        final fillBlank = FillBlankExercise(
          question: question,
          initialAnswer: writtenAnswer,
          isSubmitted: isSubmitted,
          onChanged: _updateText,
        );
        if (question.skill == SkillArea.listening &&
            question.audioUrl != null &&
            question.audioUrl!.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AudioPlayerBar(
                audioUrl: question.audioUrl!,
                maxPlays: isSubmitted ? null : 2,
              ),
              const SizedBox(height: AppSpacing.x5),
              fillBlank,
            ],
          );
        }
        return fillBlank;

      case QuestionType.writing:
        return WritingInputExercise(
          question: question,
          initialAnswer: writtenAnswer,
          isSubmitted: isSubmitted,
          onChanged: _updateText,
        );

      case QuestionType.speaking:
        return SpeakingRecorderExercise(
          question: question,
          isSubmitted: isSubmitted,
          lessonId: lessonId,
          examAttemptId: examAttemptId,
          existingAudioPath: writtenAnswer,
          onRecordingComplete: _updateText,
        );

      case QuestionType.matching:
      case QuestionType.ordering:
        // Day 9+: matching/ordering renderers
        return _UnimplementedRenderer(type: question.type);
    }
  }
}

// ── Fallback for unimplemented types ──────────────────────────────────────────

class _UnimplementedRenderer extends StatelessWidget {
  const _UnimplementedRenderer({required this.type});
  final QuestionType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x6),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Center(
        child: Text(
          'Loại câu hỏi "${type.name}" chưa được hỗ trợ.',
          style: _body(cs),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  TextStyle _body(ColorScheme cs) =>
      TextStyle(color: cs.onSurfaceVariant, fontSize: 14);
}
