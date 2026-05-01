import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'deck_session_screen.dart';
import 'vocab_grammar_exercise_screen.dart';

/// Shows exercises of one type with a "Start all" deck button at top.
/// Individual exercises still open VocabGrammarExerciseScreen.
class VocabTypeListScreen extends StatelessWidget {
  const VocabTypeListScreen({
    super.key,
    required this.client,
    required this.moduleId,
    required this.exerciseType,
    required this.typeLabel,
    required this.exercises,
  });

  final ApiClient client;
  final String moduleId;
  final String exerciseType;
  final String typeLabel;
  final List<ExerciseSummary> exercises;

  Future<void> _openExercise(BuildContext context, ExerciseSummary exercise) async {
    final ExerciseDetail detail;
    try {
      detail = ExerciseDetail.fromJson(
        await client.getExercise(exercise.id),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).exerciseOpenError),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VocabGrammarExerciseScreen(
        client: client,
        detail: detail,
        onOpenNext: null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App bar ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
                const SizedBox(width: AppSpacing.x3),
                Text(typeLabel, style: AppTypography.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${exercises.length} bài',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            ),

            // ── "Start all" button ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DeckSessionScreen(
                      client: client,
                      moduleId: moduleId,
                      exerciseType: exerciseType,
                      typeLabel: typeLabel,
                      exercises: exercises,
                    ),
                  )),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text('${l.deckStartAll} (${exercises.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ),

            // ── Section label ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, AppSpacing.x2),
              child: Text(
                l.deckOrStudyOne,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // ── Exercise list ──────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(h, 0, h, AppSpacing.x6),
                itemCount: exercises.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _ExerciseListTile(
                      exercise: exercises[i],
                      onTap: () => _openExercise(context, exercises[i]),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseListTile extends StatelessWidget {
  const _ExerciseListTile({required this.exercise, required this.onTap});
  final ExerciseSummary exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.title,
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (exercise.shortInstruction.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(exercise.shortInstruction,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }
}
