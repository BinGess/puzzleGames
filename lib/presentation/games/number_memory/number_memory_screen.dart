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

enum _MemPhase { config, memorize, input, feedback }

class NumberMemoryScreen extends ConsumerStatefulWidget {
  const NumberMemoryScreen({super.key});

  @override
  ConsumerState<NumberMemoryScreen> createState() =>
      _NumberMemoryScreenState();
}

class _NumberMemoryScreenState extends ConsumerState<NumberMemoryScreen> {
  static const _maxLength = 10;

  final _rng = Random();
  _MemPhase _phase = _MemPhase.config;

  int _currentLength = 3;
  String _currentSequence = '';
  String _inputValue = '';
  bool _lastCorrect = false;
  int _maxReached = 0;

  Timer? _timer;
  int _countdown = 3; // seconds remaining during memorize phase

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameRulesHelper.ensureShownOnce(context, GameType.numberMemory);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _currentLength = 3;
      _inputValue = '';
      _maxReached = 0;
      _phase = _MemPhase.config;
    });
    _startRound();
  }

  void _startRound() {
    // Generate random digit sequence
    final digits = List.generate(
        _currentLength, (_) => _rng.nextInt(10).toString());
    _currentSequence = digits.join();

    // Show duration: 3s for 3 digits, +0.5s per additional digit
    final showSecs = 3 + max(0, (_currentLength - 3) * 0.5);
    _countdown = showSecs.ceil();

    setState(() {
      _phase = _MemPhase.memorize;
      _inputValue = '';
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        setState(() => _phase = _MemPhase.input);
      }
    });
  }

  void _onDigitTap(String digit) {
    if (_phase != _MemPhase.input) return;
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
    final correct = _inputValue == _currentSequence;
    Haptics.light();

    if (correct) {
      _maxReached = _currentLength;
      _currentLength = min(_currentLength + 1, _maxLength);
      setState(() {
        _phase = _MemPhase.feedback;
        _lastCorrect = true;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _startRound();
      });
    } else {
      Haptics.medium();
      setState(() {
        _phase = _MemPhase.feedback;
        _lastCorrect = false;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _finishGame();
      });
    }
  }

  Future<void> _finishGame() async {
    _timer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.numberMemory.id,
      score: _maxReached.toDouble(),
      timestamp: DateTime.now(),
      difficulty: 1,
      metadata: {'maxLength': _maxReached},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.numberMemory.id));
    final isNewRecord = best == null || _maxReached >= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.numberMemory,
      'score': _maxReached.toDouble(),
      'metric': 'length',
      'lowerIsBetter': false,
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
          tr(context, 'ذاكرة الأرقام', 'Number Memory', '数字记忆'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _MemPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_currentLength.toArabicDigits()} أرقام'
                      : '$_currentLength ${tr(context, 'أرقام', 'digits', '位')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.numberMemory),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.numberMemory),
          ),
        ],
      ),
      body: switch (_phase) {
        _MemPhase.config => _buildConfig(context),
        _MemPhase.memorize => _buildMemorize(context),
        _MemPhase.input => _buildInput(context),
        _MemPhase.feedback => _buildFeedback(context),
      },
    );
  }

  Widget _buildConfig(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pin, color: AppColors.numberMemory, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'ذاكرة الأرقام', 'Number Memory', '数字记忆'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context,
                  'احفظ الأرقام ثم أدخلها بنفس الترتيب. يزيد الطول مع كل إجابة صحيحة.',
                  'Memorize the numbers then enter them in order. Length increases with each correct answer.',
                  '记住数字并按顺序输入。每答对一次长度增加。'),
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
            style: AppTypography.digitFlash,
            textDirection: TextDirection.ltr, // digits always LTR order
          ),
          const SizedBox(height: 32),
          Text(
            tr(context, 'يختفي خلال $_countdown ث', 'Disappears in $_countdown''s',
                '$_countdown秒后消失'),
            style: AppTypography.caption,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: _countdown / (3 + max(0, (_currentLength - 3) * 0.5).ceil()),
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.numberMemory),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final displayInput = useArabicDigits(context)
        ? _inputValue.toArabicNumerals()
        : _inputValue;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(context, 'أدخل الأرقام', 'Enter the digits', '输入数字'),
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: AppColors.numberMemory, width: 2),
                    ),
                  ),
                  child: Text(
                    displayInput.isEmpty ? '___' : displayInput,
                    style: AppTypography.digitFlash.copyWith(
                      color: displayInput.isEmpty
                          ? AppColors.textDisabled
                          : AppColors.numberMemory,
                      letterSpacing: 6,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_currentLength, (i) {
                    final filled = i < _inputValue.length;
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppColors.numberMemory
                            : AppColors.border,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        // Numpad
        SafeArea(
          top: false,
          child: _buildNumpad(context),
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _lastCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: _lastCorrect ? AppColors.success : AppColors.error,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            _lastCorrect
                ? tr(context, 'صحيح!', 'Correct!', '正确!')
                : tr(context, 'خطأ! الإجابة كانت: ', 'Wrong! Answer was: ',
                        '错误！答案是：') +
                    (useArabicDigits(context)
                        ? _currentSequence.toArabicNumerals()
                        : _currentSequence),
            style: AppTypography.headingMedium.copyWith(
              color: _lastCorrect ? AppColors.success : AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad(BuildContext context) {
    final rows = [
      ['١', '٢', '٣'],
      ['٤', '٥', '٦'],
      ['٧', '٨', '٩'],
      ['', '٠', '⌫'],
    ];

    final westernRows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    final displayRows = useArabicDigits(context) ? rows : westernRows;
    final westRows = westernRows;

    return Column(
      children: [
        ...List.generate(displayRows.length, (r) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              children: List.generate(displayRows[r].length, (c) {
                final label = displayRows[r][c];
                final westernDigit = westRows[r][c];
                if (label.isEmpty) return const Expanded(child: SizedBox());
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        if (label == '⌫') {
                          _onDelete();
                        } else {
                          _onDigitTap(westernDigit);
                        }
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.border, width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: AppTypography.headingSmall.copyWith(
                              color: label == '⌫'
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
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
        // Submit button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _inputValue.length == _currentLength ? _onSubmit : null,
              child: Text(tr(context, 'تأكيد', 'Submit', '确认')),
            ),
          ),
        ),
      ],
    );
  }
}
