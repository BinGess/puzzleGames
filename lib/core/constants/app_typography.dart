import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// App typography — Cairo font (Arabic + Latin, RTL-aware)
/// Line height 1.25x for Arabic text to prevent stroke overlap
abstract final class AppTypography {
  // ─── Display ────────────────────────────────────────────────────
  /// Large score display (LQ number)
  static TextStyle get displayLarge => GoogleFonts.cairo(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        color: AppColors.gold,
        height: 1.1,
        letterSpacing: -1,
      );

  /// Medium display (game score on result screen)
  static TextStyle get displayMedium => GoogleFonts.cairo(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  // ─── Heading ────────────────────────────────────────────────────
  static TextStyle get headingLarge => GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle get headingMedium => GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle get headingSmall => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.25,
      );

  // ─── Body ────────────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle get bodyMedium => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle get bodySmall => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.25,
      );

  // ─── Label / Caption ────────────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get labelMedium => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.2,
      );

  static TextStyle get caption => GoogleFonts.cairo(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textDisabled,
        height: 1.2,
      );

  // ─── Game-specific ───────────────────────────────────────────────
  /// Large Arabic numeral in game cells (Schulte, matrix)
  static TextStyle get gameNumber => GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.0,
      );

  /// Huge digit string (Number Memory flash)
  static TextStyle get digitFlash => GoogleFonts.cairo(
        fontSize: 52,
        fontWeight: FontWeight.w800,
        color: AppColors.gold,
        height: 1.0,
        letterSpacing: 8,
      );

  /// Timer display (Stopwatch, countdown)
  static TextStyle get timer => GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.0,
        letterSpacing: 1,
      );

  /// Color word in Stroop test
  static TextStyle get stroopWord => GoogleFonts.cairo(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.25,
      );

  /// LQ tier badge text
  static TextStyle get tierBadge => GoogleFonts.cairo(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnGold,
        height: 1.0,
      );

  // ─── Gold variants ────────────────────────────────────────────────
  static TextStyle get goldHeading => headingLarge.copyWith(color: AppColors.gold);
  static TextStyle get goldLabel => labelLarge.copyWith(color: AppColors.gold);
}
