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

enum _SeqPhase { config, playing, inputting, feedback }

enum _SequenceDifficulty { easy, medium, hard }

class SequenceMemoryScreen extends ConsumerStatefulWidget {
  const SequenceMemoryScreen({super.key});

  @override
  ConsumerState<SequenceMemoryScreen> createState() =>
      _SequenceMemoryScreenState();
}

class _SequenceMemoryScreenState extends ConsumerState<SequenceMemoryScreen> {
  final _rng = Random();
  _SeqPhase _phase = _SeqPhase.config;
  _SequenceDifficulty _difficulty = _SequenceDifficulty.medium;
  int _gridSize = 4;

  List<int> _sequence = []; // the target sequence
  int _playbackIndex = 0; // which cell is currently lit during playback
  int _inputIndex = 0; // how many cells user has tapped
  int? _litCell; // cell index currently lit
  int? _decoyCell; // hard mode distractor cell during playback
  bool _litCellIsError =
      false; // whether current lit cell should render as error
  bool? _lastFeedbackCorrect; // null=none, true=correct, false=wrong
  int _maxLength = 0;

  Timer? _playbackTimer;

  int _difficultyValue(_SequenceDifficulty difficulty) => switch (difficulty) {
        _SequenceDifficulty.easy => 1,
        _SequenceDifficulty.medium => 2,
        _SequenceDifficulty.hard => 3,
      };

  int _gridSizeFor(_SequenceDifficulty difficulty) => switch (difficulty) {
        _SequenceDifficulty.easy => 3,
        _SequenceDifficulty.medium => 4,
        _SequenceDifficulty.hard => 5,
      };

  int get _gridCells => _gridSize * _gridSize;

  int _startLengthFor(_SequenceDifficulty difficulty) => switch (difficulty) {
        _SequenceDifficulty.easy => 2,
        _SequenceDifficulty.medium => 3,
        _SequenceDifficulty.hard => 4,
      };

  int _goalLengthFor(_SequenceDifficulty difficulty) => switch (difficulty) {
        _SequenceDifficulty.easy => 7,
        _SequenceDifficulty.medium => 9,
        _SequenceDifficulty.hard => 11,
      };

  Duration _lightDurationFor(_SequenceDifficulty difficulty) =>
      switch (difficulty) {
        _SequenceDifficulty.easy => const Duration(milliseconds: 700),
        _SequenceDifficulty.medium => const Duration(milliseconds: 560),
        _SequenceDifficulty.hard => const Duration(milliseconds: 430),
      };

  Duration _gapDurationFor(_SequenceDifficulty difficulty) =>
      switch (difficulty) {
        _SequenceDifficulty.easy => const Duration(milliseconds: 280),
        _SequenceDifficulty.medium => const Duration(milliseconds: 180),
        _SequenceDifficulty.hard => const Duration(milliseconds: 130),
      };

  Duration _postPlaybackPauseFor(_SequenceDifficulty difficulty) =>
      switch (difficulty) {
        _SequenceDifficulty.easy => const Duration(milliseconds: 450),
        _SequenceDifficulty.medium => const Duration(milliseconds: 320),
        _SequenceDifficulty.hard => const Duration(milliseconds: 220),
      };

  Duration _betweenRoundsPauseFor(_SequenceDifficulty difficulty) =>
      switch (difficulty) {
        _SequenceDifficulty.easy => const Duration(milliseconds: 520),
        _SequenceDifficulty.medium => const Duration(milliseconds: 420),
        _SequenceDifficulty.hard => const Duration(milliseconds: 320),
      };

  String _difficultyLabel(
          BuildContext context, _SequenceDifficulty difficulty) =>
      switch (difficulty) {
        _SequenceDifficulty.easy => tr(context, 'سهل', 'Easy', '简单'),
        _SequenceDifficulty.medium => tr(context, 'متوسط', 'Medium', '中等'),
        _SequenceDifficulty.hard => tr(context, 'صعب', 'Hard', '困难'),
      };

  String _difficultyHint(
          BuildContext context, _SequenceDifficulty difficulty) =>
      switch (difficulty) {
        _SequenceDifficulty.easy => tr(context, '٣×٣ بسرعة عرض أبطأ',
            '3×3 with slower playback', '3×3，播放节奏更慢'),
        _SequenceDifficulty.medium =>
          tr(context, '٤×٤ بإيقاع متوازن', '4×4 balanced rhythm', '4×4，平衡节奏'),
        _SequenceDifficulty.hard => tr(
            context,
            'اضغط المسار البنفسجي، والأخضر للتشتيت',
            'Tap the purple path; green is distraction',
            '点击紫色轨迹，绿色为干扰'),
      };

