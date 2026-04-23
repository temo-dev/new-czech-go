import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/storage/prefs_storage.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/mock_test/models/exam_analysis.dart';
import 'package:app_czech/features/mock_test/models/mock_test_result.dart';
import 'package:app_czech/features/mock_test/providers/exam_analysis_provider.dart';
import 'package:app_czech/features/mock_test/providers/exam_result_provider.dart';
import 'package:app_czech/features/mock_test/widgets/overall_insights_card.dart';
import 'package:app_czech/features/mock_test/widgets/question_review_list.dart';
import 'package:app_czech/features/mock_test/widgets/result_cta_section.dart';
import 'package:app_czech/features/mock_test/widgets/skill_breakdown_chart.dart';
import 'package:app_czech/features/mock_test/widgets/total_score_hero.dart';
import 'package:app_czech/shared/utils/skill_labels.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

class MockTestResultScreen extends ConsumerStatefulWidget {
  const MockTestResultScreen({super.key, required this.attemptId});
  final String attemptId;

  @override
  ConsumerState<MockTestResultScreen> createState() =>
      _MockTestResultScreenState();
}

class _MockTestResultScreenState extends ConsumerState<MockTestResultScreen> {
  @override
  void initState() {
    super.initState();
    // Store pending attempt for anonymous linking
    _savePendingAttempt();
  }

