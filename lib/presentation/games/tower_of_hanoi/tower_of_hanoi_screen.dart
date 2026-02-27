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

class TowerOfHanoiScreen extends ConsumerStatefulWidget {
  const TowerOfHanoiScreen({super.key});

  @override
  ConsumerState<TowerOfHanoiScreen> createState() =>
      _TowerOfHanoiScreenState();
}

class _TowerOfHanoiScreenState extends ConsumerState<TowerOfHanoiScreen> {
  int _diskCount = 3;
  bool _showingConfig = true;

  // 3 pegs, each holds a list of disk sizes (largest = largest number)
  List<List<int>> _pegs = [[], [], []];
  int? _selectedPeg; // peg index user tapped first
  int _moves = 0;
  bool _gameActive = false;

  void _startGame() {
    // Peg 0 starts with discs from bottom (largest) to top (smallest)
    final discs = List.generate(_diskCount, (i) => _diskCount - i);
    setState(() {
      _pegs = [discs, [], []];
      _selectedPeg = null;
      _moves = 0;
      _gameActive = true;
      _showingConfig = false;
    });
  }

  void _onPegTap(int pegIndex) {
    if (!_gameActive) return;

    if (_selectedPeg == null) {
      // Select source peg — must have discs
      if (_pegs[pegIndex].isEmpty) return;
      Haptics.selection();
      setState(() => _selectedPeg = pegIndex);
    } else {
      if (_selectedPeg == pegIndex) {
        // Deselect
        setState(() => _selectedPeg = null);
        return;
      }

      final src = _selectedPeg!;
      final dst = pegIndex;
      final srcTop = _pegs[src].last;
      final dstTop = _pegs[dst].isEmpty ? null : _pegs[dst].last;

      if (dstTop != null && dstTop < srcTop) {
        // Invalid move
        Haptics.medium();
        setState(() => _selectedPeg = null);
        return;
      }

      // Valid move
      Haptics.light();
      setState(() {
        _pegs[dst].add(_pegs[src].removeLast());
        _moves++;
        _selectedPeg = null;
      });

      // Check win: all discs on peg 2 (rightmost = target in RTL)
      if (_pegs[2].length == _diskCount) {
        _gameActive = false;
        _finishGame();
      }
    }
  }

  Future<void> _finishGame() async {
    final record = ScoreRecord(
      gameId: GameType.towerOfHanoi.id,
      score: _moves.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _diskCount - 2,
      metadata: {'diskCount': _diskCount, 'moves': _moves},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.towerOfHanoi.id));
    final isNewRecord = best == null || _moves <= best.score;

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.towerOfHanoi,
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
          isAr ? 'برج هانو' : 'Tower of Hanoi',
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
                      .copyWith(color: AppColors.towerOfHanoi),
                ),
              ),
            ),
        ],
      ),
      body: _showingConfig ? _buildConfig(isAr) : _buildGame(isAr),
    );
  }

  Widget _buildConfig(bool isAr) {
    final optimalMoves = (1 << _diskCount) - 1; // 2^n - 1
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers, color: AppColors.towerOfHanoi, size: 64),
            const SizedBox(height: 24),
            Text(
              isAr ? 'برج هانو' : 'Tower of Hanoi',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'انقل جميع الأقراص من العمود إلى اليسار'
                  : 'Move all discs to the rightmost peg',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [3, 4, 5].map((n) {
                final selected = _diskCount == n;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () {
                      Haptics.selection();
                      setState(() => _diskCount = n);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 64,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.towerOfHanoi.withValues(alpha: 0.15)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.towerOfHanoi
                              : AppColors.border,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isAr ? n.toArabicDigits() : '$n',
                            style: AppTypography.headingMedium.copyWith(
                                color: selected
                                    ? AppColors.towerOfHanoi
                                    : AppColors.textPrimary),
                          ),
                          Text(
                            isAr ? 'أقراص' : 'discs',
                            style: AppTypography.caption.copyWith(
                                color: selected
                                    ? AppColors.towerOfHanoi
                                    : AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'الحد الأدنى: ${optimalMoves.toArabicDigits()} حركة'
                  : 'Optimal: $optimalMoves moves',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 40),
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

  Widget _buildGame(bool isAr) {
    return Column(
      children: [
        // Instructions
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _selectedPeg != null
                ? (isAr ? 'اختر العمود الهدف' : 'Choose destination peg')
                : (isAr ? 'اضغط على عمود لاختيار القرص العلوي' : 'Tap a peg to select the top disc'),
            style: AppTypography.caption,
          ),
        ),
        // Pegs
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(3, (pegIdx) {
                final peg = _pegs[pegIdx];
                final isSelected = _selectedPeg == pegIdx;
                final isTarget = pegIdx == 2; // rightmost = target in RTL

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onPegTap(pegIdx),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Peg label
                        Text(
                          isTarget
                              ? (isAr ? 'الهدف' : 'Goal')
                              : '',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.towerOfHanoi),
                        ),
                        const SizedBox(height: 4),
                        // Discs on peg
                        ...peg.reversed.map((diskSize) {
                          final width = 20.0 + diskSize * 16.0;
                          final isTopOfSelected = isSelected &&
                              peg.isNotEmpty &&
                              diskSize == peg.last;
                          return Container(
                            width: width,
                            height: 28,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isTopOfSelected
                                    ? [
                                        AppColors.gold,
                                        AppColors.goldMuted,
                                      ]
                                    : [
                                        AppColors.towerOfHanoi
                                            .withValues(alpha: 0.8),
                                        AppColors.towerOfHanoi
                                            .withValues(alpha: 0.5),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                        // Peg pole and base
                        Container(
                          width: 6,
                          height: 40 + _diskCount * 8.0,
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.surfaceElevated,
                        ),
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: isTarget
                                ? AppColors.towerOfHanoi.withValues(alpha: 0.5)
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isAr
                              ? (pegIdx == 0
                                  ? 'ثالث'
                                  : pegIdx == 1
                                      ? 'وسط'
                                      : 'أول')
                              : (pegIdx == 0
                                  ? 'A'
                                  : pegIdx == 1
                                      ? 'B'
                                      : 'C'),
                          style: AppTypography.caption.copyWith(
                              color: isTarget
                                  ? AppColors.towerOfHanoi
                                  : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
