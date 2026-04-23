import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import '../models/exam_meta.dart';

/// Full-screen card shown between exam sections.
class SectionTransitionCard extends StatelessWidget {
  const SectionTransitionCard({
    super.key,
    required this.completedSection,
    required this.nextSection,
    required this.onContinue,
  });

  final SectionMeta completedSection;
  final SectionMeta nextSection;
  final VoidCallback onContinue;

  IconData _iconFor(String skill) => switch (skill) {
        'reading' => Icons.menu_book_outlined,
        'listening' => Icons.headphones_outlined,
        'writing' => Icons.edit_note_outlined,
        'speaking' => Icons.mic_outlined,
        _ => Icons.quiz_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Completed badge
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.scoreExcellent, size: 32),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Hoàn thành phần: ${completedSection.label}',
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x8),

              // Next section info
              Container(
                padding: const EdgeInsets.all(AppSpacing.x4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text('Phần tiếp theo',
                        style: AppTypography.labelSmall
                            .copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.x3),
                    Icon(_iconFor(nextSection.skill),
                        color: AppColors.primary, size: 32),
                    const SizedBox(height: AppSpacing.x2),
                    Text(nextSection.label,
                        style: AppTypography.titleSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      '${nextSection.questionCount} câu'
                      '${nextSection.sectionDurationMinutes != null ? ' · ${nextSection.sectionDurationMinutes} phút' : ''}',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x8),

              AppButton(
                key: const Key('section_transition_continue_button'),
                label: 'Bắt đầu ${nextSection.label}',
                onPressed: onContinue,
                icon: Icons.play_arrow_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
