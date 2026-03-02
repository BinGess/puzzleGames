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

enum _RevPhase { config, memorize, input, feedback }

enum _ReverseDifficulty { easy, medium, hard }

class ReverseMemoryScreen extends ConsumerStatefulWidget {
  const ReverseMemoryScreen({super.key});

  @override
  ConsumerState<ReverseMemoryScreen> createState() =>
      _ReverseMemoryScreenState();
}

class _ReverseMemoryScreenState extends ConsumerState<ReverseMemoryScreen> {
  final _rng = Random();
  _RevPhase _phase = _RevPhase.config;
  _ReverseDifficulty _difficulty = _ReverseDifficulty.medium;

  int _currentLength = 3;
  String _currentSequence = '';
  String _inputValue = '';
  int _maxReached = 0;
  bool _clearedChallenge = false;
  double _roundDisplaySecs = 3;

  Timer? _timer;
  int _countdown = 3;

  int _difficultyValue(_ReverseDifficulty difficulty) => switch (difficulty) {
        _ReverseDifficulty.easy => 1,
        _ReverseDifficulty.medium => 2,
        _ReverseDifficulty.hard => 3,
      };

  int _startLengthFor(_ReverseDifficulty difficulty) => switch (difficulty) {
        _ReverseDifficulty.easy => 3,
        _ReverseDifficulty.medium => 4,
        _ReverseDifficulty.hard => 5,
      };

  int _goalLengthFor(_ReverseDifficulty difficulty) => switch (difficulty) {
        _ReverseDifficulty.easy => 9,
        _ReverseDifficulty.medium => 12,
        _ReverseDifficulty.hard => 14,
      };

  String _difficultyLabel(
          BuildContext context, _ReverseDifficulty difficulty) =>
      switch (difficulty) {
        _ReverseDifficulty.easy => tr(context, 'سهل', 'Easy', '简单'),
        _ReverseDifficulty.medium => tr(context, 'متوسط', 'Medium', '中等'),
        _ReverseDifficulty.hard => tr(context, 'صعب', 'Hard', '困难'),
      };

  String _difficultyHint(BuildContext context, _ReverseDifficulty difficulty) =>
      switch (difficulty) {
        _ReverseDifficulty.easy => tr(context, 'إيقاع ثابت وبداية قصيرة',
            'Steady pace, shorter strings', '节奏稳定，起始更短'),
        _ReverseDifficulty.medium => tr(context, 'ضغط متوازن في الطول',
            'Balanced pressure on sequence length', '长度压力更均衡'),
        _ReverseDifficulty.hard => tr(context, 'سلاسل أطول وتحدٍ أعلى',
            'Longer chains, higher challenge', '序列更长，挑战更高'),
      };

  String _difficultyMeta(BuildContext context, _ReverseDifficulty difficulty) {
    final start = _startLengthFor(difficulty);
    final goal = _goalLengthFor(difficulty);
    return tr(
      context,
      'بداية $start أرقام · هدف $goal',
      'Start $start digits · Goal $goal',
      '起始 $start 位 · 目标 $goal 位',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.reverseMemory.id);
      GameRulesHelper.ensureShownOnce(context, GameType.reverseMemory);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    final canStart = await GameEconomyHelper.consumeEntryCost(
      context,
      ref,
      GameType.reverseMemory,
    );
    if (!canStart) return;

    setState(() {
      _currentLength = _startLengthFor(_difficulty);
      _inputValue = '';
      _maxReached = 0;
      _clearedChallenge = false;
    });
    _startRound();
  }

  double _memorizeSeconds(int length) {
    final start = _startLengthFor(_difficulty);
    return switch (_difficulty) {
      _ReverseDifficulty.easy =>
        (4.8 - (length - start) * 0.20).clamp(2.4, 4.8),
      _ReverseDifficulty.medium =>
        (4.2 - (length - start) * 0.28).clamp(1.6, 4.2),
      _ReverseDifficulty.hard =>
        (3.0 - (length - start) * 0.20).clamp(2.0, 3.0),
    };
  }

