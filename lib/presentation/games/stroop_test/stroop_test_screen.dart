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

// ─── Color entries for Stroop ─────────────────────────────────────────────────
class _StroopColor {
  final String nameAr;
  final String nameEn;
  final String nameZh;
  final Color value;

  const _StroopColor(this.nameAr, this.nameEn, this.nameZh, this.value);
}

const _stroopColors = [
  _StroopColor('أحمر', 'Red', '红', AppColors.colorRed),
  _StroopColor('أزرق', 'Blue', '蓝', AppColors.colorBlue),
  _StroopColor('أخضر', 'Green', '绿', AppColors.colorGreen),
  _StroopColor('أصفر', 'Yellow', '黄', AppColors.colorYellow),
  _StroopColor('برتقالي', 'Orange', '橙', AppColors.colorOrange),
  _StroopColor('بنفسجي', 'Purple', '紫', AppColors.colorPurple),
  _StroopColor('سماوي', 'Cyan', '青', AppColors.colorCyan),
  _StroopColor('وردي', 'Pink', '粉', AppColors.colorPink),
];

enum _StroopPhase { config, playing, done }

class StroopTestScreen extends ConsumerStatefulWidget {
  const StroopTestScreen({super.key});

  @override
  ConsumerState<StroopTestScreen> createState() => _StroopTestScreenState();
}

class _StroopTestScreenState extends ConsumerState<StroopTestScreen> {
  static int _recommendedDifficulty = 1;

  final _rng = Random();
  _StroopPhase _phase = _StroopPhase.config;
  int _difficulty = _recommendedDifficulty;

  // Current stimulus
  late _StroopColor _word; // the word displayed (meaning = distractor)
  late _StroopColor _ink; // the actual ink color (correct answer)

  // Scoring
  int _correct = 0;
  int _current = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _challengePoints = 0;
  int _timeouts = 0;
  bool _inputLocked = false;
  final List<double> _reactionTimes = [];

  // Timer
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _stimulusTimer;

