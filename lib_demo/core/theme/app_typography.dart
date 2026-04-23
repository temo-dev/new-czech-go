import 'package:flutter/material.dart';

/// Design token: text styles.
/// Source: Stitch "Sahara" — EB Garamond (serif italic headlines) + Manrope (body/labels).
///
/// KEY RULE: ALL headlines use EB Garamond with fontStyle: italic.
/// Body/labels/buttons use Manrope (normal style).
/// Font family name constants — use instead of raw strings.
abstract final class AppFonts {
  static const headline = 'EBGaramond'; // Serif — italic display & headlines
  static const body = 'Manrope';        // Sans — body, titles, labels, buttons
}

abstract final class AppTypography {
  static const _headline = AppFonts.headline;
  static const _body = AppFonts.body;

  // ── Display (EB Garamond Italic — large editorial) ─────────────────────────
  static const displayLarge = TextStyle(
    fontFamily: _headline,
    fontSize: 57,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.12,
  );
  static const displayMedium = TextStyle(
    fontFamily: _headline,
    fontSize: 45,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.16,
  );
  static const displaySmall = TextStyle(
    fontFamily: _headline,
    fontSize: 36,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.22,
  );

  // ── Headlines (EB Garamond Italic) ────────────────────────────────────────
  static const headlineLarge = TextStyle(
    fontFamily: _headline,
    fontSize: 32,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.25,
  );
  static const headlineMedium = TextStyle(
    fontFamily: _headline,
    fontSize: 28,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    height: 1.29,
  );
  static const headlineSmall = TextStyle(
    fontFamily: _headline,
    fontSize: 24,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.33,
  );

  // ── Titles (Manrope — navigation, cards) ──────────────────────────────────
  static const titleLarge = TextStyle(
    fontFamily: _body,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );
  static const titleMedium = TextStyle(
    fontFamily: _body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.5,
  );
  static const titleSmall = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );

  // ── Body (Manrope — readable, generous line-height) ───────────────────────
  static const bodyLarge = TextStyle(
    fontFamily: _body,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.6,
  );
  static const bodyMedium = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.57,
  );
  static const bodySmall = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.5,
  );

  // ── Labels (Manrope — buttons, chips, captions) ───────────────────────────
  static const labelLarge = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );
  static const labelMedium = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.33,
  );
  static const labelSmall = TextStyle(
    fontFamily: _body,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // ── Special: Uppercase label (badge, section header) ─────────────────────
  /// Used for status badges, section labels. "CẦN CẢI THIỆN", "ĐANG HỌC", etc.
  static const labelUppercase = TextStyle(
    fontFamily: _body,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.4,
  );

  // ── Score display (EB Garamond Italic — large numbers in circles) ─────────
  /// Used inside CircularProgressRing and score heroes.
  static const scoreDisplay = TextStyle(
    fontFamily: _headline,
    fontSize: 48,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.0,
  );
  static const scoreDisplaySmall = TextStyle(
    fontFamily: _headline,
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
