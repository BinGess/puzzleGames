import 'package:hive_flutter/hive_flutter.dart';

part 'score_record.g.dart';

@HiveType(typeId: 1)
class ScoreRecord extends HiveObject {
  @HiveField(0)
  final String gameId;

  /// Primary metric: ms for timed games, length for memory games, count for correct-count games
  @HiveField(1)
  final double score;

  /// Accuracy 0.0–1.0 (for Stroop, Visual Memory)
  @HiveField(2)
  final double? accuracy;

  @HiveField(3)
  final DateTime timestamp;

  /// 1=easy, 2=medium, 3=hard
  @HiveField(4)
  final int difficulty;

  /// Game-specific extras: e.g. gridSize, moveCount, roundsCompleted
  @HiveField(5)
  final Map<String, dynamic> metadata;

  ScoreRecord({
    required this.gameId,
    required this.score,
    this.accuracy,
    required this.timestamp,
    this.difficulty = 1,
    this.metadata = const {},
  });

  @override
  String toString() =>
      'ScoreRecord(gameId: $gameId, score: $score, time: $timestamp)';
}
