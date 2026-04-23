import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// MCQ answer option tile.
/// Matches Stitch HTML: letter circle (A/B/C/D) + text + state border/bg.
///
/// States:
///   idle:     border-outlineVariant, white bg, hover:border-primary
///   selected: border-2 border-primary, bg-primary/5, radio dot
///   correct:  border-2 border-green, bg-green-50, check icon
///   wrong:    border-2 border-error, bg-errorContainer/30, x icon
enum McqOptionState { idle, selected, correct, wrong }

class McqOptionTile extends StatefulWidget {
  const McqOptionTile({
    super.key,
    required this.letter,
    required this.text,
    this.state = McqOptionState.idle,
    this.onTap,
    this.enabled = true,
  });

  final String letter;
  final String text;
  final McqOptionState state;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<McqOptionTile> createState() => _McqOptionTileState();
}

class _McqOptionTileState extends State<McqOptionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  Color get _borderColor => switch (widget.state) {
        McqOptionState.idle => AppColors.outlineVariant,
        McqOptionState.selected => AppColors.primary,
        McqOptionState.correct => const Color(0xFF16A34A), // green-600
        McqOptionState.wrong => AppColors.error,
      };

  Color get _bgColor => switch (widget.state) {
        McqOptionState.idle => AppColors.surfaceContainerLowest,
        McqOptionState.selected => AppColors.primary.withOpacity(0.05),
        McqOptionState.correct => const Color(0xFFF0FDF4), // green-50
        McqOptionState.wrong => AppColors.errorContainer.withOpacity(0.3),
      };

  double get _borderWidth =>
      widget.state == McqOptionState.idle ? 1.0 : 2.0;

  Widget? get _trailingIcon => switch (widget.state) {
        McqOptionState.idle => null,
        McqOptionState.selected => Icon(
            Icons.radio_button_checked_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        McqOptionState.correct => const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: Color(0xFF16A34A),
          ),
        McqOptionState.wrong => const Icon(
            Icons.cancel_rounded,
            size: 20,
            color: AppColors.error,
          ),
      };

  Color get _letterBgColor => switch (widget.state) {
        McqOptionState.idle => AppColors.surfaceContainerHigh,
        McqOptionState.selected => AppColors.primary.withOpacity(0.15),
        McqOptionState.correct => const Color(0xFFDCFCE7),
        McqOptionState.wrong => AppColors.errorContainer,
      };

  Color get _letterTextColor => switch (widget.state) {
        McqOptionState.idle => AppColors.onSurfaceVariant,
        McqOptionState.selected => AppColors.primary,
        McqOptionState.correct => const Color(0xFF166534),
        McqOptionState.wrong => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: widget.enabled && widget.onTap != null
            ? (_) => _scaleCtrl.forward()
            : null,
        onTapUp: widget.enabled && widget.onTap != null
            ? (_) => _scaleCtrl.reverse()
            : null,
        onTapCancel: () => _scaleCtrl.reverse(),
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _borderColor,
              width: _borderWidth,
            ),
          ),
          child: Row(
            children: [
              // Letter circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _letterBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.letter,
                    style: AppTypography.labelMedium.copyWith(
                      color: _letterTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Text(
                  widget.text,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: widget.state == McqOptionState.selected
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (_trailingIcon != null) ...[
                const SizedBox(width: 8),
                _trailingIcon!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
