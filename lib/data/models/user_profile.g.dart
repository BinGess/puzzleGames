// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 0;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String?,
      age: fields[1] as int?,
      languageCode: (fields[2] as String?) ?? 'system',
      soundEnabled: (fields[3] as bool?) ?? true,
      soundVolumeLevel: (fields[7] as int?) ?? 2,
      hapticsEnabled: (fields[4] as bool?) ?? true,
      fontScale: (fields[5] as double?) ?? 1.12,
      createdAt: (fields[6] as DateTime?) ?? DateTime.now(),
      coins: (fields[8] as int?) ?? 100,
      xp: (fields[9] as int?) ?? 0,
      level: (fields[10] as int?) ?? 1,
      lifetimeEarned: (fields[11] as int?) ?? 0,
      lifetimeSpent: (fields[12] as int?) ?? 0,
      lastDailySupplyAt: fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.age)
      ..writeByte(2)
      ..write(obj.languageCode)
      ..writeByte(3)
      ..write(obj.soundEnabled)
      ..writeByte(7)
      ..write(obj.soundVolumeLevel)
      ..writeByte(4)
      ..write(obj.hapticsEnabled)
      ..writeByte(5)
      ..write(obj.fontScale)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.coins)
      ..writeByte(9)
      ..write(obj.xp)
      ..writeByte(10)
      ..write(obj.level)
      ..writeByte(11)
      ..write(obj.lifetimeEarned)
      ..writeByte(12)
      ..write(obj.lifetimeSpent)
      ..writeByte(13)
      ..write(obj.lastDailySupplyAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
