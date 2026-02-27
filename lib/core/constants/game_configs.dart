/// Per-game configuration constants — grid sizes, timing, max levels
abstract final class GameConfigs {
  // ─── Schulte Grid ───────────────────────────────────────────────
  static const List<int> schulteGridSizes = [3, 4, 5]; // 3x3, 4x4, 5x5

  // ─── Reaction Time ──────────────────────────────────────────────
  static const int reactionRounds = 5;
  static const double reactionMinDelaySec = 2.0;
  static const double reactionMaxDelaySec = 5.0;

  // ─── Number Memory ──────────────────────────────────────────────
  static const int numberMemoryStartLength = 3;
  static const int numberMemoryMaxLength = 10;
  static const double numberMemoryShowDuration = 3.0; // seconds
  static const double numberMemoryShowDurationFast = 2.0; // when length >= 7

  // ─── Stroop Test ────────────────────────────────────────────────
  static const int stroopTotalTrials = 30;
  static const double stroopStimulusDuration = 1.5; // seconds

  // ─── Visual Memory ──────────────────────────────────────────────
  static const List<int> visualMemoryGridSizes = [3, 4, 5];
  static const double visualMemoryFlashDuration = 1.5;
  static const double visualMemoryFlashDurationFast = 1.0; // hard
  static const int visualMemoryStartLitCells = 3;

  // ─── Sequence Memory ─────────────────────────────────────────────
  static const int sequenceMemoryGridCount = 9; // 3x3 = 9 cells
  static const int sequenceMemoryStartLength = 2;
  static const int sequenceMemoryMaxLength = 15;
  static const double sequenceMemoryFlashDuration = 0.6; // per cell
  static const double sequenceMemoryFlashGap = 0.2;

  // ─── Number Matrix Test ──────────────────────────────────────────
  static const int numberMatrixSize = 5; // 5x5 = 25 numbers

  // ─── Reverse Memory ──────────────────────────────────────────────
  static const int reverseMemoryStartLength = 3;
  static const int reverseMemoryMaxLength = 8;
  static const double reverseMemoryShowDuration = 3.0;
  static const double reverseMemoryShowDurationFast = 2.0;

  // ─── Sliding Puzzle ──────────────────────────────────────────────
  static const List<int> slidingPuzzleSizes = [3, 4]; // 3x3 (8-puzzle), 4x4 (15-puzzle)

  // ─── Tower of Hanoi ──────────────────────────────────────────────
  static const List<int> hanoiDiscCounts = [3, 4, 5, 6]; // levels
  static const int hanoiDefaultDiscs = 3;
}
