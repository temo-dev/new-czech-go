import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import '../providers/exam_session_notifier.dart';

/// Small status dot in the exam top bar showing autosave state.
class AutosaveIndicator extends StatelessWidget {
  const AutosaveIndicator({super.key, required this.status});

  final AutosaveStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      AutosaveStatus.idle => const SizedBox.shrink(),
      AutosaveStatus.saving => _Indicator(
          color: AppColors.warning,
          label: 'Đang lưu...',
          pulsing: true,
        ),
      AutosaveStatus.saved => _Indicator(
          color: AppColors.scoreExcellent,
          label: 'Đã lưu',
          icon: Icons.check_circle_rounded,
        ),
      AutosaveStatus.failed => _Indicator(
          color: AppColors.error,
          label: 'Lưu thất bại',
          icon: Icons.cloud_off_rounded,
        ),
    };
  }
}

class _Indicator extends StatefulWidget {
  const _Indicator({
    required this.color,
    required this.label,
    this.icon,
    this.pulsing = false,
  });
  final Color color;
  final String label;
  final IconData? icon;
  final bool pulsing;

  @override
  State<_Indicator> createState() => _IndicatorState();
}

class _IndicatorState extends State<_Indicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.pulsing) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
      ),
    );

    if (widget.pulsing) {
      dot = FadeTransition(opacity: _ctrl, child: dot);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.icon != null
            ? Icon(widget.icon, size: 14, color: widget.color)
            : dot,
        const SizedBox(width: 4),
        Text(
          widget.label,
          style: AppTypography.labelSmall.copyWith(color: widget.color),
        ),
      ],
    );
  }
}
