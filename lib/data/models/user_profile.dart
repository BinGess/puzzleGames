import 'package:hive_flutter/hive_flutter.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  final String? name;

  /// Age for percentile ranking (future use)
  @HiveField(1)
  final int? age;

  /// Language preference: 'system' | 'ar' | 'en' | 'zh'
  @HiveField(2)
  final String languageCode;

  /// Sound effects enabled
  @HiveField(3)
  final bool soundEnabled;

  /// Sound volume level: 0 = mute, 1 = low, 2 = medium, 3 = high
  @HiveField(7)
  final int soundVolumeLevel;

  /// Haptic feedback enabled
  @HiveField(4)
  final bool hapticsEnabled;

  /// Font scale presets: 1.00 | 1.12 | 1.24
  @HiveField(5)
  final double fontScale;

  @HiveField(6)
  final DateTime createdAt;

  UserProfile({
    this.name,
    this.age,
    this.languageCode = 'system',
    this.soundEnabled = true,
    this.soundVolumeLevel = 2,
    this.hapticsEnabled = true,
    this.fontScale = 1.12,
    required this.createdAt,
  });

  static UserProfile get defaults => UserProfile(
        languageCode: 'system',
        soundEnabled: true,
        soundVolumeLevel: 2,
        hapticsEnabled: true,
        fontScale: 1.12,
        createdAt: DateTime.now(),
      );

  UserProfile copyWith({
    String? name,
    int? age,
    String? languageCode,
    bool? soundEnabled,
    int? soundVolumeLevel,
    bool? hapticsEnabled,
    double? fontScale,
  }) =>
      UserProfile(
        name: name ?? this.name,
        age: age ?? this.age,
        languageCode: languageCode ?? this.languageCode,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        soundVolumeLevel: soundVolumeLevel ?? this.soundVolumeLevel,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        fontScale: fontScale ?? this.fontScale,
        createdAt: createdAt,
      );
}
