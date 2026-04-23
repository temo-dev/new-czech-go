import 'package:flutter/material.dart';

/// Design token: color palette.
/// Source: Stitch "Sahara (Warm Minimalism)" — pixel-exact from HTML designs.
abstract final class AppColors {
  // ── Brand (Sahara palette) ─────────────────────────────────────────────────
  static const primary            = Color(0xFFC2652A); // #c2652a — burnt sienna
  static const onPrimary          = Color(0xFFFFFFFF);
  static const primaryContainer   = Color(0xFFE08850); // warm gold
  static const onPrimaryContainer = Color(0xFFFBE8D8);
  static const primaryFixed       = Color(0xFFFBE8D8); // badges / soft bg
  static const primaryFixedDim    = Color(0xFFF0A878);
  static const onPrimaryFixed     = Color(0xFF7A3010); // text on primaryFixed
  static const inversePrimary     = Color(0xFFF0A878);

  static const secondary          = Color(0xFF78706A);
  static const onSecondary        = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFEAE2DA);
  static const onSecondaryContainer = Color(0xFF605850);

  static const tertiary           = Color(0xFF8C3C3C); // alerts / needs improvement
  static const onTertiary         = Color(0xFFFFFFFF);
  static const tertiaryContainer  = Color(0xFFD47070);
  static const onTertiaryContainer = Color(0xFF3A2020);
  static const tertiaryFixed      = Color(0xFFFCE0E0);
  static const onTertiaryFixed    = Color(0xFF6B2020); // text on tertiaryFixed

  // ── Surfaces — warm linen hierarchy ──────────────────────────────────────
  // Elevation order: lowest (white) → low → container → high → highest
  static const surface                = Color(0xFFFAF5EE); // page bg — #faf5ee
  static const surfaceContainerLowest = Color(0xFFFFFFFF); // cards, inputs
  static const surfaceContainerLow    = Color(0xFFF6F0E8); // section bg
  static const surfaceContainer       = Color(0xFFF2ECE4); // medium elevation
  static const surfaceContainerHigh   = Color(0xFFECE6DC);
  static const surfaceContainerHighest= Color(0xFFE6E0D6);

  // Legacy aliases (kept for backward compat during rewrite)
  static const backgroundLight        = Color(0xFFFAF5EE);
  static const surfaceLight           = Color(0xFFFAF5EE);
  static const surfaceContainerLight  = Color(0xFFF2ECE4);
  static const surfaceVariantLight    = Color(0xFFECE6DC);
  static const surfaceBrightLight     = Color(0xFFFAF5EE);
  static const surfaceDimLight        = Color(0xFFDCD6CC);
  static const inverseSurfaceLight    = Color(0xFF3A302A);
  static const inverseOnSurfaceLight  = Color(0xFFFAF5EE);

  // ── Text on surfaces ──────────────────────────────────────────────────────
  static const onBackground       = Color(0xFF3A302A); // #3a302a primary text
  static const onSurface          = Color(0xFF3A302A);
  static const onSurfaceVariant   = Color(0xFF605850); // #605850 muted text
  // Legacy aliases
  static const onBackgroundLight  = Color(0xFF3A302A);
  static const onSurfaceLight     = Color(0xFF3A302A);
  static const onSurfaceMutedLight = Color(0xFF605850);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const outline            = Color(0xFF9A9088); // #9a9088
  static const outlineVariant     = Color(0xFFD8D0C8); // #d8d0c8 light borders
  // Legacy aliases
  static const outlineLight       = Color(0xFF9A9088);
  static const borderLight        = Color(0xFFD8D0C8);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const error              = Color(0xFFC0392B);
  static const onError            = Color(0xFFFFFFFF);
  static const errorContainer     = Color(0xFFFCE4E0);
  static const onErrorContainer   = Color(0xFF7A1A10);

  static const success            = Color(0xFF2E7D32);
  static const successContainer   = Color(0xFFE8F5E9);
  static const onSuccess          = Color(0xFFFFFFFF);

  static const warning            = Color(0xFFF57C00);
  static const warningContainer   = Color(0xFFFFF3E0);

  static const info               = Color(0xFF1565C0);
  static const infoContainer      = Color(0xFFE3F2FD);

  // ── Score grade bands ─────────────────────────────────────────────────────
  static const scoreExcellent     = Color(0xFF2E7D32); // 85–100
  static const scoreGood          = Color(0xFF1565C0); // 70–84
  static const scoreFair          = Color(0xFFF57C00); // 50–69
  static const scorePoor          = Color(0xFFC0392B); // 0–49

  // ── Gamification ─────────────────────────────────────────────────────────
  static const xpGold             = Color(0xFFE08850); // warm gold
  static const xpGoldDim          = Color(0xFFF0A878);

  // ── Medal colors (leaderboard) ────────────────────────────────────────────
  static const medalGold          = Color(0xFFFFD700); // #1 rank
  static const medalSilver        = Color(0xFFC0C0C0); // #2 rank
  static const medalBronze        = Color(0xFFCD7F32); // #3 rank

  // ── Skill feedback (correct/incorrect state in exercises) ─────────────────
  static const skillCorrectBg     = Color(0xFFECFDF5); // emerald-50
  static const skillCorrectBorder = Color(0xFFD1FAE5); // emerald-100
  static const skillCorrectIcon   = Color(0xFF059669); // emerald-700
  static const skillCorrectText   = Color(0xFF065F46); // emerald-900
  static const skillCorrectGreen  = Color(0xFF16A34A); // green-600

  // ── Success state (form confirmations) ────────────────────────────────────
  static const successContainerAlt = Color(0xFFF0FDF4); // green-50 (lighter)
  static const successTextDark     = Color(0xFF166534); // green-800
  static const successTextDeep     = Color(0xFF14532D); // green-900

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const onSecond           = Color(0xFFFFFFFF);
  static const surfaceTint        = Color(0xFFC2652A);
  static const scrim              = Color(0x80000000);
}
