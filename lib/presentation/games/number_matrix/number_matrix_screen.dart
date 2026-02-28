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

// ─── Phase ───────────────────────────────────────────────────────────────────
enum _ChimpPhase { config, showing, recalling, levelSuccess }

// ─── Screen ──────────────────────────────────────────────────────────────────
class NumberMatrixScreen extends ConsumerStatefulWidget {
  const NumberMatrixScreen({super.key});

  @override
  ConsumerState<NumberMatrixScreen> createState() => _NumberMatrixScreenState();
}

class _NumberMatrixScreenState extends ConsumerState<NumberMatrixScreen> {
  // 4×4 = 16-cell grid
  static const _cols = 4;
  static const _rows = 4;
  static const _total = _cols * _rows; // 16

  final _rng = Random();
  _ChimpPhase _phase = _ChimpPhase.config;

  // Numbers placed in grid (null = empty cell)
  List<int?> _grid = List.filled(_total, null);
  // Whether each cell has been correctly tapped
  List<bool> _done = List.filled(_total, false);

  int _level = 4; // how many numbers in current round
  int _maxCompleted = 0; // highest level fully recalled (= score)

  int _nextExpected = 1; // next number user must tap

  // Flash feedback
  int? _flashCell;
  bool _flashCorrect = false;

  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.numberMatrix.id);
      GameRulesHelper.ensureShownOnce(context, GameType.numberMatrix);
    });
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  // ─── Game logic ────────────────────────────────────────────────────────────

  void _startGame() {
    _level = 4;
    _maxCompleted = 0;
    _startRound();
  }

  void _startRound() {
    // Pick _level random positions and assign numbers 1.._level
    final positions = List.generate(_total, (i) => i)..shuffle(_rng);
    final newGrid = List<int?>.filled(_total, null);
    for (int i = 0; i < _level; i++) {
      newGrid[positions[i]] = i + 1;
    }
    setState(() {
      _grid = newGrid;
      _done = List.filled(_total, false);
      _nextExpected = 1;
      _flashCell = null;
      _phase = _ChimpPhase.showing;
    });
  }

  void _onCellTap(int index) {
    final val = _grid[index];

    // ── Showing phase: only clicking "1" advances ──
    if (_phase == _ChimpPhase.showing) {
      if (val == 1) {
        Haptics.light();
        setState(() {
          _done[index] = true;
          _nextExpected = 2;
          _flashCell = index;
          _flashCorrect = true;
          _phase = _ChimpPhase.recalling;
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _flashCell = null);
        });
      } else {
        // Wrong first tap — flash the cell red as feedback
        if (val != null) {
          Haptics.medium();
          setState(() {
            _flashCell = index;
            _flashCorrect = false;
          });
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) setState(() => _flashCell = null);
          });
        }
      }
      return;
    }

    // ── Recalling phase ──
    if (_phase != _ChimpPhase.recalling) return;
    if (_done[index]) return; // already correctly tapped

    if (val == _nextExpected) {
      // Correct
      Haptics.light();
      setState(() {
        _done[index] = true;
        _nextExpected++;
        _flashCell = index;
        _flashCorrect = true;
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _flashCell = null);
        if (_nextExpected > _level) {
          // Level complete!
          _maxCompleted = _level;
          setState(() => _phase = _ChimpPhase.levelSuccess);
          _successTimer = Timer(const Duration(milliseconds: 900), () {
            if (mounted) {
              _level++;
              _startRound();
            }
          });
        }
      });
    } else {
      // Wrong
      Haptics.medium();
      setState(() {
        _flashCell = index;
        _flashCorrect = false;
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _finishGame();
      });
    }
  }

  Future<void> _finishGame() async {
    _successTimer?.cancel();
    final score = _maxCompleted.toDouble();
    final record = ScoreRecord(
      gameId: GameType.numberMatrix.id,
      score: score,
      timestamp: DateTime.now(),
      difficulty: (_level - 4).clamp(0, 10),
      metadata: {'maxCompleted': _maxCompleted, 'failedAt': _level},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.numberMatrix.id));
    final isNewRecord = best == null || score >= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.numberMatrix,
      'score': score,
      'metric': 'length',
      'lowerIsBetter': false,
      'isNewRecord': isNewRecord,
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          tr(context, 'اختبار الشمبانزي', 'Chimp Test', '猩猩测试'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _ChimpPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? 'مستوى ${_level.toArabicDigits()}'
                      : 'Level $_level',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.numberMatrix),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.numberMatrix),
          ),
        ],
      ),
      body: switch (_phase) {
        _ChimpPhase.config => _buildConfig(context),
        _ChimpPhase.levelSuccess => _buildLevelSuccess(context),
        _ => _buildGame(context),
      },
    );
  }

  // ── Config ────────────────────────────────────────────────────────────────
  Widget _buildConfig(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology,
                color: AppColors.numberMatrix, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'اختبار الشمبانزي', 'Chimp Test', '猩猩测试'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'احفظ مواضع الأرقام — اضغط ١ أولاً، ثم تذكّر البقية!',
                'Memorize positions — tap ١ first, then recall the rest!',
                '记住位置 — 先点击１，再凭记忆完成！',
              ),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
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

  // ── Level success overlay ─────────────────────────────────────────────────
  Widget _buildLevelSuccess(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.numberMatrix, size: 72),
          const SizedBox(height: 16),
          Text(
            tr(context, 'ممتاز!', 'Excellent!', '完美！'),
            style: AppTypography.headingMedium
                .copyWith(color: AppColors.numberMatrix),
          ),
          const SizedBox(height: 6),
          Text(
            useArabicDigits(context)
                ? 'المستوى ${_level.toArabicDigits()} اكتمل ✓'
                : 'Level $_level complete ✓',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Active game grid ──────────────────────────────────────────────────────
  Widget _buildGame(BuildContext context) {
    final isShowing = _phase == _ChimpPhase.showing;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instruction hint
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                key: ValueKey(isShowing),
                isShowing
                    ? tr(context, 'اضغط على ١ للبدء', 'Tap ١ to begin',
                        '点击 １ 开始')
                    : tr(context, 'تذكّر وأكمل الترتيب', 'Recall the order',
                        '凭记忆完成顺序'),
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            // Grid
            AspectRatio(
              aspectRatio: _cols / _rows,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _cols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _total,
                itemBuilder: (_, i) => _ChimpCell(
                  value: _grid[i],
                  isDone: _done[i],
                  isFlashing: _flashCell == i,
                  flashCorrect: _flashCorrect,
                  isShowingPhase: isShowing,
                  useArabic: useArabicDigits(context),
                  accentColor: AppColors.numberMatrix,
                  onTap: () => _onCellTap(i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chimp Cell Widget ────────────────────────────────────────────────────────
class _ChimpCell extends StatelessWidget {
  final int? value;
  final bool isDone;
  final bool isFlashing;
  final bool flashCorrect;
  final bool isShowingPhase;
  final bool useArabic;
  final Color accentColor;
  final VoidCallback onTap;

  const _ChimpCell({
    required this.value,
    required this.isDone,
    required this.isFlashing,
    required this.flashCorrect,
    required this.isShowingPhase,
    required this.useArabic,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null;
    final flashColor = flashCorrect ? accentColor : AppColors.error;

    // ── Colors ──
    final Color bgColor;
    final Color borderColor;
    final double borderWidth;

    if (isFlashing) {
      bgColor = flashColor.withValues(alpha: 0.3);
      borderColor = flashColor;
      borderWidth = 1.5;
    } else if (isDone) {
      // Correctly tapped cell — subtle gold
      bgColor = accentColor.withValues(alpha: 0.12);
      borderColor = accentColor.withValues(alpha: 0.25);
      borderWidth = 0.5;
    } else if (isEmpty) {
      // Never had a number
      bgColor = AppColors.surface.withValues(alpha: 0.4);
      borderColor = AppColors.border.withValues(alpha: 0.2);
      borderWidth = 0.5;
    } else if (isShowingPhase) {
      // Has a number, visible
      bgColor = const Color(0xFF1A1A26);
      borderColor = AppColors.border;
      borderWidth = 0.5;
    } else {
      // Recalling phase — number hidden
      bgColor = const Color(0xFF181824);
      borderColor = AppColors.border.withValues(alpha: 0.5);
      borderWidth = 0.5;
    }

    // ── Label ──
    String? label;
    if (isFlashing && !isEmpty) {
      // Show the number on flash (both phases)
      label = useArabic ? value!.toArabicDigits() : '$value';
    } else if (!isDone && !isEmpty && isShowingPhase) {
      // Show number during showing phase
      label = useArabic ? value!.toArabicDigits() : '$value';
    }
    // In recalling: no label (blank squares)

    // ── Tap handler ──
    // Showing: any non-empty cell can be tapped (only "1" has effect in logic)
    // Recalling: any non-done cell is tappable (including empty = wrong)
    final bool tappable = isShowingPhase ? (!isEmpty) : (!isDone);

    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isFlashing && flashCorrect
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: label != null
            ? Center(
                child: Text(
                  label,
                  style: AppTypography.headingSmall.copyWith(
                    color: isFlashing ? flashColor : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
