import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/feedback_card.dart';
import '../../../shared/widgets/audio_playback_card.dart';
import '../../../shared/widgets/primary_button.dart';

/// Shows feedback, review artifact, and retry CTA after an attempt completes.
class ResultCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final feedback = result.feedback;
    final l = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.resultTitle, style: AppTypography.titleLarge),
              const Spacer(),
              if (result.transcriptIsSynthetic)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    l.pillSyntheticTranscript,
                    style: AppTypography.labelUppercase.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),

          // Transcript
          if (result.transcript?.isNotEmpty == true) ...[
            Text(l.resultTranscriptTitle, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.x2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.x4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.mdAll,
              ),
              child: Text(
                result.transcript!,
                style: AppTypography.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
          ],

          // Audio playback
          if (result.audio != null) ...[
            AttemptAudioPlaybackCard(
              client: client,
              attemptId: result.id,
              audio: result.audio!,
            ),
            const SizedBox(height: AppSpacing.x4),
          ],

          // Feedback
          if (feedback != null) ...[
            if (feedback.readinessLevel.isNotEmpty) ...[
              Text(
                _readinessLabel(l, feedback.readinessLevel),
                style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
            if (feedback.overallSummary.isNotEmpty) ...[
              Text(feedback.overallSummary, style: AppTypography.bodyLarge),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (feedback.strengths.isNotEmpty) ...[
              FeedbackCard(
                title: l.resultStrengthsTitle,
                items: feedback.strengths,
                tone: FeedbackTone.success,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (feedback.improvements.isNotEmpty) ...[
              FeedbackCard(
                title: l.resultImprovementsTitle,
                items: feedback.improvements,
                tone: FeedbackTone.primary,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (feedback.retryAdvice.isNotEmpty) ...[
              FeedbackCard(
                title: l.resultRetryAdviceTitle,
                items: feedback.retryAdvice,
                tone: FeedbackTone.info,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (feedback.sampleAnswer.isNotEmpty) ...[
              Text(l.resultSampleAnswerTitle, style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.x2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.x4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  feedback.sampleAnswer,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
            ],
          ],

          // Review artifact section
          if (result.status == 'completed') ...[
            const Divider(),
            const SizedBox(height: AppSpacing.x4),
            _ReviewArtifactSection(client: client, result: result),
            const SizedBox(height: AppSpacing.x4),
          ],

          // Retry + Next CTA
          if (onNext != null) ...[
            PrimaryButton(
              label: l.resultNextExerciseCta,
              icon: Icons.arrow_forward,
              onPressed: onNext,
            ),
            const SizedBox(height: AppSpacing.x3),
            SecondaryButton(
              label: l.resultRetryCta,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ] else
            PrimaryButton(
              label: l.resultRetryCta,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

// ── Review artifact ────────────────────────────────────────────────────────────

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
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        if (_loading && artifact == null)
          const Center(child: CircularProgressIndicator())
        else if (_error != null && artifact == null)
          _StatusBlock(
            title: l.reviewLoadError,
            body: _error!,
            isError: true,
          )
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
          _TextBlock(title: l.reviewSourceTitle, body: _sourceText(context, artifact)),
          const SizedBox(height: AppSpacing.x3),
          _TextBlock(
            title: l.reviewCorrectedTitle,
            body: artifact.correctedTranscriptText,
            highlight: true,
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
          ? (widget.result.transcript ??
              AppLocalizations.of(context).reviewSourceFallback)
          : a.sourceTranscriptText;
}

String _readinessLabel(AppLocalizations l, String level) => switch (level) {
      'ready_for_mock' || 'exam_ready' => l.pillReadinessReady,
      'almost_ready' => l.pillReadinessAlmost,
      'needs_work' => l.pillReadinessNeedsWork,
      'not_ready' => l.pillReadinessNotReady,
      _ => level.toUpperCase(),
    };

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.title,
    required this.body,
    this.highlight = false,
  });
  final String title;
  final String body;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryFixed : AppColors.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelMedium.copyWith(
              color: highlight ? AppColors.onPrimaryFixed : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(body, style: AppTypography.bodyMedium),
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
                Text(
                  l.reviewPendingTitle,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  l.reviewPendingBody,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.title,
    required this.body,
    required this.isError,
  });
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
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              color: isError ? AppColors.error : AppColors.info,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(body, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
