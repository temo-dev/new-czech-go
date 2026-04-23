import 'package:flutter/material.dart';

// Headlines: PlayfairDisplay (serif italic) — replaces EBGaramond from lib_demo
// Body/labels: system sans — Manrope to be added in Phase 6
abstract final class AppFonts {
  static const headline = 'PlayfairDisplay';
  static const body     = null; // system sans until Manrope added
}

abstract final class AppTypography {
  // ── Display ───────────────────────────────────────────────────────────────
  static const displayLarge = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 57,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.12,
  );
  static const displayMedium = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 45,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.16,
  );
  static const displaySmall = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 36,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.22,
  );

  // ── Headlines ─────────────────────────────────────────────────────────────
  static const headlineLarge = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 32,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.25,
  );
  static const headlineMedium = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 28,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    height: 1.29,
  );
  static const headlineSmall = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 24,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.33,
  );

  // ── Titles (system sans) ──────────────────────────────────────────────────
  static const titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );
  static const titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.5,
  );
  static const titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.6,
  );
  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.57,
  );
  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.5,
  );

  // ── Labels ────────────────────────────────────────────────────────────────
  static const labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );
  static const labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.33,
  );
  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );
  static const labelUppercase = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.4,
  );

  // ── Score display ─────────────────────────────────────────────────────────
  static const scoreDisplay = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 48,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.0,
  );
  static const scoreDisplaySmall = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 32,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static TextTheme get textTheme => const TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
