import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/ai_teacher/models/ai_teacher_review.dart';
import 'package:app_czech/features/ai_teacher/providers/ai_teacher_review_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiTeacherInlineReviewCard extends ConsumerWidget {
  const AiTeacherInlineReviewCard({
    super.key,
    required this.request,
    this.pendingLabel = 'AI Teacher đang phân tích...',
    this.emptyMessage = 'Chưa có nhận xét AI Teacher.',
    this.showDetailCta = false,
    this.onTapDetail,
  });

  final AiTeacherReviewRequest request;
  final String pendingLabel;
  final String emptyMessage;
  final bool showDetailCta;
  final VoidCallback? onTapDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responseAsync = ref.watch(aiTeacherReviewEntryProvider(request));

    void retry() =>
        ref.invalidate(aiTeacherReviewEntryProvider(request));

    return responseAsync.when(
      loading: () => _AiTeacherLoadingCard(label: pendingLabel),
      error: (_, __) => _AiTeacherErrorCard(
        message: 'Không thể tải AI Teacher review.',
        onRetry: retry,
      ),
      data: (response) {
        if (response.isPending) {
          return _AiTeacherLoadingCard(
            label: response.message ?? pendingLabel,
          );
        }
        if (response.isError || response.review == null) {
          return _AiTeacherErrorCard(
            message: response.message ?? emptyMessage,
            onRetry: retry,
          );
        }
        return _AiTeacherSummaryCard(
          review: response.review!,
          showDetailCta: showDetailCta,
          onTapDetail: onTapDetail,
        );
      },
    );
  }
}

class AiTeacherDetailView extends StatelessWidget {
  const AiTeacherDetailView({
    super.key,
    required this.review,
    required this.title,
    this.subtitle,
  });

