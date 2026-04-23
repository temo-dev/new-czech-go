import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Full-page explanation screen after completing an exercise.
///
/// extras: `{
///   'isCorrect': bool,
///   'explanation': String,
///   'correctAnswer': String?,
///   'userAnswer': String?,
/// }`
class ExerciseExplanationScreen extends StatelessWidget {
  const ExerciseExplanationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final isCorrect = extra?['isCorrect'] as bool? ?? false;
    final explanation = extra?['explanation'] as String? ?? '';
    final correctAnswer = extra?['correctAnswer'] as String?;
    final userAnswer = extra?['userAnswer'] as String?;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context, isCorrect),
      body: ResponsivePageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ResultBanner(isCorrect: isCorrect),
              const SizedBox(height: AppSpacing.x6),
              if (correctAnswer != null) ...[
                _AnswerCard(
                  label: 'ĐÁP ÁN ĐÚNG',
                  text: correctAnswer,
                  color: AppColors.success,
                  bgColor: AppColors.successContainer,
                ),
                const SizedBox(height: AppSpacing.x3),
              ],
              if (userAnswer != null && !isCorrect) ...[
                _AnswerCard(
                  label: 'CÂU TRẢ LỜI CỦA BẠN',
                  text: userAnswer,
                  color: AppColors.error,
                  bgColor: AppColors.errorContainer,
                ),
                const SizedBox(height: AppSpacing.x3),
              ],
              if (explanation.isNotEmpty) ...[
                _ExplanationCard(explanation: explanation),
                const SizedBox(height: AppSpacing.x6),
              ],
              AppButton(
                label: 'Tiếp tục',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(AppRoutes.practiceIntro),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isCorrect) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            bottom: BorderSide(color: AppColors.outlineVariant),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onBackground.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x2,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.onSurfaceVariant,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go(AppRoutes.practiceIntro),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  'Giải thích đáp án',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Result Banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.isCorrect});
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x6),
      decoration: BoxDecoration(
        color: isCorrect ? AppColors.successContainer : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.error.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCorrect ? Icons.verified_rounded : Icons.cancel_rounded,
              color: isCorrect ? AppColors.success : AppColors.error,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? 'Chính xác!' : 'Chưa đúng',
                  style: AppTypography.titleMedium.copyWith(
                    color: isCorrect ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isCorrect
                      ? 'Bạn đã trả lời đúng câu này.'
                      : 'Xem lại đáp án và giải thích bên dưới.',
                  style: AppTypography.bodySmall.copyWith(
                    color: isCorrect
                        ? AppColors.success.withOpacity(0.8)
                        : AppColors.error.withOpacity(0.8),
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

// ── Answer Card ───────────────────────────────────────────────────────────────

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.label,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final String text;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelUppercase.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Explanation Card ──────────────────────────────────────────────────────────

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.explanation});
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'GIẢI THÍCH',
                style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            explanation,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onBackground,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
