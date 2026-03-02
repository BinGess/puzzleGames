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

    var lq = (rawLq + stabilityBonus).clamp(0.0, 100.0).toDouble();

    final latest = recentAllGames.isNotEmpty ? recentAllGames.first : null;
    if (latest != null) {
      final latestNorm = _normalizeByGame(latest);
      if (_isCatastrophicRun(latest) || _isFirstStepFailure(latest)) {
        // Hard rule: first-step / catastrophic failures should never show high LQ.
        lq = math.min(lq, 10.0);
      } else if (latestNorm <= 5.0) {
        lq = math.min(lq, 12.0);
      } else if (latestNorm <= 10.0) {
        lq = math.min(lq, 18.0);
      } else if (latestNorm <= 16.0) {
        lq = math.min(lq, 25.0);
      }
    }

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

  double _metaNum(Map<String, dynamic> metadata, String key, double fallback) {
    final v = metadata[key];
    return v is num ? v.toDouble() : fallback;
  }

  bool _metaBool(Map<String, dynamic> metadata, String key) {
    final v = metadata[key];
    return v is bool ? v : false;
  }

  double _clamp01(double v) => v.clamp(0.0, 1.0).toDouble();

  int _intMeta(Map<String, dynamic> metadata, String key, int fallback) {
    final v = metadata[key];
    return v is num ? v.toInt() : fallback;
  }

  double _normalizeFromStart({
    required double score,
    required double start,
    required double goal,
  }) {
    final baseline = start - 1;
    return _clamp01((score - baseline) / (goal - baseline).clamp(1, 99)) * 100;
  }

  bool _isFirstStepFailure(ScoreRecord record) {
    final type = GameTypeId.fromId(record.gameId);
    if (type == null || type.lowerIsBetter) return false;
    final metadata = record.metadata;
    final difficulty = record.difficulty.clamp(1, 4);
    return switch (type) {
      GameType.numberMemory => record.score <=
          (_metaNum(
                metadata,
                'startLength',
                switch (difficulty) {
                  1 => 3.0,
                  2 => 5.0,
                  _ => 7.0,
                },
              ) -
              1),
      GameType.sequenceMemory => record.score <=
          (_metaNum(
                metadata,
                'startLength',
                switch (difficulty) {
                  1 => 2.0,
                  2 => 3.0,
                  _ => 4.0,
                },
              ) -
              1),
      GameType.numberMatrix => record.score <=
          (_metaNum(
                metadata,
                'startLevel',
                switch (difficulty) {
                  1 => 3.0,
                  2 => 4.0,
                  _ => 5.0,
                },
              ) -
              1),
      GameType.reverseMemory => record.score <=
          (_metaNum(
                metadata,
                'startLength',
                switch (difficulty) {
                  1 => 3.0,
                  2 => 4.0,
                  _ => 5.0,
                },
              ) -
              1),
      GameType.visualMemory => record.score <=
          (_metaNum(
                metadata,
                'startLit',
                switch (difficulty) {
                  1 => 3.0,
                  2 => 5.0,
                  _ => 6.0,
                },
              ) -
              1),
      GameType.stroopTest => record.score <= 0,
      _ => false,
    };
  }

  bool _isCatastrophicRun(ScoreRecord record) {
    final metadata = record.metadata;
    if (_metaBool(metadata, 'antiCheatFailed')) return true;
    final type = GameTypeId.fromId(record.gameId);
    if (type == null) return false;

    if (!type.lowerIsBetter && record.score <= 1e-6) return true;
    if (_isFirstStepFailure(record)) return true;
    if (type == GameType.stroopTest) {
      final total = _metaNum(metadata, 'total', 0);
      final correct = _metaNum(metadata, 'correct', record.score);
      if (total > 0 && (correct / total) <= 0.05) return true;
    }
    return false;
  }

  double _normalizeByGame(ScoreRecord record) {
    final type = GameTypeId.fromId(record.gameId);
    if (type == null) return 0;
    return switch (type) {
      GameType.reactionTime => _normalizeReactionTime(record),
      GameType.schulteGrid => _normalizeSchulte(record),
      GameType.numberMemory => _normalizeMemoryLength(record),
      GameType.visualMemory => _normalizeVisualMemory(record),
      GameType.sequenceMemory => _normalizeSequenceLength(record),
      GameType.numberMatrix => _normalizeNumberMatrix(record),
      GameType.reverseMemory => _normalizeReverseLength(record),
      GameType.stroopTest => _normalizeStroop(record),
      GameType.slidingPuzzle => _normalizeSlidingPuzzle(record),
      GameType.towerOfHanoi => _normalizeHanoi(record),
    };
  }

  /// Reaction Time: average ms, lower is better.
  double _normalizeReactionTime(ScoreRecord record) {
    final ms = record.score;
    final difficulty = record.difficulty.clamp(1, 4);
    final targetMs = switch (difficulty) {
      1 => 320.0,
      2 => 280.0,
      _ => math.max(170.0, 240.0 - (difficulty - 3) * 20.0),
    };
    final spanMs = switch (difficulty) {
      1 => 220.0,
      2 => 180.0,
      _ => math.max(110.0, 150.0 - (difficulty - 3) * 10.0),
    };
    return (_clamp01(1 - ((ms - targetMs) / spanMs)) * 100).clamp(0, 100);
  }

  /// Schulte Grid: completion time ms, lower is better. Uses grid size.
  double _normalizeSchulte(ScoreRecord record) {
    final ms = record.score;
    final grid = _intMeta(record.metadata, 'gridSize', record.difficulty + 2);
    final targetMs = switch (grid) {
      3 => 14000.0,
      4 => 30000.0,
      _ => 55000.0 + (grid - 5) * 18000.0,
    };
    final spanMs = switch (grid) {
      3 => 26000.0,
      4 => 42000.0,
      _ => 70000.0 + (grid - 5) * 22000.0,
    };
    return (_clamp01(1 - ((ms - targetMs) / spanMs)) * 100).clamp(0, 100);
  }

  /// Number Memory: max recalled length, higher is better.
  double _normalizeMemoryLength(ScoreRecord record) {
    final length = record.score;
    final difficulty = record.difficulty.clamp(1, 4);
    final start = _metaNum(
      record.metadata,
      'startLength',
      switch (difficulty) {
        1 => 3.0,
        2 => 5.0,
        _ => 7.0,
      },
    );
    final goal = _metaNum(
      record.metadata,
      'goalLength',
      switch (difficulty) {
        1 => 8.0,
        2 => 12.0,
        _ => 16.0 + (difficulty - 3) * 2.0,
      },
    );
    return _normalizeFromStart(score: length, start: start, goal: goal)
        .clamp(0, 100);
  }

  /// Visual Memory: max cells remembered over grid capacity.
  double _normalizeVisualMemory(ScoreRecord record) {
    final cells = _metaNum(record.metadata, 'maxCells', record.score);
    final gridSize =
        _intMeta(record.metadata, 'gridSize', record.difficulty == 1 ? 4 : 5);
    final startLit = _metaNum(
      record.metadata,
      'startLit',
      switch (record.difficulty.clamp(1, 4)) {
        1 => 3.0,
        2 => 5.0,
        _ => 6.0,
      },
    );
    final maxPossible = (gridSize * gridSize - 1).clamp(1, 99).toDouble();
    return _normalizeFromStart(score: cells, start: startLit, goal: maxPossible)
        .clamp(0, 100);
  }

  /// Sequence Memory: max sequence length vs difficulty goal.
  double _normalizeSequenceLength(ScoreRecord record) {
    final length = record.score;
    final difficulty = record.difficulty.clamp(1, 4);
    final start = _metaNum(
      record.metadata,
      'startLength',
      switch (difficulty) {
        1 => 2.0,
        2 => 3.0,
        _ => 4.0,
      },
    );
    final goal = _metaNum(
      record.metadata,
      'goalLength',
      switch (difficulty) {
        1 => 7.0,
        2 => 9.0,
        _ => 11.0 + (difficulty - 3) * 2.0,
      },
    );
    return _normalizeFromStart(score: length, start: start, goal: goal)
        .clamp(0, 100);
  }

  /// Number Matrix (Chimp): score is completed level count, higher is better.
  double _normalizeNumberMatrix(ScoreRecord record) {
    final level = _metaNum(record.metadata, 'maxCompleted', record.score);
    final difficulty = record.difficulty.clamp(1, 4);
    final start = _metaNum(
      record.metadata,
      'startLevel',
      switch (difficulty) {
        1 => 3.0,
        2 => 4.0,
        _ => 5.0,
      },
    );
    final goal = _metaNum(
      record.metadata,
      'goalLevel',
      switch (difficulty) {
        1 => 7.0,
        2 => 9.0,
        _ => 11.0 + (difficulty - 3) * 2.0,
      },
    );
    return _normalizeFromStart(score: level, start: start, goal: goal)
        .clamp(0, 100);
  }

  /// Reverse Memory: max reversed length vs target.
  double _normalizeReverseLength(ScoreRecord record) {
    final length = record.score;
    final difficulty = record.difficulty.clamp(1, 4);
    final start = switch (difficulty) {
      1 => 3.0,
      2 => 4.0,
      _ => 5.0,
    };
    final goal = _metaNum(
      record.metadata,
      'targetLength',
      _metaNum(
        record.metadata,
        'goalLength',
        switch (difficulty) {
          1 => 9.0,
          2 => 12.0,
          _ => 14.0 + (difficulty - 3) * 2.0,
        },
      ),
    );
    return _normalizeFromStart(score: length, start: start, goal: goal)
        .clamp(0, 100);
  }

  /// Stroop: blend of accuracy and response speed.
  double _normalizeStroop(ScoreRecord record) {
    if (_metaBool(record.metadata, 'antiCheatFailed')) return 0;
    final difficulty = record.difficulty.clamp(1, 4);
    final total = _metaNum(
      record.metadata,
      'total',
      switch (difficulty) {
        1 => 20.0,
        2 => 28.0,
        _ => 36.0 + (difficulty - 3) * 8.0,
      },
    );
    final correct = _metaNum(record.metadata, 'correct', record.score);
    final acc =
        total > 0 ? _clamp01(correct / total) : _clamp01(record.accuracy ?? 0);
    final avgMsRaw = _metaNum(record.metadata, 'avgMs', 1100.0);
    final avgMs = avgMsRaw <= 0 ? 1800.0 : avgMsRaw;
    final speed = _clamp01(1 - ((avgMs - 700.0) / 1400.0));
    final timeouts = _metaNum(record.metadata, 'timeouts', 0);
    final timeoutPenalty =
        ((timeouts / math.max(1.0, total * 0.25)) * 0.12).clamp(0.0, 0.12);
    return (_clamp01(acc * 0.85 + speed * 0.15 - timeoutPenalty) * 100)
        .clamp(0, 100);
  }

  /// Sliding Puzzle: fewer moves is better.
  double _normalizeSlidingPuzzle(ScoreRecord record) {
    final moves = record.score;
    final gridSize =
        _intMeta(record.metadata, 'gridSize', record.difficulty + 2);
    final moveTarget = switch (gridSize) {
      3 => 45.0,
      4 => 140.0,
      _ => 260.0 + (gridSize - 5) * 120.0,
    };
    return (_clamp01(1 - ((moves - moveTarget) / (moveTarget * 1.2))) * 100)
        .clamp(0, 100);
  }

  /// Tower of Hanoi: closer to optimal move count is better.
  double _normalizeHanoi(ScoreRecord record) {
    final moves = record.score.clamp(1, 99999).toDouble();
    final diskCount =
        _intMeta(record.metadata, 'diskCount', record.difficulty + 2);
    final optimal = ((1 << diskCount) - 1).toDouble();
    return (_clamp01(optimal / moves) * 100).clamp(0, 100);
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  /// Robust per-game normalized score (0-100):
  /// - 70% recent average (last up to 5 attempts)
  /// - 30% top-K average (best up to 3 attempts)
  /// - confidence scaling for low sample counts
  double _gameScoreNormalized(
    List<ScoreRecord>? records,
    double Function(ScoreRecord) normalize,
  ) {
    if (records == null || records.isEmpty) return 0;
    final normalizedRecent = records
        .take(5)
        .map((r) => normalize(r).clamp(0, 100).toDouble())
        .toList();
    final recentAvg =
        normalizedRecent.reduce((a, b) => a + b) / normalizedRecent.length;

    final normalizedAll = records
        .map((r) => normalize(r).clamp(0, 100).toDouble())
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

  double _round1(double v) => (v * 10).round() / 10;
}
