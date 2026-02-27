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

// ─── Color entries for Stroop ─────────────────────────────────────────────────
class _StroopColor {
  final String nameAr;
  final String nameEn;
  final Color value;

  const _StroopColor(this.nameAr, this.nameEn, this.value);
}

const _stroopColors = [
  _StroopColor('أحمر', 'Red', AppColors.colorRed),
  _StroopColor('أزرق', 'Blue', AppColors.colorBlue),
  _StroopColor('أخضر', 'Green', AppColors.colorGreen),
  _StroopColor('أصفر', 'Yellow', AppColors.colorYellow),
];

enum _StroopPhase { config, playing, done }

class StroopTestScreen extends ConsumerStatefulWidget {
  const StroopTestScreen({super.key});

  @override
  ConsumerState<StroopTestScreen> createState() => _StroopTestScreenState();
}

class _StroopTestScreenState extends ConsumerState<StroopTestScreen> {
  static const _totalStimuli = 20;

  final _rng = Random();
  _StroopPhase _phase = _StroopPhase.config;

  // Current stimulus
  late _StroopColor _word; // the word displayed (meaning = distractor)
  late _StroopColor _ink; // the actual ink color (correct answer)

  // Scoring
  int _correct = 0;
  int _current = 0;
  final List<double> _reactionTimes = [];

  // Timer
  Timer? _stimulusTimer;
  final Stopwatch _stopwatch = Stopwatch();

  // Flash feedback
  Color? _flashColor;

  @override
  void dispose() {
    _stimulusTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _phase = _StroopPhase.playing;
      _correct = 0;
      _current = 0;
      _reactionTimes.clear();
      _flashColor = null;
    });
    _nextStimulus();
  }

  void _nextStimulus() {
    // Generate a mismatched pair
    final shuffled = List.of(_stroopColors)..shuffle(_rng);
    _word = shuffled[0];
    _ink = shuffled.firstWhere((c) => c != _word);

    setState(() => _flashColor = null);
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _onColorTap(Color tappedColor) {
    if (_phase != _StroopPhase.playing) return;
    _stopwatch.stop();
    final ms = _stopwatch.elapsedMilliseconds.toDouble();

    final isCorrect = tappedColor == _ink.value;

    if (isCorrect) {
      Haptics.light();
      _correct++;
      _reactionTimes.add(ms);
      setState(() => _flashColor = _ink.value);
    } else {
      Haptics.medium();
      setState(() => _flashColor = AppColors.error);
    }

    _current++;

    if (_current >= _totalStimuli) {
      Future.delayed(const Duration(milliseconds: 300), _finishGame);
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _nextStimulus();
      });
    }
  }

  Future<void> _finishGame() async {
    _stimulusTimer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.stroopTest.id,
      score: _correct.toDouble(),
      accuracy: _totalStimuli > 0 ? _correct / _totalStimuli : 0,
      timestamp: DateTime.now(),
      difficulty: 1,
      metadata: {
        'total': _totalStimuli,
        'correct': _correct,
        'avgMs': _reactionTimes.isEmpty
            ? 0
            : _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length,
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.stroopTest.id));
    final isNewRecord = best == null || _correct >= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.stroopTest,
      'score': _correct.toDouble(),
      'metric': 'correct',
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
          isAr ? 'اختبار ستروب' : 'Stroop Test',
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase == _StroopPhase.playing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  isAr
                      ? '${_correct.toArabicDigits()}/${_current.toArabicDigits()}'
                      : '$_correct/$_current',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.stroop),
                ),
              ),
            ),
        ],
      ),
      body: switch (_phase) {
        _StroopPhase.config => _buildConfig(isAr),
        _StroopPhase.playing => _buildPlaying(isAr),
        _StroopPhase.done => _buildConfig(isAr),
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
            Icon(Icons.format_color_text,
                color: AppColors.stroop, size: 64),
            const SizedBox(height: 24),
            Text(
              isAr ? 'اختبار ستروب' : 'Stroop Test',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'اضغط الزر الذي يطابق لون الخط — لا معنى الكلمة!'
                  : 'Tap the button matching the font color — not the word meaning!',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? '$_totalStimuli سؤال' : '$_totalStimuli questions',
              style: AppTypography.caption,
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

  Widget _buildPlaying(bool isAr) {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: _current / _totalStimuli,
          backgroundColor: AppColors.border,
          valueColor:
              const AlwaysStoppedAnimation<Color>(AppColors.stroop),
          minHeight: 2,
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
                isAr ? _word.nameAr : _word.nameEn,
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
            child: _buildColorButtons(isAr),
          ),
        ),
      ],
    );
  }

  Widget _buildColorButtons(bool isAr) {
    return Column(
      children: [
        Row(
          children: [
            _colorBtn(AppColors.colorRed, isAr ? 'أحمر' : 'Red'),
            const SizedBox(width: 8),
            _colorBtn(AppColors.colorBlue, isAr ? 'أزرق' : 'Blue'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _colorBtn(AppColors.colorGreen, isAr ? 'أخضر' : 'Green'),
            const SizedBox(width: 8),
            _colorBtn(AppColors.colorYellow, isAr ? 'أصفر' : 'Yellow'),
          ],
        ),
      ],
    );
  }

  Widget _colorBtn(Color color, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onColorTap(color),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
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
      ),
    );
  }
}
