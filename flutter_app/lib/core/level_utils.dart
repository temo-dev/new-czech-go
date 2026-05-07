// V21 CEFR level helpers — single source of truth for the four levels
// the gating service exposes. Mirrors backend/internal/processing/level_*.go.
//
// Sibling to skill_utils.dart (per-skill labels/icons); kept in core/ so any
// feature/widget can import without dragging models.dart along.

import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_colors.dart';

/// CefrLevel enumerates the four supported levels in ascending order. Use
/// [cefrLevelOrder] when comparing instead of relying on enum index, so a
/// future re-order does not break call sites.
enum CefrLevel { a0, a1, a2, b1 }

/// CourseUnlockState mirrors the backend `unlock_state` field on
/// `GET /v1/courses(/:id)`. The "unknown" value is what we render when the
/// server omits the field (legacy / dev fixture without level service).
enum CourseUnlockState { unknown, unlocked, demo, locked }

/// parseLevel coerces a server-provided string into a CefrLevel. Falls back
/// to [CefrLevel.a0] for empty or unrecognised input so callers never have
/// to null-check.
CefrLevel parseLevel(String? raw) {
  switch (raw) {
    case 'a0':
      return CefrLevel.a0;
    case 'a1':
      return CefrLevel.a1;
    case 'a2':
      return CefrLevel.a2;
    case 'b1':
      return CefrLevel.b1;
    default:
      return CefrLevel.a0;
  }
}

/// cefrLevelCode is the inverse of [parseLevel] — used when the client needs
/// to send a level back to the server (placement complete, promotion target).
String cefrLevelCode(CefrLevel level) {
  switch (level) {
    case CefrLevel.a0:
      return 'a0';
    case CefrLevel.a1:
      return 'a1';
    case CefrLevel.a2:
      return 'a2';
    case CefrLevel.b1:
      return 'b1';
  }
}

/// nextCefrLevel returns the next rung on the ladder, or null at the top.
/// Matches backend processing.nextLevelAfter.
CefrLevel? nextCefrLevel(CefrLevel level) {
  switch (level) {
    case CefrLevel.a0:
      return CefrLevel.a1;
    case CefrLevel.a1:
      return CefrLevel.a2;
    case CefrLevel.a2:
      return CefrLevel.b1;
    case CefrLevel.b1:
      return null;
  }
}

/// cefrLevelOrder returns the integer rank of a level (0..3). Use for sort
/// comparisons; do **not** assume `index` matches forever.
int cefrLevelOrder(CefrLevel level) {
  switch (level) {
    case CefrLevel.a0:
      return 0;
    case CefrLevel.a1:
      return 1;
    case CefrLevel.a2:
      return 2;
    case CefrLevel.b1:
      return 3;
  }
}

/// cefrLevelLabel returns the short display label rendered in chips +
/// badges. Pure code; the surrounding sub-copy is owned by the calling
/// widget so it can run through [AppLocalizations].
String cefrLevelLabel(CefrLevel level) => cefrLevelCode(level).toUpperCase();

/// parseCourseUnlockState coerces a server-provided string.
CourseUnlockState parseCourseUnlockState(String? raw) {
  switch (raw) {
    case 'unlocked':
      return CourseUnlockState.unlocked;
    case 'demo':
      return CourseUnlockState.demo;
    case 'locked':
      return CourseUnlockState.locked;
    default:
      return CourseUnlockState.unknown;
  }
}

/// cefrLevelChipColor returns the brand-aligned chip background for a level
/// badge. Centralised here so the home LevelBadge + course list cards stay
/// in sync without each rederiving a palette mapping.
Color cefrLevelChipColor(CefrLevel level) {
  switch (level) {
    case CefrLevel.a0:
      return AppColors.surfaceContainerHigh;
    case CefrLevel.a1:
      return AppColors.tertiaryContainer;
    case CefrLevel.a2:
      return AppColors.primaryContainer;
    case CefrLevel.b1:
      return AppColors.secondaryContainer;
  }
}
