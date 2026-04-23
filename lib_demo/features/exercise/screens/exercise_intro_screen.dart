import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Skill selection hub before a practice session.
/// Navigates to PracticeScreen via practiceExercise route with skill-based exercises.
class ExerciseIntroScreen extends StatelessWidget {
  const ExerciseIntroScreen({super.key});

  static const _skills = [
    (SkillArea.reading, 'Đọc hiểu', Icons.menu_book_rounded, 'Luyện đọc hiểu văn bản tiếng Czech'),
    (SkillArea.listening, 'Nghe hiểu', Icons.headphones_rounded, 'Luyện nghe hội thoại và phát âm'),
    (SkillArea.grammar, 'Ngữ pháp', Icons.edit_note_rounded, 'Ôn tập ngữ pháp cơ bản'),
    (SkillArea.vocabulary, 'Từ vựng', Icons.abc_rounded, 'Mở rộng vốn từ vựng hằng ngày'),
    (SkillArea.writing, 'Viết', Icons.draw_rounded, 'Luyện viết câu và đoạn văn'),
    (SkillArea.speaking, 'Nói', Icons.mic_rounded, 'Luyện phát âm và hội thoại'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(context),
      body: ResponsivePageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Luyện tập',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Chọn kỹ năng bạn muốn ôn luyện hôm nay.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.x8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: AppSpacing.x3,
                  mainAxisSpacing: AppSpacing.x3,
                ),
                itemCount: _skills.length,
                itemBuilder: (context, i) {
                  final (skill, label, icon, desc) = _skills[i];
                  return _SkillCard(
                    skill: skill,
                    label: label,
                    icon: icon,
                    description: desc,
                    onTap: () => _onSkillTap(context, skill),
                  );
                },
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
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.onSurfaceVariant,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  'Luyện tập',
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

  void _onSkillTap(BuildContext context, SkillArea skill) {
    // Navigate to practice with skill filter as query param.
    // The practiceExercise route handles actual exercise loading by exerciseId.
    // For now, show skill-based practice selection via the exam catalog as fallback.
    context.push('${AppRoutes.practiceExercise.replaceAll('/:exerciseId', '')}?skill=${skill.name}');
  }
}

// ── Skill Card ────────────────────────────────────────────────────────────────

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.label,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  final SkillArea skill;
  final String label;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  Color get _bgColor => switch (skill) {
        SkillArea.reading => const Color(0xFFF0F4FF),
        SkillArea.listening => const Color(0xFFF5F0FF),
        SkillArea.grammar => AppColors.primaryFixed,
        SkillArea.vocabulary => const Color(0xFFF0FFF4),
        SkillArea.writing => const Color(0xFFFFFBF0),
        SkillArea.speaking => const Color(0xFFFFF0F0),
        _ => AppColors.surfaceContainerLow,
      };

  Color get _iconColor => switch (skill) {
        SkillArea.reading => AppColors.info,
        SkillArea.listening => const Color(0xFF7C3AED),
        SkillArea.grammar => AppColors.primary,
        SkillArea.vocabulary => AppColors.success,
        SkillArea.writing => AppColors.warning,
        SkillArea.speaking => AppColors.tertiary,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: _iconColor.withOpacity(0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.x2),
              decoration: BoxDecoration(
                color: _iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: _iconColor, size: 20),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              description,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
