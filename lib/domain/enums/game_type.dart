/// All 10 game types (IDs are stable — used as Hive keys)
enum GameType {
  schulteGrid,       // 1. Schulte Grid        (rec #1)
  reactionTime,      // 2. Reaction Time        (rec #6)
  numberMemory,      // 3. Number Memory        (rec #7)
  stroopTest,        // 4. Stroop Test          (rec #2)
  visualMemory,      // 5. Visual Memory        (rec #8)
  sequenceMemory,    // 6. Sequence / Simon     (rec #4/#9)
  numberMatrix,      // 7. Chimp Test           (rec #10)
  reverseMemory,     // 8. Reverse Memory       (rec #3)
  slidingPuzzle,     // 9. Sliding Puzzle       (rec #11)
  towerOfHanoi,      // 10. Tower of Hanoi      (rec #5)
}

extension GameTypeId on GameType {
  String get id => switch (this) {
    GameType.schulteGrid => 'schulte_grid',
    GameType.reactionTime => 'reaction_time',
    GameType.numberMemory => 'number_memory',
    GameType.stroopTest => 'stroop_test',
    GameType.visualMemory => 'visual_memory',
    GameType.sequenceMemory => 'sequence_memory',
    GameType.numberMatrix => 'number_matrix',
    GameType.reverseMemory => 'reverse_memory',
    GameType.slidingPuzzle => 'sliding_puzzle',
    GameType.towerOfHanoi => 'tower_of_hanoi',
  };

  int get priority => index + 1;

  /// Primary score label key (for display)
  /// 'time' | 'ms' | 'length' | 'correct' | 'moves'
  String get scoreMetric => switch (this) {
    GameType.schulteGrid => 'time',
    GameType.reactionTime => 'ms',
    GameType.numberMemory => 'length',
    GameType.stroopTest => 'correct',
    GameType.visualMemory => 'correct',
    GameType.sequenceMemory => 'length',
    GameType.numberMatrix => 'length',
    GameType.reverseMemory => 'length',
    GameType.slidingPuzzle => 'moves',
    GameType.towerOfHanoi => 'moves',
  };

  /// Whether a lower score is better (time-based games)
  bool get lowerIsBetter => switch (this) {
    GameType.schulteGrid => true,
    GameType.reactionTime => true,
    GameType.numberMemory => false,
    GameType.stroopTest => false,
    GameType.visualMemory => false,
    GameType.sequenceMemory => false,
    GameType.numberMatrix => false,
    GameType.reverseMemory => false,
    GameType.slidingPuzzle => true,
    GameType.towerOfHanoi => true,
  };

  static GameType? fromId(String id) {
    return GameType.values.where((g) => g.id == id).firstOrNull;
  }
}
