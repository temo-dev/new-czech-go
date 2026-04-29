import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

// ── Skill filter options ──────────────────────────────────────────────────────

const _kFilters = [
  ('noi',       'Nói'),
  ('viet',      'Viết'),
  ('nghe',      'Nghe'),
  ('doc',       'Đọc'),
  ('tu_vung',   'Từ vựng'),
  ('ngu_phap',  'Ngữ pháp'),
];

bool _exerciseMatchesSkillKind(String exerciseType, String skillKind) {
  switch (skillKind) {
    case 'noi':      return exerciseType.startsWith('uloha_');
    case 'viet':     return exerciseType.startsWith('psani_');
    case 'nghe':     return exerciseType.startsWith('poslech_');
    case 'doc':      return exerciseType.startsWith('cteni_');
    case 'tu_vung':  return const {'quizcard_basic', 'matching', 'fill_blank', 'choice_word'}.contains(exerciseType);
    case 'ngu_phap': return const {'matching', 'fill_blank', 'choice_word'}.contains(exerciseType);
    default:         return false;
  }
}

String? _exerciseTypeForAttempt(
    AttemptResult attempt, Map<String, List<ExerciseSummary>> exercisesByModule) {
  for (final exercises in exercisesByModule.values) {
    for (final e in exercises) {
      if (e.id == attempt.exerciseId) return e.exerciseType;
    }
  }
  return null;
}

/// History tab: stats + skill filter pills + activity list + CTA card.
class HistoryScreen extends StatefulWidget {
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
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _activeFilter; // null = all

  List<AttemptResult> get _filtered {
    if (_activeFilter == null) return widget.attempts;
    return widget.attempts.where((a) {
      final exerciseType = _exerciseTypeForAttempt(a, widget.exercisesByModule);
      if (exerciseType == null) return false;
      return _exerciseMatchesSkillKind(exerciseType, _activeFilter!);
    }).toList();
  }

  int get _readyCount => _filtered
      .where((a) => a.readinessLevel == 'ready_for_mock' || a.readinessLevel == 'almost_ready')
      .length;

  int get _avgSuccessPct {
    final f = _filtered;
    if (f.isEmpty) return 0;
    return ((_readyCount / f.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);
    final filtered = _filtered;

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

        // ── Skill filter pills ─────────────────────────────────────────────
        if (widget.attempts.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterPill(
                label: 'Tất cả',
                selected: _activeFilter == null,
                onTap: () => setState(() => _activeFilter = null),
              ),
              const SizedBox(width: 6),
              ..._kFilters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterPill(
                  label: f.$2,
                  selected: _activeFilter == f.$1,
                  onTap: () => setState(() =>
                      _activeFilter = _activeFilter == f.$1 ? null : f.$1),
                ),
              )),
            ]),
          ),
          const SizedBox(height: AppSpacing.x4),
        ],

        // ── Stats row ─────────────────────────────────────────────────────
        if (filtered.isNotEmpty) ...[
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
                  Text('${filtered.length}',
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
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: Column(children: [
              const Icon(Icons.history_rounded, size: 48, color: AppColors.outlineVariant),
              const SizedBox(height: AppSpacing.x3),
              Text(
                _activeFilter != null
                    ? 'Chưa có bài tập kỹ năng này.'
                    : l.historyEmpty,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
            ]),
          )
        else ...[
          // ── Attempt list ────────────────────────────────────────────────
          ...filtered.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: _AttemptRow(
              attempt: a,
              exerciseTitle: _exerciseTitleForAttempt(a, widget.exercisesByModule),
              onOpen: () => widget.onOpenAttemptExercise(a),
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

// ── Filter pill ───────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
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
