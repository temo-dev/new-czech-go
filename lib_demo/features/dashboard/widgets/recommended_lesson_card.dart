import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/dashboard/models/dashboard_models.dart';

/// Large primary-bg bento hero card — "Bài học hôm nay".
/// Matches Stitch: bg-primary rounded-[28px] p-8 text-white, full-width,
/// badge "Gợi ý dành cho bạn", serif italic title, "Học ngay" white button.
class RecommendedLessonCard extends StatelessWidget {
  const RecommendedLessonCard({super.key, required this.lesson});

  final RecommendedLesson lesson;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.courseDetailPath(lesson.courseId),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background glow
            Positioned(
              right: -24,
              bottom: -24,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10,
                ),
              ),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: Icon(
                Icons.menu_book_rounded,
                size: 80,
                color: Colors.white.withOpacity(0.08),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'GỢI Ý DÀNH CHO BẠN',
                    style: AppTypography.labelUppercase.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  lesson.lessonTitle,
                  style: AppTypography.headlineMedium.copyWith(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

                // CTA row
                Row(
                  children: [
                    // Learn now button
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Học ngay',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.play_arrow_rounded,
                              color: AppColors.primary, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Duration
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            color: Colors.white.withOpacity(0.8), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '15 phút',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
