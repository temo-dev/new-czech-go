import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// LevelBadge renders the V21 CEFR chip + 4-dot ladder shown in the home
/// app bar. Tap-to-open opens the level history screen (wired by the
/// caller). Reduced-motion-safe: this widget renders no animation; the
/// upcoming pulse on `LevelProgressRing` is owned by that widget.
///
/// Visual:
///   [A1] ●●○○
///   Đang học A2
///
/// Sizing: the surrounding tap area is at least 48dp tall (Material
/// touch-target minimum) regardless of the typography scale.
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.currentLevel,
    required this.unlockedLevels,
    this.onTap,
  });

  final CefrLevel currentLevel;
  final Set<CefrLevel> unlockedLevels;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final next = nextCefrLevel(currentLevel);
    final studyingLabel = next == null
        ? null
        : 'Đang học ${cefrLevelLabel(next)}';
    final semanticsLabel = next == null
        ? 'Cấp độ ${cefrLevelLabel(currentLevel)}'
        : 'Cấp độ ${cefrLevelLabel(currentLevel)}, đang học ${cefrLevelLabel(next)}';

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.x3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x2,
                vertical: AppSpacing.x1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LevelChip(level: currentLevel),
                      const SizedBox(width: 6),
                      _LadderDots(
                        currentLevel: currentLevel,
                        unlockedLevels: unlockedLevels,
                      ),
                    ],
                  ),
                  if (studyingLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      studyingLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final CefrLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        cefrLevelLabel(level),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _LadderDots extends StatelessWidget {
  const _LadderDots({
    required this.currentLevel,
    required this.unlockedLevels,
  });

  final CefrLevel currentLevel;
  final Set<CefrLevel> unlockedLevels;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final lvl in CefrLevel.values) ...[
          _Dot(color: _colorFor(lvl)),
          if (lvl != CefrLevel.values.last) const SizedBox(width: 3),
        ],
      ],
    );
  }

  Color _colorFor(CefrLevel level) {
    if (level == currentLevel) return AppColors.primary;
    if (unlockedLevels.contains(level)) return AppColors.success;
    return AppColors.surfaceContainerHighest;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
