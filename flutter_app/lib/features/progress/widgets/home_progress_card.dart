import 'package:flutter/material.dart';

import '../../../core/api/progress_api.dart';
import '../../../core/api/progress_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'mastery_bar.dart';
import 'progress_empty_state.dart';
import 'progress_error_state.dart';
import 'skill_mastery_row.dart';

/// Function shape that returns the next [ProgressFetchResult]. Tests inject
/// stubs; production passes `progressApi.fetch`.
typedef ProgressFetcher = Future<ProgressFetchResult> Function({
  bool forceRefresh,
});

/// Bag of localised strings the card renders. Keeps the widget free of
/// inline VI/EN copy — UI-6 wires this up via `AppLocalizations`.
class HomeProgressCardLabels {
  const HomeProgressCardLabels({
    required this.cardTitle,
    required this.overallLabel,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyCtaLabel,
    required this.errorTitle,
    required this.errorMessage,
    required this.retryLabel,
    required this.offlineLabel,
    required this.skillLabelFor,
  });

  final String cardTitle;
  final String overallLabel;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyCtaLabel;
  final String errorTitle;
  final String errorMessage;
  final String retryLabel;
  final String offlineLabel;
  final String Function(String skillKind) skillLabelFor;
}

/// V20: home-screen card showing overall mastery + per-skill rows.
///
/// Behaviour:
/// - Loading: spinner.
/// - Loaded with skills: title + overall bar + tappable skill rows.
/// - Loaded with no skills: [ProgressEmptyState] with optional CTA.
/// - Error: [ProgressErrorState] with retry that re-runs `fetcher`.
/// - Stale cache: offline chip rendered alongside the populated card.
class HomeProgressCard extends StatefulWidget {
  const HomeProgressCard({
    super.key,
    required this.fetcher,
    required this.labels,
    this.onSkillTap,
    this.onEmptyCta,
  });

  final ProgressFetcher fetcher;
  final HomeProgressCardLabels labels;
  final void Function(String skillKind)? onSkillTap;
  final VoidCallback? onEmptyCta;

  @override
  State<HomeProgressCard> createState() => _HomeProgressCardState();
}

class _HomeProgressCardState extends State<HomeProgressCard> {
  ProgressFetchResult? _result;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.fetcher(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return ProgressErrorState(
        title: widget.labels.errorTitle,
        message: widget.labels.errorMessage,
        retryLabel: widget.labels.retryLabel,
        onRetry: () => _load(forceRefresh: true),
      );
    }
    final progress = _result?.progress ?? UserProgress.empty();
    if (progress.isEmpty) {
      return ProgressEmptyState(
        title: widget.labels.emptyTitle,
        message: widget.labels.emptyMessage,
        ctaLabel: widget.onEmptyCta == null ? null : widget.labels.emptyCtaLabel,
        onCta: widget.onEmptyCta,
      );
    }
    return _populated(progress, _result?.isStale ?? false);
  }

  Widget _populated(UserProgress progress, bool isStale) {
    final overallPct = (progress.overallProgress.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.labels.cardTitle,
                style: AppTypography.titleMedium,
              ),
            ),
            if (isStale)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  widget.labels.offlineLabel,
                  style: AppTypography.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.labels.overallLabel,
                style: AppTypography.bodyMedium,
              ),
            ),
            Text(
              '$overallPct%',
              style: AppTypography.titleMedium.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        MasteryBar(
          mastery: progress.overallProgress,
          band: progress.overallBand,
          height: 10,
        ),
        const SizedBox(height: AppSpacing.x3),
        for (final skill in progress.skills)
          SkillMasteryRow(
            label: widget.labels.skillLabelFor(skill.skillKind),
            mastery: skill.mastery,
            band: skill.band,
            onTap: widget.onSkillTap == null
                ? null
                : () => widget.onSkillTap!(skill.skillKind),
          ),
      ],
    );
  }
}
