// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'score_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScoreRecordAdapter extends TypeAdapter<ScoreRecord> {
  @override
  final int typeId = 1;

  @override
  ScoreRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScoreRecord(
      gameId: fields[0] as String,
      score: fields[1] as double,
      accuracy: fields[2] as double?,
      timestamp: fields[3] as DateTime,
      difficulty: fields[4] as int,
      metadata: (fields[5] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ScoreRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.gameId)
      ..writeByte(1)
      ..write(obj.score)
      ..writeByte(2)
      ..write(obj.accuracy)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.difficulty)
      ..writeByte(5)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
