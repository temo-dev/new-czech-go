import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import '../providers/exam_session_notifier.dart';
import 'autosave_indicator.dart';
import 'exam_timer.dart';

/// Full-width sticky top bar for the exam session.
/// Matches Stitch: Timer (left, EB Garamond italic primary) | Title (absolute center) | Submit button (right)
class ExamTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ExamTopBar({
    super.key,
    required this.sectionLabel,
    required this.questionLabel,
    required this.remainingSeconds,
    required this.autosaveStatus,
    required this.onNavTap,
    this.onExit,
    this.onSubmit,
  });

  final String sectionLabel;
  final String questionLabel;
  final int remainingSeconds;
  final AutosaveStatus autosaveStatus;
  final VoidCallback onNavTap;
  final VoidCallback? onExit;
  final VoidCallback? onSubmit;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left: timer
              Positioned(
                left: 16,
                child: ExamTimer(remainingSeconds: remainingSeconds),
              ),

              // Center: title (absolute)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sectionLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    questionLabel,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBackground,
                    ),
                  ),
                ],
              ),

              // Right: autosave + submit
              Positioned(
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutosaveIndicator(status: autosaveStatus),
                    const SizedBox(width: 8),
                    // Grid nav button
                    IconButton(
                      icon: const Icon(Icons.grid_view_rounded,
                          size: 20, color: AppColors.onSurfaceVariant),
                      tooltip: 'Danh sách câu hỏi',
                      onPressed: onNavTap,
                      padding: EdgeInsets.zero,
                    ),
                    if (onSubmit != null)
                      GestureDetector(
                        onTap: onSubmit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'Nộp bài',
                            style: AppTypography.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
