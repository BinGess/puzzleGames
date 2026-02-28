import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// App theme — dark luxury with gold accent
abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: _textTheme,
        appBarTheme: _appBarTheme,
        cardTheme: _cardTheme,
        elevatedButtonTheme: _elevatedButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme,
        textButtonTheme: _textButtonTheme,
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 0.5,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceElevated,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceElevated,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          contentTextStyle: GoogleFonts.cairo(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceOverlay,
          contentTextStyle: GoogleFonts.cairo(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  static ColorScheme get _colorScheme => const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.gold,
        onPrimary: AppColors.textOnGold,
        primaryContainer: AppColors.goldVeryMuted,
        onPrimaryContainer: AppColors.gold,
        secondary: AppColors.sequenceMemory,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.border,
      );

  static TextTheme get _textTheme => TextTheme(
        displayLarge: GoogleFonts.cairo(
            fontSize: 56, fontWeight: FontWeight.w800, height: 1.1),
        displayMedium: GoogleFonts.cairo(
            fontSize: 40, fontWeight: FontWeight.w700, height: 1.2),
        displaySmall: GoogleFonts.cairo(
            fontSize: 32, fontWeight: FontWeight.w700, height: 1.2),
        headlineLarge: GoogleFonts.cairo(
            fontSize: 26, fontWeight: FontWeight.w700, height: 1.3),
        headlineMedium: GoogleFonts.cairo(
            fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
        headlineSmall: GoogleFonts.cairo(
            fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
        titleLarge: GoogleFonts.cairo(
            fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
        titleMedium: GoogleFonts.cairo(
            fontSize: 13, fontWeight: FontWeight.w500, height: 1.25),
        titleSmall: GoogleFonts.cairo(
            fontSize: 12, fontWeight: FontWeight.w500, height: 1.25),
        bodyLarge: GoogleFonts.cairo(
            fontSize: 17, fontWeight: FontWeight.w400, height: 1.35),
        bodyMedium: GoogleFonts.cairo(
            fontSize: 16, fontWeight: FontWeight.w400, height: 1.35),
        bodySmall: GoogleFonts.cairo(
            fontSize: 14, fontWeight: FontWeight.w400, height: 1.35),
        labelLarge: GoogleFonts.cairo(
            fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
        labelMedium: GoogleFonts.cairo(
            fontSize: 13, fontWeight: FontWeight.w500, height: 1.25),
        labelSmall: GoogleFonts.cairo(
            fontSize: 12, fontWeight: FontWeight.w400, height: 1.25),
      );

  static AppBarTheme get _appBarTheme => AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
      );

  static CardThemeData get _cardTheme => CardThemeData(
        color: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderGold, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      );

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.textOnGold,
          textStyle:
              GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      );

  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle:
              GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          side: const BorderSide(color: AppColors.goldMuted, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle:
              GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );
}
