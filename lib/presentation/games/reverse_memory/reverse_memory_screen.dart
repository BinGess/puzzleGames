import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
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

enum _RevPhase { config, memorize, input, feedback }

enum _RevDifficulty { easy, medium, hardVoice }

class ReverseMemoryScreen extends ConsumerStatefulWidget {
  const ReverseMemoryScreen({super.key});

  @override
  ConsumerState<ReverseMemoryScreen> createState() =>
      _ReverseMemoryScreenState();
}

class _ReverseMemoryScreenState extends ConsumerState<ReverseMemoryScreen> {
  final _rng = Random();
  final _tts = FlutterTts();
  _RevPhase _phase = _RevPhase.config;
  _RevDifficulty _difficulty = _RevDifficulty.easy;

  int _currentLength = 3;
  String _currentSequence = '';
  String _inputValue = '';
  int _maxReached = 0;
  int _roundToken = 0;
  bool _isSpeaking = false;
  bool _voiceFallbackToText = false;

  Timer? _timer;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.reverseMemory.id);
      GameRulesHelper.ensureShownOnce(context, GameType.reverseMemory);
    });
    _tts.awaitSpeakCompletion(true);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.48);
    _tts.setQueueMode(0);
    if (!kIsWeb) {
      // Helps iOS play in more audio-focus scenarios.
      _tts.setSharedInstance(true);
      _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
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
    });
    _startRound();
  }

  Future<void> _startRound() async {
    final token = ++_roundToken;
    final digits =
        List.generate(_currentLength, (_) => _rng.nextInt(10).toString());
    _currentSequence = digits.join();

    final showSecs = _memorizeDurationByDifficulty(_currentLength);
    _countdown = showSecs.ceil();

    setState(() {
      _phase = _RevPhase.memorize;
      _inputValue = '';
      _isSpeaking = _difficulty == _RevDifficulty.hardVoice;
      _voiceFallbackToText = false;
    });

    if (_difficulty == _RevDifficulty.hardVoice) {
      final spoken = await _speakSequence(_currentSequence);
      if (!mounted || token != _roundToken) return;
      setState(() {
        _isSpeaking = false;
        _voiceFallbackToText = !spoken;
      });
      if (!spoken && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'تعذر تشغيل الصوت، تم التحويل إلى العرض النصي',
                'Voice unavailable, switched to text display',
                '语音不可用，已切换为文字显示',
              ),
            ),
          ),
        );
      }
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
      Haptics.success();
      _maxReached = _currentLength;
      _currentLength =
          min(_currentLength + 1, _maxLengthByDifficulty(_difficulty));
      setState(() {
        _phase = _RevPhase.feedback;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _startRound();
        }
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
    _roundToken++;
    _timer?.cancel();
    await _tts.stop();
    final record = ScoreRecord(
      gameId: GameType.reverseMemory.id,
      score: _maxReached.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _difficulty.index + 1,
      metadata: {
        'maxLength': _maxReached,
        'mode': _difficulty.name,
        'voice': _difficulty == _RevDifficulty.hardVoice,
      },
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

  int _startLengthByDifficulty(_RevDifficulty difficulty) {
    return switch (difficulty) {
      _RevDifficulty.easy => 3,
      _RevDifficulty.medium => 4,
      _RevDifficulty.hardVoice => 5,
    };
  }

  int _maxLengthByDifficulty(_RevDifficulty difficulty) {
    return switch (difficulty) {
      _RevDifficulty.easy => 10,
      _RevDifficulty.medium => 14,
      _RevDifficulty.hardVoice => 18,
    };
  }

  double _memorizeDurationByDifficulty(int length) {
    return switch (_difficulty) {
      _RevDifficulty.easy => 3.0,
      _RevDifficulty.medium => 2.0,
      _RevDifficulty.hardVoice => 2.0,
    };
  }

  Future<bool> _speakSequence(String sequence) async {
    final locale = Localizations.localeOf(context).languageCode;
    final preferred = switch (locale) {
      'zh' => ['zh-CN', 'zh-TW', 'en-US'],
      'ar' => ['ar-SA', 'ar-EG', 'en-US'],
      _ => ['en-US', 'en-GB'],
    };
    final speechSpaced = sequence.split('').join(' ');
    final speechComma = sequence.split('').join(', ');
    for (final lang in preferred) {
      final ok = await _trySpeak(lang, speechSpaced) ||
          await _trySpeak(lang, speechComma);
      if (ok) return true;
    }
    // Last fallback: speak with current system language/voice.
    final fallbackOk = await _trySpeakWithoutLanguage(speechSpaced) ||
        await _trySpeakWithoutLanguage(speechComma);
    return fallbackOk;
  }

  Future<bool> _trySpeak(String lang, String text) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(0.48);
      final result = await _tts.speak(text);
      return result == null || result == 1 || result == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _trySpeakWithoutLanguage(String text) async {
    try {
      await _tts.stop();
      final result = await _tts.speak(text);
      return result == null || result == 1 || result == true;
    } catch (_) {
      return false;
    }
  }

  String _difficultyTitle(BuildContext context, _RevDifficulty difficulty) {
    return switch (difficulty) {
      _RevDifficulty.easy => tr(context, '简单', 'Easy', '简单'),
      _RevDifficulty.medium => tr(context, '进阶', 'Medium', '进阶'),
      _RevDifficulty.hardVoice => tr(context, '专家语音', 'Hard Voice', '专家语音'),
    };
  }

  String _difficultySubtitle(BuildContext context, _RevDifficulty difficulty) {
    return switch (difficulty) {
      _RevDifficulty.easy => tr(context, '起始3位，固定3秒记忆',
          'Start at 3 digits, fixed 3s memory', '从3位开始，固定3秒记忆'),
      _RevDifficulty.medium => tr(context, '起始4位，固定2秒记忆',
          'Start at 4 digits, fixed 2s memory', '从4位开始，固定2秒记忆'),
      _RevDifficulty.hardVoice => tr(context, '起始5位，2秒，仅语音播报',
          'Start at 5 digits, 2s, voice-only broadcast', '从5位开始，2秒，仅语音播报'),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_horiz,
                  color: AppColors.reverseMemory, size: 64),
              const SizedBox(height: 24),
              Text(
                tr(context, 'ذاكرة العكس', 'Reverse Memory', '数字倒序'),
                style: AppTypography.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                    context,
                    'اختر الصعوبة ثم أدخل الأرقام بالترتيب المعكوس',
                    'Choose a difficulty and enter digits in reverse order',
                    '选择难度后按倒序输入数字'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ..._RevDifficulty.values.map((difficulty) {
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
                            ? AppColors.reverseMemory.withValues(alpha: 0.16)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.reverseMemory
                              : AppColors.border,
                          width: selected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            difficulty == _RevDifficulty.hardVoice
                                ? Icons.record_voice_over_rounded
                                : Icons.timer_rounded,
                            color: selected
                                ? AppColors.reverseMemory
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
    final isVoiceMode =
        _difficulty == _RevDifficulty.hardVoice && !_voiceFallbackToText;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVoiceMode)
            Icon(
              _isSpeaking ? Icons.volume_up_rounded : Icons.hearing_rounded,
              size: 72,
              color: AppColors.reverseMemory,
            )
          else
            Text(
              displaySeq,
              style: AppTypography.digitFlash
                  .copyWith(color: AppColors.reverseMemory),
              textDirection: TextDirection.ltr,
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
                ? tr(context, 'صحيح!', 'Correct!', '正确!')
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
