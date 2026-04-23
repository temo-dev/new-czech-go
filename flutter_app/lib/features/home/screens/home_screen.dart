import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';

/// Home screen: hero header + recent attempts + module/exercise list.
/// Navigation actions are passed as callbacks so this widget stays decoupled
/// from ExerciseScreen (extracted in Phase 5).
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.learnerName,
    required this.modules,
    required this.exercisesByModule,
    required this.recentAttempts,
    required this.onOpenExercise,
    required this.onOpenAttemptExercise,
  });

  final String learnerName;
  final List<ModuleSummary> modules;
  final Map<String, List<ExerciseSummary>> exercisesByModule;
  final List<AttemptResult> recentAttempts;
  final ValueChanged<ExerciseSummary> onOpenExercise;
  final ValueChanged<AttemptResult> onOpenAttemptExercise;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        _HeroCard(learnerName: learnerName),
        const SizedBox(height: AppSpacing.x5),
        if (recentAttempts.isNotEmpty) ...[
          _RecentAttemptsSection(
            attempts: recentAttempts.take(5).toList(),
            exerciseTitleForAttempt: (attempt) =>
                _exerciseTitleForAttempt(attempt, exercisesByModule),
            onOpenAttemptExercise: onOpenAttemptExercise,
          ),
          const SizedBox(height: AppSpacing.x5),
        ],
        for (final module in modules) ...[
          _ModuleCard(
            module: module,
            exercises: exercisesByModule[module.id] ?? const [],
            onOpenExercise: onOpenExercise,
          ),
          const SizedBox(height: AppSpacing.x4),
        ],
      ],
    );
  }
}

String _exerciseTitleForAttempt(
  AttemptResult attempt,
  Map<String, List<ExerciseSummary>> exercisesByModule,
) {
  for (final exercises in exercisesByModule.values) {
    for (final e in exercises) {
      if (e.id == attempt.exerciseId) return e.title;
    }
  }
  return attempt.exerciseId;
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.learnerName});
  final String learnerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.xxlAll,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoPill(label: 'FOCUSED SPEAKING PRACTICE', tone: PillTone.primary),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'A2 Mluvení Sprint',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Xin chào, $learnerName. Ưu tiên sự rõ ràng, nhẹ nhàng, và tiến độ liên tục — như coach bình tĩnh, không phải bài test đáng sợ.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x5),
          const Wrap(
            spacing: AppSpacing.x3,
            runSpacing: AppSpacing.x3,
            children: [
              InfoPill(label: '14 NGÀY', tone: PillTone.primary),
              InfoPill(label: '1 TASK / MÀN HÌNH', tone: PillTone.neutral),
              InfoPill(label: 'FEEDBACK NGAY SAU MỖI LẦN NÓI', tone: PillTone.info),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Module card ───────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.exercises,
    required this.onOpenExercise,
  });

  final ModuleSummary module;
  final List<ExerciseSummary> exercises;
  final ValueChanged<ExerciseSummary> onOpenExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPill(
            label: module.moduleKind.replaceAll('_', ' ').toUpperCase(),
            tone: PillTone.neutral,
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            module.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            '${exercises.length} bài tập',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          for (final exercise in exercises) ...[
            _ExerciseTile(
              exercise: exercise,
              onTap: () => onOpenExercise(exercise),
            ),
            if (exercise != exercises.last)
              const SizedBox(height: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onTap});
  final ExerciseSummary exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.title, style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    exercise.shortInstruction,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  InfoPill(
                    label: exercise.exerciseType.toUpperCase(),
                    tone: PillTone.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent attempts ───────────────────────────────────────────────────────────

class _RecentAttemptsSection extends StatelessWidget {
  const _RecentAttemptsSection({
    required this.attempts,
    required this.exerciseTitleForAttempt,
    required this.onOpenAttemptExercise,
  });

  final List<AttemptResult> attempts;
  final String Function(AttemptResult) exerciseTitleForAttempt;
  final ValueChanged<AttemptResult> onOpenAttemptExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lần tập gần đây', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.x1),
          Text(
            'Xem transcript và feedback để theo dõi tiến bộ.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          for (var i = 0; i < attempts.length; i++) ...[
            _RecentAttemptCard(
              attempt: attempts[i],
              exerciseTitle: exerciseTitleForAttempt(attempts[i]),
              onOpen: () => onOpenAttemptExercise(attempts[i]),
            ),
            if (i < attempts.length - 1) const SizedBox(height: AppSpacing.x3),
          ],
        ],
      ),
    );
  }
}

class _RecentAttemptCard extends StatelessWidget {
  const _RecentAttemptCard({
    required this.attempt,
    required this.exerciseTitle,
    required this.onOpen,
  });

  final AttemptResult attempt;
  final String exerciseTitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final preview = attempt.feedback?.overallSummary.isNotEmpty == true
        ? attempt.feedback!.overallSummary
        : (attempt.transcriptPreview.isNotEmpty
            ? attempt.transcriptPreview
            : _statusCopy(attempt.status));

    final (pillLabel, pillTone) = _readinessPill(attempt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exerciseTitle, style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      _formatTimestamp(attempt.startedAt),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              InfoPill(label: pillLabel, tone: pillTone),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            preview,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              InfoPill(label: attempt.status.toUpperCase(), tone: PillTone.neutral),
              if (attempt.transcriptIsSynthetic)
                const InfoPill(label: 'TRANSCRIPT GIẢ LẬP', tone: PillTone.warning),
              if (attempt.failureCode.isNotEmpty)
                InfoPill(label: 'FAILURE: ${attempt.failureCode.toUpperCase()}', tone: PillTone.error),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          OutlinedButton(
            onPressed: onOpen,
            child: const Text('Mở bài tập'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _statusCopy(String status) => switch (status) {
      'starting'   => 'Chuẩn bị bắt đầu attempt mới.',
      'recording'  => 'Tập trung vào sự rõ ràng và trả lời đúng ý chính.',
      'uploading'  => 'Đang đóng gói bản ghi để gửi lên pipeline.',
      'processing' => 'Hệ thống đang transcript và tổng hợp feedback.',
      'completed'  => 'Feedback đã sẵn sàng. Hãy đọc kết quả và thử lại ngay.',
      'failed'     => 'Attempt gặp lỗi. Bạn có thể thử lại với một lần ghi mới.',
      _            => 'Sẵn sàng cho một lần nói mới.',
    };

(String, PillTone) _readinessPill(AttemptResult attempt) {
  if (attempt.failureCode.isNotEmpty || attempt.status == 'failed') {
    return ('FAILED', PillTone.error);
  }
  return switch (attempt.readinessLevel) {
    'ready_for_mock' => ('SẴN SÀNG', PillTone.success),
    'almost_ready'   => ('GẦN ĐỦ', PillTone.info),
    'needs_work'     => ('CẦN LUYỆN', PillTone.warning),
    'not_ready'      => ('CHƯA SẴN SÀNG', PillTone.error),
    _                => (attempt.status.toUpperCase(), PillTone.neutral),
  };
}

String _formatTimestamp(String startedAt) {
  final dt = DateTime.tryParse(startedAt)?.toLocal();
  if (dt == null) return startedAt;
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m $h:$min';
}
