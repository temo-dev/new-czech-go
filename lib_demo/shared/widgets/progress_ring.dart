import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Animated circular progress indicator with a label in the centre.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,       // 0.0 – 1.0
    this.size = 72,
    this.strokeWidth = 6,
    this.color,
    this.label,
    this.labelStyle,
    this.backgroundColor,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? label;
  final TextStyle? labelStyle;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ringColor = color ?? AppColors.primary;
    final bgColor = backgroundColor ?? cs.surfaceContainerHighest;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            color: ringColor,
            backgroundColor: bgColor,
            strokeCap: StrokeCap.round,
          ),
          if (label != null)
            Text(
              label!,
              style: labelStyle ??
                  AppTypography.labelSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}
