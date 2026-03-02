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
import '../../common_widgets/difficulty_option_list.dart';
import '../game_economy_helper.dart';
import '../game_rules_helper.dart';
import '../../providers/app_providers.dart';

// ─── Phase ───────────────────────────────────────────────────────────────────
enum _ChimpPhase { config, showing, recalling, levelSuccess }

enum _ChimpDifficulty { easy, medium, hard }

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
  _ChimpDifficulty _difficulty = _ChimpDifficulty.medium;

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
  Timer? _recallTimer;
  int _recallTotalMs = 1;
  int _recallLeftMs = 0;

  int _difficultyValue(_ChimpDifficulty difficulty) => switch (difficulty) {
        _ChimpDifficulty.easy => 1,
        _ChimpDifficulty.medium => 2,
        _ChimpDifficulty.hard => 3,
      };

  int _startLevelFor(_ChimpDifficulty difficulty) => switch (difficulty) {
        _ChimpDifficulty.easy => 3,
        _ChimpDifficulty.medium => 4,
        _ChimpDifficulty.hard => 5,
      };

  int _goalLevelFor(_ChimpDifficulty difficulty) => switch (difficulty) {
        _ChimpDifficulty.easy => 7,
        _ChimpDifficulty.medium => 9,
        _ChimpDifficulty.hard => 11,
      };

  int _recallLimitMsFor(int level) => switch (_difficulty) {
        _ChimpDifficulty.easy => (4600 - (level - 3) * 180).clamp(2200, 4600),
        _ChimpDifficulty.medium => (3400 - (level - 4) * 220).clamp(1600, 3400),
        _ChimpDifficulty.hard => (2600 - (level - 5) * 240).clamp(1100, 2600),
      };

  String _difficultyLabel(BuildContext context, _ChimpDifficulty difficulty) =>
      switch (difficulty) {
        _ChimpDifficulty.easy => tr(context, 'سهل', 'Easy', '简单'),
        _ChimpDifficulty.medium => tr(context, 'متوسط', 'Medium', '中等'),
        _ChimpDifficulty.hard => tr(context, 'صعب', 'Hard', '困难'),
      };

  String _difficultyHint(BuildContext context, _ChimpDifficulty difficulty) =>
      switch (difficulty) {
        _ChimpDifficulty.easy => tr(context, 'بداية أسهل مع مهلة أطول',
            'Lower start level with longer timer', '更低起始等级，时限更宽'),
        _ChimpDifficulty.medium => tr(context, 'تحدٍ متوازن مع مؤقت',
            'Balanced challenge with timer', '平衡挑战，含倒计时'),
        _ChimpDifficulty.hard => tr(context, 'بداية أعلى ومؤقت أقصر',
            'Higher start level and tighter timer', '更高起始等级，时限更短'),
      };

  String _difficultyMeta(BuildContext context, _ChimpDifficulty difficulty) {
    final start = _startLevelFor(difficulty);
    final goal = _goalLevelFor(difficulty);
    return tr(
      context,
      'بداية مستوى $start · هدف $goal',
      'Start level $start · Goal $goal',
      '起始等级 $start · 目标 $goal',
    );
  }

  void _stopRecallCountdown() {
    _recallTimer?.cancel();
    _recallTimer = null;
    if (!mounted) return;
    setState(() {
      _recallLeftMs = 0;
      _recallTotalMs = 1;
    });
  }

  void _startRecallCountdown() {
    _recallTimer?.cancel();
    _recallTotalMs = _recallLimitMsFor(_level);
    _recallLeftMs = _recallTotalMs;
    _recallTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _phase != _ChimpPhase.recalling) {
        timer.cancel();
        return;
      }
      final next = _recallLeftMs - 100;
      if (next <= 0) {
        timer.cancel();
        setState(() => _recallLeftMs = 0);
        _finishGame();
        return;
      }
      setState(() => _recallLeftMs = next);
    });
  }

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
    _recallTimer?.cancel();
    super.dispose();
  }

  // ─── Game logic ────────────────────────────────────────────────────────────

  Future<void> _startGame() async {
    final canStart = await GameEconomyHelper.consumeEntryCost(
      context,
      ref,
      GameType.numberMatrix,
    );
    if (!canStart) return;

    _level = _startLevelFor(_difficulty);
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
      _recallTotalMs = 1;
      _recallLeftMs = 0;
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
        _startRecallCountdown();
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
          _stopRecallCountdown();
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
      _stopRecallCountdown();
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
    _recallTimer?.cancel();
    final score = _maxCompleted.toDouble();
    final selectedDifficulty = _difficultyValue(_difficulty);
    final record = ScoreRecord(
      gameId: GameType.numberMatrix.id,
      score: score,
      timestamp: DateTime.now(),
      difficulty: selectedDifficulty,
      metadata: {
        'maxCompleted': _maxCompleted,
        'failedAt': _level,
        'selectedDifficulty': selectedDifficulty,
        'startLevel': _startLevelFor(_difficulty),
        'goalLevel': _goalLevelFor(_difficulty),
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(scoreRepoProvider).getBestScore(
          GameType.numberMatrix.id,
          lowerIsBetter: false,
          difficulty: selectedDifficulty,
        );
    final isNewRecord = best == null || score >= best.score;
    final won = _maxCompleted >= _goalLevelFor(_difficulty);
    final performance =
        (_maxCompleted / _goalLevelFor(_difficulty)).clamp(0.0, 1.0);
    final economy = await GameEconomyHelper.settleGame(
      ref,
      gameType: GameType.numberMatrix,
      won: won,
      difficulty: selectedDifficulty,
      isNewRecord: isNewRecord,
      performance: performance.toDouble(),
    );

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.numberMatrix,
      'score': score,
      'metric': 'length',
      'lowerIsBetter': false,
      'isNewRecord': isNewRecord,
      'bestByDifficulty': true,
      'difficulty': selectedDifficulty,
      'economyLabel': GameEconomyHelper.buildRewardLabel(context, economy),
      'economyTip': GameEconomyHelper.buildRewardTip(context, economy),
      'economyWon': economy.won,
      'economyCoins': economy.coinsGained,
      'economyXp': economy.xpGained,
      'economyLevel': economy.newLevel,
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
                      : tr(context, 'مستوى $_level', 'Level $_level',
                          '第 $_level 关'),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DifficultyOptionList<_ChimpDifficulty>(
                options: _ChimpDifficulty.values
                    .map((d) => DifficultyOption(
                          value: d,
                          badge: switch (d) {
                            _ChimpDifficulty.easy => 'E',
                            _ChimpDifficulty.medium => 'M',
                            _ChimpDifficulty.hard => 'H',
                          },
                          title: _difficultyLabel(context, d),
                          subtitle: _difficultyHint(context, d),
                          details: _difficultyMeta(context, d),
                        ))
                    .toList(),
                selectedValue: _difficulty,
                accentColor: AppColors.numberMatrix,
                onChanged: (value) => setState(() => _difficulty = value),
              ),
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
                : tr(context, 'المستوى $_level اكتمل ✓',
                    'Level $_level complete ✓', '第 $_level 关完成 ✓'),
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
            if (!isShowing) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value:
                      _recallTotalMs <= 0 ? 0 : _recallLeftMs / _recallTotalMs,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.numberMatrix),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'الوقت المتبقي: ${(_recallLeftMs / 1000).toStringAsFixed(1)}ث',
                  'Time left: ${(_recallLeftMs / 1000).toStringAsFixed(1)}s',
                  '剩余时间：${(_recallLeftMs / 1000).toStringAsFixed(1)} 秒',
                ),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
            ],
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
