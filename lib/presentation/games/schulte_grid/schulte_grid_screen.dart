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

class SchulteGridScreen extends ConsumerStatefulWidget {
  const SchulteGridScreen({super.key});

  @override
  ConsumerState<SchulteGridScreen> createState() => _SchulteGridScreenState();
}

class _SchulteGridScreenState extends ConsumerState<SchulteGridScreen>
    with SingleTickerProviderStateMixin {
  // ─── Game state ───────────────────────────────────────────────────
  int _gridSize = 3; // 3, 4, or 5
  List<int> _numbers = [];
  int _nextTarget = 1;
  bool _gameActive = false;
  bool _showingConfig = true;

  // ─── Timer ───────────────────────────────────────────────────────
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  String _elapsedDisplay = '0.0s';

  // ─── Flash state ─────────────────────────────────────────────────
  int? _flashIndex; // index in _numbers that just got tapped
  bool _flashCorrect = false;

  // ─── Animation ───────────────────────────────────────────────────
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _stopwatch.stop();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame() {
    final count = _gridSize * _gridSize;
    final nums = List.generate(count, (i) => i + 1)..shuffle();
    setState(() {
      _numbers = nums;
      _nextTarget = 1;
      _gameActive = true;
      _showingConfig = false;
      _flashIndex = null;
      _elapsedDisplay = '0.0s';
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
    final num = _numbers[index];
    if (num == _nextTarget) {
      Haptics.light();
      setState(() {
        _flashIndex = index;
        _flashCorrect = true;
        _nextTarget++;
      });
      _pulseController.forward(from: 0);
      if (_nextTarget > _gridSize * _gridSize) {
        _finishGame();
      } else {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) setState(() => _flashIndex = null);
        });
      }
    } else {
      Haptics.medium();
      setState(() {
        _flashIndex = index;
        _flashCorrect = false;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
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
      gameId: GameType.schulteGrid.id,
      score: elapsedMs,
      timestamp: DateTime.now(),
      difficulty: _gridSize - 2, // 1=3x3, 2=4x4, 3=5x5
      metadata: {'gridSize': _gridSize},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.schulteGrid.id));
    final isNewRecord = best == null || elapsedMs <= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.schulteGrid,
      'score': elapsedMs,
      'metric': 'time',
      'lowerIsBetter': true,
      'isNewRecord': isNewRecord,
      'gridSize': _gridSize,
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
          isAr ? 'شبكة شولت' : 'Schulte Grid',
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
                    color: AppColors.schulte,
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

  // ─── Config / difficulty selection ───────────────────────────────
  Widget _buildConfig(bool isAr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAr ? 'اختر الحجم' : 'Choose Size',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SizeButton(
                  label: isAr ? '٣×٣' : '3×3',
                  sublabel: isAr ? 'سهل' : 'Easy',
                  selected: _gridSize == 3,
                  color: AppColors.schulte,
                  onTap: () => setState(() => _gridSize = 3),
                ),
                const SizedBox(width: 12),
                _SizeButton(
                  label: isAr ? '٤×٤' : '4×4',
                  sublabel: isAr ? 'متوسط' : 'Medium',
                  selected: _gridSize == 4,
                  color: AppColors.schulte,
                  onTap: () => setState(() => _gridSize = 4),
                ),
                const SizedBox(width: 12),
                _SizeButton(
                  label: isAr ? '٥×٥' : '5×5',
                  sublabel: isAr ? 'صعب' : 'Hard',
                  selected: _gridSize == 5,
                  color: AppColors.schulte,
                  onTap: () => setState(() => _gridSize = 5),
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

  // ─── Active grid ─────────────────────────────────────────────────
  Widget _buildGrid(bool isAr) {
    const padding = 20.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Next target hint
            Text(
              isAr
                  ? 'اضغط: ${_nextTarget.toArabicDigits()}'
                  : 'Tap: $_nextTarget',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Grid
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _numbers.length,
                itemBuilder: (ctx, i) {
                  final num = _numbers[i];
                  final isFlash = _flashIndex == i;
                  final isDone = num < _nextTarget;

                  return _SchulteCell(
                    number: num,
                    isFlashing: isFlash,
                    flashCorrect: _flashCorrect,
                    isDone: isDone,
                    accentColor: AppColors.schulte,
                    useArabic: isAr,
                    onTap: () => _onCellTap(i),
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

// ─── Size selection button ────────────────────────────────────────────
class _SizeButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SizeButton({
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
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [color.withValues(alpha: 0.25), color.withValues(alpha: 0.1)]
                : [const Color(0xFF1C1C28), const Color(0xFF111118)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.headingSmall.copyWith(
                color: selected ? color : AppColors.textPrimary,
              ),
            ),
            Text(
              sublabel,
              style: AppTypography.caption.copyWith(
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single grid cell ─────────────────────────────────────────────────
class _SchulteCell extends StatelessWidget {
  final int number;
  final bool isFlashing;
  final bool flashCorrect;
  final bool isDone;
  final Color accentColor;
  final bool useArabic;
  final VoidCallback onTap;

  const _SchulteCell({
    required this.number,
    required this.isFlashing,
    required this.flashCorrect,
    required this.isDone,
    required this.accentColor,
    required this.useArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flashColor = flashCorrect ? accentColor : AppColors.error;
    final bgColor = isFlashing
        ? flashColor.withValues(alpha: 0.3)
        : isDone
            ? accentColor.withValues(alpha: 0.08)
            : const Color(0xFF1A1A26);

    final textColor = isFlashing
        ? flashColor
        : isDone
            ? accentColor.withValues(alpha: 0.4)
            : AppColors.textPrimary;

    final borderColor = isFlashing
        ? flashColor
        : isDone
            ? accentColor.withValues(alpha: 0.2)
            : AppColors.border;

    return GestureDetector(
      onTap: isDone ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Center(
          child: Text(
            useArabic ? number.toArabicDigits() : '$number',
            style: AppTypography.headingSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
