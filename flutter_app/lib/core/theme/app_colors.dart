import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand (Sahara palette) ─────────────────────────────────────────────────
  static const primary            = Color(0xFFC2652A);
  static const onPrimary          = Color(0xFFFFFFFF);
  static const primaryContainer   = Color(0xFFE08850);
  static const onPrimaryContainer = Color(0xFFFBE8D8);
  static const primaryFixed       = Color(0xFFFBE8D8);
  static const primaryFixedDim    = Color(0xFFF0A878);
  static const onPrimaryFixed     = Color(0xFF7A3010);
  static const inversePrimary     = Color(0xFFF0A878);

  static const secondary            = Color(0xFF78706A);
  static const onSecondary          = Color(0xFFFFFFFF);
  static const secondaryContainer   = Color(0xFFEAE2DA);
  static const onSecondaryContainer = Color(0xFF605850);

  static const tertiary             = Color(0xFF8C3C3C);
  static const onTertiary           = Color(0xFFFFFFFF);
  static const tertiaryContainer    = Color(0xFFD47070);
  static const onTertiaryContainer  = Color(0xFF3A2020);
  static const tertiaryFixed        = Color(0xFFFCE0E0);
  static const onTertiaryFixed      = Color(0xFF6B2020);

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const surface                 = Color(0xFFFAF5EE);
  static const surfaceContainerLowest  = Color(0xFFFFFFFF);
  static const surfaceContainerLow     = Color(0xFFF6F0E8);
  static const surfaceContainer        = Color(0xFFF2ECE4);
  static const surfaceContainerHigh    = Color(0xFFECE6DC);
  static const surfaceContainerHighest = Color(0xFFE6E0D6);
  static const inverseSurfaceLight     = Color(0xFF3A302A);
  static const inverseOnSurfaceLight   = Color(0xFFFAF5EE);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const onSurface        = Color(0xFF3A302A);
  static const onBackground     = Color(0xFF3A302A);
  static const onSurfaceVariant = Color(0xFF605850);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const outline        = Color(0xFF9A9088);
  static const outlineVariant = Color(0xFFD8D0C8);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const error            = Color(0xFFC0392B);
  static const onError          = Color(0xFFFFFFFF);
  static const errorContainer   = Color(0xFFFCE4E0);
  static const onErrorContainer = Color(0xFF7A1A10);

  static const success          = Color(0xFF2E7D32);
  static const successContainer = Color(0xFFE8F5E9);
  static const onSuccess        = Color(0xFFFFFFFF);

  static const warning          = Color(0xFFF57C00);
  static const warningContainer = Color(0xFFFFF3E0);

  static const info          = Color(0xFF1565C0);
  static const infoContainer = Color(0xFFE3F2FD);

  // ── Score grade bands ─────────────────────────────────────────────────────
  static const scoreExcellent = Color(0xFF2E7D32); // 85–100
  static const scoreGood      = Color(0xFF1565C0); // 70–84
  static const scoreFair      = Color(0xFFF57C00); // 50–69
  static const scorePoor      = Color(0xFFC0392B); // 0–49

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const scrim       = Color(0x80000000);
  static const surfaceTint = Color(0xFFC2652A);
}
