import 'package:hive_flutter/hive_flutter.dart';

part 'ability_snapshot.g.dart';

@HiveType(typeId: 3)
class AbilitySnapshot extends HiveObject {
  @HiveField(0)
  final double lqScore;

  @HiveField(1)
  final double speedScore; // 0-100

  @HiveField(2)
  final double memoryScore; // 0-100

  @HiveField(3)
  final double spaceLogicScore; // 0-100

  @HiveField(4)
  final double focusScore; // 0-100

  @HiveField(5)
  final double perceptionScore; // 0-100 (fixed 50.0 in MVP)

  @HiveField(6)
  final DateTime timestamp;

  AbilitySnapshot({
    required this.lqScore,
    required this.speedScore,
    required this.memoryScore,
    required this.spaceLogicScore,
    required this.focusScore,
    this.perceptionScore = 50.0,
    required this.timestamp,
  });

  static AbilitySnapshot get empty => AbilitySnapshot(
        lqScore: 0,
        speedScore: 0,
        memoryScore: 0,
        spaceLogicScore: 0,
        focusScore: 0,
        perceptionScore: 50,
        timestamp: DateTime.now(),
      );

  AbilitySnapshot copyWith({
    double? lqScore,
    double? speedScore,
    double? memoryScore,
    double? spaceLogicScore,
    double? focusScore,
    double? perceptionScore,
    DateTime? timestamp,
  }) =>
      AbilitySnapshot(
        lqScore: lqScore ?? this.lqScore,
        speedScore: speedScore ?? this.speedScore,
        memoryScore: memoryScore ?? this.memoryScore,
        spaceLogicScore: spaceLogicScore ?? this.spaceLogicScore,
        focusScore: focusScore ?? this.focusScore,
        perceptionScore: perceptionScore ?? this.perceptionScore,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  String toString() => 'AbilitySnapshot(lq: $lqScore, timestamp: $timestamp)';
}
