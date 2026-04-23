import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';

/// Animated waveform visualizer for speaking recording screens.
/// Shows N vertical bars that animate when [isActive] is true.
/// Bars oscillate with randomized phases for a natural look.
class WaveformVisualizer extends StatefulWidget {
  const WaveformVisualizer({
    super.key,
    this.barCount = 28,
    this.width = 200,
    this.height = 48,
    this.isActive = false,
    this.color,
    this.barWidth = 3.0,
    this.barSpacing = 3.0,
  });

  final int barCount;
  final double width;
  final double height;
  final bool isActive;
  final Color? color;
  final double barWidth;
  final double barSpacing;

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<double> _phases;
  late List<double> _amplitudes;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initBars();
    if (widget.isActive) _ctrl.repeat();
  }

  void _initBars() {
    final rng = math.Random(42);
    _phases = List.generate(
      widget.barCount,
      (i) => rng.nextDouble() * math.pi * 2,
    );
    _amplitudes = List.generate(
      widget.barCount,
      (i) => 0.3 + rng.nextDouble() * 0.7,
    );
  }

  @override
  void didUpdateWidget(WaveformVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.repeat();
    } else if (!widget.isActive && old.isActive) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _WaveformPainter(
            progress: _ctrl.value,
            phases: _phases,
            amplitudes: _amplitudes,
            barCount: widget.barCount,
            barWidth: widget.barWidth,
            barSpacing: widget.barSpacing,
            color: color,
            isActive: widget.isActive,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.phases,
    required this.amplitudes,
    required this.barCount,
    required this.barWidth,
    required this.barSpacing,
    required this.color,
    required this.isActive,
  });

  final double progress;
  final List<double> phases;
  final List<double> amplitudes;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final Color color;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final totalBarWidth = barWidth + barSpacing;
    final startX = (size.width - (totalBarWidth * barCount - barSpacing)) / 2;

    for (int i = 0; i < barCount; i++) {
      double heightFraction;
      if (isActive) {
        // Oscillating wave effect
        final wave = math.sin(
          progress * math.pi * 2 + phases[i],
        );
        // Normalize to 0.15–1.0 range
        heightFraction = (amplitudes[i] * (wave * 0.5 + 0.5)).clamp(0.15, 1.0);
      } else {
        // Static idle state — short flat bars
        heightFraction = 0.15 + (i % 3 == 0 ? 0.1 : 0.0);
      }

      final barHeight = size.height * heightFraction;
      final x = startX + i * totalBarWidth;
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.isActive != isActive ||
      old.color != color;
}

/// Compact waveform for audio player (static, not animated).
/// Used in dictation / listening screens to show waveform decoration.
class StaticWaveformBar extends StatelessWidget {
  const StaticWaveformBar({
    super.key,
    this.width = 160,
    this.height = 32,
    this.color,
    this.barCount = 20,
  });

  final double width;
  final double height;
  final Color? color;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    return WaveformVisualizer(
      width: width,
      height: height,
      barCount: barCount,
      isActive: false,
      color: color ?? AppColors.primary.withOpacity(0.5),
      barWidth: 2.5,
      barSpacing: 2.5,
    );
  }
}
