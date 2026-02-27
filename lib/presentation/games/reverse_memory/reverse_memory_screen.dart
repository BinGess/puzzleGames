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
import '../../../data/models/score_record.dart';
import '../../../domain/enums/game_type.dart';
import '../../providers/app_providers.dart';

enum _RevPhase { config, memorize, input, feedback }

class ReverseMemoryScreen extends ConsumerStatefulWidget {
  const ReverseMemoryScreen({super.key});

  @override
  ConsumerState<ReverseMemoryScreen> createState() =>
      _ReverseMemoryScreenState();
}

class _ReverseMemoryScreenState extends ConsumerState<ReverseMemoryScreen> {
  static const _maxLength = 8;

  final _rng = Random();
  _RevPhase _phase = _RevPhase.config;

  int _currentLength = 3;
  String _currentSequence = '';
  String _inputValue = '';
  int _maxReached = 0;

  Timer? _timer;
  int _countdown = 3;

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
    });
    _startRound();
  }

  void _startRound() {
    final digits = List.generate(
        _currentLength, (_) => _rng.nextInt(10).toString());
    _currentSequence = digits.join();

    final showSecs = 3 + max(0, (_currentLength - 3) * 0.5);
    _countdown = showSecs.ceil();

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
      _currentLength = min(_currentLength + 1, _maxLength);
      setState(() {
        _phase = _RevPhase.feedback;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _startRound();
      });
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
      difficulty: 1,
      metadata: {'maxLength': _maxReached},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.reverseMemory.id));
    final isNewRecord = best == null || _maxReached >= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.reverseMemory,
      'score': _maxReached.toDouble(),
      'metric': 'length',
      'lowerIsBetter': false,
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
          isAr ? 'ذاكرة العكس' : 'Reverse Memory',
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _RevPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  isAr
                      ? '${_currentLength.toArabicDigits()} أرقام'
                      : '$_currentLength digits',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.reverseMemory),
                ),
              ),
            ),
        ],
      ),
      body: switch (_phase) {
        _RevPhase.config => _buildConfig(isAr),
        _RevPhase.memorize => _buildMemorize(isAr),
        _RevPhase.input => _buildInput(isAr),
        _RevPhase.feedback => _buildFeedback(isAr),
      },
    );
  }

  Widget _buildConfig(bool isAr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, color: AppColors.reverseMemory, size: 64),
            const SizedBox(height: 24),
            Text(
              isAr ? 'ذاكرة العكس' : 'Reverse Memory',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'احفظ الأرقام ثم أدخلها بالترتيب المعكوس'
                  : 'Memorize the digits, then enter them in reverse order',
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

  Widget _buildMemorize(bool isAr) {
    final displaySeq =
        isAr ? _currentSequence.toArabicNumerals() : _currentSequence;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displaySeq,
            style: AppTypography.digitFlash.copyWith(
                color: AppColors.reverseMemory),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 32),
          Text(
            isAr ? 'يختفي خلال $_countdown ث' : 'Disappears in ${_countdown}s',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isAr) {
    final displayInput =
        isAr ? _inputValue.toArabicNumerals() : _inputValue;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAr ? 'أدخل الأرقام معكوسة' : 'Enter digits in reverse',
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? '(إذا رأيت ١٢٣ أدخل ٣٢١)'
                      : '(If you saw 123, enter 321)',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: AppColors.reverseMemory, width: 2),
                    ),
                  ),
                  child: Text(
                    displayInput.isEmpty ? '___' : displayInput,
                    style: AppTypography.digitFlash.copyWith(
                      color: displayInput.isEmpty
                          ? AppColors.textDisabled
                          : AppColors.reverseMemory,
                      letterSpacing: 6,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(top: false, child: _buildNumpad(isAr)),
      ],
    );
  }

  Widget _buildFeedback(bool isAr) {
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
                ? (isAr ? 'صحيح!' : 'Correct!')
                : (isAr
                    ? 'خطأ! الإجابة كانت: ${reversed.toArabicNumerals()}'
                    : 'Wrong! Answer was: $reversed'),
            style: AppTypography.headingMedium.copyWith(
              color: correct ? AppColors.success : AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad(bool isAr) {
    final rows = isAr
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _inputValue.length == _currentLength
                  ? _onSubmit
                  : null,
              child: Text(isAr ? 'تأكيد' : 'Submit'),
            ),
          ),
        ),
      ],
    );
  }
}
