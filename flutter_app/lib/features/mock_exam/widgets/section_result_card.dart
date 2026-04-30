import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../exercise/widgets/objective_result_card.dart';
import '../../exercise/widgets/result_card.dart';

/// Unified section result wrapper.
///
/// Renders a skill-aware header (icon + label + score + progress bar) above
/// the correct result body:
///   - noi / viet  → [ResultCard]  (tabs: feedback / transcript / sample)
///   - nghe        → [ObjectiveResultCard]
///   - doc         → [ObjectiveResultCard] with collapsible passage
///
/// [skillKind] may be empty — falls back via [result.exerciseType] prefix.
class SectionResultCard extends StatelessWidget {
  const SectionResultCard({
    super.key,
    required this.client,
    required this.result,
    required this.skillKind,
    required this.maxPoints,
    required this.onRetry,
    this.onNext,
  });

  final ApiClient client;
  final AttemptResult result;
  final String skillKind;
  final int maxPoints;
  final VoidCallback onRetry;
  final VoidCallback? onNext;

  String get _resolvedKind {
    if (skillKind.isNotEmpty) return skillKind;
    final t = result.exerciseType;
    if (t.startsWith('uloha_')) return 'noi';
    if (t.startsWith('poslech_')) return 'nghe';
    if (t.startsWith('cteni_')) return 'doc';
    if (t.startsWith('psani_')) return 'viet';
    return 'noi';
  }

  int get _score {
    return result.feedback?.objectiveResult?.score ?? 0;
  }

  bool get _isObjective {
    final k = _resolvedKind;
    return k == 'nghe' || k == 'doc';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          skillKind: _resolvedKind,
          score: _isObjective ? _score : null,
          maxPoints: maxPoints,
        ),
        const SizedBox(height: AppSpacing.x4),
        _body(),
      ],
    );
  }

  Widget _body() {
    final kind = _resolvedKind;
    if (kind == 'nghe' || kind == 'doc') {
      return ObjectiveResultCard(
        result: result,
        onRetry: onRetry,
        showPassage: kind == 'doc',
        exerciseId: result.exerciseId,
        client: client,
      );
    }
    return ResultCard(
      client: client,
      result: result,
      onRetry: onRetry,
      onNext: onNext,
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.skillKind,
    required this.score,
    required this.maxPoints,
  });

  final String skillKind;
  final int? score;   // null for speaking/writing (no objective score)
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = _skillLabel(l, skillKind);
    final pct = (score != null && maxPoints > 0) ? score! / maxPoints : null;
    final barColor = pct == null
        ? AppColors.primary
        : (pct >= 0.75
            ? AppColors.success
            : pct >= 0.50
                ? AppColors.info
                : AppColors.error);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_skillIcon(skillKind), size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              if (score != null && maxPoints > 0)
                Text(
                  '$score/$maxPoints',
                  style: AppTypography.titleSmall.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (score != null && maxPoints > 0) ...[
            const SizedBox(height: AppSpacing.x2),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _skillLabel(AppLocalizations l, String kind) => switch (kind) {
    'noi' => l.skillNoi,
    'nghe' => l.skillNghe,
    'doc' => l.skillDoc,
    'viet' => l.skillViet,
    _ => kind.toUpperCase(),
  };

  IconData _skillIcon(String kind) => switch (kind) {
    'noi' => Icons.mic_outlined,
    'nghe' => Icons.headphones_outlined,
    'doc' => Icons.menu_book_outlined,
    'viet' => Icons.edit_outlined,
    _ => Icons.quiz_outlined,
  };
}
