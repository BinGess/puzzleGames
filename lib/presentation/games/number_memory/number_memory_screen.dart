import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

enum _MemDifficulty { easy, medium, hardVoice }

class NumberMemoryScreen extends ConsumerStatefulWidget {
  const NumberMemoryScreen({super.key});

  @override
  ConsumerState<NumberMemoryScreen> createState() => _NumberMemoryScreenState();
}

class _NumberMemoryScreenState extends ConsumerState<NumberMemoryScreen> {
  final _rng = Random();
  final _tts = FlutterTts();
  _MemPhase _phase = _MemPhase.config;
  _MemDifficulty _difficulty = _MemDifficulty.easy;

  int _currentLength = 3;
  String _currentSequence = '';
  String _inputValue = '';
  bool _lastCorrect = false;
  int _maxReached = 0;
  int _roundToken = 0;
  bool _isSpeaking = false;

  Timer? _timer;
  int _countdown = 3; // seconds remaining during memorize phase

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.numberMemory.id);
      GameRulesHelper.ensureShownOnce(context, GameType.numberMemory);
    });
    _tts.awaitSpeakCompletion(true);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _roundToken++;
    _tts.stop();
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _currentLength = _startLengthByDifficulty(_difficulty);
      _inputValue = '';
      _maxReached = 0;
      _phase = _MemPhase.config;
    });
    _startRound();
  }

  Future<void> _startRound() async {
    final token = ++_roundToken;
    // Generate random digit sequence
    final digits =
        List.generate(_currentLength, (_) => _rng.nextInt(10).toString());
    _currentSequence = digits.join();

    final showSecs = _memorizeDurationByDifficulty(_currentLength);
    _countdown = showSecs.ceil();

    setState(() {
      _phase = _MemPhase.memorize;
      _inputValue = '';
      _isSpeaking = _difficulty == _MemDifficulty.hardVoice;
    });

    if (_difficulty == _MemDifficulty.hardVoice) {
      await _speakSequence(_currentSequence);
      if (!mounted || token != _roundToken) return;
      setState(() => _isSpeaking = false);
    }

    if (!mounted || token != _roundToken) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || token != _roundToken) {
        t.cancel();
        return;
      }
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

    if (correct) {
      Haptics.success();
      _maxReached = _currentLength;
      _currentLength =
          min(_currentLength + 1, _maxLengthByDifficulty(_difficulty));
      setState(() {
        _phase = _MemPhase.feedback;
        _lastCorrect = true;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _startRound();
        }
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
    _roundToken++;
    _timer?.cancel();
    await _tts.stop();
    final record = ScoreRecord(
      gameId: GameType.numberMemory.id,
      score: _maxReached.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _difficulty.index + 1,
      metadata: {
        'maxLength': _maxReached,
        'mode': _difficulty.name,
        'voice': _difficulty == _MemDifficulty.hardVoice,
      },
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

  int _startLengthByDifficulty(_MemDifficulty difficulty) {
    return switch (difficulty) {
      _MemDifficulty.easy => 3,
      _MemDifficulty.medium => 4,
      _MemDifficulty.hardVoice => 5,
    };
  }

  int _maxLengthByDifficulty(_MemDifficulty difficulty) {
    return switch (difficulty) {
      _MemDifficulty.easy => 10,
      _MemDifficulty.medium => 14,
      _MemDifficulty.hardVoice => 18,
    };
  }

  double _memorizeDurationByDifficulty(int length) {
    final extra = max(0, length - _startLengthByDifficulty(_difficulty));
    return switch (_difficulty) {
      _MemDifficulty.easy => 3.2 + extra * 0.55,
      _MemDifficulty.medium => 2.4 + extra * 0.4,
      _MemDifficulty.hardVoice => 1.4 + extra * 0.22,
    };
  }

  Future<void> _speakSequence(String sequence) async {
    final locale = Localizations.localeOf(context).languageCode;
    final lang = switch (locale) {
      'zh' => 'zh-CN',
      'ar' => 'ar-SA',
      _ => 'en-US',
    };
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(0.48);
    await _tts.setQueueMode(0);
    await _tts.stop();
    final speech = sequence.split('').join(' ');
    await _tts.speak(speech);
  }

  String _difficultyTitle(BuildContext context, _MemDifficulty difficulty) {
    return switch (difficulty) {
      _MemDifficulty.easy => tr(context, '简单', 'Easy', '简单'),
      _MemDifficulty.medium => tr(context, '进阶', 'Medium', '进阶'),
      _MemDifficulty.hardVoice => tr(context, '专家语音', 'Hard Voice', '专家语音'),
    };
  }

  String _difficultySubtitle(BuildContext context, _MemDifficulty difficulty) {
    return switch (difficulty) {
      _MemDifficulty.easy => tr(context, '起始3位，显示更久',
          'Start at 3 digits, longer memory time', '从3位开始，记忆时间更长'),
      _MemDifficulty.medium => tr(context, '起始4位，更短记忆时间',
          'Start at 4 digits, shorter memory time', '从4位开始，记忆时间更短'),
      _MemDifficulty.hardVoice => tr(context, '起始5位，仅语音播报',
          'Start at 5 digits, voice-only broadcast', '从5位开始，仅语音播报'),
    };
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
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
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
        child: SingleChildScrollView(
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
                tr(
                    context,
                    'اختر الصعوبة ثم أدخل الأرقام بنفس الترتيب',
                    'Choose a difficulty and then enter digits in the same order',
                    '选择难度后按原顺序输入数字'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ..._MemDifficulty.values.map((difficulty) {
                final selected = _difficulty == difficulty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _difficulty = difficulty),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.numberMemory.withValues(alpha: 0.16)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.numberMemory
                              : AppColors.border,
                          width: selected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            difficulty == _MemDifficulty.hardVoice
                                ? Icons.record_voice_over_rounded
                                : Icons.timer_rounded,
                            color: selected
                                ? AppColors.numberMemory
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _difficultyTitle(context, difficulty),
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _difficultySubtitle(context, difficulty),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
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
      ),
    );
  }

  Widget _buildMemorize(BuildContext context) {
    final displaySeq = useArabicDigits(context)
        ? _currentSequence.toArabicNumerals()
        : _currentSequence;
    final totalCountdown = _memorizeDurationByDifficulty(_currentLength).ceil();
    final isVoiceMode = _difficulty == _MemDifficulty.hardVoice;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVoiceMode)
            Icon(
              _isSpeaking ? Icons.volume_up_rounded : Icons.hearing_rounded,
              size: 72,
              color: AppColors.numberMemory,
            )
          else
            Text(
              displaySeq,
              style: AppTypography.digitFlash,
              textDirection: TextDirection.ltr, // digits always LTR order
            ),
          const SizedBox(height: 32),
          Text(
            isVoiceMode
                ? (_isSpeaking
                    ? tr(context, 'استمع جيدًا...', 'Listen carefully...',
                        '请认真听语音...')
                    : tr(context, '开始输入 خلال $_countdown ث',
                        'Input starts in $_countdown' 's', '$_countdown秒后开始输入'))
                : tr(context, 'يختفي خلال $_countdown ث',
                    'Disappears in $_countdown' 's', '$_countdown秒后消失'),
            style: AppTypography.caption,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: _countdown / max(1, totalCountdown),
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.numberMemory),
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
                  tr(context, 'أدخل الأرقام', 'Enter the digits', '输入数字'),
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: AppColors.numberMemory, width: 2),
                    ),
                  ),
                  child: Text(
                    displayInput.isEmpty ? '___' : displayInput,
                    style: AppTypography.digitFlash.copyWith(
                      color: displayInput.isEmpty
                          ? AppColors.textDisabled
                          : AppColors.numberMemory,
                      letterSpacing: 4,
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
                        color:
                            filled ? AppColors.numberMemory : AppColors.border,
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
        // Submit button
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
