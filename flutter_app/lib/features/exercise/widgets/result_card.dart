import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

import '../../../shared/widgets/audio_playback_card.dart';
import '../../../shared/widgets/primary_button.dart';

/// Shows feedback result with tabbed view: Phản hồi / Bản ghi / Bài mẫu.
class ResultCard extends StatefulWidget {
  const ResultCard({
    super.key,
    required this.client,
    required this.result,
    required this.onRetry,
    this.onNext,
  });

  final ApiClient client;
  final AttemptResult result;
  final VoidCallback onRetry;
  final VoidCallback? onNext;

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final feedback = widget.result.feedback;
    final l = AppLocalizations.of(context);
    final readiness = feedback?.readinessLevel ?? widget.result.readinessLevel;

    final hasFeedback = (feedback?.strengths.isNotEmpty == true) ||
        (feedback?.improvements.isNotEmpty == true) ||
        (feedback?.retryAdvice.isNotEmpty == true);
    final hasTranscript = widget.result.transcript?.isNotEmpty == true ||
        widget.result.audio != null;
    final hasSample = feedback?.sampleAnswer.isNotEmpty == true ||
        widget.result.status == 'completed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Readiness hero ───────────────────────────────────────────────────
        if (readiness.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _readinessBg(readiness),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                _readinessLabel(l, readiness),
                style: AppTypography.labelUppercase.copyWith(
                  color: _readinessFg(readiness),
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          if (feedback?.overallSummary.isNotEmpty == true)
            Center(
              child: Text(
                feedback!.overallSummary,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.x4),
        ],

        // ── Tab bar ──────────────────────────────────────────────────────────
        _TabBar(
          tabs: [
            _TabItem(label: l.resultTabFeedback,   enabled: hasFeedback),
            _TabItem(label: l.resultTabTranscript, enabled: hasTranscript),
            _TabItem(label: l.resultTabSample,     enabled: hasSample),
          ],
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: AppSpacing.x4),

        // ── Tab content ──────────────────────────────────────────────────────
        if (_tab == 0) _FeedbackTab(feedback: feedback, l: l),
        if (_tab == 1) _TranscriptTab(result: widget.result, client: widget.client, l: l),
        if (_tab == 2) _SampleTab(feedback: feedback, result: widget.result, client: widget.client, l: l),

        const SizedBox(height: AppSpacing.x5),

        // ── CTAs ─────────────────────────────────────────────────────────────
        if (widget.onNext != null) ...[
          PrimaryButton(
            label: l.resultNextExerciseCta,
            icon: Icons.arrow_forward,
            onPressed: widget.onNext,
          ),
          const SizedBox(height: AppSpacing.x3),
          SecondaryButton(
            label: l.resultRetryCta,
            icon: Icons.refresh,
            onPressed: widget.onRetry,
          ),
        ] else
          PrimaryButton(
            label: l.resultRetryCta,
            icon: Icons.refresh,
            onPressed: widget.onRetry,
          ),
      ],
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabItem {
  const _TabItem({required this.label, this.enabled = true});
  final String label;
  final bool enabled;
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });
  final List<_TabItem> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0D281C10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          final t = tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: t.enabled ? () => onSelect(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppColors.surfaceContainerLowest : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: active
                      ? const [BoxShadow(color: Color(0x14281C10), blurRadius: 8, offset: Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  t.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? AppColors.onSurface
                        : t.enabled
                            ? AppColors.onSurfaceVariant
                            : AppColors.outline,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Tab 0: Phản hồi ───────────────────────────────────────────────────────────

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab({required this.feedback, required this.l});
  final AttemptFeedbackView? feedback;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    if (feedback == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Text(l.resultNoFeedback,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (feedback!.strengths.isNotEmpty) ...[
          _FeedbackSection(
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
            bgColor: AppColors.successContainer,
            title: l.resultStrengthsTitle,
            items: feedback!.strengths,
            textColor: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (feedback!.improvements.isNotEmpty) ...[
          _FeedbackSection(
            icon: Icons.error_outline_rounded,
            iconColor: AppColors.error,
            bgColor: AppColors.errorContainer,
            title: l.resultImprovementsTitle,
            items: feedback!.improvements,
            textColor: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (feedback!.criteriaResults.isNotEmpty) ...[
          _CriteriaChecklist(criteria: feedback!.criteriaResults),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (feedback!.retryAdvice.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: AppRadius.lgAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.surfaceContainerLow, size: 18),
                  const SizedBox(width: AppSpacing.x2),
                  Text(l.resultCoachTipLabel,
                      style: AppTypography.labelUppercase.copyWith(
                          color: AppColors.surfaceContainerLow,
                          fontSize: 10,
                          letterSpacing: 1.2)),
                ]),
                const SizedBox(height: AppSpacing.x2),
                ...feedback!.retryAdvice.map((tip) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(tip,
                      style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondaryContainer, height: 1.5)),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Tab 1: Bản ghi ────────────────────────────────────────────────────────────

class _TranscriptTab extends StatelessWidget {
  const _TranscriptTab({
    required this.result,
    required this.client,
    required this.l,
  });
  final AttemptResult result;
  final ApiClient client;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.transcript?.isNotEmpty == true) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.description_outlined,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(l.resultTranscriptTitle,
                      style: AppTypography.labelUppercase.copyWith(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 1.2)),
                  const Spacer(),
                  if (result.transcriptIsSynthetic)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(l.pillSyntheticTranscript,
                          style: AppTypography.labelUppercase.copyWith(
                              fontSize: 9, color: AppColors.warning)),
                    ),
                ]),
                const SizedBox(height: AppSpacing.x3),
                Text(result.transcript!,
                    style: AppTypography.bodyMedium.copyWith(height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (result.audio != null)
          AttemptAudioPlaybackCard(
            client: client,
            attemptId: result.id,
            audio: result.audio!,
          ),
        if (result.transcript == null && result.audio == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Text(l.resultNoTranscript,
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

// ── Tab 2: Bài mẫu ───────────────────────────────────────────────────────────

class _SampleTab extends StatelessWidget {
  const _SampleTab({
    required this.feedback,
    required this.result,
    required this.client,
    required this.l,
  });
  final AttemptFeedbackView? feedback;
  final AttemptResult result;
  final ApiClient client;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (feedback?.sampleAnswer.isNotEmpty == true) ...[
          Text(l.resultSampleAnswerTitle, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.x2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadius.lgAll,
            ),
            child: Text(feedback!.sampleAnswer,
                style: AppTypography.bodyMedium.copyWith(
                    height: 1.6,
                    color: AppColors.onPrimaryContainer)),
          ),
          const SizedBox(height: AppSpacing.x4),
        ],
        if (result.status == 'completed') ...[
          const Divider(),
          const SizedBox(height: AppSpacing.x4),
          _ReviewArtifactSection(client: client, result: result),
        ],
        if (feedback?.sampleAnswer == null && result.status != 'completed')
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Text(l.resultNoSample,
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

// ── Feedback section ──────────────────────────────────────────────────────────

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.items,
    required this.textColor,
  });
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final List<String> items;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(title,
                style: AppTypography.labelUppercase.copyWith(
                    color: iconColor, fontSize: 10, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: AppSpacing.x2),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: AppTypography.bodySmall.copyWith(color: textColor)),
                Expanded(
                    child: Text(item,
                        style: AppTypography.bodySmall.copyWith(height: 1.5))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

Color _readinessBg(String level) => switch (level) {
  'ready' || 'ready_for_mock' || 'exam_ready' => AppColors.successContainer,
  'almost' || 'almost_ready'                  => AppColors.infoContainer,
  'needs_work'                                => AppColors.warningContainer,
  _                                           => AppColors.errorContainer,
};

Color _readinessFg(String level) => switch (level) {
  'ready' || 'ready_for_mock' || 'exam_ready' => AppColors.success,
  'almost' || 'almost_ready'                  => AppColors.info,
  'needs_work'                                => AppColors.warning,
  _                                           => AppColors.error,
};

// ── Review artifact ───────────────────────────────────────────────────────────

class _ReviewArtifactSection extends StatefulWidget {
  const _ReviewArtifactSection({required this.client, required this.result});
  final ApiClient client;
  final AttemptResult result;

  @override
  State<_ReviewArtifactSection> createState() => _ReviewArtifactSectionState();
}

class _ReviewArtifactSectionState extends State<_ReviewArtifactSection> {
  AttemptReviewArtifactView? _artifact;
  bool _loading = true;
  String? _error;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.client.getAttemptReview(widget.result.id);
      if (!mounted) return;
      final artifact = AttemptReviewArtifactView.fromJson(data);
      setState(() {
        _artifact = artifact;
        _loading = false;
      });
      if (artifact.isPending) {
        _poller = Timer.periodic(const Duration(seconds: 3), (_) async {
          final refreshed = AttemptReviewArtifactView.fromJson(
            await widget.client.getAttemptReview(widget.result.id),
          );
          if (!mounted) return;
          setState(() => _artifact = refreshed);
          if (!refreshed.isPending) _poller?.cancel();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final artifact = _artifact;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.reviewArtifactTitle, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.x2),
        Text(
          l.reviewArtifactSubtitle,
          style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.x4),
        if (_loading && artifact == null)
          const Center(child: CircularProgressIndicator())
        else if (_error != null && artifact == null)
          _StatusBlock(title: l.reviewLoadError, body: _error!, isError: true)
        else if (artifact == null || artifact.isPending)
          const _PendingBlock()
        else if (artifact.isNotApplicable)
          _StatusBlock(
            title: l.reviewNotApplicableTitle,
            body: l.reviewNotApplicableBody,
            isError: false,
          )
        else if (artifact.isFailed)
          _StatusBlock(
            title: l.reviewFailedTitle,
            body: artifact.failureCode.isEmpty
                ? l.reviewFailedBodyUnknown
                : l.reviewFailedBodyCode(artifact.failureCode),
            isError: true,
          )
        else ...[
          _DiffTextBlock(
            title: l.reviewSourceTitle,
            chunks: artifact.diffChunks,
            getText: (c) => c.sourceText,
            isSourceView: true,
            fallback: _sourceText(context, artifact),
          ),
          const SizedBox(height: AppSpacing.x3),
          _DiffTextBlock(
            title: l.reviewCorrectedTitle,
            chunks: artifact.diffChunks,
            getText: (c) => c.targetText,
            isSourceView: false,
            containerHighlight: true,
            fallback: artifact.correctedTranscriptText,
          ),
          const SizedBox(height: AppSpacing.x3),
          _TextBlock(title: l.reviewModelTitle, body: artifact.modelAnswerText),
          if (artifact.ttsAudio != null) ...[
            const SizedBox(height: AppSpacing.x3),
            ReviewAudioPlaybackCard(
              client: widget.client,
              attemptId: widget.result.id,
              audio: artifact.ttsAudio!,
            ),
          ],
        ],
      ],
    );
  }

  String _sourceText(BuildContext context, AttemptReviewArtifactView a) =>
      a.sourceTranscriptText.isEmpty
          ? (widget.result.transcript ?? AppLocalizations.of(context).reviewSourceFallback)
          : a.sourceTranscriptText;
}

String _readinessLabel(AppLocalizations l, String level) => switch (level) {
  'ready_for_mock' || 'exam_ready' => l.pillReadinessReady,
  'almost_ready'                   => l.pillReadinessAlmost,
  'needs_work'                     => l.pillReadinessNeedsWork,
  'not_ready'                      => l.pillReadinessNotReady,
  _                                => level.toUpperCase(),
};

// ── Criteria checklist ───────────────────────────────────────────────────────

class _CriteriaChecklist extends StatelessWidget {
  const _CriteriaChecklist({required this.criteria});
  final List<CriterionCheckView> criteria;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.checklist_rounded,
                size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              l.resultCriteriaLabel,
              style: AppTypography.labelUppercase.copyWith(
                fontSize: 10,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.x3),
          ...criteria.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: c.met
                        ? AppColors.successContainer
                        : AppColors.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    c.met ? Icons.check_rounded : Icons.close_rounded,
                    size: 11,
                    color: c.met ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.label,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      if (c.comment.isNotEmpty)
                        Text(
                          c.comment,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: AppTypography.labelMedium.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(body, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

/// Renders source or corrected text with diff-chunk highlighting.
///
/// Backend diff kinds: 'unchanged' | 'deleted' | 'inserted' | 'replaced'
///
/// Source view  ([isSourceView]=true):  deleted+replaced → red (errors).
/// Corrected view ([isSourceView]=false): inserted+replaced → green (fixes).
/// Falls back to plain [fallback] string when [chunks] is empty.
class _DiffTextBlock extends StatelessWidget {
  const _DiffTextBlock({
    required this.title,
    required this.chunks,
    required this.getText,
    required this.isSourceView,
    required this.fallback,
    this.containerHighlight = false,
  });

  final String title;
  final List<DiffChunkView> chunks;
  final String Function(DiffChunkView) getText;
  final bool isSourceView;
  final String fallback;
  final bool containerHighlight;

  bool _isError(String kind) =>
      isSourceView && (kind == 'deleted' || kind == 'replaced');

  bool _isFix(String kind) =>
      !isSourceView && (kind == 'inserted' || kind == 'replaced');

  @override
  Widget build(BuildContext context) {
    final bgColor = containerHighlight
        ? AppColors.primaryContainer
        : AppColors.surfaceContainerLow;
    final titleColor = containerHighlight
        ? AppColors.onPrimaryContainer
        : AppColors.onSurfaceVariant;

    Widget body;
    if (chunks.isEmpty) {
      body = Text(fallback, style: AppTypography.bodyMedium);
    } else {
      final spans = <TextSpan>[];
      for (final chunk in chunks) {
        final text = getText(chunk);
        if (text.isEmpty) continue;
        if (_isError(chunk.kind)) {
          spans.add(TextSpan(
            text: text,
            style: AppTypography.bodyMedium.copyWith(
              backgroundColor: AppColors.errorContainer,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ));
        } else if (_isFix(chunk.kind)) {
          spans.add(TextSpan(
            text: text,
            style: AppTypography.bodyMedium.copyWith(
              backgroundColor: AppColors.successContainer,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ));
        } else if (chunk.kind == 'unchanged') {
          spans.add(TextSpan(text: text, style: AppTypography.bodyMedium));
        }
      }
      body = spans.isEmpty
          ? Text(fallback, style: AppTypography.bodyMedium)
          : RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                children: spans,
              ),
            );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(color: bgColor, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelMedium.copyWith(color: titleColor)),
          const SizedBox(height: AppSpacing.x2),
          body,
        ],
      ),
    );
  }
}

class _PendingBlock extends StatelessWidget {
  const _PendingBlock();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.reviewPendingTitle,
                    style: AppTypography.titleSmall.copyWith(color: AppColors.info)),
                const SizedBox(height: AppSpacing.x1),
                Text(l.reviewPendingBody, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.title, required this.body, required this.isError});
  final String title;
  final String body;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorContainer : AppColors.infoContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.titleSmall.copyWith(
                  color: isError ? AppColors.error : AppColors.info)),
          const SizedBox(height: AppSpacing.x2),
          Text(body, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