  void _startRound() {
    final digits =
        List.generate(_currentLength, (_) => _rng.nextInt(10).toString());
    _currentSequence = digits.join();

    _roundDisplaySecs = _memorizeSeconds(_currentLength);
    _countdown = _roundDisplaySecs.ceil();

    setState(() {
      _phase = _RevPhase.memorize;
      _inputValue = '';
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        setState(() => _phase = _RevPhase.input);
      }
    });
  }

  void _onDigitTap(String digit) {
    if (_phase != _RevPhase.input) return;
    if (_inputValue.length >= _currentLength) return;
    Haptics.selection();
    setState(() => _inputValue += digit);
  }

  void _onDelete() {
    if (_inputValue.isEmpty) return;
    Haptics.selection();
    setState(
        () => _inputValue = _inputValue.substring(0, _inputValue.length - 1));
  }

  void _onSubmit() {
    if (_inputValue.length < _currentLength) return;

    // Expected = reversed original
    final reversed = _currentSequence.split('').reversed.join();
    final correct = _inputValue == reversed;

    if (correct) {
      Haptics.light();
      _maxReached = _currentLength;
      setState(() {
        _phase = _RevPhase.feedback;
      });
      if (_currentLength >= _goalLengthFor(_difficulty)) {
        _clearedChallenge = true;
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _finishGame();
        });
      } else {
        _currentLength = min(_currentLength + 1, _goalLengthFor(_difficulty));
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _startRound();
        });
      }
    } else {
      Haptics.medium();
      setState(() => _phase = _RevPhase.feedback);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _finishGame();
      });
    }
  }

  Future<void> _finishGame() async {
    _timer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.reverseMemory.id,
      score: _maxReached.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _difficultyValue(_difficulty),
      metadata: {
        'maxLength': _maxReached,
        'targetLength': _goalLengthFor(_difficulty),
        'clearedChallenge': _clearedChallenge,
        'selectedDifficulty': _difficultyValue(_difficulty),
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.reverseMemory.id));
    final isNewRecord = best == null || _maxReached >= best.score;
    final won = _clearedChallenge;
    final performance =
        (_maxReached / _goalLengthFor(_difficulty)).clamp(0.0, 1.0);
    final economy = await GameEconomyHelper.settleGame(
      ref,
      gameType: GameType.reverseMemory,
      won: won,
      difficulty: _difficultyValue(_difficulty),
      isNewRecord: isNewRecord,
      performance: performance.toDouble(),
    );

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.reverseMemory,
      'score': _maxReached.toDouble(),
      'metric': 'length',
      'lowerIsBetter': false,
      'isNewRecord': isNewRecord,
      'challengeTip': _clearedChallenge
          ? tr(
              context,
              'أكملت تحدي ${_goalLengthFor(_difficulty).toArabicDigits()} رقمًا! جرّب الآن تحسين السرعة.',
              'You cleared the ${_goalLengthFor(_difficulty)}-digit challenge! Now push for speed.',
              '你已通关 ${_goalLengthFor(_difficulty)} 位挑战！下一步挑战更快反应。',
            )
          : tr(
              context,
              'واصل التدريب لرفع أقصى طول يمكن عكسه.',
              'Keep training to push your maximum reverse length.',
              '继续训练，提升你的最大倒序长度。',
            ),
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
          tr(context, 'ذاكرة العكس', 'Reverse Memory', '数字倒序'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _RevPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_currentLength.toArabicDigits()} أرقام'
                      : '$_currentLength ${tr(context, 'أرقام', 'digits', '位')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.reverseMemory),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () => GameRulesHelper.showRulesDialog(
                context, GameType.reverseMemory),
          ),
        ],
      ),
      body: switch (_phase) {
        _RevPhase.config => _buildConfig(context),
        _RevPhase.memorize => _buildMemorize(context),
        _RevPhase.input => _buildInput(context),
        _RevPhase.feedback => _buildFeedback(context),
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
              tr(
                  context,
                  'احفظ الأرقام ثم أدخلها بالترتيب المعكوس',
                  'Memorize the digits, then enter them in reverse order',
                  '记住数字并按倒序输入'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                'التحدي يمتد حسب الصعوبة المختارة',
                'Challenge length depends on selected difficulty',
                '挑战长度取决于所选难度',
              ),
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DifficultyOptionList<_ReverseDifficulty>(
                options: _ReverseDifficulty.values
                    .map((d) => DifficultyOption(
                          value: d,
                          badge: switch (d) {
                            _ReverseDifficulty.easy => 'E',
                            _ReverseDifficulty.medium => 'M',
                            _ReverseDifficulty.hard => 'H',
                          },
                          title: _difficultyLabel(context, d),
                          subtitle: _difficultyHint(context, d),
                          details: _difficultyMeta(context, d),
                        ))
                    .toList(),
                selectedValue: _difficulty,
                accentColor: AppColors.reverseMemory,
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

  Widget _buildMemorize(BuildContext context) {
    final displaySeq = useArabicDigits(context)
        ? _currentSequence.toArabicNumerals()
        : _currentSequence;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displaySeq,
            style: AppTypography.digitFlash
                .copyWith(color: AppColors.reverseMemory),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 32),
          Text(
            tr(context, 'يختفي خلال $_countdown ث',
                'Disappears in $_countdown' 's', '$_countdown秒后消失'),
            style: AppTypography.caption,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: _countdown / _roundDisplaySecs.ceil(),
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.reverseMemory),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final displayInput =
        useArabicDigits(context) ? _inputValue.toArabicNumerals() : _inputValue;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(context, 'أدخل الأرقام معكوسة', 'Enter digits in reverse',
                      '倒序输入数字'),
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, '(إذا رأيت ١٢٣ أدخل ٣٢١)',
                      '(If you saw 123, enter 321)', '(如看到 123，输入 321)'),
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: AppColors.reverseMemory, width: 2),
                    ),
                  ),
                  child: Text(
                    displayInput.isEmpty ? '___' : displayInput,
                    style: AppTypography.digitFlash.copyWith(
                      color: displayInput.isEmpty
                          ? AppColors.textDisabled
                          : AppColors.reverseMemory,
                      letterSpacing: 4,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(top: false, child: _buildNumpad(context)),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context) {
    final reversed = _currentSequence.split('').reversed.join();
    final correct = _inputValue == reversed;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: correct ? AppColors.success : AppColors.error,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            correct
                ? (_clearedChallenge
                    ? tr(context, 'تم اجتياز التحدي! 🔥',
                        'Challenge Cleared! 🔥', '挑战通关！🔥')
                    : tr(context, 'صحيح!', 'Correct!', '正确!'))
                : tr(context, 'خطأ! الإجابة كانت: ', 'Wrong! Answer was: ',
                        '错误！答案是：') +
                    (useArabicDigits(context)
                        ? reversed.toArabicNumerals()
                        : reversed),
            style: AppTypography.headingMedium.copyWith(
              color: correct ? AppColors.success : AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad(BuildContext context) {
    final rows = useArabicDigits(context)
        ? [
            ['١', '٢', '٣'],
            ['٤', '٥', '٦'],
            ['٧', '٨', '٩'],
            ['', '٠', '⌫'],
          ]
        : [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ];
    final westRows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: [
        ...List.generate(rows.length, (r) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: List.generate(rows[r].length, (c) {
                final label = rows[r][c];
                final westernDigit = westRows[r][c];
                final isDelete = label == '⌫';
                if (label.isEmpty) return const Expanded(child: SizedBox());
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        if (isDelete) {
                          _onDelete();
                        } else {
                          _onDigitTap(westernDigit);
                        }
                      },
                      child: Container(
                        height: 62,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Center(
                          child: isDelete
                              ? const Icon(
                                  Icons.backspace_rounded,
                                  size: 30,
                                  color: AppColors.textSecondary,
                                )
                              : Text(
                                  label,
                                  style: AppTypography.headingSmall.copyWith(
                                    fontSize: 28,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _inputValue.length == _currentLength ? _onSubmit : null,
              child: Text(tr(context, 'تأكيد', 'Submit', '确认')),
            ),
          ),
        ),
      ],
    );
  }
}
