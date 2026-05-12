import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../models/exam_section_state.dart';
import '../widgets/question_status_chip.dart';
import 'mock_exam_skill_dispatch.dart';

/// V39 — fullscreen "Đáp án list" view of a mock-exam session. Read-only
/// in this slice (S6); S7 turns the chips into jump-back actions by
/// wiring an `onTap` that pops the route with the tapped `displayOrder`.
///
/// The route is opened from the mock-exam screen's app bar via
/// `Navigator.push(MaterialPageRoute(fullscreenDialog: true))`. The
/// caller awaits the returned `int?`: a value means jump to that
/// section, null means the learner dismissed without a choice.
class AnswerSheetScreen extends StatelessWidget {
  const AnswerSheetScreen({
    super.key,
    required this.session,
    this.currentDisplayOrder = 0,
  });

  /// Session being inspected. Sections are read in `displayOrder` order
  /// for the grid; cosmetic skill headers group the same data.
  final MockExamSessionView session;

  /// The section the player is on right now. 0 means none (e.g. when
  /// the sheet is opened from a non-player surface). Used to mark the
  /// matching chip as [SectionState.current].
  final int currentDisplayOrder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sorted = [...session.sections]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final byKind = <String, List<MockExamSection>>{};
    for (final s in sorted) {
      final k = sectionSkillKind(s);
      byKind.putIfAbsent(k, () => []).add(s);
    }
    final order = ['doc', 'viet', 'nghe', 'noi', 'interview'];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Danh sách câu'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Đóng',
        ),
        elevation: 0,
        backgroundColor: AppColors.surfaceContainerLow,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Legend(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
                children: [
                  for (final kind in order)
                    if (byKind.containsKey(kind)) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.x4,
                          bottom: AppSpacing.x2,
                        ),
                        child: Text(
                          skillLabel(l, kind).toUpperCase(),
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _SkillGrid(
                        sections: byKind[kind]!,
                        currentDisplayOrder: currentDisplayOrder,
                      ),
                    ],
                ],
              ),
            ),
            _SummaryFooter(session: session),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Wrap(
        spacing: AppSpacing.x4,
        runSpacing: AppSpacing.x2,
        children: const [
          _LegendItem(
            icon: Icons.check_rounded,
            color: AppColors.success,
            label: 'Đã làm',
          ),
          _LegendItem(
            icon: Icons.block_rounded,
            color: AppColors.onSurfaceVariant,
            label: 'Bỏ qua',
          ),
          _LegendItem(
            icon: Icons.radio_button_unchecked_rounded,
            color: AppColors.outline,
            label: 'Chưa làm',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.bodySmall),
      ],
    );
  }
}

class _SkillGrid extends StatelessWidget {
  const _SkillGrid({
    required this.sections,
    required this.currentDisplayOrder,
  });
  final List<MockExamSection> sections;
  final int currentDisplayOrder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x3,
      children: [
        for (final s in sections)
          QuestionStatusChip(
            label: s.displayOrder.toString(),
            state: sectionStateFor(s, currentDisplayOrder: currentDisplayOrder),
            // S7 will set onTap → pop with the displayOrder so the
            // caller can jump back. Kept null in S6 for read-only.
          ),
      ],
    );
  }
}

class _SummaryFooter extends StatelessWidget {
  const _SummaryFooter({required this.session});
  final MockExamSessionView session;

  @override
  Widget build(BuildContext context) {
    final done = session.sections.where((s) => s.isCompleted).length;
    final skipped = session.sections.where((s) => s.isSkipped).length;
    final total = session.sections.length;
    final remaining = total - done - skipped;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x4,
      ),
      child: Text(
        '$done/$total đã làm · $skipped bỏ qua · $remaining chưa',
        style: AppTypography.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
