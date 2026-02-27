import 'dart:async';
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

class NumberMatrixScreen extends ConsumerStatefulWidget {
  const NumberMatrixScreen({super.key});

  @override
  ConsumerState<NumberMatrixScreen> createState() =>
      _NumberMatrixScreenState();
}

class _NumberMatrixScreenState
    extends ConsumerState<NumberMatrixScreen> {
  int _gridSize = 5;
  int get _total => _gridSize * _gridSize;

  List<int?> _cells = []; // null = tapped/cleared
  int _nextTarget = 1;
  bool _gameActive = false;
  bool _showingConfig = true;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  String _elapsedDisplay = '0.0s';
  int? _flashIndex;
  bool _flashCorrect = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameRulesHelper.ensureShownOnce(context, GameType.numberMatrix);
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startGame() {
    final nums = List.generate(_total, (i) => i + 1)..shuffle();
    _uiTimer?.cancel();
    setState(() {
      _cells = nums;
      _nextTarget = 1;
      _gameActive = true;
      _showingConfig = false;
      _elapsedDisplay = '0.0s';
      _flashIndex = null;
      _flashCorrect = false;
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
        _flashCorrect = true;
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _flashIndex = null);
      });

      if (_nextTarget > _total) {
        _finishGame();
      }
    } else {
      Haptics.medium();
      // Wrong tap — no penalty, but show clear feedback + next target hint
      setState(() {
        _flashIndex = index;
        _flashCorrect = false;
      });
      final expected = useArabicDigits(context)
          ? _nextTarget.toArabicDigits()
          : '$_nextTarget';
      final hint = tr(
        context,
        'الرقم المطلوب الآن: $expected',
        'Current target: $expected',
        '当前目标：$expected',
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(hint),
            duration: const Duration(milliseconds: 700),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      difficulty: _gridSize - 2,
      metadata: {'gridSize': _gridSize},
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          tr(context, 'مصفوفة الأرقام', 'Number Matrix', '数字矩阵'),
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
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.numberMatrix),
          ),
        ],
      ),
      body: _showingConfig ? _buildConfig(context) : _buildGrid(context),
    );
  }

  Widget _buildConfig(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app, color: AppColors.numberMatrix, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'مصفوفة الأرقام', 'Number Matrix', '数字矩阵'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context,
                  'اضغط الأرقام بالترتيب. فقط الرقم المطلوب يختفي',
                  'Tap numbers in order. Only the current target will clear',
                  '按顺序点击数字，只有当前目标会消失'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MatrixSizeBtn(
                  label: tr(context, '٣×٣', '3×3', '3×3'),
                  sublabel: tr(context, 'سهل', 'Easy', '简单'),
                  selected: _gridSize == 3,
                  color: AppColors.numberMatrix,
                  onTap: () => setState(() => _gridSize = 3),
                ),
                const SizedBox(width: 12),
                _MatrixSizeBtn(
                  label: tr(context, '٤×٤', '4×4', '4×4'),
                  sublabel: tr(context, 'متوسط', 'Medium', '中等'),
                  selected: _gridSize == 4,
                  color: AppColors.numberMatrix,
                  onTap: () => setState(() => _gridSize = 4),
                ),
                const SizedBox(width: 12),
                _MatrixSizeBtn(
                  label: tr(context, '٥×٥', '5×5', '5×5'),
                  sublabel: tr(context, 'صعب', 'Hard', '困难'),
                  selected: _gridSize == 5,
                  color: AppColors.numberMatrix,
                  onTap: () => setState(() => _gridSize = 5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              useArabicDigits(context)
                  ? '${_total.toArabicDigits()} رقم'
                  : '$_total ${tr(context, 'رقم', 'numbers', '个数字')}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 40),
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
    );
  }

  Widget _buildGrid(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'اضغط: ', 'Tap: ', '点击: ') +
                  (useArabicDigits(context)
                      ? _nextTarget.toArabicDigits()
                      : '$_nextTarget'),
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                                ? (_flashCorrect
                                    ? AppColors.numberMatrix.withValues(alpha: 0.3)
                                    : AppColors.error.withValues(alpha: 0.25))
                                : const Color(0xFF1A1A26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isEmpty
                              ? AppColors.border.withValues(alpha: 0.3)
                              : isFlash
                                  ? (_flashCorrect
                                      ? AppColors.numberMatrix
                                      : AppColors.error)
                                  : AppColors.border,
                          width: isFlash ? 1.4 : 0.5,
                        ),
                      ),
                      child: isEmpty
                          ? null
                          : Center(
                              child: Text(
                                useArabicDigits(context)
                                    ? num.toArabicDigits()
                                    : '$num',
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

class _MatrixSizeBtn extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _MatrixSizeBtn({
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
              style: AppTypography.headingSmall
                  .copyWith(color: selected ? color : AppColors.textPrimary),
            ),
            Text(
              sublabel,
              style: AppTypography.caption
                  .copyWith(color: selected ? color : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
