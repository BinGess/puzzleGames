import 'package:hive_flutter/hive_flutter.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  final String? name;

  /// Age for percentile ranking (future use)
  @HiveField(1)
  final int? age;

  /// Language preference: 'ar' | 'en'
  @HiveField(2)
  final String languageCode;

  /// Sound effects enabled
  @HiveField(3)
  final bool soundEnabled;

  /// Haptic feedback enabled
  @HiveField(4)
  final bool hapticsEnabled;

  /// Font scale: 0.85 | 1.0 | 1.15
  @HiveField(5)
  final double fontScale;

  @HiveField(6)
  final DateTime createdAt;

  UserProfile({
    this.name,
    this.age,
    this.languageCode = 'ar',
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.fontScale = 1.0,
    required this.createdAt,
  });

  static UserProfile get defaults => UserProfile(
        languageCode: 'ar',
        soundEnabled: true,
        hapticsEnabled: true,
        fontScale: 1.0,
        createdAt: DateTime.now(),
      );

  UserProfile copyWith({
    String? name,
    int? age,
    String? languageCode,
    bool? soundEnabled,
    bool? hapticsEnabled,
    double? fontScale,
  }) =>
      UserProfile(
        name: name ?? this.name,
        age: age ?? this.age,
        languageCode: languageCode ?? this.languageCode,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        fontScale: fontScale ?? this.fontScale,
        createdAt: createdAt,
      );
}
