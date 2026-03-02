import '../models/score_record.dart';
import '../datasources/hive_datasource.dart';

class ScoreRepository {
  /// Save a new score record
  Future<void> saveScore(ScoreRecord record) async {
    await scoresBox.add(record);
  }

  /// Get all scores for a specific game, sorted by timestamp descending
  List<ScoreRecord> getScoresForGame(String gameId) {
    return scoresBox.values.where((s) => s.gameId == gameId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get the N most recent scores for a game
  List<ScoreRecord> getRecentScores(String gameId, {int n = 10}) {
    final all = getScoresForGame(gameId);
    return all.take(n).toList();
  }

  /// Get the best score for a game (optionally scoped to one difficulty).
  /// lowerIsBetter=true for time/move games, false for count/length games.
  ScoreRecord? getBestScore(
    String gameId, {
    bool lowerIsBetter = false,
    int? difficulty,
  }) {
    final all = difficulty == null
        ? getScoresForGame(gameId)
        : getScoresForGame(gameId)
            .where((s) => s.difficulty == difficulty)
            .toList(growable: false);
    if (all.isEmpty) return null;
    if (lowerIsBetter) {
      return all.reduce((a, b) => a.score < b.score ? a : b);
    }
    return all.reduce((a, b) => a.score > b.score ? a : b);
  }

  /// Highest played difficulty for a game.
  int? getHighestPlayedDifficulty(String gameId) {
    final all = getScoresForGame(gameId);
    if (all.isEmpty) return null;
    return all.fold<int>(
      all.first.difficulty,
      (maxDiff, s) => s.difficulty > maxDiff ? s.difficulty : maxDiff,
    );
  }

  /// Best score from the highest played difficulty for a game.
  ScoreRecord? getBestScoreAtHighestDifficulty(
    String gameId, {
    bool lowerIsBetter = false,
  }) {
    final highestDifficulty = getHighestPlayedDifficulty(gameId);
    if (highestDifficulty == null) return null;
    return getBestScore(
      gameId,
      lowerIsBetter: lowerIsBetter,
      difficulty: highestDifficulty,
    );
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
