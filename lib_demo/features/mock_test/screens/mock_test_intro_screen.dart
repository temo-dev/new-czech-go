import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import '../models/exam_meta.dart';
import '../providers/mock_exam_meta_provider.dart';

class MockTestIntroScreen extends ConsumerWidget {
  const MockTestIntroScreen({super.key, this.examId});

  /// Specific exam to load. Null → first active exam (guest path from landing).
  final String? examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(examMetaProvider(examId));
    final creatorState = ref.watch(examAttemptCreatorProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.landing),
        ),
        title: Text(
          'Czech Proficiency',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.onBackground,
          ),
        ),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      body: metaAsync.when(
        loading: () => const _IntroSkeleton(),
        error: (e, _) => ErrorState(
          message: 'Lỗi: $e',
          onRetry: () => ref.invalidate(examMetaProvider(examId)),
        ),
        data: (meta) => _IntroBody(
          meta: meta,
          isStarting: creatorState is AsyncLoading,
          onStart: () async {
            final id = await ref
                .read(examAttemptCreatorProvider.notifier)
                .create(meta.id, meta.durationMinutes);
            if (id != null && context.mounted) {
              context.push(AppRoutes.mockTestQuestionPath(id));
            }
          },
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _IntroBody extends StatelessWidget {
  const _IntroBody({
    required this.meta,
    required this.isStarting,
    required this.onStart,
  });

  final ExamMeta meta;
  final bool isStarting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero headline
              Text(
                meta.title.isNotEmpty ? meta.title : 'Thi thử miễn phí',
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.onBackground,
                  fontSize: 36,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Prepare yourself with a realistic exam simulation. Find out your current level and get AI feedback to pass Trvalý faster.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // ── Test Overview card ─────────────────────────────────────────
              _SaharaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Test Overview',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.onBackground,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _OverviewItem(
                            icon: Icons.schedule_rounded,
                            label: 'Duration',
                            value: '${meta.durationMinutes} minutes',
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _OverviewItem(
                            icon: Icons.checklist_rounded,
                            label: 'Skills',
                            value: meta.sections.map((s) => s.label).join(', '),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Exam Conditions card ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_rounded,
                            color: AppColors.tertiary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Exam Conditions',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.onBackground,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '"Hãy chọn nơi yên tĩnh và chuẩn bị tai nghe. Bài thi sẽ diễn ra liên tục để mô phỏng áp lực thực tế."',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onTertiaryFixed,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Benefits card ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benefits',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.onBackground,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _BenefitRow('Realistic exam format'),
                    _BenefitRow('AI score prediction'),
                    _BenefitRow('Detailed mistake analysis'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── What you'll get card ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "WHAT YOU'LL GET",
                      style: AppTypography.labelUppercase.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A comprehensive report with your probability of passing and areas to improve.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // ── CTAs ──────────────────────────────────────────────────────
              AppButton(
                key: const Key('mock_exam_start_button'),
                label: 'Bắt đầu thi thử ngay',
                icon: Icons.book,
                loading: isStarting,
                onPressed: isStarting ? null : onStart,
                size: AppButtonSize.lg,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.canPop() ? context.pop() : null,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(
                    'QUAY LẠI',
                    style: AppTypography.labelUppercase.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                  ),
                ),
              ),

              // Decorative image placeholder
              const SizedBox(height: 20),
              Container(
                height: 200,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    image: DecorationImage(
                        image: AssetImage('assets/images/banner01.png'),
                        fit: BoxFit.contain)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SaharaCard extends StatelessWidget {
  const _SaharaCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A302A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onBackground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onBackground,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _IntroSkeleton extends StatelessWidget {
  const _IntroSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block({double h = 16, double w = double.infinity}) => LoadingShimmer(
          child: Container(
            height: h,
            width: w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(h: 36),
          const SizedBox(height: 12),
          block(h: 20, w: 280),
          const SizedBox(height: 48),
          block(h: 140),
          const SizedBox(height: 24),
          block(h: 100),
          const SizedBox(height: 24),
          block(h: 100),
        ],
      ),
    );
  }
}
