import 'package:flutter/material.dart';

import '../../../core/api/progress_api.dart';
import '../../../core/api/progress_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/home_progress_card.dart' show ProgressFetcher;
import '../widgets/mastery_bar.dart';
import '../widgets/progress_empty_state.dart';
import '../widgets/progress_error_state.dart';
import '../widgets/skill_mastery_row.dart';

/// Bag of localised strings the detail screen renders. Strings come from the
/// caller so the screen itself stays free of hardcoded VI/EN copy.
class ProgressDetailLabels {
  const ProgressDetailLabels({
    required this.titleAll,
    required this.titleForSkill,
    required this.moduleLabelFor,
    required this.skillLabelFor,
    required this.attemptsCountLabel,
    required this.overallLabel,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyCtaLabel,
    required this.errorTitle,
    required this.errorMessage,
    required this.retryLabel,
    required this.offlineLabel,
  });

  final String titleAll;
  final String Function(String skillKind) titleForSkill;
  final String Function(String moduleId) moduleLabelFor;
  final String Function(String skillKind) skillLabelFor;
  final String Function(int attempts) attemptsCountLabel;
  final String overallLabel;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyCtaLabel;
  final String errorTitle;
  final String errorMessage;
  final String retryLabel;
  final String offlineLabel;
}

/// V20 screen: drilldown of one skill (or all skills if [skillKind] is null).
///
/// - skillKind == null: lists all skills with per-skill bars + module rows.
/// - skillKind == "noi": lists modules for that skill only.
/// - Pull-to-refresh re-fetches with `forceRefresh: true`.
class ProgressDetailScreen extends StatefulWidget {
  const ProgressDetailScreen({
    super.key,
    required this.fetcher,
    required this.labels,
    this.skillKind,
    this.onEmptyCta,
  });

  final ProgressFetcher fetcher;
  final ProgressDetailLabels labels;
  final String? skillKind;
  final VoidCallback? onEmptyCta;

  @override
  State<ProgressDetailScreen> createState() => _ProgressDetailScreenState();
}

class _ProgressDetailScreenState extends State<ProgressDetailScreen> {
  ProgressFetchResult? _result;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
    final title = widget.skillKind == null
        ? widget.labels.titleAll
        : widget.labels.titleForSkill(widget.skillKind!);
    final isStale = _result?.isStale ?? false;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isStale)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x4),
              child: Center(
                child: Text(
                  widget.labels.offlineLabel,
                  style: AppTypography.labelSmall,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _result == null) {
      return ListView(
        children: const [
          SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        children: [
          ProgressErrorState(
            title: widget.labels.errorTitle,
            message: widget.labels.errorMessage,
            retryLabel: widget.labels.retryLabel,
            onRetry: () => _load(forceRefresh: true),
          ),
        ],
      );
    }
    final progress = _result?.progress ?? UserProgress.empty();
    if (progress.isEmpty) {
      return ListView(
        children: [
          ProgressEmptyState(
            title: widget.labels.emptyTitle,
            message: widget.labels.emptyMessage,
            ctaLabel:
                widget.onEmptyCta == null ? null : widget.labels.emptyCtaLabel,
            onCta: widget.onEmptyCta,
          ),
        ],
      );
    }

    if (widget.skillKind != null) {
      final skill = progress.skills.firstWhere(
        (s) => s.skillKind == widget.skillKind,
        orElse: () => SkillProgress(
          skillKind: widget.skillKind!,
          mastery: 0,
          band: 'needs_work',
          attemptsCount: 0,
          modules: const [],
        ),
      );
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: [
          _SkillSection(skill: skill, labels: widget.labels),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.x4),
      itemCount: progress.skills.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _OverallSection(progress: progress, labels: widget.labels);
        }
        return _SkillSection(
          skill: progress.skills[i - 1],
          labels: widget.labels,
        );
      },
    );
  }
}

class _OverallSection extends StatelessWidget {
  const _OverallSection({required this.progress, required this.labels});

  final UserProgress progress;
  final ProgressDetailLabels labels;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.overallProgress.clamp(0.0, 1.0) * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.lgAll,
        ),
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    labels.overallLabel,
                    style: AppTypography.titleMedium,
                  ),
                ),
                Text(
                  '$pct%',
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
          ],
        ),
      ),
    );
  }
}

// Resolution order for the per-module row label:
//   1. Server-provided moduleTitle (V20 progress payload)
//   2. Caller-supplied moduleLabelFor (legacy fallback / tests)
//   3. Skill label (exam-pool aggregate, ModuleID is empty)
String _moduleRowLabel(
  SkillProgress skill,
  ModuleProgress m,
  ProgressDetailLabels labels,
) {
  if (m.moduleId.isEmpty) return labels.skillLabelFor(skill.skillKind);
  if (m.moduleTitle.isNotEmpty) return m.moduleTitle;
  return labels.moduleLabelFor(m.moduleId);
}

class _SkillSection extends StatelessWidget {
  const _SkillSection({required this.skill, required this.labels});

  final SkillProgress skill;
  final ProgressDetailLabels labels;

  @override
  Widget build(BuildContext context) {
    final pct = (skill.mastery.clamp(0.0, 1.0) * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.lgAll,
        ),
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    labels.skillLabelFor(skill.skillKind),
                    style: AppTypography.titleMedium,
                  ),
                ),
                Text(
                  '$pct%',
                  style: AppTypography.titleMedium.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            MasteryBar(mastery: skill.mastery, band: skill.band, height: 10),
            const SizedBox(height: AppSpacing.x2),
            Text(
              labels.attemptsCountLabel(skill.attemptsCount),
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.x3),
            for (final m in skill.modules)
              SkillMasteryRow(
                label: _moduleRowLabel(skill, m, labels),
                mastery: m.mastery,
                band: m.band,
              ),
          ],
        ),
      ),
    );
  }
}
