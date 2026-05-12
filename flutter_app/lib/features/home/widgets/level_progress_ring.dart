import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/models/models.dart';

/// LevelProgressRing renders the home hero — a 6-arc ring (one per skill)
/// with a center label of `<current> → <next>` and the readiness percent.
/// When the promotion gates are met, the ring pulses to draw attention to
/// the upgrade banner. Reduced-motion users get a static "Sẵn sàng" pill
/// instead of the animation.
///
/// Tokens only — uses AppColors.scoreExcellent/Good/Fair/Poor for the
/// arcs; no new palette is introduced.
class LevelProgressRing extends StatefulWidget {
  const LevelProgressRing({
    super.key,
    required this.currentLevel,
    required this.nextLevel,
    required this.skillMastery,
    required this.coveragePct,
    required this.coverageThresholdPct,
    required this.promotionUnlocked,
    this.diameter = 200,
  });

  final CefrLevel currentLevel;
  final CefrLevel? nextLevel;
  final Map<String, SkillMasteryInfo> skillMastery;
  final double coveragePct;
  final double coverageThresholdPct;
  final bool promotionUnlocked;
  final double diameter;

  @override
  State<LevelProgressRing> createState() => _LevelProgressRingState();
}

class _LevelProgressRingState extends State<LevelProgressRing>
    with SingleTickerProviderStateMixin {
  // S2: skill order comes from the server payload's insertion order so a
  // new skill (e.g. V36 interview) renders without a client release.
  List<String> get _skillOrder => widget.skillMastery.keys.toList();

  AnimationController? _pulseController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshController();
  }

  @override
  void didUpdateWidget(covariant LevelProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshController();
  }

  void _refreshController() {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final shouldPulse = widget.promotionUnlocked && !reducedMotion;
    if (shouldPulse) {
      _pulseController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true);
    } else {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final readinessPct = _readinessPct();

    final ring = SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: CustomPaint(
        painter: _LevelArcsPainter(
          skills: _skillOrder,
          mastery: widget.skillMastery,
        ),
        child: Center(child: _CenterLabel(
          currentLevel: widget.currentLevel,
          nextLevel: widget.nextLevel,
          readinessPct: readinessPct,
        )),
      ),
    );

    Widget body = ring;
    if (widget.promotionUnlocked && !reducedMotion && _pulseController != null) {
      final scale = Tween<double>(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
      body = ScaleTransition(
        key: const Key('level_progress_ring_pulse'),
        scale: scale,
        child: ring,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        if (widget.promotionUnlocked && reducedMotion) ...[
          const SizedBox(height: 12),
          _ReadyPill(),
        ],
      ],
    );
  }

  double _readinessPct() {
    final order = _skillOrder;
    if (order.isEmpty) return 0;
    double sum = 0;
    for (final k in order) {
      final info = widget.skillMastery[k];
      if (info != null) sum += info.pct;
    }
    return sum / order.length;
  }
}

class _CenterLabel extends StatelessWidget {
  const _CenterLabel({
    required this.currentLevel,
    required this.nextLevel,
    required this.readinessPct,
  });

  final CefrLevel currentLevel;
  final CefrLevel? nextLevel;
  final double readinessPct;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cefrLevelLabel(currentLevel),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            if (nextLevel != null) ...[
              const SizedBox(width: 6),
              const Text(
                '→',
                style: TextStyle(
                  fontSize: 22,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                cefrLevelLabel(nextLevel!),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${readinessPct.toStringAsFixed(0)}% sẵn sàng',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReadyPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('level_progress_ring_ready_pill'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Sẵn sàng',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
      ),
    );
  }
}

class _LevelArcsPainter extends CustomPainter {
  _LevelArcsPainter({required this.skills, required this.mastery});

  final List<String> skills;
  final Map<String, SkillMasteryInfo> mastery;

  static const _trackStrokeWidth = 10.0;
  static const _arcStrokeWidth = 12.0;
  static const _gapDegrees = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - _arcStrokeWidth;
    final segmentDegrees = 360 / skills.length;

    for (var i = 0; i < skills.length; i++) {
      final startDeg = -90 + segmentDegrees * i + _gapDegrees / 2;
      final segmentSpanDeg = segmentDegrees - _gapDegrees;
      final start = _deg2rad(startDeg);
      final span = _deg2rad(segmentSpanDeg);

      // Track (always full segment)
      final trackPaint = Paint()
        ..color = AppColors.surfaceContainerHigh
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackStrokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, span, false, trackPaint,
      );

      final info = mastery[skills[i]];
      final pct = (info?.pct ?? 0).clamp(0.0, 100.0);
      if (pct <= 0) continue;
      final fillSpan = span * (pct / 100);
      final arcPaint = Paint()
        ..color = _scoreBandColor(pct)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _arcStrokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, fillSpan, false, arcPaint,
      );
    }
  }

  Color _scoreBandColor(double pct) {
    if (pct >= 85) return AppColors.scoreExcellent;
    if (pct >= 70) return AppColors.scoreGood;
    if (pct >= 50) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }

  static double _deg2rad(double d) => d * math.pi / 180;

  @override
  bool shouldRepaint(covariant _LevelArcsPainter old) =>
      old.mastery != mastery || old.skills != skills;
}
