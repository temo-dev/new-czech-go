import 'package:flutter/material.dart';

/// Design token: border radii + shadows.
/// Source: Stitch "Sahara" HTML designs.
///
/// Radius scale (from HTML Tailwind classes):
///   rounded-lg  = 8px  → inputs, small buttons
///   rounded-xl  = 12px → standard buttons, cards (Sahara default)
///   rounded-2xl = 16px → medium cards, modules
///   rounded-3xl = 24px → large hero cards (lesson hero)
///   rounded-[28px]     → bento cards (dashboard, unlock bonus)
///   rounded-full= 999  → pills, avatars, badges
abstract final class AppRadius {
  static const double xs   = 4;
  static const double sm   = 8;   // inputs, small elements (rounded-lg)
  static const double md   = 12;  // standard cards, buttons (rounded-xl) ← Sahara default
  static const double lg   = 16;  // medium cards (rounded-2xl)
  static const double xl   = 24;  // large hero cards (rounded-3xl)
  static const double xxl  = 28;  // bento hero cards (rounded-[28px])
  static const double full = 999; // pills, badges, avatars

  static const BorderRadius xsAll   = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll  = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));

  // Bottom sheet / modal top radius
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

/// Design token: shadows.
/// Sahara: ultra-soft, warm-tinted. Prefer background tinting over elevation.
abstract final class AppShadows {
  // Default card shadow — barely visible, warm undertone
  // HTML: shadow-[0_2px_16px_rgba(58,48,42,0.04)]
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A3A302A), // rgba(58, 48, 42, 0.04)
      blurRadius: 16,
      offset: Offset(0, 2),
    ),
  ];

  // Slightly more visible — raised cards, dropdowns
  // HTML: shadow-[0_4px_24px_rgba(58,48,42,0.08)]
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x143A302A), // rgba(58, 48, 42, 0.08)
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
  ];

  // Transaction card / unlock bonus
  // HTML: shadow-[0_2px_16px_rgba(58,48,42,0.10)]
  static const List<BoxShadow> transaction = [
    BoxShadow(
      color: Color(0x1A3A302A), // rgba(58, 48, 42, 0.10)
      blurRadius: 16,
      offset: Offset(0, 2),
    ),
  ];

  // Modal / bottom sheet
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x1A3A302A),
      blurRadius: 40,
      offset: Offset(0, -4),
    ),
  ];

  // Primary button glow (unlock bonus)
  // HTML: shadow-lg shadow-primary/20
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x33C2652A), // primary/20
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];
}
