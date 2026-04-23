import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';

/// Circular progress ring — matches the SVG conic-gradient rings in Stitch HTML designs.
///
/// Used in: ExamResult (w-48 score hero), ModuleDetail (w-20 progress),
/// Progress (conic 35%), Dashboard (daily goal).
class CircularProgressRing extends StatefulWidget {
  const CircularProgressRing({
    super.key,
    required this.value,           // 0.0 – 1.0
    this.size = 80,
    this.strokeWidth = 8,
    this.color,
    this.bgColor,
    this.child,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? bgColor;
  final Widget? child;
  final bool animate;
  final Duration animationDuration;

  @override
  State<CircularProgressRing> createState() => _CircularProgressRingState();
}

class _CircularProgressRingState extends State<CircularProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(CircularProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.color ?? AppColors.primary;
    final bgColor = widget.bgColor ?? AppColors.surfaceContainerHighest;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _RingPainter(
              value: widget.animate ? _animation.value : widget.value,
              strokeWidth: widget.strokeWidth,
              color: ringColor,
              bgColor: bgColor,
            ),
            child: child,
          );
        },
        child: widget.child != null
            ? Center(child: widget.child)
            : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.bgColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background ring (full circle)
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc — starts from top (-π/2), clockwise
    final sweepAngle = 2 * math.pi * value.clamp(0.0, 1.0);
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.bgColor != bgColor ||
      old.strokeWidth != strokeWidth;
}

/// Score hero variant — large ring with percentage text in center.
/// Used in ExamResult and AI feedback screens.
class ScoreHeroRing extends StatelessWidget {
  const ScoreHeroRing({
    super.key,
    required this.score,       // 0–100
    this.maxScore = 100,
    this.size = 192,           // w-48 = 192px
    this.strokeWidth = 12,
    this.color,
    this.label = 'Tổng điểm',
  });

  final int score;
  final int maxScore;
  final double size;
  final double strokeWidth;
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? _scoreColor(score, maxScore);
    final pct = score / maxScore;

    return CircularProgressRing(
      value: pct,
      size: size,
      strokeWidth: strokeWidth,
      color: ringColor,
      bgColor: AppColors.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: const TextStyle(
              fontFamily: 'EBGaramond',
              fontSize: 44,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: AppColors.onBackground,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score, int max) {
    final pct = score / max * 100;
    if (pct >= 85) return AppColors.scoreExcellent;
    if (pct >= 70) return AppColors.scoreGood;
    if (pct >= 50) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }
}
