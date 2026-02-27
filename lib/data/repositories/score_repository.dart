import '../models/score_record.dart';
import '../datasources/hive_datasource.dart';

class ScoreRepository {
  /// Save a new score record
  Future<void> saveScore(ScoreRecord record) async {
    await scoresBox.add(record);
  }

  /// Get all scores for a specific game, sorted by timestamp descending
  List<ScoreRecord> getScoresForGame(String gameId) {
    return scoresBox.values
        .where((s) => s.gameId == gameId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get the N most recent scores for a game
  List<ScoreRecord> getRecentScores(String gameId, {int n = 10}) {
    final all = getScoresForGame(gameId);
    return all.take(n).toList();
  }

  /// Get the best score for a game (lowest for time-based, highest for count-based)
  ScoreRecord? getBestScore(String gameId, {bool lowerIsBetter = false}) {
    final all = getScoresForGame(gameId);
    if (all.isEmpty) return null;
    if (lowerIsBetter) {
      return all.reduce((a, b) => a.score < b.score ? a : b);
    }
    return all.reduce((a, b) => a.score > b.score ? a : b);
  }

  /// Get all scores across all games
  List<ScoreRecord> getAllScores() {
    return scoresBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Delete all scores (reset)
  Future<void> clearAll() async {
    await scoresBox.clear();
  }
}
