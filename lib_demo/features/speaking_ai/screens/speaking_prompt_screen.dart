import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Entry screen for a speaking exercise.
/// Receives [prompt], [questionId], [exerciseId], and [lessonId] via GoRouter extra.
class SpeakingPromptScreen extends StatelessWidget {
  const SpeakingPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final prompt = extra?['prompt'] as String? ?? '';
    final questionId = extra?['questionId'] as String? ?? '';
    final exerciseId = extra?['exerciseId'] as String? ??
        (questionId.isNotEmpty ? questionId : '');
    final lessonId = extra?['lessonId'] as String? ?? '';
    final lessonBlockId = extra?['lessonBlockId'] as String? ?? '';
    final courseId = extra?['courseId'] as String? ?? '';
    final moduleId = extra?['moduleId'] as String? ?? '';

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Luyện nói')),
      body: SingleChildScrollView(
        child: ResponsivePageContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon header
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),

                // Title
                const Text(
                  'Bài tập nói',
                  style: AppTypography.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Đọc đề bài, chuẩn bị rồi nhấn Bắt đầu để ghi âm.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x8),

                // Prompt card
                if (prompt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x5),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            Text(
                              'Đề bài',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        Text(
                          prompt,
                          style: AppTypography.bodyLarge.copyWith(height: 1.6),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.x6),

                // Tips
                _TipRow(
                  icon: Icons.volume_up_rounded,
                  text: 'Nói rõ ràng, đủ to để micro ghi lại.',
                ),
                const SizedBox(height: AppSpacing.x2),
                _TipRow(
                  icon: Icons.timer_rounded,
                  text: 'Không giới hạn thời gian — ghi đến khi hoàn thành.',
                ),
                const SizedBox(height: AppSpacing.x2),
                _TipRow(
                  icon: Icons.replay_rounded,
                  text: 'Có thể ghi lại nếu chưa hài lòng.',
                ),

                const SizedBox(height: AppSpacing.x8),

                AppButton(
                  label: 'Bắt đầu ghi âm',
                  icon: Icons.mic_rounded,
                  onPressed: () => context.push(
                    AppRoutes.speakingRecording,
                    extra: {
                      'prompt': prompt,
                      'questionId': questionId,
                      'exerciseId': exerciseId,
                      'lessonId': lessonId,
                      'lessonBlockId': lessonBlockId,
                      'courseId': courseId,
                      'moduleId': moduleId,
                    },
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

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
