import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// V20: 8 dp progress bar coloured by mastery band.
///
/// `band` is the four-band token surfaced by the backend
/// (`needs_work`, `learning`, `solid`, `ready`). The bar animates from 0 →
/// `mastery` on first paint; under reduced-motion (`MediaQuery.disableAnimations`)
/// it paints the final value immediately to honour the system preference.
class MasteryBar extends StatelessWidget {
  const MasteryBar({
    super.key,
    required this.mastery,
    required this.band,
    this.height = 8,
    this.semanticsLabel,
  });

  /// Test hook — parent of the animated fill `ColoredBox`.
  static const fractionKey = ValueKey('mastery_bar_fraction');

  /// Test hook — the `ColoredBox` whose `color` reflects the band.
  static const fillKey = ValueKey('mastery_bar_fill');

  static const _animDuration = Duration(milliseconds: 400);

  final double mastery;
  final String band;
  final double height;
  final String? semanticsLabel;

  static Color colorForBand(String band) {
    switch (band) {
      case 'ready':
        return AppColors.scoreExcellent;
      case 'solid':
        return AppColors.scoreGood;
      case 'learning':
        return AppColors.scoreFair;
      case 'needs_work':
      default:
        return AppColors.scorePoor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = mastery.isNaN ? 0.0 : mastery.clamp(0.0, 1.0).toDouble();
    final fill = colorForBand(band);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(height / 2);

    final track = ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: AppColors.surfaceContainerHigh,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: reducedMotion ? value : 0, end: value),
            duration: reducedMotion ? Duration.zero : _animDuration,
            curve: Curves.easeOut,
            builder: (_, w, __) => FractionallySizedBox(
              key: fractionKey,
              alignment: AlignmentDirectional.centerStart,
              widthFactor: w,
              heightFactor: 1,
              child: ColoredBox(key: fillKey, color: fill),
            ),
          ),
        ),
      ),
    );

    if (semanticsLabel == null) return track;
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '${(value * 100).round()}%',
      child: ExcludeSemantics(child: track),
    );
  }
}
