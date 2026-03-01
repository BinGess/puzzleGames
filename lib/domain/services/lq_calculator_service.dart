import 'dart:math' as math;
import '../../data/models/score_record.dart';
import '../../data/models/ability_snapshot.dart';
import '../enums/game_type.dart';

/// LQ Calculator Service
///
/// Converts raw game scores into normalized 0-100 dimension scores,
/// then computes the weighted LQ composite score.
///
/// Normalization uses a sigmoid-based approach with reference benchmarks
/// derived from cognitive science literature and typical human performance.
class LqCalculatorService {
  /// Compute a full AbilitySnapshot from all available game scores
  AbilitySnapshot compute({
    required Map<String, List<ScoreRecord>> scoresByGame,
    required List<ScoreRecord> recentAllGames,
  }) {
    final speed = _computeSpeed(scoresByGame);
    final memory = _computeMemory(scoresByGame);
    final spaceLogic = _computeSpaceLogic(scoresByGame);
    final focus = _computeFocus(scoresByGame);
    const perception = 50.0; // MVP: fixed

    final stabilityBonus = _computeStabilityBonus(recentAllGames);

    final rawLq = speed * 0.25 +
        memory * 0.25 +
        spaceLogic * 0.30 +
        focus * 0.15 +
        perception * 0.05;

    final lq = (rawLq + stabilityBonus).clamp(0.0, 100.0);

    return AbilitySnapshot(
      lqScore: _round1(lq),
      speedScore: _round1(speed),
      memoryScore: _round1(memory),
      spaceLogicScore: _round1(spaceLogic),
      focusScore: _round1(focus),
      perceptionScore: perception,
      timestamp: DateTime.now(),
    );
  }

  // ─── Dimension Computations ──────────────────────────────────────

  double _computeSpeed(Map<String, List<ScoreRecord>> byGame) {
    // reactionTime (60%) + schulteGrid (40%)
    final reaction = _gameScoreNormalized(
      byGame[GameType.reactionTime.id],
      _normalizeReactionTime,
    );
    final schulte = _gameScoreNormalized(
      byGame[GameType.schulteGrid.id],
      _normalizeSchulte,
    );
    return _weightedAvg([reaction, schulte], [0.60, 0.40]);
  }

  double _computeMemory(Map<String, List<ScoreRecord>> byGame) {
    // numberMemory(35%) + visualMemory(25%) + sequenceMemory(25%) + reverseMemory(15%)
    final numMem = _gameScoreNormalized(
      byGame[GameType.numberMemory.id],
      _normalizeMemoryLength,
    );
    final visMem = _gameScoreNormalized(
      byGame[GameType.visualMemory.id],
      _normalizeVisualMemory,
    );
    final seqMem = _gameScoreNormalized(
      byGame[GameType.sequenceMemory.id],
      _normalizeSequenceLength,
    );
    final revMem = _gameScoreNormalized(
      byGame[GameType.reverseMemory.id],
      _normalizeReverseLength,
    );
    return _weightedAvg(
      [numMem, visMem, seqMem, revMem],
      [0.35, 0.25, 0.25, 0.15],
    );
  }

  double _computeSpaceLogic(Map<String, List<ScoreRecord>> byGame) {
    // numberMatrix(20%) + sequenceMemory(15%) + visualMemory(15%)
    // + slidingPuzzle(20%) + hanoi(20%) + reverseMemory(10%)
    final numMatrix = _gameScoreNormalized(
      byGame[GameType.numberMatrix.id],
      _normalizeNumberMatrix,
    );
    final seqMem = _gameScoreNormalized(
      byGame[GameType.sequenceMemory.id],
      _normalizeSequenceLength,
    );
    final visMem = _gameScoreNormalized(
      byGame[GameType.visualMemory.id],
      _normalizeVisualMemory,
    );
    final sliding = _gameScoreNormalized(
      byGame[GameType.slidingPuzzle.id],
      _normalizeSlidingPuzzle,
    );
    final hanoi = _gameScoreNormalized(
      byGame[GameType.towerOfHanoi.id],
      _normalizeHanoi,
    );
    final revMem = _gameScoreNormalized(
      byGame[GameType.reverseMemory.id],
      _normalizeReverseLength,
    );
    return _weightedAvg(
      [numMatrix, seqMem, visMem, sliding, hanoi, revMem],
      [0.20, 0.15, 0.15, 0.20, 0.20, 0.10],
    );
  }

  double _computeFocus(Map<String, List<ScoreRecord>> byGame) {
    // stroop(50%) + schulteGrid(30%) + numberMatrix(20%)
    final stroop = _gameScoreNormalized(
      byGame[GameType.stroopTest.id],
      _normalizeStroop,
    );
    final schulte = _gameScoreNormalized(
      byGame[GameType.schulteGrid.id],
      _normalizeSchulte,
    );
    final numMatrix = _gameScoreNormalized(
      byGame[GameType.numberMatrix.id],
      _normalizeNumberMatrix,
    );
    return _weightedAvg([stroop, schulte, numMatrix], [0.50, 0.30, 0.20]);
  }

  // ─── Stability Bonus ─────────────────────────────────────────────

