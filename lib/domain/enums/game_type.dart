/// All 10 game types, ordered by priority
enum GameType {
  schulteGrid,       // 1. Schulte Grid
  reactionTime,      // 2. Reaction Time
  numberMemory,      // 3. Number Memory
  stroopTest,        // 4. Stroop Test
  visualMemory,      // 5. Visual Memory
  sequenceMemory,    // 6. Sequence Memory
  numberMatrix,      // 7. Number Matrix Test
  reverseMemory,     // 8. Reverse Memory
  slidingPuzzle,     // 9. Sliding Puzzle
  towerOfHanoi,      // 10. Tower of Hanoi
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
    GameType.numberMatrix => 'time',
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
    GameType.numberMatrix => true,
    GameType.reverseMemory => false,
    GameType.slidingPuzzle => true,
    GameType.towerOfHanoi => true,
  };

  static GameType? fromId(String id) {
    return GameType.values.where((g) => g.id == id).firstOrNull;
  }
}
