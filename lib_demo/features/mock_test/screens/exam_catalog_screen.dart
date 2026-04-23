import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';
import '../models/exam_meta.dart';
import '../providers/exam_list_provider.dart';

/// Catalog of all active exam papers — the landing screen for the "Luyện đề" tab.
class ExamCatalogScreen extends ConsumerWidget {
  const ExamCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examListProvider);

    return Scaffold(
      primary: false,
      backgroundColor: AppColors.surface,
      body: examsAsync.when(
        loading: () => const _CatalogSkeleton(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.onSurfaceVariant),
              const SizedBox(height: AppSpacing.x4),
              const Text(
                'Không tải được danh sách đề thi.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x4),
              TextButton.icon(
                onPressed: () => ref.invalidate(examListProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (exams) => SingleChildScrollView(
          child: ResponsivePageContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Đề thi thử', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.x2),
                  const Text(
                    'Chọn một bộ đề để bắt đầu luyện tập.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  if (exams.isEmpty)
                    const _EmptyCatalog()
                  else
                    ...exams.map(
                      (exam) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                        child: _ExamCard(exam: exam),
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

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});
  final ExamMeta exam;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
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
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(Icons.assignment_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.title,
                  style: AppTypography.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${exam.durationMinutes} phút',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
              textStyle: AppTypography.labelMedium,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.smAll,
              ),
            ),
            onPressed: () => context
                .push('${AppRoutes.mockTestIntro}?examId=${exam.id}'),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.x10),
        child: Text(
          'Chưa có đề thi nào.',
          style: AppTypography.bodyMedium,
        ),
      ),
    );
  }
}

class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  Widget _block({double h = 16, double? w}) => LoadingShimmer(
        child: Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: AppRadius.smAll,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePageContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _block(h: 22, w: 120),
              const SizedBox(height: AppSpacing.x5),
              ...List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: LoadingShimmer(
                    child: Container(
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: AppRadius.mdAll,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
