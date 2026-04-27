import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

/// History tab: Stitch redesign — stats + activity list + CTA card.
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

  int get _readyCount => attempts
      .where((a) => a.readinessLevel == 'ready_for_mock' || a.readinessLevel == 'almost_ready')
      .length;

  int get _avgSuccessPct {
    if (attempts.isEmpty) return 0;
    return ((_readyCount / attempts.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x5),
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Text(
          l.historyLabel,
          style: AppTypography.labelUppercase.copyWith(
            color: AppColors.primary, fontSize: 11, letterSpacing: 1.0),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(l.historyTitle,
            style: AppTypography.titleLarge.copyWith(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.x1),
        Text(l.historySubtitle,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),

        const SizedBox(height: AppSpacing.x4),

        // ── Stats row ─────────────────────────────────────────────────────
        if (attempts.isNotEmpty) ...[
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.x4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.historyStatTotal,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${attempts.length}',
                      style: AppTypography.titleLarge.copyWith(
                          fontSize: 32, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.x4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.historyStatSuccess,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('$_avgSuccessPct %',
                      style: AppTypography.titleLarge.copyWith(
                          fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.x4),
        ],

        // ── Empty state ───────────────────────────────────────────────────
        if (attempts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: Column(children: [
              const Icon(Icons.history_rounded, size: 48, color: AppColors.outlineVariant),
              const SizedBox(height: AppSpacing.x3),
              Text(l.historyEmpty,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
            ]),
          )
        else ...[
          // ── Attempt list ────────────────────────────────────────────────
          ...attempts.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: _AttemptRow(
              attempt: a,
              exerciseTitle: _exerciseTitleForAttempt(a, exercisesByModule),
              onOpen: () => onOpenAttemptExercise(a),
            ),
          )),
        ],

        // ── CTA card ─────────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.x3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.x5),
          decoration: BoxDecoration(
            color: AppColors.inverseSurfaceLight,
            borderRadius: AppRadius.lgAll,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pokračujte v tempu!',
                style: AppTypography.titleMedium.copyWith(
                    color: AppColors.inverseOnSurfaceLight, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x2),
            Text('Procvičte si další téma a zvyšte svou plynulost v češtině.',
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inverseOnSurfaceLight.withAlpha(200))),
            const SizedBox(height: AppSpacing.x4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: null, // navigates to courses — wired in main shell
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.inverseOnSurfaceLight,
                  side: BorderSide(color: AppColors.inverseOnSurfaceLight.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Začít trénink'),
              ),
            ),
          ]),
        ),

        const SizedBox(height: AppSpacing.x8),
      ],
    );
  }
}

// ── Attempt row ──────────────────────────────────────────────────────────────

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt, required this.exerciseTitle, required this.onOpen});
  final AttemptResult attempt;
  final String exerciseTitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeColor, badgeBg) = _badge(attempt);

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(children: [
          // Icon badge — circle
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _iconBg(attempt),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon(attempt), color: _iconColor(attempt), size: 18),
          ),
          const SizedBox(width: AppSpacing.x3),
          // Text
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exerciseTitle,
                style: AppTypography.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_formatTimestamp(attempt.startedAt),
                style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
          ])),
          const SizedBox(width: AppSpacing.x2),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
            child: Text(badgeLabel,
                style: AppTypography.labelUppercase.copyWith(
                    fontSize: 9, color: badgeColor, letterSpacing: 1.0)),
          ),
          const SizedBox(width: AppSpacing.x2),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.onSurfaceVariant),
        ]),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

(String, Color, Color) _badge(AttemptResult a) {
  if (a.status == 'failed' || a.failureCode.isNotEmpty) {
    return ('FAILED', AppColors.error, AppColors.errorContainer);
  }
  return switch (a.readinessLevel) {
    'ready_for_mock' || 'exam_ready' => ('READY', AppColors.success, AppColors.successContainer),
    'almost_ready'                   => ('ALMOST', AppColors.info, AppColors.infoContainer),
    'needs_work'                     => ('NEEDS WORK', AppColors.warning, AppColors.warningContainer),
    'not_ready'                      => ('NOT READY', AppColors.error, AppColors.errorContainer),
    _                                => (a.status.toUpperCase(), AppColors.onSurfaceVariant, AppColors.surfaceContainerHigh),
  };
}

IconData _icon(AttemptResult a) {
  if (a.status == 'failed') return Icons.error_outline_rounded;
  return switch (a.readinessLevel) {
    'ready_for_mock' || 'exam_ready' => Icons.mic_rounded,
    'almost_ready' => Icons.mic_rounded,
    _ => Icons.mic_none_rounded,
  };
}

Color _iconBg(AttemptResult a) {
  if (a.status == 'failed') return AppColors.errorContainer;
  return switch (a.readinessLevel) {
    'ready_for_mock' || 'exam_ready' || 'ready' => AppColors.successContainer,
    'almost_ready'                              => AppColors.primaryContainer,
    'needs_work'                                => AppColors.warningContainer,
    _                                           => AppColors.surfaceContainerHigh,
  };
}

Color _iconColor(AttemptResult a) {
  if (a.status == 'failed') return AppColors.error;
  return switch (a.readinessLevel) {
    'ready_for_mock' || 'exam_ready' || 'ready' => AppColors.success,
    'almost_ready'                              => AppColors.primary,
    'needs_work'                                => AppColors.warning,
    _                                           => AppColors.onSurfaceVariant,
  };
}

String _exerciseTitleForAttempt(
    AttemptResult attempt, Map<String, List<ExerciseSummary>> exercisesByModule) {
  for (final exercises in exercisesByModule.values) {
    for (final e in exercises) {
      if (e.id == attempt.exerciseId) return e.title;
    }
  }
  return attempt.exerciseId;
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
