import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';

/// History tab: full list of recent attempts with readiness pills + open CTA.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.attempts,
    required this.exercisesByModule,
    required this.onOpenAttemptExercise,
  });

  final List<AttemptResult> attempts;
  final Map<String, List<ExerciseSummary>> exercisesByModule;
  final ValueChanged<AttemptResult> onOpenAttemptExercise;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (attempts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Text(
            l.historyEmpty,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        Text(l.recentAttemptsTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.x1),
        Text(
          l.recentAttemptsSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.x4),
        for (var i = 0; i < attempts.length; i++) ...[
          _AttemptCard(
            attempt: attempts[i],
            exerciseTitle: _exerciseTitleForAttempt(attempts[i], exercisesByModule),
            onOpen: () => onOpenAttemptExercise(attempts[i]),
          ),
          if (i < attempts.length - 1) const SizedBox(height: AppSpacing.x3),
        ],
      ],
    );
  }
}

String _exerciseTitleForAttempt(
  AttemptResult attempt,
  Map<String, List<ExerciseSummary>> exercisesByModule,
) {
  for (final exercises in exercisesByModule.values) {
    for (final e in exercises) {
      if (e.id == attempt.exerciseId) return e.title;
    }
  }
  return attempt.exerciseId;
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({
    required this.attempt,
    required this.exerciseTitle,
    required this.onOpen,
  });

  final AttemptResult attempt;
  final String exerciseTitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final preview = attempt.feedback?.overallSummary.isNotEmpty == true
        ? attempt.feedback!.overallSummary
        : (attempt.transcriptPreview.isNotEmpty
            ? attempt.transcriptPreview
            : _statusCopy(l, attempt.status));

    final (pillLabel, pillTone) = _readinessPill(l, attempt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exerciseTitle, style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      _formatTimestamp(attempt.startedAt),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              InfoPill(label: pillLabel, tone: pillTone),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            preview,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              InfoPill(label: attempt.status.toUpperCase(), tone: PillTone.neutral),
              if (attempt.transcriptIsSynthetic)
                InfoPill(label: l.pillSyntheticTranscript, tone: PillTone.warning),
              if (attempt.failureCode.isNotEmpty)
                InfoPill(
                  label: l.pillFailure(attempt.failureCode.toUpperCase()),
                  tone: PillTone.error,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          OutlinedButton(
            onPressed: onOpen,
            child: Text(l.openExercise),
          ),
        ],
      ),
    );
  }
}

String _statusCopy(AppLocalizations l, String status) => switch (status) {
      'starting'   => l.statusCopyStarting,
      'recording'  => l.statusCopyRecording,
      'uploading'  => l.statusCopyUploading,
      'processing' => l.statusCopyProcessing,
      'completed'  => l.statusCopyCompleted,
      'failed'     => l.statusCopyFailed,
      _            => l.statusCopyReady,
    };

(String, PillTone) _readinessPill(AppLocalizations l, AttemptResult attempt) {
  if (attempt.failureCode.isNotEmpty || attempt.status == 'failed') {
    return (l.pillFailed, PillTone.error);
  }
  return switch (attempt.readinessLevel) {
    'ready_for_mock' => (l.pillReadinessReady, PillTone.success),
    'almost_ready'   => (l.pillReadinessAlmost, PillTone.info),
    'needs_work'     => (l.pillReadinessNeedsWork, PillTone.warning),
    'not_ready'      => (l.pillReadinessNotReady, PillTone.error),
    _                => (attempt.status.toUpperCase(), PillTone.neutral),
  };
}

String _formatTimestamp(String startedAt) {
  final dt = DateTime.tryParse(startedAt)?.toLocal();
  if (dt == null) return startedAt;
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m $h:$min';
}
