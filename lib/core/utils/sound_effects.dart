import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Lightweight game SFX wrapper — respects global sound enable and volume level.
abstract final class SoundEffects {
  static bool _enabled = true;
  static int _volumeLevel = 2; // 0 mute, 1 low, 2 medium, 3 high
  static String _gameId = '';
  static DateTime _lastClickAt = DateTime.fromMillisecondsSinceEpoch(0);

  static final AudioPlayer _tapPlayer = AudioPlayer();
  static final AudioPlayer _errorPlayer = AudioPlayer();
  static final AudioPlayer _successPlayer = AudioPlayer();

  static const Set<String> _speedGames = {
    'schulte_grid',
    'reaction_time',
    'stroop_test',
  };
  static const Set<String> _memoryGames = {
    'number_memory',
    'visual_memory',
    'sequence_memory',
    'reverse_memory',
  };
  static const Set<String> _logicGames = {
    'number_matrix',
    'sliding_puzzle',
    'tower_of_hanoi',
  };

  static void setEnabled(bool enabled) => _enabled = enabled;
  static bool get isEnabled => _enabled;
  static void setVolumeLevel(int level) => _volumeLevel = level.clamp(0, 3);
  static int get volumeLevel => _volumeLevel;
  static void setGameId(String gameId) => _gameId = gameId;

  static double get _baseVolume {
    if (!_enabled || _volumeLevel <= 0) return 0;
    return switch (_volumeLevel) {
      1 => 0.35,
      2 => 0.65,
      _ => 1.0,
    };
  }

  static String get _familyPrefix {
    if (_speedGames.contains(_gameId)) return 'speed';
    if (_memoryGames.contains(_gameId)) return 'memory';
    if (_logicGames.contains(_gameId)) return 'logic';
    return 'logic';
  }

  static Future<void> _play(AudioPlayer player, String suffix,
      {double gain = 1.0}) async {
    final volume = _baseVolume * gain;
    if (volume <= 0) return;
    try {
      await player.stop();
      await player.play(
        AssetSource('sounds/${_familyPrefix}_$suffix.wav'),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Ignore audio playback failures to keep gameplay uninterrupted.
    }
  }

  /// UI tap/click feedback.
  static void selection() {
    if (_baseVolume <= 0) return;
    final now = DateTime.now();
    if (now.difference(_lastClickAt) < const Duration(milliseconds: 24)) {
      return;
    }
    _lastClickAt = now;
    unawaited(_play(_tapPlayer, 'tap', gain: 0.9));
  }

  /// Correct action / confirmed input.
  static void confirm() {
    unawaited(_play(_tapPlayer, 'tap'));
  }

  /// Wrong action / invalid move.
  static void error() {
    unawaited(_play(_errorPlayer, 'error'));
  }

  /// Round/game success.
  static void success() {
    unawaited(_play(_successPlayer, 'success'));
  }
}