  final AiTeacherReview review;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AiTeacherHeader(
              title: title,
              subtitle: subtitle,
              review: review,
            ),
            const SizedBox(height: AppSpacing.x4),
            if (review.artifacts.shortTips.isNotEmpty) ...[
              _TipsCard(tips: review.artifacts.shortTips),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (review.summary.isNotEmpty ||
                review.reinforcement.isNotEmpty) ...[
              _NarrativeCard(review: review),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (review.criteria.isNotEmpty) ...[
              _CriteriaCard(criteria: review.criteria),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (review.mistakes.isNotEmpty) ...[
              _MistakesCard(mistakes: review.mistakes),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (review.suggestions.isNotEmpty) ...[
              _SuggestionsCard(suggestions: review.suggestions),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (review.artifacts.annotatedSpans.isNotEmpty) ...[
              _AnnotatedTextCard(spans: review.artifacts.annotatedSpans),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (review.artifacts.transcript.isNotEmpty ||
                review.artifacts.transcriptIssues.isNotEmpty) ...[
              _TranscriptCard(artifacts: review.artifacts),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (review.correctedAnswer.isNotEmpty) ...[
              _CorrectedAnswerCard(text: review.correctedAnswer),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiTeacherLoadingCard extends StatelessWidget {
  const _AiTeacherLoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTeacherErrorCard extends StatelessWidget {
  const _AiTeacherErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelSmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.x3),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Thử lại',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiTeacherSummaryCard extends StatelessWidget {
  const _AiTeacherSummaryCard({
    required this.review,
    required this.showDetailCta,
    this.onTapDetail,
  });

  final AiTeacherReview review;
  final bool showDetailCta;
  final VoidCallback? onTapDetail;

  @override
  Widget build(BuildContext context) {
    final score = review.overallScore;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  'AI Teacher',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score điểm',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          if (review.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              review.summary,
              style: AppTypography.bodySmall.copyWith(height: 1.5),
            ),
          ],
          if (review.reinforcement.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            _InfoPill(
              color: AppColors.success,
              icon: Icons.check_circle_outline,
              text: review.reinforcement,
            ),
          ],
          if (review.mistakes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            ...review.mistakes.take(2).map(
                  (mistake) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                    child: _InfoPill(
                      color: AppColors.error,
                      icon: Icons.cancel_outlined,
                      text: '${mistake.title}: ${mistake.explanation}',
                    ),
                  ),
                ),
          ],
          if (review.suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            ...review.suggestions.take(2).map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                    child: _InfoPill(
                      color: AppColors.warning,
                      icon: Icons.lightbulb_outline_rounded,
                      text: suggestion.detail,
                    ),
                  ),
                ),
          ],
          if (showDetailCta && onTapDetail != null) ...[
            const SizedBox(height: AppSpacing.x2),
            GestureDetector(
              onTap: onTapDetail,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xem nhận xét chi tiết',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiTeacherHeader extends StatelessWidget {
  const _AiTeacherHeader({
    required this.title,
    required this.review,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final AiTeacherReview review;

  @override
  Widget build(BuildContext context) {
    final score = review.overallScore;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (score ?? 0) / 100,
                  strokeWidth: 6,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                  color: _scoreColor(score ?? 0),
                ),
                Text(
                  '${score ?? '--'}',
                  style: AppTypography.titleLarge.copyWith(
                    color: _scoreColor(score ?? 0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  subtitle ?? _verdictSubtitle(review.verdict),
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.review});

  final AiTeacherReview review;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Nhận xét tổng quan',
      icon: Icons.record_voice_over_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.summary.isNotEmpty)
            Text(
              review.summary,
              style: AppTypography.bodyMedium.copyWith(height: 1.6),
            ),
          if (review.reinforcement.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            _InfoPill(
              color: AppColors.success,
              icon: Icons.check_circle_outline,
              text: review.reinforcement,
            ),
          ],
        ],
      ),
    );
  }
}

class _CriteriaCard extends StatelessWidget {
  const _CriteriaCard({required this.criteria});

  final List<AiTeacherCriterion> criteria;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Tiêu chí chấm',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: criteria.map((criterion) {
          final score = criterion.score?.round();
          final maxScore = criterion.maxScore?.round();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        criterion.title,
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (criterion.feedback.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          criterion.feedback,
                          style: AppTypography.bodySmall.copyWith(height: 1.5),
                        ),
                      ],
                      if (criterion.tip.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          criterion.tip,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (score != null && maxScore != null)
                  Text(
                    '$score/$maxScore',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MistakesCard extends StatelessWidget {
  const _MistakesCard({required this.mistakes});

  final List<AiTeacherMistake> mistakes;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Điểm sai cần sửa',
      icon: Icons.error_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mistakes.map((mistake) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mistake.title,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  mistake.explanation,
                  style: AppTypography.bodySmall.copyWith(height: 1.5),
                ),
                if (mistake.correction.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Sửa gợi ý: ${mistake.correction}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                if (mistake.tip.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    mistake.tip,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.suggestions});

  final List<AiTeacherSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Gợi ý cải thiện',
      icon: Icons.lightbulb_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: suggestions.map((suggestion) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: _InfoPill(
              color: AppColors.warning,
              icon: Icons.arrow_right_alt_rounded,
              text: suggestion.detail,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnnotatedTextCard extends StatelessWidget {
  const _AnnotatedTextCard({required this.spans});

  final List<AiTeacherAnnotatedSpan> spans;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Đoạn cần chú ý',
      icon: Icons.draw_outlined,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: spans.map((span) {
          final color =
              span.hasIssue ? AppColors.errorContainer : AppColors.surface;
          final borderColor = span.hasIssue
              ? AppColors.error.withValues(alpha: 0.25)
              : AppColors.outlineVariant;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2,
              vertical: AppSpacing.x1 + 2,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              span.text,
              style: AppTypography.bodySmall.copyWith(height: 1.4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.artifacts});

  final AiTeacherArtifacts artifacts;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Bản ghi lời nói',
      icon: Icons.mic_none_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (artifacts.transcript.isNotEmpty)
            RichText(
              text: TextSpan(
                children: _buildTranscriptSpans(),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurface,
                  height: 1.6,
                ),
              ),
            ),
          if (artifacts.transcriptIssues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            ...artifacts.transcriptIssues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                child: _InfoPill(
                  color: _issueColor(issue.issue),
                  icon: _issueIcon(issue.issue),
                  text:
                      '${issue.token}${issue.suggestion != null ? ' -> ${issue.suggestion}' : ''}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _buildTranscriptSpans() {
    final issueMap = <String, AiTeacherTranscriptIssue>{};
    for (final issue in artifacts.transcriptIssues) {
      final token = _normalizeTranscriptToken(issue.token);
      if (token.isNotEmpty) {
        issueMap[token] = issue;
      }
    }

    return RegExp(r'\S+|\s+')
        .allMatches(artifacts.transcript)
        .map((match) => match.group(0) ?? '')
        .map((segment) {
          if (segment.trim().isEmpty) {
            return TextSpan(text: segment);
          }

          final normalized = _normalizeTranscriptToken(segment);
          final issue = issueMap[normalized];
          if (issue == null) {
            return TextSpan(text: segment);
          }

          return TextSpan(
            text: segment,
            style: AppTypography.bodyMedium.copyWith(
              color: _issueColor(issue.issue),
              fontWeight: FontWeight.w700,
              backgroundColor:
                  _issueColor(issue.issue).withValues(alpha: 0.12),
              height: 1.6,
            ),
          );
        })
        .toList();
  }

  String _normalizeTranscriptToken(String value) {
    return value
        .replaceAll(RegExp(r'^[\.,!?;:"()\[\]{}]+'), '')
        .replaceAll(RegExp(r'[\.,!?;:"()\[\]{}]+$'), '')
        .trim()
        .toLowerCase();
  }

  Color _issueColor(String? issue) {
    switch (issue) {
      case 'grammar':
        return AppColors.warning;
      case 'vocabulary':
        return AppColors.secondary;
      default:
        return AppColors.error;
    }
  }

  IconData _issueIcon(String? issue) {
    switch (issue) {
      case 'grammar':
        return Icons.rule_folder_outlined;
      case 'vocabulary':
        return Icons.translate_outlined;
      default:
        return Icons.hearing_outlined;
    }
  }
}

class _CorrectedAnswerCard extends StatelessWidget {
  const _CorrectedAnswerCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Bản sửa gợi ý',
      icon: Icons.edit_note_outlined,
      child: Text(
        text,
        style: AppTypography.bodyMedium.copyWith(height: 1.6),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Mẹo ngắn để luyện tiếp',
      icon: Icons.tips_and_updates_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tips
            .map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                child: _InfoPill(
                  color: AppColors.warning,
                  icon: Icons.lightbulb_outline_rounded,
                  text: tip,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.x2),
              Text(
                title,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}

String _verdictSubtitle(AiTeacherReviewVerdict verdict) {
  switch (verdict) {
    case AiTeacherReviewVerdict.correct:
      return 'Bạn đang làm tốt. Hãy giữ cách trả lời này.';
    case AiTeacherReviewVerdict.partial:
      return 'Bài làm đã có ý đúng, nhưng vẫn còn điểm cần chỉnh.';
    case AiTeacherReviewVerdict.needsRetry:
      return 'Bạn cần làm lại để AI có thể chấm đúng theo yêu cầu.';
    case AiTeacherReviewVerdict.incorrect:
      return 'Hãy xem kỹ các lỗi chính và gợi ý sửa bên dưới.';
  }
}

Color _scoreColor(int score) {
  if (score >= 85) return AppColors.scoreExcellent;
  if (score >= 70) return AppColors.scoreGood;
  if (score >= 50) return AppColors.scoreFair;
  return AppColors.scorePoor;
}
