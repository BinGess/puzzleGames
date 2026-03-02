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

enum _VisPhase { config, showing, recalling, feedback }

class VisualMemoryScreen extends ConsumerStatefulWidget {
  const VisualMemoryScreen({super.key});

  @override
  ConsumerState<VisualMemoryScreen> createState() => _VisualMemoryScreenState();
}

class _VisualMemoryScreenState extends ConsumerState<VisualMemoryScreen> {
  int _difficultyLevel = 1; // 1 easy, 2 medium, 3 hard
  int _gridSize = 3;
  _VisPhase _phase = _VisPhase.config;

  final _rng = Random();

  // Round state
  int _numLit = 3; // cells to remember (grows)
  Set<int> _litIndices = {};
  Set<int> _decoyIndices = {};
  Set<int> _tappedIndices = {};
  int _maxCorrect = 0;

  Timer? _showTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.visualMemory.id);
      GameRulesHelper.ensureShownOnce(context, GameType.visualMemory);
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    final canStart = await GameEconomyHelper.consumeEntryCost(
      context,
      ref,
      GameType.visualMemory,
    );
    if (!canStart) return;

    final startGrid = switch (_difficultyLevel) {
      1 => 3,
      2 => 5,
      _ => 5,
    };
    final startLit = switch (_difficultyLevel) {
      1 => 3,
      2 => 5,
      _ => 6,
    };

    setState(() {
      _phase = _VisPhase.config;
      _gridSize = startGrid;
      _numLit = startLit;
      _maxCorrect = 0;
      _litIndices = {};
      _decoyIndices = {};
      _tappedIndices = {};
    });
    _startRound();
  }

  void _startRound() {
    final total = _gridSize * _gridSize;
    final indices = List.generate(total, (i) => i)..shuffle(_rng);
    final lit = indices.take(_numLit).toSet();
    final decoys = _difficultyLevel == 3
        ? () {
            final available =
                indices.where((i) => !lit.contains(i)).toList(growable: false);
            final decoyCount = min(max(2, _numLit ~/ 2), available.length);
            return available.take(decoyCount).toSet();
          }()
        : <int>{};

    setState(() {
      _litIndices = lit;
      _decoyIndices = decoys;
      _tappedIndices = {};
      _phase = _VisPhase.showing;
    });

    // Hard mode: faster flash + green decoy highlights while showing.
    final baseShowMs = _difficultyLevel == 3 ? 1200 : 1500;
    final minShowMs = _difficultyLevel == 3 ? 550 : 800;
    final showMs = max(minShowMs, baseShowMs - (_numLit - 3) * 100);
    _showTimer = Timer(Duration(milliseconds: showMs), () {
      if (mounted) {
        setState(() {
          _phase = _VisPhase.recalling;
          _decoyIndices = {};
        });
      }
    });
  }

  void _onCellTap(int index) {
    if (_phase != _VisPhase.recalling) return;
    if (_tappedIndices.contains(index)) return;

    final isCorrect = _litIndices.contains(index);
    setState(() => _tappedIndices.add(index));

    if (!isCorrect) {
      // Wrong tap — end
      Haptics.medium();
      setState(() => _phase = _VisPhase.feedback);
      Future.delayed(const Duration(milliseconds: 1000), _finishGame);
      return;
    }

    Haptics.light();

    // Check if all lit cells tapped
    if (_tappedIndices.containsAll(_litIndices)) {
      Haptics.success();
      _maxCorrect = _numLit;
      final totalCells = _gridSize * _gridSize;
      final isAtCap = _numLit >= totalCells - 1;

      // Auto-promotion pacing:
      // when current grid reaches the "only one dark cell" ceiling,
      // promote to the next grid size instead of repeating endlessly.
      if (isAtCap && _gridSize < 5) {
        _gridSize += 1;
        _numLit = _gridSize; // 4x4 starts at 4 lit cells, 5x5 starts at 5
      } else {
        _numLit = min(_numLit + 1, totalCells - 1);
      }
      setState(() => _phase = _VisPhase.feedback);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _startRound();
      });
    }
  }

  Future<void> _finishGame() async {
    _showTimer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.visualMemory.id,
      score: _maxCorrect.toDouble(),
      accuracy: 1.0,
      timestamp: DateTime.now(),
      difficulty: _difficultyLevel,
      metadata: {
        'gridSize': _gridSize,
        'maxCells': _maxCorrect,
        'difficultyMode': _difficultyLevel,
        'hardDecoy': _difficultyLevel == 3,
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(scoreRepoProvider).getBestScore(
          GameType.visualMemory.id,
          lowerIsBetter: false,
          difficulty: _difficultyLevel,
        );
    final isNewRecord = best == null || _maxCorrect >= best.score;
    final won = _maxCorrect >= 5;
    final maxPossible = (_gridSize * _gridSize - 1).toDouble().clamp(1.0, 99.0);
    final performance = (_maxCorrect / maxPossible).clamp(0.0, 1.0);
    final economy = await GameEconomyHelper.settleGame(
      ref,
      gameType: GameType.visualMemory,
      won: won,
      difficulty: _difficultyLevel,
      isNewRecord: isNewRecord,
      performance: performance.toDouble(),
    );

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.visualMemory,
      'score': _maxCorrect.toDouble(),
      'metric': 'correct',
      'lowerIsBetter': false,
      'isNewRecord': isNewRecord,
      'bestByDifficulty': true,
      'difficulty': _difficultyLevel,
      'economyLabel': GameEconomyHelper.buildRewardLabel(context, economy),
      'economyTip': GameEconomyHelper.buildRewardTip(context, economy),
      'economyWon': economy.won,
      'economyCoins': economy.coinsGained,
      'economyXp': economy.xpGained,
      'economyLevel': economy.newLevel,
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
          tr(context, 'ذاكرة بصرية', 'Visual Memory', '视觉记忆'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _VisPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_numLit.toArabicDigits()} خلايا'
                      : '$_numLit ${tr(context, 'خلايا', 'cells', '格')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.visualMemory),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.visualMemory),
          ),
        ],
      ),
      body: switch (_phase) {
        _VisPhase.config => _buildConfig(context),
        _VisPhase.showing => _buildGrid(context, showLit: true),
        _VisPhase.recalling => _buildGrid(context, showLit: false),
        _VisPhase.feedback => _buildGrid(context, showLit: true),
      },
    );
  }

  Widget _buildConfig(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'تذكّر المربعات التي أضاءت وحدد مواقعها',
                  'Remember which squares lit up and tap them', '记住亮起的方格并点击它们'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DifficultyOptionList<int>(
                options: [
                  DifficultyOption(
                    value: 1,
                    badge: tr(context, '٣×٣', '3×3', '3×3'),
                    title: tr(context, 'سهل', 'Easy', '简单'),
                    subtitle: tr(
                      context,
                      'شبكة صغيرة للبدء بثقة',
                      'Small grid to build confidence',
                      '小网格，适合快速上手',
                    ),
                    details: tr(
                      context,
                      'أخطاء أقل وسهولة أعلى في تذكر المواقع',
                      'Lower memory load for cleaner recall',
                      '记忆负担更轻，容错更高',
                    ),
                  ),
                  DifficultyOption(
                    value: 2,
                    badge: tr(context, '٥×٥', '5×5', '5×5'),
                    title: tr(context, 'متوسط', 'Medium', '中等'),
                    subtitle: tr(
                      context,
                      'شبكة أكبر لرفع ضغط التذكر',
                      'Larger board for stronger memory pressure',
                      '更大网格，记忆压力更高',
                    ),
                    details: tr(
                      context,
                      'ابدأ مباشرة من ٥×٥ دون تمهيد ٤×٤',
                      'Starts directly at 5×5 (no 4×4 warm-up)',
                      '中等模式直接从 5×5 开始',
                    ),
                  ),
                  DifficultyOption(
                    value: 3,
                    badge: tr(context, '٥×٥', '5×5', '5×5'),
                    title: tr(context, 'صعب', 'Hard', '困难'),
                    subtitle: tr(
                      context,
                      'إيقاع أسرع ومساحة تذكر أقصر',
                      'Faster pace with a shorter memory window',
                      '节奏更快，记忆窗口更短',
                    ),
                    details: tr(
                      context,
                      'الهدف هو البنفسجي فقط، والأخضر للتشويش',
                      'Target purple cells only; green is decoy',
                      '只点紫色目标块，绿色是干扰块',
                    ),
                  ),
                ],
                selectedValue: _difficultyLevel,
                accentColor: AppColors.visualMemory,
                onChanged: (value) => setState(() => _difficultyLevel = value),
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

  Widget _buildGrid(BuildContext context, {required bool showLit}) {
    final total = _gridSize * _gridSize;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _phase == _VisPhase.showing
                  ? tr(context, 'تذكّر!', 'Memorize!', '记住！')
                  : (_phase == _VisPhase.recalling
                      ? tr(context, 'اضغط المربعات', 'Tap the squares', '点击方格')
                      : (_tappedIndices.any((i) => !_litIndices.contains(i))
                          ? tr(context, 'خطأ!', 'Wrong!', '错误！')
                          : tr(context, 'صحيح!', 'Correct!', '正确！'))),
              style: AppTypography.labelMedium.copyWith(
                color: _phase == _VisPhase.feedback
                    ? (_tappedIndices.any((i) => !_litIndices.contains(i))
                        ? AppColors.error
                        : AppColors.success)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: total,
                itemBuilder: (ctx, i) {
                  final isLit = _litIndices.contains(i);
                  final isDecoy = _phase == _VisPhase.showing &&
                      _difficultyLevel == 3 &&
                      _decoyIndices.contains(i);
                  final isTapped = _tappedIndices.contains(i);
                  final isCorrectTap = isTapped && isLit;
                  final isWrongTap = isTapped && !isLit;

                  Color bgColor;
                  if (showLit && isLit) {
                    bgColor = AppColors.visualMemory.withValues(alpha: 0.7);
                  } else if (isDecoy) {
                    bgColor = AppColors.reaction.withValues(alpha: 0.58);
                  } else if (isCorrectTap) {
                    bgColor = AppColors.visualMemory.withValues(alpha: 0.4);
                  } else if (isWrongTap) {
                    bgColor = AppColors.error.withValues(alpha: 0.4);
                  } else {
                    bgColor = const Color(0xFF1A1A26);
                  }

                  return GestureDetector(
                    onTap: _phase == _VisPhase.recalling
                        ? () => _onCellTap(i)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: showLit && isLit
                              ? AppColors.visualMemory
                              : isDecoy
                                  ? AppColors.reaction
                                  : AppColors.border,
                          width: (showLit && isLit) || isDecoy ? 1.5 : 0.5,
                        ),
                        boxShadow: showLit && isLit
                            ? [
                                BoxShadow(
                                  color: AppColors.visualMemory
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                )
                              ]
                            : isDecoy
                                ? [
                                    BoxShadow(
                                      color: AppColors.reaction
                                          .withValues(alpha: 0.26),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
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
