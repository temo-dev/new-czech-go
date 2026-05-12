import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/exam_session_controller.dart';

/// V39 — mock-exam player app bar.
///
/// Top row (left → right):
///   * `⏱ MM:SS` timer with tabular figures. Turns red below 5 minutes.
///   * "N/M · Pđ" progress + current points.
///   * Sheet button (S6 wires the route).
///   * Overflow ⋮ with a single "Nộp bài ngay" entry (S9 wires it).
///
/// Bottom row is a thin progress bar (resolved ÷ total).
///
/// The widget listens to the controller via `ListenableBuilder` so the
/// 1-second ticker drives the timer without re-mounting children.
class ExamAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ExamAppBar({
    super.key,
    required this.controller,
    this.onSheetTap,
    this.onSubmitAllTap,
  });

  final ExamSessionController controller;
  final VoidCallback? onSheetTap;
  final VoidCallback? onSubmitAllTap;

  static const _height = 96.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final session = controller.session;
        final remaining = controller.remaining;
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        final timerStr =
            '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        final warning = remaining < const Duration(minutes: 5);
        final timerColor = warning ? AppColors.error : AppColors.onSurface;
        final resolved = controller.resolvedCount;
        final total = session.sections.length;
        final currentSection = session.sections.isEmpty
            ? null
            : controller.currentSection;
        final progressFraction = total == 0 ? 0.0 : resolved / total;

        return Material(
          color: AppColors.surfaceContainerLow,
          elevation: 0,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        if (session.hasTimer) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 20,
                            color: timerColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timerStr,
                            style: AppTypography.titleLarge.copyWith(
                              color: timerColor,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            currentSection == null
                                ? '$resolved/$total'
                                : '${currentSection.displayOrder}/$total · ${currentSection.maxPoints}đ',
                            style: AppTypography.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Danh sách câu',
                          icon: const Icon(Icons.grid_view_rounded),
                          onPressed: onSheetTap,
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Tuỳ chọn',
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (key) {
                            if (key == 'submit-all') {
                              onSubmitAllTap?.call();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'submit-all',
                              child: Text('Nộp bài ngay'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progressFraction.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
