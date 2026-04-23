import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/exercise/widgets/audio_player_bar.dart';
import 'package:app_czech/features/exercise/widgets/mcq_exercise.dart';
import 'package:app_czech/shared/models/question_model.dart';

/// Listening exercise: audio player bar above MCQ options.
/// The audio URL comes from [Question.audioUrl].
/// [maxPlays] controls how many times the audio can be played (null = unlimited).
class ListeningExercise extends StatelessWidget {
  const ListeningExercise({
    super.key,
    required this.question,
    this.selectedOptionId,
    this.isSubmitted = false,
    this.maxPlays = 2,
    this.onSelect,
  });

  final Question question;
  final String? selectedOptionId;
  final bool isSubmitted;
  final int? maxPlays;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Audio player (hidden if no audio URL)
        if (question.audioUrl != null && question.audioUrl!.isNotEmpty) ...[
          AudioPlayerBar(
            audioUrl: question.audioUrl!,
            maxPlays: isSubmitted ? null : maxPlays,
          ),
          const SizedBox(height: AppSpacing.x5),
        ] else ...[
          _NoAudioPlaceholder(),
          const SizedBox(height: AppSpacing.x5),
        ],

        // Question + MCQ options
        McqExercise(
          question: question,
          selectedOptionId: selectedOptionId,
          isSubmitted: isSubmitted,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _NoAudioPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.headphones_outlined, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.x3),
          Text(
            'Không có file âm thanh cho câu hỏi này',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
