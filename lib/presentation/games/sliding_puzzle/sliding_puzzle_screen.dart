import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/score_record.dart';
import '../../../domain/enums/game_type.dart';
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

  void _startGame() {
    final tiles = _generateSolvable(_gridSize);
    setState(() {
      _tiles = tiles;
      _moves = 0;
      _gameActive = true;
      _showingConfig = false;
    });
  }

  /// Generate a solvable puzzle by making random legal moves from solved state
  List<int> _generateSolvable(int size) {
    final total = size * size;
    // Start with solved state
    List<int> tiles = List.generate(total, (i) => (i + 1) % total);
    // Make 200 random moves from solved
    int emptyIdx = tiles.indexOf(0);
    for (int i = 0; i < 200; i++) {
      final neighbors = _neighbors(emptyIdx, size);
      final neighbor = neighbors[_rng.nextInt(neighbors.length)];
      tiles[emptyIdx] = tiles[neighbor];
      tiles[neighbor] = 0;
      emptyIdx = neighbor;
    }
    return tiles;
  }

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

    Haptics.selection();
    setState(() {
      _tiles[emptyIdx] = _tiles[index];
      _tiles[index] = 0;
      _moves++;
    });

    if (_isSolved()) {
      _gameActive = false;
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

  Future<void> _finishGame() async {
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
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          isAr ? 'لغز الأرقام' : 'Sliding Puzzle',
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_gameActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  isAr
                      ? '${_moves.toArabicDigits()} حركة'
                      : '$_moves moves',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.slidingPuzzle),
                ),
              ),
            ),
        ],
      ),
      body: _showingConfig ? _buildConfig(isAr) : _buildPuzzle(isAr),
    );
  }

  Widget _buildConfig(bool isAr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension, color: AppColors.slidingPuzzle, size: 64),
            const SizedBox(height: 24),
            Text(
              isAr ? 'لغز الأرقام' : 'Sliding Puzzle',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'رتّب الأرقام بالترتيب الصحيح بأقل عدد من الحركات'
                  : 'Arrange the numbers in order with the fewest moves',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SizePill(
                  label: isAr ? '٣×٣' : '3×3',
                  sublabel: isAr ? 'سهل' : 'Easy',
                  selected: _gridSize == 3,
                  color: AppColors.slidingPuzzle,
                  onTap: () => setState(() => _gridSize = 3),
                ),
                const SizedBox(width: 12),
                _SizePill(
                  label: isAr ? '٤×٤' : '4×4',
                  sublabel: isAr ? 'صعب' : 'Hard',
                  selected: _gridSize == 4,
                  color: AppColors.slidingPuzzle,
                  onTap: () => setState(() => _gridSize = 4),
                ),
              ],
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                child: Text(isAr ? 'ابدأ' : 'Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzle(bool isAr) {
    final total = _gridSize * _gridSize;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        : LinearGradient(
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
                            width: 1),
                  ),
                  child: isEmpty
                      ? null
                      : Center(
                          child: Text(
                            isAr ? num.toArabicDigits() : '$num',
                            style: AppTypography.headingSmall.copyWith(
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
    );
  }
}

class _SizePill extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SizePill({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.headingSmall.copyWith(
                    color: selected ? color : AppColors.textPrimary)),
            Text(sublabel,
                style: AppTypography.caption.copyWith(
                    color: selected ? color : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
