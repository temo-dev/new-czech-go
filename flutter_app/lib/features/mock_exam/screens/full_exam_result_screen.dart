import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';

/// Shows the result of a full písemná exam session.
class FullExamResultScreen extends StatelessWidget {
  const FullExamResultScreen({super.key, required this.session, required this.test});

  final FullExamSessionView session;
  final MockTest test;

  @override
  Widget build(BuildContext context) {
    final pisemnaMax = 70;
    final ustniMax = 40;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Kết quả bài thi', style: AppTypography.titleMedium),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall result banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.x6),
                decoration: BoxDecoration(
                  color: session.overallPassed
                      ? AppColors.successContainer
                      : session.pisemnaPassed
                          ? AppColors.warningContainer
                          : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      session.overallPassed ? Icons.emoji_events_rounded : Icons.assignment_late_rounded,
                      size: 48,
                      color: session.overallPassed ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    Text(
                      session.overallPassed ? 'ĐẠT' : 'CHƯA ĐẠT',
                      style: AppTypography.headlineLarge.copyWith(
                        color: session.overallPassed ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!session.overallPassed && session.pisemnaPassed)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.x2),
                        child: Text(
                          'Písemná đạt — cần hoàn thành phần nói để có kết quả tổng',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.onTertiaryContainer),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x6),

              // Písemná part
              Text('Phần viết (Písemná)', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.x3),
              _ScoreRow(
                label: 'Điểm đạt được',
                score: session.pisemnaScore,
                maxScore: pisemnaMax,
                passScore: 42,
                passed: session.pisemnaPassed,
              ),
              const SizedBox(height: AppSpacing.x4),

              // Ústní part (if completed)
              if (session.status == 'completed') ...[
                Text('Phần nói (Ústní)', style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.x3),
                _ScoreRow(
                  label: 'Điểm đạt được',
                  score: session.ustniScore,
                  maxScore: ustniMax,
                  passScore: 24,
                  passed: session.ustniPassed,
                ),
                const SizedBox(height: AppSpacing.x4),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.info),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Text(
                          'Phần nói (Ústní) chưa hoàn thành. Làm bài thi nói riêng để có kết quả tổng.',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
              ],

              // Go home
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Về trang chủ', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.passScore,
    required this.passed,
  });
  final String label;
  final int score;
  final int maxScore;
  final int passScore;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: passed ? AppColors.successContainer : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
                Text(
                  '$score / $maxScore  (cần ≥$passScore)',
                  style: AppTypography.titleMedium.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(
              passed ? 'ĐẠT' : 'TRƯỢT',
              style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
