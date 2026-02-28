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

// ─── Game phases ─────────────────────────────────────────────────────────────
enum _Phase { config, waiting, ready, tooEarly, roundResult }

class ReactionTimeScreen extends ConsumerStatefulWidget {
  const ReactionTimeScreen({super.key});

  @override
  ConsumerState<ReactionTimeScreen> createState() => _ReactionTimeScreenState();
}

class _ReactionTimeScreenState extends ConsumerState<ReactionTimeScreen> {
  static const _totalRounds = 5;

  _Phase _phase = _Phase.config;
  final _rng = Random();

  // Timing
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _waitTimer;

  // Scores
  final List<double> _roundMs = [];
  int _currentRound = 0;
  double _lastMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.reactionTime.id);
      GameRulesHelper.ensureShownOnce(context, GameType.reactionTime);
    });
  }

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
      _lastMs = 0;
    });
    _scheduleReady();
  }

  void _scheduleReady() {
    final delay = 2000 + _rng.nextInt(3000);
    _waitTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted) {
        setState(() => _phase = _Phase.ready);
        _stopwatch.reset();
        _stopwatch.start();
      }
    });
  }

  void _onTap() {
    switch (_phase) {
      case _Phase.waiting:
        _waitTimer?.cancel();
        Haptics.medium();
        setState(() => _phase = _Phase.tooEarly);
        break;

      case _Phase.ready:
        _stopwatch.stop();
        final ms = _stopwatch.elapsedMilliseconds.toDouble();
        Haptics.light();
        _roundMs.add(ms);
        _lastMs = ms;
        _currentRound++;

        if (_currentRound >= _totalRounds) {
          _finishGame();
        } else {
          setState(() => _phase = _Phase.roundResult);
          // Auto-advance after 1 s — player can also tap to skip
          _waitTimer = Timer(const Duration(milliseconds: 1000), () {
            if (mounted && _phase == _Phase.roundResult) {
              setState(() => _phase = _Phase.waiting);
              _scheduleReady();
            }
          });
        }
        break;

      case _Phase.tooEarly:
        setState(() => _phase = _Phase.waiting);
        _scheduleReady();
        break;

      case _Phase.roundResult:
        // Player tapped to skip the auto-advance countdown
        _waitTimer?.cancel();
        setState(() => _phase = _Phase.waiting);
        _scheduleReady();
        break;

      case _Phase.config:
        break;
    }
  }

  Future<void> _finishGame() async {
    _waitTimer?.cancel();
    if (_roundMs.isEmpty) {
      setState(() => _phase = _Phase.config);
      return;
    }
    final avgMs = _roundMs.reduce((a, b) => a + b) / _roundMs.length;

    final record = ScoreRecord(
      gameId: GameType.reactionTime.id,
      score: avgMs,
      timestamp: DateTime.now(),
      difficulty: 1,
      metadata: {
        'rounds': _roundMs.length,
        'times': _roundMs,
        'bestMs': _roundMs.reduce(min),
      },
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          tr(context, 'وقت التفاعل', 'Reaction Time', '反应时间'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _Phase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '${_currentRound + (_phase == _Phase.roundResult ? 0 : 1)}/$_totalRounds',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.reaction),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.reactionTime),
          ),
        ],
      ),
      body: switch (_phase) {
        _Phase.config => _buildConfig(context),
        _Phase.waiting => _buildWaiting(context),
        _Phase.ready => _buildReady(context),
        _Phase.tooEarly => _buildTooEarly(context),
        _Phase.roundResult => _buildRoundResult(context),
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
            const Icon(Icons.bolt, color: AppColors.reaction, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'وقت التفاعل', 'Reaction Time', '反应时间'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'عندما تتحول الشاشة إلى اللون الأخضر، اضغط بأسرع ما يمكن!',
                'When the screen turns green, tap as fast as you can!',
                '当屏幕变绿时，尽快点击！',
              ),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, '$_totalRounds جولات', '$_totalRounds rounds',
                  '$_totalRounds 轮'),
              style: AppTypography.caption,
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

  Widget _buildWaiting(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.error.withValues(alpha: 0.08),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.error, width: 2),
                ),
                child: const Icon(Icons.hourglass_empty_rounded,
                    color: AppColors.error, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                tr(context, 'انتظر اللون الأخضر...', 'Wait for green...',
                    '等待变绿...'),
                style: AppTypography.headingMedium
                    .copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'لا تضغط الآن!', "Don't tap yet!", '先不要点击！'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReady(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.success.withValues(alpha: 0.15),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.25),
                  border: Border.all(color: AppColors.success, width: 3),
                ),
                child: const Icon(Icons.touch_app_rounded,
                    color: AppColors.success, size: 56),
              ),
              const SizedBox(height: 24),
              Text(
                tr(context, 'اضغط الآن!', 'TAP NOW!', '立即点击！'),
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTooEarly(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.warning.withValues(alpha: 0.08),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 72),
              const SizedBox(height: 24),
              Text(
                tr(context, 'مبكر جداً!', 'Too early!', '太早了！'),
                style: AppTypography.headingMedium
                    .copyWith(color: AppColors.warning),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'اضغط للمحاولة مرة أخرى', 'Tap to try again',
                    '点击重试'),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundResult(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              useArabicDigits(context)
                  ? _lastMs.toInt().toArabicDigits()
                  : '${_lastMs.toInt()}',
              style: AppTypography.displayLarge.copyWith(
                color: AppColors.reaction,
                fontSize: 72,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              tr(context, 'مللي ثانية', 'ms', '毫秒'),
              style: AppTypography.headingMedium.copyWith(
                color: AppColors.reaction,
              ),
            ),
            const SizedBox(height: 32),
            ..._roundMs.asMap().entries.map((entry) {
              final idx = entry.key;
              final ms = entry.value;
              final isLast = idx == _roundMs.length - 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  useArabicDigits(context)
                      ? '${(idx + 1).toArabicDigits()}: ${ms.toInt().toArabicDigits()} مللي ثانية'
                      : 'Round ${idx + 1}: ${ms.toInt()} ms',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isLast
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              );
            }),
            const SizedBox(height: 32),
            Text(
              tr(context, 'اضغط للمتابعة', 'Tap to continue', '点击继续'),
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
