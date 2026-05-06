import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'mastery_bar.dart';

/// V20: one skill or module row — label, 8 dp coloured bar, percent text.
///
/// Min height 56 dp so the full row stays a comfortable tap target. Wraps in
/// `MergeSemantics` so screen readers announce the row as a single unit.
class SkillMasteryRow extends StatelessWidget {
  const SkillMasteryRow({
    super.key,
    required this.label,
    required this.mastery,
    required this.band,
    this.onTap,
    this.semanticsLabel,
    this.trailing,
  });

  static const constraintsKey = ValueKey('skill_mastery_row_constraints');

  final String label;
  final double mastery;
  final String band;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final value = mastery.isNaN ? 0.0 : mastery.clamp(0.0, 1.0).toDouble();
    final percentText = '${(value * 100).round()}%';

    final row = ConstrainedBox(
      key: constraintsKey,
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: AppTypography.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: MasteryBar(mastery: value, band: band),
            ),
            const SizedBox(width: AppSpacing.x3),
            SizedBox(
              width: 44,
              child: Text(
                percentText,
                textAlign: TextAlign.end,
                style: AppTypography.labelLarge.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.x2),
              trailing!,
            ],
          ],
        ),
      ),
    );

    final merged = MergeSemantics(
      child: Semantics(
        button: onTap != null,
        label: semanticsLabel ?? '$label, $percentText',
        onTap: onTap,
        child: ExcludeSemantics(child: row),
      ),
    );

    if (onTap == null) return merged;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: merged,
      ),
    );
  }
}
