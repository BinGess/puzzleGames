import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/tr.dart';
import '../../../data/models/score_record.dart';
import '../../../domain/enums/game_type.dart';
import '../game_rules_helper.dart';
import '../../providers/app_providers.dart';

class SlidingPuzzleScreen extends ConsumerStatefulWidget {
  const SlidingPuzzleScreen({super.key});

  @override
  ConsumerState<SlidingPuzzleScreen> createState() =>
      _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends ConsumerState<SlidingPuzzleScreen> {
  int _gridSize = 3;
  List<int> _tiles = []; // 0 = empty
  int _moves = 0;
  bool _gameActive = false;
  bool _showingConfig = true;

  final _rng = Random();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  String _elapsedDisplay = '0.0s';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.slidingPuzzle.id);
      GameRulesHelper.ensureShownOnce(context, GameType.slidingPuzzle);
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startGame() {
    final tiles = _generateSolvable(_gridSize, _shuffleMoves(_gridSize));
    setState(() {
      _tiles = tiles;
      _moves = 0;
      _gameActive = true;
      _showingConfig = false;
      _elapsedDisplay = '0.0s';
    });
    _stopwatch.reset();
    _stopwatch.start();
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _gameActive) {
        setState(() {
          _elapsedDisplay =
              '${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
        });
      }
    });
  }

  /// Generate a solvable puzzle by making random legal moves from solved state
  List<int> _generateSolvable(int size, int shuffleMoves) {
    final total = size * size;
    // Start with solved state
    List<int> tiles = List.generate(total, (i) => (i + 1) % total);
    // Make random legal moves from solved to guarantee solvability
    int emptyIdx = tiles.indexOf(0);
    for (int i = 0; i < shuffleMoves; i++) {
      final neighbors = _neighbors(emptyIdx, size);
      final neighbor = neighbors[_rng.nextInt(neighbors.length)];
      tiles[emptyIdx] = tiles[neighbor];
      tiles[neighbor] = 0;
      emptyIdx = neighbor;
    }
    // Avoid edge case: still solved after random walk.
    if (_isSolvedTiles(tiles, size)) {
      final neighbors = _neighbors(emptyIdx, size);
      final neighbor = neighbors[_rng.nextInt(neighbors.length)];
      tiles[emptyIdx] = tiles[neighbor];
      tiles[neighbor] = 0;
    }
    return tiles;
  }

  int _shuffleMoves(int size) => switch (size) {
        3 => 70,
        4 => 170,
        _ => 300,
      };

  List<int> _neighbors(int idx, int size) {
    final row = idx ~/ size;
    final col = idx % size;
    final result = <int>[];
    if (row > 0) result.add((row - 1) * size + col);
    if (row < size - 1) result.add((row + 1) * size + col);
    if (col > 0) result.add(row * size + col - 1);
    if (col < size - 1) result.add(row * size + col + 1);
    return result;
  }

  void _onTileTap(int index) {
    if (!_gameActive) return;
    final emptyIdx = _tiles.indexOf(0);
    if (!_neighbors(emptyIdx, _gridSize).contains(index)) return;

    Haptics.light();
    setState(() {
      _tiles[emptyIdx] = _tiles[index];
      _tiles[index] = 0;
      _moves++;
    });

    if (_isSolved()) {
      _gameActive = false;
      Haptics.success();
      _finishGame();
    }
  }

  bool _isSolved() {
    final total = _gridSize * _gridSize;
    for (int i = 0; i < total - 1; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return _tiles[total - 1] == 0;
  }

  bool _isSolvedTiles(List<int> tiles, int size) {
    final total = size * size;
    for (int i = 0; i < total - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles[total - 1] == 0;
  }

  String _difficultyLabel(BuildContext context, int size) {
    return switch (size) {
      3 => tr(context, 'عادي', 'Normal', '普通'),
      4 => tr(context, 'صعب', 'Hard', '高难度'),
      _ => tr(context, 'تحدي', 'Challenge', '挑战'),
    };
  }

  String _difficultyHint(BuildContext context, int size) {
    return switch (size) {
      3 => tr(context, 'مناسب للبداية', 'Warm-up', '入门热身'),
      4 => tr(context, 'يتطلب تخطيطًا', 'Need planning', '需要规划'),
      _ => tr(context, 'نمط متقدم', 'Expert mode', '高手模式'),
    };
  }

  IconData _difficultyIcon(int size) {
    return switch (size) {
      3 => Icons.grid_view_rounded,
      4 => Icons.extension_rounded,
      _ => Icons.bolt_rounded,
    };
  }

  Future<void> _finishGame() async {
    _stopwatch.stop();
    _uiTimer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.slidingPuzzle.id,
      score: _moves.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _gridSize - 2,
      metadata: {'gridSize': _gridSize, 'moves': _moves},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.slidingPuzzle.id));
    final isNewRecord = best == null || _moves <= best.score;

    if (!mounted) return;

    // Show solved state briefly
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.slidingPuzzle,
      'score': _moves.toDouble(),
      'metric': 'moves',
      'lowerIsBetter': true,
      'isNewRecord': isNewRecord,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          tr(context, 'لغز الأرقام', 'Sliding Puzzle', '数字华容道'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_gameActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  _elapsedDisplay,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.slidingPuzzle,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          if (_gameActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_moves.toArabicDigits()} حركة'
                      : '$_moves ${tr(context, 'حركة', 'moves', '步')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.slidingPuzzle),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () => GameRulesHelper.showRulesDialog(
                context, GameType.slidingPuzzle),
          ),
        ],
      ),
      body: _showingConfig ? _buildConfig(context) : _buildPuzzle(context),
    );
  }

  Widget _buildConfig(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.extension, color: AppColors.slidingPuzzle, size: 64),
              const SizedBox(height: 24),
              Text(
                tr(context, 'لغز الأرقام', 'Sliding Puzzle', '数字华容道'),
                style: AppTypography.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  context,
                  'اختر مستوى الصعوبة ثم رتّب الأرقام بأقل عدد حركات',
                  'Choose a difficulty, then solve with the fewest moves',
                  '选择难度后，用最少步数完成拼图',
                ),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ...[3, 4, 5].map((size) {
                final selected = _gridSize == size;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Haptics.selection();
                      setState(() => _gridSize = size);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.slidingPuzzle.withValues(alpha: 0.16)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.slidingPuzzle
                              : AppColors.border,
                          width: selected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _difficultyIcon(size),
                            color: selected
                                ? AppColors.slidingPuzzle
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${size}×$size · ${_difficultyLabel(context, size)}',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _difficultyHint(context, size),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startGame,
                  child: Text(tr(context, 'ابدأ', 'Start', '开始')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPuzzle(BuildContext context) {
    final total = _gridSize * _gridSize;
    final tileFontSize = switch (_gridSize) {
      3 => 32.0,
      4 => 26.0,
      _ => 20.0,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          Text(
            '${tr(context, 'الصعوبة: ', 'Difficulty: ', '难度：')}${_difficultyLabel(context, _gridSize)} · ${tr(context, 'الهدف: ترتيب تصاعدي والخانة الأخيرة فارغة', 'Goal: ascending order, last cell empty', '目标：升序排列，最后一格留空')}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: total,
                  itemBuilder: (ctx, i) {
                    final num = _tiles[i];
                    final isEmpty = num == 0;

                    return GestureDetector(
                      onTap: isEmpty ? null : () => _onTileTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          gradient: isEmpty
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.surfaceElevated,
                                    AppColors.surface,
                                  ],
                                ),
                          color: isEmpty ? Colors.transparent : null,
                          borderRadius: BorderRadius.circular(10),
                          border: isEmpty
                              ? null
                              : Border.all(
                                  color: AppColors.slidingPuzzle
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                        ),
                        child: isEmpty
                            ? null
                            : Center(
                                child: Text(
                                  useArabicDigits(context)
                                      ? num.toArabicDigits()
                                      : '$num',
                                  style: AppTypography.headingSmall.copyWith(
                                    fontSize: tileFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
