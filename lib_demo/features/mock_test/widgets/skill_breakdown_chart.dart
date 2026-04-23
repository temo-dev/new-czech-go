import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/mock_test/models/mock_test_result.dart';

/// Horizontal bar chart showing score per skill.
class SkillBreakdownChart extends StatefulWidget {
  const SkillBreakdownChart({
    super.key,
    required this.sectionScores,
  });

  final Map<String, SectionResult> sectionScores;

  @override
  State<SkillBreakdownChart> createState() => _SkillBreakdownChartState();
}

class _SkillBreakdownChartState extends State<SkillBreakdownChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _skillOrder = ['speaking', 'writing', 'listening', 'reading'];

  @override
  Widget build(BuildContext context) {
    final skills = _skillOrder
        .where((k) => widget.sectionScores.containsKey(k))
        .map((k) => MapEntry(k, widget.sectionScores[k]!))
        .toList();
    return Column(
      children: skills
          .map((e) => _SkillBar(
                skill: e.key,
                result: e.value,
                animation: _controller,
              ))
          .toList(),
    );
  }
}

class _SkillBar extends AnimatedWidget {
  const _SkillBar({
    required this.skill,
    required this.result,
    required Animation<double> animation,
  }) : super(listenable: animation);

  final String skill;
  final SectionResult result;

  Animation<double> get animation => listenable as Animation<double>;

  static const _skillLabels = {
    'reading': 'Đọc hiểu',
    'listening': 'Nghe hiểu',
    'writing': 'Viết',
    'speaking': 'Nói',
  };

  static const _skillIcons = {
    'reading': Icons.menu_book_outlined,
    'listening': Icons.headphones_outlined,
    'writing': Icons.edit_note_outlined,
    'speaking': Icons.mic_outlined,
  };

  Color _barColor(double pct) {
    if (pct >= 0.85) return AppColors.scoreExcellent;
    if (pct >= 0.70) return AppColors.scoreGood;
    if (pct >= 0.50) return AppColors.scoreFair;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final pct = result.percentage.clamp(0.0, 1.0);
    final animated = (pct * animation.value).clamp(0.0, 1.0);
    final label = _skillLabels[skill] ?? skill;
    final icon = _skillIcons[skill] ?? Icons.quiz_outlined;
    final color = _barColor(pct);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(label, style: AppTypography.labelMedium),
              ),
              Text(
                '${result.score}/${result.total}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                '${(pct * 100).round()}%',
                style: AppTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: animated,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