  // Flash feedback
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hydrateUnlockedDifficulty();
      Haptics.setSoundGameId(GameType.stroopTest.id);
      GameRulesHelper.ensureShownOnce(context, GameType.stroopTest);
    });
  }

  void _hydrateUnlockedDifficulty() {
    final scores =
        ref.read(scoreRepoProvider).getScoresForGame(GameType.stroopTest.id);
    var unlocked = 1;
    for (final s in scores.take(60)) {
      final diff = s.difficulty.clamp(1, 3);
      final total = (s.metadata['total'] as num?)?.toInt() ?? 0;
      final correct =
          (s.metadata['correct'] as num?)?.toInt() ?? s.score.round();
      if (total <= 0) continue;
      final acc = correct / total;
      if (diff == 1 && acc >= 0.72) unlocked = max(unlocked, 2);
      if (diff == 2 && acc >= 0.80) unlocked = max(unlocked, 3);
    }
    _recommendedDifficulty = max(_recommendedDifficulty, unlocked);
    if (mounted) {
      setState(() => _difficulty = max(_difficulty, _recommendedDifficulty));
    }
  }

  @override
  void dispose() {
    _stimulusTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  int _totalStimuliFor(int difficulty) => switch (difficulty) {
        1 => 20,
        2 => 28,
        _ => 36,
      };

  int get _totalStimuli => _totalStimuliFor(_difficulty);

  int _timeLimitMsFor(int difficulty) => switch (difficulty) {
        1 => 0,
        2 => 2600,
        _ => 2000,
      };

  int get _timeLimitMs => _timeLimitMsFor(_difficulty);

  int get _basePoints => switch (_difficulty) {
        1 => 10,
        2 => 14,
        _ => 18,
      };

  int _colorCountFor(int difficulty) => switch (difficulty) {
        1 => 4,
        2 => 6,
        _ => 8,
      };

  List<_StroopColor> _colorsForDifficulty(int difficulty) =>
      _stroopColors.take(_colorCountFor(difficulty)).toList(growable: false);

  String _difficultyLabel(BuildContext context, int difficulty) =>
      switch (difficulty) {
        1 => tr(context, 'عادي', 'Normal', '普通'),
        2 => tr(context, 'صعب', 'Hard', '高难度'),
        _ => tr(context, 'تحدي', 'Challenge', '挑战'),
      };

  String _difficultyHint(BuildContext context, int difficulty) =>
      switch (difficulty) {
        1 => tr(context, '4 ألوان · إيقاع مريح', '4 colors · warm-up pace',
            '4 色 · 热身节奏'),
        2 => tr(context, '6 ألوان + وقت محدود', '6 colors + time limit',
            '6 色 + 限时'),
        _ => tr(context, '8 ألوان + عقوبة أخطاء', '8 colors + penalties',
            '8 色 + 惩罚'),
      };

  int _speedBonus(double elapsedMs) {
    if (_timeLimitMs <= 0) {
      return max(0, ((1300 - elapsedMs) / 180).floor());
    }
    final leftMs = (_timeLimitMs - elapsedMs).clamp(0, _timeLimitMs).toDouble();
    final step = _timeLimitMs / 6;
    return (leftMs / step).floor();
  }

  void _onTimedOut() {
    if (!mounted || _phase != _StroopPhase.playing || _inputLocked) return;
    _stopwatch.stop();
    _resolveAnswer(
        isCorrect: false, elapsedMs: _timeLimitMs.toDouble(), timedOut: true);
  }

  Future<void> _startGame() async {
    final canStart = await GameEconomyHelper.consumeEntryCost(
      context,
      ref,
      GameType.stroopTest,
    );
    if (!canStart) return;

    setState(() {
      _phase = _StroopPhase.playing;
      _correct = 0;
      _current = 0;
      _streak = 0;
      _bestStreak = 0;
      _challengePoints = 0;
      _timeouts = 0;
      _inputLocked = false;
      _reactionTimes.clear();
      _flashColor = null;
    });
    _nextStimulus();
  }

  void _nextStimulus() {
    final activeColors = _colorsForDifficulty(_difficulty);
    // Generate a mismatched pair
    final shuffled = List.of(activeColors)..shuffle(_rng);
    _word = shuffled[0];
    _ink = shuffled.firstWhere((c) => c != _word);

    _stimulusTimer?.cancel();
    setState(() {
      _flashColor = null;
      _inputLocked = false;
    });
    _stopwatch.reset();
    _stopwatch.start();
    if (_timeLimitMs > 0) {
      _stimulusTimer = Timer(Duration(milliseconds: _timeLimitMs), _onTimedOut);
    }
  }

  void _onColorTap(Color tappedColor) {
    if (_phase != _StroopPhase.playing || _inputLocked) return;
    _stimulusTimer?.cancel();
    _stopwatch.stop();
    final elapsedMs = _stopwatch.elapsedMilliseconds.toDouble();
    _resolveAnswer(
      isCorrect: tappedColor == _ink.value,
      elapsedMs: elapsedMs,
      timedOut: false,
    );
  }

  void _resolveAnswer({
    required bool isCorrect,
    required double elapsedMs,
    required bool timedOut,
  }) {
    if (_phase != _StroopPhase.playing || _inputLocked) return;
    _inputLocked = true;

    if (isCorrect) {
      Haptics.light();
      _correct++;
      _streak++;
      _bestStreak = max(_bestStreak, _streak);
      _reactionTimes.add(elapsedMs);
      _challengePoints +=
          _basePoints + _speedBonus(elapsedMs) + min(_streak, 8);
      setState(() => _flashColor = _ink.value);
    } else {
      Haptics.medium();
      _streak = 0;
      _challengePoints = max(0, _challengePoints - (_difficulty >= 3 ? 10 : 6));
      if (timedOut) _timeouts++;
      setState(() => _flashColor = AppColors.error);
    }

    _current++;
    if (_current >= _totalStimuli) {
      Future.delayed(const Duration(milliseconds: 280), _finishGame);
      return;
    }

    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _nextStimulus();
    });
  }

  Future<void> _finishGame() async {
    _stimulusTimer?.cancel();
    final accuracy = _totalStimuli > 0 ? _correct / _totalStimuli : 0.0;
    final unlockThreshold = switch (_difficulty) {
      1 => 0.72,
      2 => 0.80,
      _ => 1.1,
    };
    final unlockedNext = _difficulty < 3 && accuracy >= unlockThreshold;
    if (unlockedNext) {
      _recommendedDifficulty = max(_recommendedDifficulty, _difficulty + 1);
    }

    final record = ScoreRecord(
      gameId: GameType.stroopTest.id,
      score: _correct.toDouble(),
      accuracy: accuracy,
      timestamp: DateTime.now(),
      difficulty: _difficulty,
      metadata: {
        'total': _totalStimuli,
        'correct': _correct,
        'points': _challengePoints,
        'bestStreak': _bestStreak,
        'timeouts': _timeouts,
        'avgMs': _reactionTimes.isEmpty
            ? 0
            : _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length,
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(scoreRepoProvider).getBestScore(
          GameType.stroopTest.id,
          lowerIsBetter: false,
          difficulty: _difficulty,
        );
    final isNewRecord = best == null || _correct >= best.score;
    final won = accuracy >= 0.68;
    final economy = await GameEconomyHelper.settleGame(
      ref,
      gameType: GameType.stroopTest,
      won: won,
      difficulty: _difficulty,
      isNewRecord: isNewRecord,
      performance: accuracy.clamp(0.0, 1.0),
    );

    if (!mounted) return;
    final pointsText = useArabicDigits(context)
        ? _challengePoints.toArabicDigits()
        : '$_challengePoints';
    final bonusLabel =
        '${tr(context, 'نقاط التحدي: ', 'Challenge Points: ', '挑战积分：')}$pointsText';

    String? challengeTip;
    if (unlockedNext) {
      final nextLabel = _difficultyLabel(context, _difficulty + 1);
      challengeTip = tr(
        context,
        'تم فتح مستوى $nextLabel! العب مجددًا للتحدي الأعلى.',
        '$nextLabel unlocked! Play again for a tougher challenge.',
        '已解锁$nextLabel！再来一局挑战更高难度。',
      );
    } else if (_difficulty < 3) {
      final need = (unlockThreshold * _totalStimuli).ceil();
      final needText =
          useArabicDigits(context) ? need.toArabicDigits() : '$need';
      challengeTip = tr(
        context,
        'أحرز $needText إجابة صحيحة لفتح المستوى التالي.',
        'Reach $needText correct answers to unlock the next difficulty.',
        '答对 $needText 题可解锁下一档难度。',
      );
    }

    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.stroopTest,
      'score': _correct.toDouble(),
      'metric': 'correct',
      'lowerIsBetter': false,
      'isNewRecord': isNewRecord,
      'bestByDifficulty': true,
      'difficulty': _difficulty,
      'bonusLabel': bonusLabel,
      'challengeTip': challengeTip,
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
          tr(context, 'اختبار ستروب', 'Stroop Test', '斯特鲁普测试'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase == _StroopPhase.playing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      useArabicDigits(context)
                          ? '${_current.toArabicDigits()}/${_totalStimuli.toArabicDigits()}'
                          : '$_current/$_totalStimuli',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.stroop),
                    ),
                    Text(
                      '${tr(context, 'صحيح', 'Correct', '正确')}: ${useArabicDigits(context) ? _correct.toArabicDigits() : _correct} · ${tr(context, 'نقاط', 'Pts', '积分')}: ${useArabicDigits(context) ? _challengePoints.toArabicDigits() : _challengePoints}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.stroopTest),
          ),
        ],
      ),
      body: switch (_phase) {
        _StroopPhase.config => _buildConfig(context),
        _StroopPhase.playing => _buildPlaying(context),
        _StroopPhase.done => _buildConfig(context),
      },
    );
  }

  Widget _buildConfig(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(
                  context,
                  'اضغط الزر الذي يطابق لون الخط — لا معنى الكلمة!',
                  'Tap the button matching the font color — not the word meaning!',
                  '点击与字体颜色匹配的按钮，而非文字含义'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DifficultyOptionList<int>(
                options: [1, 2, 3]
                    .map(
                      (d) => DifficultyOption(
                        value: d,
                        badge: '$d',
                        title: _difficultyLabel(context, d),
                        subtitle: _difficultyHint(context, d),
                        details: _difficultyMeta(context, d),
                      ),
                    )
                    .toList(),
                selectedValue: _difficulty,
                accentColor: AppColors.stroop,
                onChanged: (value) => setState(() => _difficulty = value),
              ),
            ),
            const SizedBox(height: 24),
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

  Widget _buildPlaying(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: _current / _totalStimuli,
          backgroundColor: AppColors.border,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.stroop),
          minHeight: 2,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '${tr(context, 'الصعوبة: ', 'Difficulty: ', '难度：')}${_difficultyLabel(context, _difficulty)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (_timeLimitMs > 0)
                Text(
                  tr(context, 'محدود بزمن', 'Timed', '限时'),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.stroop,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(32),
              decoration: _flashColor != null
                  ? BoxDecoration(
                      color: _flashColor!.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Text(
                tr(context, _word.nameAr, _word.nameEn, _word.nameZh),
                style: AppTypography.stroopWord.copyWith(color: _ink.value),
              ),
            ),
          ),
        ),
        // Color buttons
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: _buildColorButtons(context),
          ),
        ),
      ],
    );
  }

  String _difficultyMeta(BuildContext context, int difficulty) {
    final rounds = _totalStimuliFor(difficulty);
    final colorCount = _colorCountFor(difficulty);
    final timeLimitMs = _timeLimitMsFor(difficulty);
    if (timeLimitMs <= 0) {
      return tr(
        context,
        '$rounds جولة · $colorCount ألوان · بدون مؤقت',
        '$rounds rounds · $colorCount colors · no timer',
        '$rounds 题 · $colorCount 色 · 无单题计时',
      );
    }
    final seconds = (timeLimitMs / 1000).toStringAsFixed(1);
    return tr(
      context,
      '$rounds جولة · $colorCount ألوان · ${seconds}ث لكل سؤال',
      '$rounds rounds · $colorCount colors · $seconds s per question',
      '$rounds 题 · $colorCount 色 · 每题 $seconds 秒',
    );
  }

  Widget _buildColorButtons(BuildContext context) {
    final activeColors = _colorsForDifficulty(_difficulty);
    final columns = switch (activeColors.length) {
      <= 4 => 2,
      <= 6 => 3,
      _ => 4,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth =
            (constraints.maxWidth - ((columns - 1) * 8)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: activeColors
              .map(
                (entry) => SizedBox(
                  width: buttonWidth,
                  child: _colorBtn(context, entry),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _colorBtn(BuildContext context, _StroopColor entry) {
    final label = tr(context, entry.nameAr, entry.nameEn, entry.nameZh);
    return GestureDetector(
      onTap: () => _onColorTap(entry.value),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: entry.value.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
