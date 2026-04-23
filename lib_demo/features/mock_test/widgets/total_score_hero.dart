import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/widgets/circular_progress_ring.dart';
import 'package:app_czech/features/mock_test/models/mock_test_result.dart';

/// Animated score ring hero shown at the top of the result screen.
/// Uses ScoreHeroRing (CustomPainter conic gradient) — matches exam_result.html.
class TotalScoreHero extends StatelessWidget {
  const TotalScoreHero({super.key, required this.result});
  final MockTestResult result;

  Color get _ringColor => switch (result.band) {
        ScoreBand.excellent => AppColors.scoreExcellent,
        ScoreBand.good => AppColors.primary,
        ScoreBand.fair => AppColors.scoreFair,
        ScoreBand.poor => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final hasOfficialBuckets =
        result.writtenTotal > 0 && result.speakingTotal > 0;
    final hasOfficialResult = result.hasOfficialResult;
    return Column(
      children: [
        // Animated ring
        ScoreHeroRing(
          score: hasOfficialResult ? result.totalScore : 0,
          maxScore: 100,
          color: hasOfficialResult ? _ringColor : AppColors.primary,
        ),
        const SizedBox(height: 20),

        // Congrats / status text
        Text(
          !hasOfficialResult
              ? 'Bài thi đang được chấm theo rule chính thức của đề Trvaly.'
              : result.passed
                  ? 'Xuất sắc! Bạn có thể đỗ kỳ thi.'
                  : 'Cần luyện tập thêm để đạt điểm chuẩn.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Pass/fail chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: !hasOfficialResult
                ? AppColors.primaryFixed
                : result.passed
                    ? const Color(0xFFDCFCE7) // green-100
                    : AppColors.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            !hasOfficialResult
                ? 'ĐANG CHẤM'
                : result.passed
                    ? 'ĐẠT YÊU CẦU'
                    : 'CHƯA ĐẠT',
            style: AppTypography.labelUppercase.copyWith(
              color: !hasOfficialResult
                  ? AppColors.primary
                  : result.passed
                      ? const Color(0xFF166534) // green-800
                      : AppColors.error,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          !hasOfficialResult
              ? 'Điểm và trạng thái đậu/rớt chỉ hiển thị sau khi phần nói/viết chấm xong.'
              : hasOfficialBuckets
                  ? 'Luật đậu chính thức: Viết ${result.writtenPassThreshold}/${result.writtenTotal} và Nói ${result.speakingPassThreshold}/${result.speakingTotal}'
                  : 'Điểm chuẩn tổng: ${result.passThreshold}/100',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
