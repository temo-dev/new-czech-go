import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Countdown timer — EB Garamond italic, primary color.
/// Changes to warning/danger colors as time runs low.
class ExamTimer extends StatelessWidget {
  const ExamTimer({super.key, required this.remainingSeconds});

  final int remainingSeconds;

  bool get _isWarning => remainingSeconds <= 300; // ≤ 5 min
  bool get _isDanger => remainingSeconds <= 60;   // ≤ 1 min

  Color _color() {
    if (_isDanger) return AppColors.error;
    if (_isWarning) return AppColors.warning;
    return AppColors.primary;
  }

  String _format() {
    final h = remainingSeconds ~/ 3600;
    final m = (remainingSeconds % 3600) ~/ 60;
    final s = remainingSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Text(
      _format(),
      style: AppTypography.headlineSmall.copyWith(
        color: color,
        fontSize: 22,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
