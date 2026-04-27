import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand — Babbel Orange ─────────────────────────────────────────────────
  static const primary            = Color(0xFFFF6A14);
  static const onPrimary          = Color(0xFFFFFFFF);
  static const primaryContainer   = Color(0xFFFFE5D2);
  static const onPrimaryContainer = Color(0xFF5A2406);
  static const primaryFixed       = Color(0xFFFFD0B0);
  static const primaryFixedDim    = Color(0xFFFFB07A);
  static const onPrimaryFixed     = Color(0xFF3D1200);
  static const inversePrimary     = Color(0xFFFFB07A);

  // ── Accent — Deep Teal ────────────────────────────────────────────────────
  static const secondary            = Color(0xFF0F3D3A);
  static const onSecondary          = Color(0xFFFFFFFF);
  static const secondaryContainer   = Color(0xFFD9E5E3);
  static const onSecondaryContainer = Color(0xFF0F3D3A);

  // ── Tertiary — Warm Amber ─────────────────────────────────────────────────
  static const tertiary             = Color(0xFFC28012);
  static const onTertiary           = Color(0xFFFFFFFF);
  static const tertiaryContainer    = Color(0xFFF8EAC9);
  static const onTertiaryContainer  = Color(0xFF5C3A06);
  static const tertiaryFixed        = Color(0xFFFFF0CC);
  static const onTertiaryFixed      = Color(0xFF3D2400);

  // ── Surfaces (warm cream) ─────────────────────────────────────────────────
  static const surface                 = Color(0xFFFBF3E7);
  static const surfaceContainerLowest  = Color(0xFFFFFFFF);
  static const surfaceContainerLow     = Color(0xFFFFF8EA);
  static const surfaceContainer        = Color(0xFFF0E9DB);
  static const surfaceContainerHigh    = Color(0xFFE8DDD0);
  static const surfaceContainerHighest = Color(0xFFDED3C5);
  static const inverseSurfaceLight     = Color(0xFF2A2420);
  static const inverseOnSurfaceLight   = Color(0xFFF5EFE6);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const onSurface        = Color(0xFF14110C);
  static const onBackground     = Color(0xFF14110C);
  static const onSurfaceVariant = Color(0xFF4D4540);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const outline        = Color(0xFF857B72);
  static const outlineVariant = Color(0xFFBCB2A6);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const error            = Color(0xFFC03A28);
  static const onError          = Color(0xFFFFFFFF);
  static const errorContainer   = Color(0xFFF8DDD6);
  static const onErrorContainer = Color(0xFF621D10);

  static const success          = Color(0xFF1F8A4D);
  static const successContainer = Color(0xFFE2F1E5);
  static const onSuccess        = Color(0xFFFFFFFF);

  static const warning          = Color(0xFFC28012);
  static const warningContainer = Color(0xFFF8EAC9);

  static const info          = Color(0xFF3060B8);
  static const infoContainer = Color(0xFFDEE9F7);

  // ── Score grade bands ─────────────────────────────────────────────────────
  static const scoreExcellent = Color(0xFF1F8A4D); // 85–100
  static const scoreGood      = Color(0xFF3060B8); // 70–84
  static const scoreFair      = Color(0xFFC28012); // 50–69
  static const scorePoor      = Color(0xFFC03A28); // 0–49

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const scrim       = Color(0x80140C06);
  static const surfaceTint = Color(0xFFFF6A14);

  // ── Recording / live state ────────────────────────────────────────────────
  static const rec       = Color(0xFFE2530A);
  static const recSoft   = Color(0xFFFFE0CD);
}
