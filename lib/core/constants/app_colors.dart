import 'package:flutter/material.dart';

/// App color palette — dark luxury + gold accent
/// Inspired by the Middle East aesthetic: brushed metal, gold, deep navy
abstract final class AppColors {
  // ─── Background & Surface ───────────────────────────────────────
  static const Color background = Color(0xFF0A0A12); // Deep dark navy
  static const Color surface = Color(0xFF14141E); // Slightly lighter
  static const Color surfaceElevated = Color(0xFF1E1E2C); // Cards
  static const Color surfaceOverlay = Color(0xFF252535); // Modals/sheets

  // ─── Gold Accent ─────────────────────────────────────────────────
  static const Color gold = Color(0xFFFFD700); // Primary gold
  static const Color goldBright = Color(0xFFFFE44D); // Brighter on press
  static const Color goldMuted = Color(0xFFC5A028); // Subtle gold
  static const Color goldGlow = Color(0x40FFD700); // Gold transparent (glow)
  static const Color goldVeryMuted = Color(0x1AFFD700); // Very subtle

  // ─── Text ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFF5A5A6A);
  static const Color textOnGold = Color(0xFF0A0A12); // Dark text on gold buttons

  // ─── Status ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF34C759);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);

  // ─── Border / Divider ────────────────────────────────────────────
  static const Color border = Color(0xFF2E2E3E);
  static const Color borderGold = Color(0x50C5A028);

  // ─── Per-game Accent Colors ───────────────────────────────────────
  /// Schulte Grid — Gold
  static const Color schulte = Color(0xFFFFD700);
  static const Color schulteGlow = Color(0x40FFD700);

  /// Reaction Time — Sport Green
  static const Color reaction = Color(0xFF34C759);
  static const Color reactionGlow = Color(0x4034C759);

  /// Number Memory — Bright Gold
  static const Color numberMemory = Color(0xFFFFCC00);
  static const Color numberMemoryGlow = Color(0x40FFCC00);

  /// Stroop Test — Sunset Orange
  static const Color stroop = Color(0xFFFF9500);
  static const Color stroopGlow = Color(0x40FF9500);

  /// Visual Memory — Orchid Purple
  static const Color visualMemory = Color(0xFFAF52DE);
  static const Color visualMemoryGlow = Color(0x40AF52DE);

  /// Sequence Memory — Aurora Blue
  static const Color sequenceMemory = Color(0xFF5856D6);
  static const Color sequenceMemoryGlow = Color(0x405856D6);

  /// Number Matrix — Matte Gold
  static const Color numberMatrix = Color(0xFFC5A059);
  static const Color numberMatrixGlow = Color(0x40C5A059);

  /// Reverse Memory — Sky Blue
  static const Color reverseMemory = Color(0xFF5AC8FA);
  static const Color reverseMemoryGlow = Color(0x405AC8FA);

  /// Sliding Puzzle — Alert Red
  static const Color slidingPuzzle = Color(0xFFFF3B30);
  static const Color slidingPuzzleGlow = Color(0x40FF3B30);

  /// Tower of Hanoi — Light Blue
  static const Color towerOfHanoi = Color(0xFF7DDDFA);
  static const Color towerOfHanoiGlow = Color(0x407DDDFA);

  // ─── Dimension Colors (for radar chart) ───────────────────────────
  static const Color dimensionSpeed = reaction; // Green
  static const Color dimensionMemory = visualMemory; // Purple
  static const Color dimensionSpaceLogic = sequenceMemory; // Blue
  static const Color dimensionFocus = stroop; // Orange
  static const Color dimensionPerception = towerOfHanoi; // Light blue

  // ─── Color Word Colors (for Stroop game) ──────────────────────────
  static const Color colorRed = Color(0xFFFF3B30);
  static const Color colorBlue = Color(0xFF007AFF);
  static const Color colorGreen = Color(0xFF34C759);
  static const Color colorYellow = Color(0xFFFFCC00);
}