  void _savePendingAttempt() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      PrefsStorage.instance.setPendingAttemptId(widget.attemptId);
    }
  }

  bool get _isAuthenticated =>
      Supabase.instance.client.auth.currentSession != null;

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(examResultProvider(widget.attemptId));

    return Scaffold(
      key: const Key('mock_exam_result_screen'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Kết quả bài thi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Trang chủ',
            onPressed: () => context.go(AppRoutes.landing),
          ),
        ],
      ),
      body: resultAsync.when(
        loading: () => const _ResultSkeleton(),
        error: (e, _) => ErrorState(
          message: 'Không thể tải kết quả. Vui lòng thử lại.',
          onRetry: () => ref.invalidate(examResultProvider(widget.attemptId)),
        ),
        data: (result) {
          final examIdAsync =
              ref.watch(attemptExamIdProvider(widget.attemptId));
          return _ResultBody(
            result: result,
            isAuthenticated: _isAuthenticated,
            onSignup: () {
              // attemptId is stored in prefs; signup screen will link it
              context.push(AppRoutes.signup);
            },
            onLogin: () => context.push(AppRoutes.login),
            onRetake: () {
              final examId = examIdAsync.valueOrNull;
              final path = examId != null
                  ? '${AppRoutes.mockTestIntro}?examId=$examId'
                  : AppRoutes.mockTestIntro;
              context.go(path);
            },
            onGoToDashboard: () => context.go(AppRoutes.dashboard),
          );
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ResultBody extends ConsumerWidget {
  const _ResultBody({
    required this.result,
    required this.isAuthenticated,
    required this.onSignup,
    required this.onLogin,
    required this.onRetake,
    required this.onGoToDashboard,
  });

  final MockTestResult result;
  final bool isAuthenticated;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onRetake;
  final VoidCallback onGoToDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(examAnalysisProvider(result.attemptId));
    final analysis = analysisAsync.valueOrNull;
    final isBatchReviewProcessing = analysisAsync.isLoading ||
        analysis?.status == ExamAnalysisStatus.processing;
    final isResultPending = result.aiGradingPending || isBatchReviewProcessing;
    final hasOfficialResult = result.hasOfficialResult;

    return ResponsivePageContainer(
      maxWidth: 640,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isResultPending) ...[
              _PendingResultState(
                result: result,
              ),
            ] else ...[
              // Score hero
              Center(child: TotalScoreHero(result: result)),
              const SizedBox(height: AppSpacing.x6),

              if (hasOfficialResult &&
                  result.writtenTotal > 0 &&
                  result.speakingTotal > 0) ...[
                _OfficialPassRuleCard(result: result),
                const SizedBox(height: AppSpacing.x5),
              ],

              // Skill breakdown
              if (hasOfficialResult && result.sectionScores.isNotEmpty) ...[
                const Text(
                  'Kết quả từng kỹ năng',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.x4),
                SkillBreakdownChart(sectionScores: result.sectionScores),
                const SizedBox(height: AppSpacing.x5),
              ],

              // Weak skills
              if (hasOfficialResult && result.weakSkills.isNotEmpty) ...[
                _WeakSkillsRow(skills: result.weakSkills),
                const SizedBox(height: AppSpacing.x5),
              ],

              if (!hasOfficialResult) ...[
                _PendingOfficialResultCard(result: result),
                const SizedBox(height: AppSpacing.x5),
              ],

              OverallInsightsCard(analysis: analysis),
              const SizedBox(height: AppSpacing.x5),

              // Review section
              QuestionReviewList(
                attemptId: result.attemptId,
                analysis: analysis,
              ),
              const SizedBox(height: AppSpacing.x6),

              // CTA section
              ResultCTASection(
                isAuthenticated: isAuthenticated,
                onSignup: onSignup,
                onLogin: onLogin,
                onRetake: onRetake,
                onGoToDashboard: onGoToDashboard,
              ),
              const SizedBox(height: AppSpacing.x8),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingResultState extends StatelessWidget {
  const _PendingResultState({
    required this.result,
  });

  final MockTestResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.x5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: AppSpacing.x4),
              const Text(
                'AI đang chấm bài thi',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Kết quả sẽ chỉ hiển thị khi phần nói và phần viết được chấm xong theo rule chính thức của bài thi Trvaly A2.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Chuẩn chính thức: Viết ${result.writtenPassThreshold}/${result.writtenTotal} và Nói ${result.speakingPassThreshold}/${result.speakingTotal}.',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
      ],
    );
  }
}

class _PendingOfficialResultCard extends StatelessWidget {
  const _PendingOfficialResultCard({required this.result});

  final MockTestResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kết quả chính thức đang được hoàn tất',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Theo rule bài thi Trvaly A2, trạng thái đậu/rớt chỉ được chốt khi đủ cả phần viết và phần nói. Trong lúc AI còn chấm, app sẽ chưa hiển thị tổng điểm cuối hoặc kết quả từng kỹ năng.',
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            'Chuẩn chính thức: Viết ${result.writtenPassThreshold}/${result.writtenTotal} và Nói ${result.speakingPassThreshold}/${result.speakingTotal}.',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weak skills row ────────────────────────────────────────────────────────────

class _WeakSkillsRow extends StatelessWidget {
  const _WeakSkillsRow({required this.skills});
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kỹ năng cần cải thiện',
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: skills.map((s) {
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Text(
                SkillLabels.forKey(s),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _OfficialPassRuleCard extends StatelessWidget {
  const _OfficialPassRuleCard({required this.result});

  final MockTestResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final writtenPassed = result.writtenScore >= result.writtenPassThreshold;
    final speakingPassed = result.speakingScore >= result.speakingPassThreshold;

    Widget scoreRow({
      required String label,
      required int score,
      required int total,
      required int threshold,
      required bool passed,
    }) {
      final fg = passed ? AppColors.success : AppColors.error;
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: passed
              ? AppColors.successContainer.withValues(alpha: 0.55)
              : AppColors.errorContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fg.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    '$score / $total',
                    style: AppTypography.titleSmall.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Chuẩn $threshold',
              style: AppTypography.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Điều kiện đậu chính thức',
            style: AppTypography.titleSmall,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Bạn cần đạt đồng thời phần viết và phần nói theo chuẩn đề A2 chính thức.',
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          scoreRow(
            label: 'Phần viết (Đọc + Nghe + Viết)',
            score: result.writtenScore,
            total: result.writtenTotal,
            threshold: result.writtenPassThreshold,
            passed: writtenPassed,
          ),
          const SizedBox(height: AppSpacing.x3),
          scoreRow(
            label: 'Phần nói',
            score: result.speakingScore,
            total: result.speakingTotal,
            threshold: result.speakingPassThreshold,
            passed: speakingPassed,
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget block({double h = 16, double w = double.infinity}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x3),
          child: LoadingShimmer(
            child: Container(
              height: h,
              width: w,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.x4),
          Center(
            child: LoadingShimmer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          block(h: 16, w: 180),
          block(h: 20),
          block(h: 20),
          block(h: 20),
          block(h: 20),
          const SizedBox(height: AppSpacing.x4),
          block(h: 100),
          const SizedBox(height: AppSpacing.x4),
          block(h: 56),
          block(h: 44),
        ],
      ),
    );
  }
}
