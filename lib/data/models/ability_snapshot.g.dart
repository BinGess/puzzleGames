// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ability_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AbilitySnapshotAdapter extends TypeAdapter<AbilitySnapshot> {
  @override
  final int typeId = 3;

  @override
  AbilitySnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AbilitySnapshot(
      lqScore: fields[0] as double,
      speedScore: fields[1] as double,
      memoryScore: fields[2] as double,
      spaceLogicScore: fields[3] as double,
      focusScore: fields[4] as double,
      perceptionScore: fields[5] as double,
      timestamp: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AbilitySnapshot obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.lqScore)
      ..writeByte(1)
      ..write(obj.speedScore)
      ..writeByte(2)
      ..write(obj.memoryScore)
      ..writeByte(3)
      ..write(obj.spaceLogicScore)
      ..writeByte(4)
      ..write(obj.focusScore)
      ..writeByte(5)
      ..write(obj.perceptionScore)
      ..writeByte(6)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbilitySnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
