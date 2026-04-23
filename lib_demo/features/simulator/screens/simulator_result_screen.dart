import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/utils/skill_labels.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Simulator result screen — shows score summary after completing the full sim.
///
/// extras: `{
///   'score': int,
///   'totalQuestions': int,
///   'correct': int,
///   'sectionScores': Map<String, int>,
/// }`
class SimulatorResultScreen extends StatelessWidget {
  const SimulatorResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final score = extra?['score'] as int? ?? 0;
    final totalQuestions = extra?['totalQuestions'] as int? ?? 0;
    final correct = extra?['correct'] as int? ?? 0;
    final sectionScores =
        (extra?['sectionScores'] as Map?)?.cast<String, int>() ?? {};

    final passed = score >= 60;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context),
      body: ResponsivePageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScoreHero(score: score, passed: passed),
              const SizedBox(height: AppSpacing.x6),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Câu đúng',
                      value: '$correct',
                      sub: 'trên $totalQuestions câu',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: _StatCard(
                      label: 'Độ chính xác',
                      value:
                          '${totalQuestions > 0 ? (correct / totalQuestions * 100).round() : 0}%',
                      sub: passed ? 'Đạt yêu cầu' : 'Cần cải thiện',
                      color: passed ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x6),

              if (sectionScores.isNotEmpty) ...[
                Text(
                  'KẾT QUẢ TỪNG KỸ NĂNG',
                  style: AppTypography.labelUppercase.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                ...sectionScores.entries.map((e) {
                  final pct = e.value / 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                    child: _SkillBar(
                      label: SkillLabels.forKey(e.key),
                      score: e.value,
                      progress: pct.clamp(0.0, 1.0),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.x4),
              ],

              Container(
                padding: const EdgeInsets.all(AppSpacing.x4),
                decoration: BoxDecoration(
                  color: passed
                      ? AppColors.successContainer
                      : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  passed
                      ? 'Chúc mừng! Bạn đã vượt qua ngưỡng đạt yêu cầu. Tiếp tục duy trì phong độ luyện tập.'
                      : 'Bạn chưa đạt yêu cầu lần này. Hãy ôn luyện thêm các kỹ năng còn yếu và thử lại.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: passed ? AppColors.success : AppColors.error,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x8),

              AppButton(
                label: 'Về trang chủ',
                onPressed: () => context.go(AppRoutes.dashboard),
              ),
              const SizedBox(height: AppSpacing.x3),
              AppButton(
                label: 'Thử lại',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.simulatorIntro),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            bottom: BorderSide(color: AppColors.outlineVariant),
          ),
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
                Text(
                  'Kết quả mô phỏng',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.onBackground,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  color: AppColors.onSurfaceVariant,
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Score Hero ────────────────────────────────────────────────────────────────

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.score, required this.passed});
  final int score;
  final bool passed;

  Color get _color => passed ? AppColors.success : AppColors.error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: _color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: _color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(_color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$score',
                style: AppTypography.headlineLarge.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            passed ? 'Đạt yêu cầu' : 'Chưa đạt',
            style: AppTypography.headlineSmall.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            passed
                ? 'Điểm của bạn đạt ngưỡng thi Trvalý pobyt.'
                : 'Cần tối thiểu 60 điểm để đạt yêu cầu.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

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
          Text(label,
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.x1),
          Text(value,
              style: AppTypography.headlineSmall.copyWith(
                  color: color, fontWeight: FontWeight.w700)),
          Text(sub,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Skill Bar ─────────────────────────────────────────────────────────────────

class _SkillBar extends StatelessWidget {
  const _SkillBar({
    required this.label,
    required this.score,
    required this.progress,
  });

  final String label;
  final int score;
  final double progress;

  Color get _color {
    if (score >= 85) return AppColors.scoreExcellent;
    if (score >= 70) return AppColors.scoreGood;
    if (score >= 50) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.onBackground)),
            Text('$score%',
                style: AppTypography.labelMedium.copyWith(
                    color: _color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: AppSpacing.x1),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(_color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
