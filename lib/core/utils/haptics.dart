import 'package:flutter/services.dart';

/// Haptic feedback wrapper — respects the global haptics enabled setting
/// Usage: Haptics.light(), Haptics.medium(), Haptics.success()
abstract final class Haptics {
  static bool _enabled = true;

  static void setEnabled(bool enabled) => _enabled = enabled;
  static bool get isEnabled => _enabled;

  /// Light tap (correct cell, button press)
  static void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium tap (wrong answer, error)
  static void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy vibration (game over, level complete)
  static void heavy() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection click (menu tap, toggle)
  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Success vibration (new record, well done)
  static void success() {
    if (!_enabled) return;
    // Double light impact = success feel
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 80), HapticFeedback.lightImpact);
  }
}
