import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/providers/subscription_provider.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/app_top_bar.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Full exam simulator intro — subscription-gated.
/// On free tier: shows upgrade prompt instead of start button.
class SimulatorIntroScreen extends ConsumerWidget {
  const SimulatorIntroScreen({super.key});

  static const _sections = [
    ('Đọc hiểu', Icons.menu_book_rounded, '30 câu • 60 phút'),
    ('Nghe hiểu', Icons.headphones_rounded, '25 câu • 40 phút'),
    ('Viết', Icons.draw_rounded, '2 bài • 30 phút'),
    ('Nói', Icons.mic_rounded, '3 câu • 15 phút'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: 'Mô phỏng thi thử',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.dashboard),
      ),
      body: ResponsivePageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero
              Text(
                'Mô phỏng thi thử toàn phần',
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Trải nghiệm 4 kỹ năng theo đúng cấu trúc đề thi Trvalý pobyt thực tế. Nhận phản hồi chi tiết từ AI ngay sau khi hoàn thành.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.x8),

              // Sections overview
              Container(
                padding: const EdgeInsets.all(AppSpacing.x6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: AppSpacing.x2),
                        Text(
                          'CẤU TRÚC ĐỀ THI',
                          style: AppTypography.labelUppercase.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    ..._sections.map((s) {
                      final (label, icon, detail) = s;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.x2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Icon(icon,
                                  color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: AppSpacing.x3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.onBackground,
                                        fontWeight: FontWeight.w600,
                                      )),
                                  Text(detail,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      )),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.outlineVariant, size: 18),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),

              // Premium badge or free info card
              if (!isPremium)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: Text(
                          'Tính năng dành cho thành viên Premium. Nâng cấp để mở khóa toàn bộ simulator.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onPrimaryFixed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.x8),

              // CTA
              if (isPremium)
                AppButton(
                  label: 'Bắt đầu thi thử',
                  onPressed: () => context.push(
                    AppRoutes.simulatorQuestionPath(0),
                    extra: {'totalCount': 4},
                  ),
                )
              else
                Text(
                  'Simulator Premium sẽ quay lại khi luồng đăng ký hoàn chỉnh.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: AppSpacing.x3),
              Center(
                child: TextButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.dashboard),
                  child: Text(
                    'Quay lại',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
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
