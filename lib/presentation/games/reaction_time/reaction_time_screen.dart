import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/score_record.dart';
import '../../../domain/enums/game_type.dart';
import '../../providers/app_providers.dart';

// ─── Color data ───────────────────────────────────────────────────────────────
class _ColorData {
  final String wordAr;
  final String wordEn;
  final Color displayColor; // the actual font color (correct answer)
  final Color wordMeaningColor; // the color the word means (distractor)

  const _ColorData({
    required this.wordAr,
    required this.wordEn,
    required this.displayColor,
    required this.wordMeaningColor,
  });
}

const _allColors = [
  _ColorData(
      wordAr: 'أحمر',
      wordEn: 'Red',
      displayColor: AppColors.colorRed,
      wordMeaningColor: AppColors.colorRed),
  _ColorData(
      wordAr: 'أزرق',
      wordEn: 'Blue',
      displayColor: AppColors.colorBlue,
      wordMeaningColor: AppColors.colorBlue),
  _ColorData(
      wordAr: 'أخضر',
      wordEn: 'Green',
      displayColor: AppColors.colorGreen,
      wordMeaningColor: AppColors.colorGreen),
  _ColorData(
      wordAr: 'أصفر',
      wordEn: 'Yellow',
      displayColor: AppColors.colorYellow,
      wordMeaningColor: AppColors.colorYellow),
];

// ─── Game phases ─────────────────────────────────────────────────────────────
enum _Phase { config, waiting, stimulus, result }

class ReactionTimeScreen extends ConsumerStatefulWidget {
  const ReactionTimeScreen({super.key});

  @override
  ConsumerState<ReactionTimeScreen> createState() =>
      _ReactionTimeScreenState();
}

class _ReactionTimeScreenState extends ConsumerState<ReactionTimeScreen> {
  static const _totalRounds = 5;

  _Phase _phase = _Phase.config;
  final _rng = Random();

  // Stimulus
  late _ColorData _wordColor; // the word that is shown (meaning)
  late _ColorData _fontColor; // the actual display color (correct answer)

  // Timing
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _waitTimer;

  // Scores
  final List<double> _roundMs = [];
  int _currentRound = 0;

  @override
  void dispose() {
    _waitTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _phase = _Phase.waiting;
      _currentRound = 0;
      _roundMs.clear();
    });
    _scheduleStimulus();
  }

  void _scheduleStimulus() {
    // Random delay 2–5 seconds
    final delay = 2000 + _rng.nextInt(3000);
    _waitTimer = Timer(Duration(milliseconds: delay), _showStimulus);
  }

  void _showStimulus() {
    // Pick word and font color — ensure they are different (Stroop effect)
    final shuffled = List.of(_allColors)..shuffle(_rng);
    _wordColor = shuffled[0]; // the word displayed
    // font color must differ from word meaning
    final otherColors = shuffled.where((c) => c != _wordColor).toList();
    _fontColor = otherColors[_rng.nextInt(otherColors.length)];

    setState(() => _phase = _Phase.stimulus);
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _onColorTap(Color tappedColor) {
    if (_phase != _Phase.stimulus) return;
    _stopwatch.stop();
    final ms = _stopwatch.elapsedMilliseconds.toDouble();

    if (tappedColor == _fontColor.displayColor) {
      // Correct
      Haptics.light();
      _roundMs.add(ms);
      _currentRound++;
      if (_currentRound >= _totalRounds) {
        _finishGame();
      } else {
        setState(() => _phase = _Phase.waiting);
        _scheduleStimulus();
      }
    } else {
      // Wrong — end game
      Haptics.medium();
      setState(() => _phase = _Phase.waiting);
      _finishGame(failed: true);
    }
  }

  Future<void> _finishGame({bool failed = false}) async {
    _waitTimer?.cancel();
    if (_roundMs.isEmpty) {
      // no valid rounds
      setState(() => _phase = _Phase.config);
      return;
    }
    final avgMs = _roundMs.reduce((a, b) => a + b) / _roundMs.length;

    final record = ScoreRecord(
      gameId: GameType.reactionTime.id,
      score: avgMs,
      timestamp: DateTime.now(),
      difficulty: 1,
      metadata: {'rounds': _roundMs.length, 'failed': failed},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.reactionTime.id));
    final isNewRecord = best == null || avgMs <= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.reactionTime,
      'score': avgMs,
      'metric': 'ms',
      'lowerIsBetter': true,
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
          isAr ? 'وقت التفاعل' : 'Reaction Time',
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _Phase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  isAr
                      ? '${_currentRound + 1}/$_totalRounds'
                      : '${_currentRound + 1}/$_totalRounds',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.reaction),
                ),
              ),
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.config => _buildConfig(isAr),
        _Phase.waiting => _buildWaiting(isAr),
        _Phase.stimulus => _buildStimulus(isAr),
        _Phase.result => _buildWaiting(isAr), // transient
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
            Icon(Icons.bolt, color: AppColors.reaction, size: 64),
            const SizedBox(height: 24),
            Text(
              isAr ? 'اضغط حسب لون الخط' : 'Tap by font color',
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'ستظهر كلمة ملونة — اضغط الزر الذي يطابق لون الخط، لا معنى الكلمة'
                  : 'A colored word appears — tap the button matching the font color, not the meaning',
              style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr ? '$_totalRounds جولات' : '$_totalRounds rounds',
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

  Widget _buildWaiting(bool isAr) {
    return GestureDetector(
      onTap: () {}, // absorb taps
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Icon(Icons.hourglass_empty_rounded,
                  color: AppColors.textSecondary, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              isAr ? 'انتظر...' : 'Wait...',
              style: AppTypography.headingMedium.copyWith(
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStimulus(bool isAr) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text(
              isAr ? _wordColor.wordAr : _wordColor.wordEn,
              style: AppTypography.stroopWord.copyWith(
                color: _fontColor.displayColor,
              ),
            ),
          ),
        ),
        // Color buttons (RTL: Red rightmost, Yellow leftmost)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Row(
              children: _colorButtons(isAr),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _colorButtons(bool isAr) {
    // RTL-ordered: Red, Blue, Green, Yellow
    final colors = [
      (AppColors.colorRed, isAr ? 'أحمر' : 'Red'),
      (AppColors.colorBlue, isAr ? 'أزرق' : 'Blue'),
      (AppColors.colorGreen, isAr ? 'أخضر' : 'Green'),
      (AppColors.colorYellow, isAr ? 'أصفر' : 'Yellow'),
    ];

    return colors
        .expand((entry) => [
              Expanded(
                child: GestureDetector(
                  onTap: () => _onColorTap(entry.$1),
                  child: Container(
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: entry.$1.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        entry.$2,
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
              ),
            ])
        .toList();
  }
}