  /// Returns 0-5 based on consistency of recent scores
  double _computeStabilityBonus(List<ScoreRecord> recent) {
    if (recent.length < 3) return 0.0; // not enough data → no bonus
    final scores = recent.take(10).map((r) => r.score).toList();
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    if (mean == 0) return 0;
    final variance = scores
            .map((s) => math.pow(s - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        scores.length;
    final stdDev = math.sqrt(variance);
    final cv = stdDev / mean; // coefficient of variation
    if (cv <= 0.10) return 5.0;
    if (cv <= 0.20) return 3.0;
    if (cv <= 0.30) return 1.0;
    return 0.0;
  }

  // ─── Normalizer Functions (raw score → 0-100) ─────────────────────

  /// Reaction Time: raw is average ms. Reference: 200ms=100, 600ms=0
  double _normalizeReactionTime(double ms) {
    // Sigmoid around reference: world-class ~150ms, average ~300ms, slow ~600ms
    return _sigmoid(ms, ref: 300, scale: 100).clamp(0, 100);
  }

  /// Schulte Grid: raw is ms to complete 3x3. Reference: 10s=100, 60s=0
  double _normalizeSchulte(double ms) {
    // Time in ms → score (lower is better)
    return _sigmoid(ms / 1000.0, ref: 25, scale: 10, invert: true).clamp(0, 100);
  }

  /// Number Memory: raw is max digit length. Reference: 7±2 digits
  double _normalizeMemoryLength(double length) {
    // 3=10, 7=60, 10=100
    return _linearMap(length, minIn: 3, maxIn: 10, minOut: 10, maxOut: 100);
  }

  /// Visual Memory: raw is max correct cells. Reference: 3=20, 10=100
  double _normalizeVisualMemory(double cells) {
    return _linearMap(cells, minIn: 1, maxIn: 12, minOut: 5, maxOut: 100);
  }

  /// Sequence Memory: raw is max sequence length
  double _normalizeSequenceLength(double length) {
    return _linearMap(length, minIn: 2, maxIn: 15, minOut: 5, maxOut: 100);
  }

  /// Number Matrix: raw is completion time in ms. Reference: 30s=100, 120s=0
  double _normalizeNumberMatrix(double ms) {
    return _sigmoid(ms / 1000.0, ref: 60, scale: 20, invert: true).clamp(0, 100);
  }

  /// Reverse Memory: raw is max reversed length
  double _normalizeReverseLength(double length) {
    return _linearMap(length, minIn: 2, maxIn: 8, minOut: 5, maxOut: 100);
  }

  /// Stroop Test: raw is correct count (out of 30). Reference: 20=60, 30=100
  double _normalizeStroop(double correct) {
    return _linearMap(correct, minIn: 0, maxIn: 30, minOut: 0, maxOut: 100);
  }

  /// Sliding Puzzle: raw is move count for 3x3. Reference: 20 moves=100, 100=0
  double _normalizeSlidingPuzzle(double moves) {
    return _sigmoid(moves, ref: 40, scale: 20, invert: true).clamp(0, 100);
  }

  /// Tower of Hanoi: raw is moves taken for 3 discs. Optimal = 7.
  double _normalizeHanoi(double moves) {
    // metadata stores disc count; approximate optimal = 2^n - 1
    return _sigmoid(moves, ref: 15, scale: 8, invert: true).clamp(0, 100);
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  /// Robust per-game normalized score (0-100):
  /// - 70% recent average (last up to 5 attempts)
  /// - 30% top-K average (best up to 3 attempts)
  /// - confidence scaling for low sample counts
  double _gameScoreNormalized(
    List<ScoreRecord>? records,
    double Function(double) normalize,
  ) {
    if (records == null || records.isEmpty) return 0;
    final normalizedRecent = records
        .take(5)
        .map((r) => normalize(r.score).clamp(0, 100).toDouble())
        .toList();
    final recentAvg =
        normalizedRecent.reduce((a, b) => a + b) / normalizedRecent.length;

    final normalizedAll = records
        .map((r) => normalize(r.score).clamp(0, 100).toDouble())
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final topK = normalizedAll.take(math.min(3, normalizedAll.length)).toList();
    final topAvg = topK.reduce((a, b) => a + b) / topK.length;

    final blended = recentAvg * 0.70 + topAvg * 0.30;
    final attempts = records.length;
    final confidenceScale = (0.55 + 0.45 * (attempts / 6).clamp(0.0, 1.0));
    return (blended * confidenceScale).clamp(0.0, 100.0);
  }

  /// Weighted average over all dimensions.
  /// Missing games remain 0 and are not scaled up.
  double _weightedAvg(List<double> values, List<double> weights) {
    assert(values.length == weights.length);
    double sum = 0;
    double totalWeight = 0;
    for (int i = 0; i < values.length; i++) {
      sum += values[i] * weights[i];
      totalWeight += weights[i];
    }
    if (totalWeight == 0) return 0;
    return (sum / totalWeight).clamp(0, 100);
  }

  /// Linear mapping with clamping
  double _linearMap(
    double value, {
    required double minIn,
    required double maxIn,
    required double minOut,
    required double maxOut,
  }) {
    if (maxIn == minIn) return minOut;
    final t = ((value - minIn) / (maxIn - minIn)).clamp(0.0, 1.0);
    return minOut + t * (maxOut - minOut);
  }

  /// Sigmoid-based mapping: invert=true means lower input = higher score
  double _sigmoid(
    double value, {
    required double ref, // midpoint (maps to ~50)
    required double scale, // steepness
    bool invert = false,
  }) {
    final x = invert ? (ref - value) : (value - ref);
    final s = 1.0 / (1.0 + math.exp(-x / scale));
    return (s * 100).clamp(0, 100);
  }

  double _round1(double v) => (v * 10).round() / 10;
}