  String _difficultyMeta(BuildContext context, _SequenceDifficulty difficulty) {
    final start = _startLengthFor(difficulty);
    final goal = _goalLengthFor(difficulty);
    final grid = _gridSizeFor(difficulty);
    return tr(
      context,
      'شبكة ${grid}×$grid · بداية $start · هدف $goal',
      '${grid}×$grid grid · Start $start · Goal $goal',
      '${grid}×$grid 网格 · 起始 $start · 目标 $goal',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.sequenceMemory.id);
      GameRulesHelper.ensureShownOnce(context, GameType.sequenceMemory);
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    final canStart = await GameEconomyHelper.consumeEntryCost(
      context,
      ref,
      GameType.sequenceMemory,
    );
    if (!canStart) return;
    final gridSize = _gridSizeFor(_difficulty);
    final startLength = _startLengthFor(_difficulty);

    setState(() {
      _gridSize = gridSize;
      _sequence = List.generate(startLength, (_) => _rng.nextInt(_gridCells));
      _maxLength = 0;
      _inputIndex = 0;
      _phase = _SeqPhase.config;
      _decoyCell = null;
      _litCell = null;
      _litCellIsError = false;
      _lastFeedbackCorrect = null;
    });
    _playSequence();
  }

  void _playSequence() {
    setState(() {
      _phase = _SeqPhase.playing;
      _playbackIndex = 0;
      _litCell = null;
      _decoyCell = null;
      _litCellIsError = false;
      _lastFeedbackCorrect = null;
    });

    _playbackTimer?.cancel();
    _playStep();
  }

  void _playStep() {
    if (_playbackIndex >= _sequence.length) {
      // Done — wait briefly then let user input
      _playbackTimer = Timer(_postPlaybackPauseFor(_difficulty), () {
        if (mounted) setState(() => _phase = _SeqPhase.inputting);
      });
      return;
    }

    final cell = _sequence[_playbackIndex];
    final decoy = _difficulty == _SequenceDifficulty.hard
        ? () {
            final candidatePool =
                List.generate(_gridCells, (i) => i).where((i) => i != cell);
            final list = candidatePool.toList(growable: false);
            if (list.isEmpty) return null;
            return list[_rng.nextInt(list.length)];
          }()
        : null;
    setState(() {
      _litCell = cell;
      _decoyCell = decoy;
      _litCellIsError = false;
    });
    Haptics.selection();

    _playbackTimer = Timer(_lightDurationFor(_difficulty), () {
      setState(() {
        _litCell = null;
        _decoyCell = null;
        _litCellIsError = false;
      });
      _playbackTimer = Timer(_gapDurationFor(_difficulty), () {
        _playbackIndex++;
        _playStep();
      });
    });
  }

