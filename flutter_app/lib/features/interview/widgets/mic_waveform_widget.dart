import 'package:flutter/material.dart';

/// Animated microphone waveform — 7 bars that pulse when [isActive] is true.
class MicWaveformWidget extends StatefulWidget {
  const MicWaveformWidget({super.key, required this.isActive});

  final bool isActive;

  @override
  State<MicWaveformWidget> createState() => _MicWaveformWidgetState();
}

class _MicWaveformWidgetState extends State<MicWaveformWidget>
    with TickerProviderStateMixin {
  static const _barHeights = [8.0, 18.0, 26.0, 22.0, 14.0, 20.0, 10.0];

  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      _barHeights.length,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 30),
      ),
    );
    _anims = List.generate(
      _barHeights.length,
      (i) => Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrls[i], curve: Curves.easeInOut),
      ),
    );
    if (widget.isActive) _startAll();
  }

  void _startAll() {
    // Stagger via different AnimationController durations rather than Future.delayed
    // (Future.delayed leaves pending timers that fail widget tests).
    for (final c in _ctrls) {
      c.repeat(reverse: true);
    }
  }

  void _stopAll() {
    for (final c in _ctrls) {
      c.stop();
      c.value = 0.3;
    }
  }

  @override
  void didUpdateWidget(MicWaveformWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _startAll();
    if (!widget.isActive && old.isActive) _stopAll();
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barHeights.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedBuilder(
              animation: _anims[i],
              builder: (_, __) => Container(
                width: 3,
                height: _barHeights[i] * _anims[i].value,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? const Color(0xFFFF6A14)
                      : Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
