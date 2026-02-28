import 'package:flutter/services.dart';
import 'sound_effects.dart';

/// Haptic feedback wrapper — respects the global haptics enabled setting
/// Usage: Haptics.light(), Haptics.medium(), Haptics.success()
abstract final class Haptics {
  static bool _hapticsEnabled = true;

  static void setEnabled(bool enabled) => _hapticsEnabled = enabled;
  static bool get isEnabled => _hapticsEnabled;

  static void setSoundEnabled(bool enabled) => SoundEffects.setEnabled(enabled);
  static bool get isSoundEnabled => SoundEffects.isEnabled;
  static void setSoundLevel(int level) => SoundEffects.setVolumeLevel(level);
  static int get soundLevel => SoundEffects.volumeLevel;
  static void setSoundGameId(String gameId) => SoundEffects.setGameId(gameId);

  /// Light tap (correct cell, button press)
  static void light() {
    SoundEffects.confirm();
    if (!_hapticsEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium tap (wrong answer, error)
  static void medium() {
    SoundEffects.error();
    if (!_hapticsEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy vibration (game over, level complete)
  static void heavy() {
    SoundEffects.success();
    if (!_hapticsEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection click (menu tap, toggle)
  static void selection() {
    SoundEffects.selection();
    if (!_hapticsEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Success vibration (new record, well done)
  static void success() {
    SoundEffects.success();
    if (!_hapticsEnabled) return;
    // Double light impact = success feel
    HapticFeedback.lightImpact();
    Future.delayed(
        const Duration(milliseconds: 80), HapticFeedback.lightImpact);
  }
}
