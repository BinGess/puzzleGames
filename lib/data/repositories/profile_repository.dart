import '../models/user_profile.dart';
import '../datasources/hive_datasource.dart';

class ProfileRepository {
  static const _key = 'user';

  UserProfile get profile {
    return profileBox.get(_key) ?? UserProfile.defaults;
  }

  Future<void> saveProfile(UserProfile p) async {
    await profileBox.put(_key, p);
  }

  Future<void> updateLanguage(String code) async {
    await saveProfile(profile.copyWith(languageCode: code));
  }

  Future<void> updateSound(bool enabled) async {
    await saveProfile(profile.copyWith(soundEnabled: enabled));
  }

  Future<void> updateSoundVolumeLevel(int level) async {
    await saveProfile(profile.copyWith(soundVolumeLevel: level.clamp(0, 3)));
  }

  Future<void> updateHaptics(bool enabled) async {
    await saveProfile(profile.copyWith(hapticsEnabled: enabled));
  }

  Future<void> updateFontScale(double scale) async {
    await saveProfile(profile.copyWith(fontScale: scale));
  }
}
