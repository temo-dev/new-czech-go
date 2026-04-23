import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/providers/course_providers.dart';
import 'package:app_czech/features/course/widgets/course_skeleton.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Catalog listing all available courses.
class CourseCatalogScreen extends ConsumerWidget {
  const CourseCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseListProvider);

    return Scaffold(
      primary: false,
      body: coursesAsync.when(
        loading: () => const CourseSkeleton(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: AppSpacing.x4),
              const Text(
                'Không tải được danh sách khóa học.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x4),
              AppButton(
                label: 'Thử lại',
                fullWidth: false,
                icon: Icons.refresh_rounded,
                onPressed: () => ref.refresh(courseListProvider),
              ),
            ],
          ),
        ),
        data: (courses) => SingleChildScrollView(
          child: ResponsivePageContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
              child: courses.isEmpty
                  ? _EmptyCatalog()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Tất cả khóa học', style: AppTypography.titleMedium),
                        const SizedBox(height: AppSpacing.x4),
                        ...courses.map(
                          (c) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.x3),
                            child: _CourseTile(course: c),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.course});
  final Map<String, dynamic> course;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skill = course['skill'] as String? ?? '';
    final isPremium = course['is_premium'] as bool? ?? false;
    final skillColor = _skillColor(skill);

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.courseDetailPath(course['id'] as String),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: skillColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(_skillIcon(skill), color: skillColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course['title'] as String? ?? '',
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (course['description'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      course['description'] as String,
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            if (isPremium)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.xpGold.withValues(alpha: 0.15),
                  borderRadius: AppRadius.fullAll,
                ),
                child: Text(
                  'Pro',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.xpGold,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Color _skillColor(String skill) => switch (skill) {
        'reading' => AppColors.info,
        'listening' => AppColors.success,
        'writing' => AppColors.warning,
        'speaking' => AppColors.tertiary,
        _ => AppColors.primary,
      };

  IconData _skillIcon(String skill) => switch (skill) {
        'reading' => Icons.menu_book_rounded,
        'listening' => Icons.headphones_rounded,
        'writing' => Icons.edit_rounded,
        'speaking' => Icons.mic_rounded,
        _ => Icons.school_rounded,
      };
}

class _EmptyCatalog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          children: [
            Icon(
              Icons.school_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.x4),
            const Text(
              'Khóa học đang được cập nhật.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
