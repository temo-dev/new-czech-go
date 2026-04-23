import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/diff_block.dart';
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
  });

  final ApiClient client;
  final AttemptResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final feedback = result.feedback;

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
              Text('Kết quả', style: AppTypography.titleLarge),
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
                    'TRANSCRIPT GIẢ LẬP',
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
            Text('Transcript của bạn', style: AppTypography.titleSmall),
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
                feedback.readinessLevel.toUpperCase(),
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
                title: 'Điểm mạnh',
                items: feedback.strengths,
                tone: FeedbackTone.success,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (feedback.improvements.isNotEmpty) ...[
              FeedbackCard(
                title: 'Cần cải thiện',
                items: feedback.improvements,
                tone: FeedbackTone.primary,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (feedback.retryAdvice.isNotEmpty) ...[
              FeedbackCard(
                title: 'Lời khuyên cho lần sau',
                items: feedback.retryAdvice,
                tone: FeedbackTone.info,
              ),
              const SizedBox(height: AppSpacing.x3),
            ],
            if (feedback.sampleAnswer.isNotEmpty) ...[
              Text('Câu trả lời mẫu', style: AppTypography.titleSmall),
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

          // Retry CTA
          PrimaryButton(
            label: 'Thử lại bài này',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sửa & luyện theo mẫu', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Bản gốc, bản đã sửa, và bản mẫu để shadow theo.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        if (_loading && artifact == null)
          const Center(child: CircularProgressIndicator())
        else if (_error != null && artifact == null)
          _StatusBlock(
            title: 'Không tải được review',
            body: _error!,
            isError: true,
          )
        else if (artifact == null || artifact.isPending)
          const _StatusBlock(
            title: 'Đang tạo bản sửa và audio mẫu...',
            body: 'Bạn vẫn có thể đọc feedback phía trên trong lúc chờ.',
            isError: false,
          )
        else if (artifact.isFailed)
          _StatusBlock(
            title: 'Review artifact gặp lỗi',
            body: artifact.failureCode.isEmpty
                ? 'Backend chưa tạo được bản sửa.'
                : 'failure_code: ${artifact.failureCode}',
            isError: true,
          )
        else ...[
          _TextBlock(title: 'Transcript của bạn', body: _sourceText(artifact)),
          const SizedBox(height: AppSpacing.x3),
          _TextBlock(
            title: 'Bạn nên nói',
            body: artifact.correctedTranscriptText,
            highlight: true,
          ),
          const SizedBox(height: AppSpacing.x3),
          _TextBlock(title: 'Bản mẫu để shadow', body: artifact.modelAnswerText),
          if (artifact.diffChunks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            DiffBlock(chunks: artifact.diffChunks),
          ],
        ],
      ],
    );
  }

  String _sourceText(AttemptReviewArtifactView a) =>
      a.sourceTranscriptText.isEmpty
          ? (widget.result.transcript ?? 'Transcript chưa sẵn sàng.')
          : a.sourceTranscriptText;
}

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
