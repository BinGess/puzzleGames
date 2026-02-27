import 'package:flutter/material.dart';

/// App spacing — 8px base grid for consistent layout
/// UX: Minimum 8px between touch targets (mobile)
abstract final class AppSpacing {
  // ─── Base unit: 8px ───────────────────────────────────────────────
  static const double xs = 4;   // 0.5x — tight (e.g. icon-text gap)
  static const double sm = 8;   // 1x — minimum touch gap
  static const double md = 12;  // 1.5x — between related elements
  static const double lg = 16;  // 2x — section internal
  static const double xl = 20;  // 2.5x — screen horizontal padding
  static const double xxl = 24; // 3x — between sections
  static const double xxxl = 32; // 4x — large gaps
  static const double huge = 40; // 5x — bottom padding
  static const double hero = 48; // 6x — major section breaks

  // ─── Pre-built EdgeInsets ────────────────────────────────────────
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: lg,
  );
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: sm,
  );
  static const EdgeInsets sectionGap = EdgeInsets.only(bottom: xxl);
}
