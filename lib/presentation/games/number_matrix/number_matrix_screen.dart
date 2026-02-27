import 'dart:async';
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

class NumberMatrixScreen extends ConsumerStatefulWidget {
  const NumberMatrixScreen({super.key});

  @override
  ConsumerState<NumberMatrixScreen> createState() =>
      _NumberMatrixScreenState();
}

class _NumberMatrixScreenState
    extends ConsumerState<NumberMatrixScreen> {
  static const _gridSize = 5;
  static const _total = 25; // 5×5

  List<int?> _cells = []; // null = tapped/cleared
  int _nextTarget = 1;
  bool _gameActive = false;
  bool _showingConfig = true;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  String _elapsedDisplay = '0.0s';
  int? _flashIndex;

  @override
  void dispose() {
    _uiTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startGame() {
    final nums = List.generate(_total, (i) => i + 1)..shuffle();
    setState(() {
      _cells = nums;
      _nextTarget = 1;
      _gameActive = true;
      _showingConfig = false;
      _elapsedDisplay = '0.0s';
      _flashIndex = null;
    });
    _stopwatch.reset();
    _stopwatch.start();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _gameActive) {
        setState(() {
          _elapsedDisplay =
              '${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
        });
      }
    });
  }

  void _onCellTap(int index) {
    if (!_gameActive) return;
    final num = _cells[index];
    if (num == null) return; // already tapped

    if (num == _nextTarget) {
      Haptics.light();
      setState(() {
        _cells[index] = null; // clear
        _nextTarget++;
        _flashIndex = index;
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _flashIndex = null);
      });

      if (_nextTarget > _total) {
        _finishGame();
      }
    } else {
      Haptics.medium();
      // Wrong tap — no penalty, just visual feedback
      setState(() => _flashIndex = index);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _flashIndex = null);
      });
    }
  }

  Future<void> _finishGame() async {
    _stopwatch.stop();
    _uiTimer?.cancel();
    setState(() => _gameActive = false);

    final elapsedMs = _stopwatch.elapsedMilliseconds.toDouble();
    final record = ScoreRecord(
      gameId: GameType.numberMatrix.id,
      score: elapsedMs,
      timestamp: DateTime.now(),
      difficulty: 1,
      metadata: {},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.numberMatrix.id));
    final isNewRecord = best == null || elapsedMs <= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.numberMatrix,
      'score': elapsedMs,
      'metric': 'time',
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
          isAr ? 'مصفوفة الأرقام' : 'Number Matrix',
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_gameActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  _elapsedDisplay,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.numberMatrix,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _showingConfig ? _buildConfig(isAr) : _buildGrid(isAr),
    );
  }

  Widget _buildConfig(bool isAr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: AppColors.numberMatrix, size: 64),
            const SizedBox(height: 24),
            Text(
              isAr ? 'مصفوفة الأرقام' : 'Number Matrix',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'اضغط الأرقام بالترتيب من ١ إلى ٢٥ بأسرع وقت'
                  : 'Tap numbers in order from 1 to 25 as fast as possible',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
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

  Widget _buildGrid(bool isAr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAr
                  ? 'اضغط: ${_nextTarget.toArabicDigits()}'
                  : 'Tap: $_nextTarget',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: _total,
                itemBuilder: (ctx, i) {
                  final num = _cells[i];
                  final isFlash = _flashIndex == i;
                  final isEmpty = num == null;

                  return GestureDetector(
                    onTap: isEmpty ? null : () => _onCellTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isEmpty
                            ? AppColors.surface
                            : isFlash
                                ? AppColors.numberMatrix.withValues(alpha: 0.3)
                                : const Color(0xFF1A1A26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isEmpty
                              ? AppColors.border.withValues(alpha: 0.3)
                              : isFlash
                                  ? AppColors.numberMatrix
                                  : AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: isEmpty
                          ? null
                          : Center(
                              child: Text(
                                isAr ? num.toArabicDigits() : '$num',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isFlash
                                      ? AppColors.numberMatrix
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