  void _onCellTap(int index) {
    if (_phase != _SeqPhase.inputting) return;

    final expected = _sequence[_inputIndex];
    if (index == expected) {
      Haptics.light();
      setState(() {
        _litCell = index;
        _decoyCell = null;
        _litCellIsError = false;
        _inputIndex++;
      });

      Future.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        setState(() => _litCell = null);

        if (_inputIndex >= _sequence.length) {
          // Correct! Extend sequence
          _maxLength = _sequence.length;
          _sequence.add(_rng.nextInt(_gridCells));
          _inputIndex = 0;
          setState(() {
            _phase = _SeqPhase.feedback;
            _lastFeedbackCorrect = true;
          });
          Future.delayed(_betweenRoundsPauseFor(_difficulty), () {
            if (mounted) _playSequence();
          });
        }
      });
    } else {
      // Wrong
      Haptics.medium();
      setState(() {
        _litCell = index;
        _decoyCell = null;
        _litCellIsError = true;
        _lastFeedbackCorrect = false;
        _phase = _SeqPhase.feedback;
      });
      Future.delayed(const Duration(milliseconds: 1000), _finishGame);
    }
  }

  Future<void> _finishGame() async {
    _playbackTimer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.sequenceMemory.id,
      score: _maxLength.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _difficultyValue(_difficulty),
      metadata: {
        'maxLength': _maxLength,
        'selectedDifficulty': _difficultyValue(_difficulty),
        'gridSize': _gridSize,
        'hardDecoy': _difficulty == _SequenceDifficulty.hard,
        'startLength': _startLengthFor(_difficulty),
        'goalLength': _goalLengthFor(_difficulty),
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.sequenceMemory.id));
    final isNewRecord = best == null || _maxLength >= best.score;
    final won = _maxLength >= _goalLengthFor(_difficulty);
    final performance =
        (_maxLength / _goalLengthFor(_difficulty)).clamp(0.0, 1.0);
    final economy = await GameEconomyHelper.settleGame(
      ref,
      gameType: GameType.sequenceMemory,
      won: won,
      difficulty: _difficultyValue(_difficulty),
      isNewRecord: isNewRecord,
      performance: performance.toDouble(),
    );

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.sequenceMemory,
      'score': _maxLength.toDouble(),
      'metric': 'length',
      'lowerIsBetter': false,
      'isNewRecord': isNewRecord,
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
          tr(context, 'تسلسل', 'Sequence Memory', '序列记忆'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _SeqPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_sequence.length.toArabicDigits()} مربعات'
                      : '${_sequence.length} ${tr(context, 'مربعات', 'squares', '格')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.sequenceMemory),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () => GameRulesHelper.showRulesDialog(
                context, GameType.sequenceMemory),
          ),
        ],
      ),
      body: switch (_phase) {
        _SeqPhase.config => _buildConfig(context),
        _ => _buildGame(context),
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
            const Icon(Icons.apps, color: AppColors.sequenceMemory, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'تسلسل', 'Sequence Memory', '序列记忆'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                  context,
                  'كرّر التسلسل الذي أضاءت به المربعات',
                  'Repeat the sequence in which the squares lit up',
                  '重复亮起方格的序列'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DifficultyOptionList<_SequenceDifficulty>(
                options: _SequenceDifficulty.values
                    .map((d) => DifficultyOption(
                          value: d,
                          badge: switch (d) {
                            _SequenceDifficulty.easy => '3×3',
                            _SequenceDifficulty.medium => '4×4',
                            _SequenceDifficulty.hard => '5×5',
                          },
                          title: _difficultyLabel(context, d),
                          subtitle: _difficultyHint(context, d),
                          details: _difficultyMeta(context, d),
                        ))
                    .toList(),
                selectedValue: _difficulty,
                accentColor: AppColors.sequenceMemory,
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

  Widget _buildGame(BuildContext context) {
    final isPlayback = _phase == _SeqPhase.playing;
    final isInput = _phase == _SeqPhase.inputting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPlayback
                  ? tr(context, 'انظر...', 'Watch...', '看...')
                  : (isInput
                      ? tr(
                          context, 'كرر التسلسل', 'Repeat the sequence', '重复序列')
                      : (_lastFeedbackCorrect == false
                          ? tr(context, 'خطأ!', 'Wrong!', '错误！')
                          : tr(context, 'صحيح!', 'Correct!', '正确！'))),
              style: AppTypography.labelMedium.copyWith(
                color: _phase == _SeqPhase.feedback
                    ? (_lastFeedbackCorrect == false
                        ? AppColors.error
                        : AppColors.success)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _gridCells,
                itemBuilder: (ctx, i) {
                  final isLit = _litCell == i;
                  final isDecoy = _phase == _SeqPhase.playing &&
                      _difficulty == _SequenceDifficulty.hard &&
                      _decoyCell == i;
                  final litColor = _litCellIsError
                      ? AppColors.error
                      : AppColors.sequenceMemory;

                  return GestureDetector(
                    onTap: isInput ? () => _onCellTap(i) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isLit
                            ? litColor.withValues(alpha: 0.7)
                            : isDecoy
                                ? AppColors.reaction.withValues(alpha: 0.58)
                                : const Color(0xFF1A1A26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLit
                              ? litColor
                              : isDecoy
                                  ? AppColors.reaction
                                  : AppColors.border,
                          width: isLit || isDecoy ? 1.5 : 0.5,
                        ),
                        boxShadow: isLit
                            ? [
                                BoxShadow(
                                  color: litColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                )
                              ]
                            : isDecoy
                                ? [
                                    BoxShadow(
                                      color: AppColors.reaction
                                          .withValues(alpha: 0.28),
                                      blurRadius: 10,
                                    )
                                  ]
                                : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isInput ? 1 : 0,
                child: Center(
                  child: Text(
                    useArabicDigits(context)
                        ? '${_inputIndex.toArabicDigits()} / ${_sequence.length.toArabicDigits()}'
                        : '$_inputIndex / ${_sequence.length}',
                    style: AppTypography.caption,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
