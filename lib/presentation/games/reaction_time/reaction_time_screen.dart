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

// ─── Game phases ─────────────────────────────────────────────────────────────
enum _Phase { config, waiting, ready, tooEarly, roundResult }

enum _ReactionDifficulty { easy, medium, hard }

class ReactionTimeScreen extends ConsumerStatefulWidget {
  const ReactionTimeScreen({super.key});

  @override
  ConsumerState<ReactionTimeScreen> createState() => _ReactionTimeScreenState();
}

class _ReactionTimeScreenState extends ConsumerState<ReactionTimeScreen> {
  _Phase _phase = _Phase.config;
  _ReactionDifficulty _difficulty = _ReactionDifficulty.medium;
  final _rng = Random();

  // Timing
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _waitTimer;
  Timer? _targetMoveTimer;

  // Scores
  final List<double> _roundMs = [];
  int _currentRound = 0;
  double _lastMs = 0;

  // Medium / Hard target circle
  Size _readyAreaSize = Size.zero;
  Offset? _targetTopLeft;
  Offset _targetVelocity = Offset.zero;

  int get _totalRounds => switch (_difficulty) {
        _ReactionDifficulty.easy => 5,
        _ReactionDifficulty.medium => 7,
        _ReactionDifficulty.hard => 9,
      };

  int _difficultyValue(_ReactionDifficulty difficulty) => switch (difficulty) {
        _ReactionDifficulty.easy => 1,
        _ReactionDifficulty.medium => 2,
        _ReactionDifficulty.hard => 3,
      };

  String _difficultyLabel(
          BuildContext context, _ReactionDifficulty difficulty) =>
      switch (difficulty) {
        _ReactionDifficulty.easy => tr(context, 'سهل', 'Easy', '简单'),
        _ReactionDifficulty.medium => tr(context, 'متوسط', 'Medium', '中等'),
        _ReactionDifficulty.hard => tr(context, 'صعب', 'Hard', '困难'),
      };

  String _difficultyHint(
          BuildContext context, _ReactionDifficulty difficulty) =>
      switch (difficulty) {
        _ReactionDifficulty.easy => tr(context, 'جولات أقل وإيقاع أهدأ',
            'Fewer rounds, calmer pace', '轮数更少，节奏更舒缓'),
        _ReactionDifficulty.medium => tr(
            context,
            'اضغط دائرة ثابتة تظهر عشوائياً',
            'Tap a randomly placed static circle',
            '点击随机出现的静止圆圈'),
        _ReactionDifficulty.hard => tr(context, 'اضغط دائرة تتحرك ببطء',
            'Tap a slowly moving circle', '点击缓慢移动的圆圈'),
      };

  String _difficultyMeta(BuildContext context, _ReactionDifficulty difficulty) {
    final rounds = switch (difficulty) {
      _ReactionDifficulty.easy => tr(context, '٥ جولات', '5 rounds', '5 轮'),
      _ReactionDifficulty.medium => tr(context, '٧ جولات', '7 rounds', '7 轮'),
      _ReactionDifficulty.hard => tr(context, '٩ جولات', '9 rounds', '9 轮'),
    };
    final wait = switch (difficulty) {
      _ReactionDifficulty.easy =>
        tr(context, 'انتظار ٢.٢–٥.٢ث', 'Wait 2.2-5.2s', '等待 2.2-5.2 秒'),
      _ReactionDifficulty.medium =>
        tr(context, 'انتظار ١.٦–٤.٢ث', 'Wait 1.6-4.2s', '等待 1.6-4.2 秒'),
      _ReactionDifficulty.hard =>
        tr(context, 'انتظار ١.٢–٣.٠ث', 'Wait 1.2-3.0s', '等待 1.2-3.0 秒'),
    };
    final target = switch (difficulty) {
      _ReactionDifficulty.easy =>
        tr(context, 'لمس أي مكان', 'Tap anywhere', '可点击任意位置'),
      _ReactionDifficulty.medium =>
        tr(context, 'دائرة ثابتة', 'Static target', '静止目标'),
      _ReactionDifficulty.hard =>
        tr(context, 'دائرة متحركة', 'Moving target', '移动目标'),
    };
    return '$rounds · $wait · $target';
  }

  int _waitMinMsFor(_ReactionDifficulty difficulty) => switch (difficulty) {
        _ReactionDifficulty.easy => 2200,
        _ReactionDifficulty.medium => 1600,
        _ReactionDifficulty.hard => 1200,
      };

  int _waitRangeMsFor(_ReactionDifficulty difficulty) => switch (difficulty) {
        _ReactionDifficulty.easy => 3000,
        _ReactionDifficulty.medium => 2600,
        _ReactionDifficulty.hard => 1800,
      };

  double _targetAvgMsFor(_ReactionDifficulty difficulty) =>
      switch (difficulty) {
        _ReactionDifficulty.easy => 320,
        _ReactionDifficulty.medium => 280,
        _ReactionDifficulty.hard => 240,
      };

  bool get _usesTargetCircle => _difficulty != _ReactionDifficulty.easy;

  double _targetDiameterFor(_ReactionDifficulty difficulty) =>
      switch (difficulty) {
        _ReactionDifficulty.easy => 120,
        _ReactionDifficulty.medium => 102,
        _ReactionDifficulty.hard => 92,
      };

  String _readyPrompt(BuildContext context) => switch (_difficulty) {
        _ReactionDifficulty.easy =>
          tr(context, 'اضغط الآن!', 'TAP NOW!', '立即点击！'),
        _ReactionDifficulty.medium =>
          tr(context, 'اضغط الدائرة', 'Tap the circle!', '点击圆圈！'),
        _ReactionDifficulty.hard => tr(context, 'اضغط الدائرة المتحركة',
            'Tap the moving circle!', '点击移动圆圈！'),
      };

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
    _stopTargetMovement();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _startGame() async {
    final canStart = await GameEconomyHelper.consumeEntryCost(
      context,
      ref,
      GameType.reactionTime,
    );
    if (!canStart) return;

    setState(() {
      _phase = _Phase.waiting;
      _currentRound = 0;
      _roundMs.clear();
      _lastMs = 0;
      _targetTopLeft = null;
      _readyAreaSize = Size.zero;
    });
    _scheduleReady();
  }

  void _scheduleReady() {
    _stopTargetMovement();
    _targetTopLeft = null;
    _readyAreaSize = Size.zero;
    final minMs = _waitMinMsFor(_difficulty);
    final rangeMs = _waitRangeMsFor(_difficulty);
    final delay = minMs + _rng.nextInt(rangeMs + 1);
    _waitTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted) {
        setState(() => _phase = _Phase.ready);
        _stopwatch.reset();
        _stopwatch.start();
      }
    });
  }

  void _stopTargetMovement() {
    _targetMoveTimer?.cancel();
    _targetMoveTimer = null;
    _targetVelocity = Offset.zero;
  }

  void _maybeInitTarget(Size size) {
    if (!_usesTargetCircle || _phase != _Phase.ready) return;
    final hasSize = size.width > 0 && size.height > 0;
    if (!hasSize) return;
    final needInit = _targetTopLeft == null ||
        (_readyAreaSize.width - size.width).abs() > 0.5 ||
        (_readyAreaSize.height - size.height).abs() > 0.5;
    if (!needInit) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _phase != _Phase.ready || !_usesTargetCircle) return;
      setState(() {
        _readyAreaSize = size;
        _targetTopLeft = _randomTargetTopLeft(size);
        _targetVelocity = _randomTargetVelocity();
      });
      if (_difficulty == _ReactionDifficulty.hard) {
        _startTargetMovement();
      } else {
        _stopTargetMovement();
      }
    });
  }

  Offset _randomTargetTopLeft(Size area) {
    final diameter = _targetDiameterFor(_difficulty);
    const outerPadding = 18.0;
    final freeX = max(0.0, area.width - diameter - outerPadding * 2);
    final freeY = max(0.0, area.height - diameter - outerPadding * 2);
    return Offset(
      outerPadding + (freeX == 0 ? 0 : _rng.nextDouble() * freeX),
      outerPadding + (freeY == 0 ? 0 : _rng.nextDouble() * freeY),
    );
  }

  Offset _randomTargetVelocity() {
    final angle = _rng.nextDouble() * pi * 2;
    final speed = 1.0 + _rng.nextDouble() * 0.4;
    return Offset(cos(angle) * speed, sin(angle) * speed);
  }

  void _startTargetMovement() {
    _stopTargetMovement();
    if (_difficulty != _ReactionDifficulty.hard ||
        _targetTopLeft == null ||
        _readyAreaSize == Size.zero) {
      return;
    }

    _targetMoveTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted ||
          _phase != _Phase.ready ||
          _difficulty != _ReactionDifficulty.hard ||
          _targetTopLeft == null) {
        t.cancel();
        return;
      }

      final diameter = _targetDiameterFor(_difficulty);
      final maxX = max(0.0, _readyAreaSize.width - diameter);
      final maxY = max(0.0, _readyAreaSize.height - diameter);

      var nextX = _targetTopLeft!.dx + _targetVelocity.dx;
      var nextY = _targetTopLeft!.dy + _targetVelocity.dy;
      var vx = _targetVelocity.dx;
      var vy = _targetVelocity.dy;

      if (nextX <= 0 || nextX >= maxX) {
        vx = -vx;
        nextX = nextX.clamp(0.0, maxX);
      }
      if (nextY <= 0 || nextY >= maxY) {
        vy = -vy;
        nextY = nextY.clamp(0.0, maxY);
      }

      setState(() {
        _targetTopLeft = Offset(nextX, nextY);
        _targetVelocity = Offset(vx, vy);
      });
    });
  }

  bool _isTapOnTarget(Offset localPosition) {
    if (_targetTopLeft == null) return false;
    final diameter = _targetDiameterFor(_difficulty);
    final center = _targetTopLeft! + Offset(diameter / 2, diameter / 2);
    return (localPosition - center).distance <= diameter / 2;
  }

  void _registerHit() {
    _stopTargetMovement();
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
  }

  void _onReadyTapDown(TapDownDetails details) {
    if (_phase != _Phase.ready) return;
    if (!_usesTargetCircle) {
      _registerHit();
      return;
    }
    if (_isTapOnTarget(details.localPosition)) {
      _registerHit();
      return;
    }
    Haptics.selection();
  }

  void _onTap() {
    switch (_phase) {
      case _Phase.waiting:
        _waitTimer?.cancel();
        _stopTargetMovement();
        Haptics.medium();
        setState(() => _phase = _Phase.tooEarly);
        break;

      case _Phase.ready:
        if (!_usesTargetCircle) _registerHit();
        break;

      case _Phase.tooEarly:
        _stopTargetMovement();
        setState(() => _phase = _Phase.waiting);
        _scheduleReady();
        break;

      case _Phase.roundResult:
        // Player tapped to skip the auto-advance countdown
        _waitTimer?.cancel();
        _stopTargetMovement();
        setState(() => _phase = _Phase.waiting);
        _scheduleReady();
        break;

      case _Phase.config:
        break;
    }
  }

  Future<void> _finishGame() async {
    _waitTimer?.cancel();
    _stopTargetMovement();
    if (_roundMs.isEmpty) {
      setState(() => _phase = _Phase.config);
      return;
    }
    final avgMs = _roundMs.reduce((a, b) => a + b) / _roundMs.length;

    final record = ScoreRecord(
      gameId: GameType.reactionTime.id,
      score: avgMs,
      timestamp: DateTime.now(),
      difficulty: _difficultyValue(_difficulty),
      metadata: {
        'rounds': _roundMs.length,
        'times': _roundMs,
        'bestMs': _roundMs.reduce(min),
        'selectedDifficulty': _difficultyValue(_difficulty),
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.reactionTime.id));
    final isNewRecord = best == null || avgMs <= best.score;
    final targetAvg = _targetAvgMsFor(_difficulty);
    final won = avgMs <= targetAvg;
    final performance = (1 -
            ((avgMs - targetAvg) /
                (switch (_difficulty) {
                  _ReactionDifficulty.easy => 220.0,
                  _ReactionDifficulty.medium => 180.0,
                  _ReactionDifficulty.hard => 150.0,
                })))
        .clamp(0.0, 1.0);
    final economy = await GameEconomyHelper.settleGame(
      ref,
      gameType: GameType.reactionTime,
      won: won,
      difficulty: _difficultyValue(_difficulty),
      isNewRecord: isNewRecord,
      performance: performance.toDouble(),
    );

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.reactionTime,
      'score': avgMs,
      'metric': 'ms',
      'lowerIsBetter': true,
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
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DifficultyOptionList<_ReactionDifficulty>(
                options: _ReactionDifficulty.values
                    .map((d) => DifficultyOption(
                          value: d,
                          badge: switch (d) {
                            _ReactionDifficulty.easy => 'E',
                            _ReactionDifficulty.medium => 'M',
                            _ReactionDifficulty.hard => 'H',
                          },
                          title: _difficultyLabel(context, d),
                          subtitle: _difficultyHint(context, d),
                          details: _difficultyMeta(context, d),
                        ))
                    .toList(),
                selectedValue: _difficulty,
                accentColor: AppColors.reaction,
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
      onTapDown: _onReadyTapDown,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.success.withValues(alpha: 0.15),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final area = Size(constraints.maxWidth, constraints.maxHeight);
            _maybeInitTarget(area);
            final diameter = _targetDiameterFor(_difficulty);

            return Stack(
              children: [
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        _readyPrompt(context),
                        style: AppTypography.displayLarge.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _usesTargetCircle
                            ? tr(
                                context,
                                'أصِب الدائرة الخضراء لتسجيل التوقيت',
                                'Hit the green circle to record your reaction',
                                '命中绿色圆圈才会记录反应时间',
                              )
                            : tr(
                                context,
                                'يمكنك الضغط في أي مكان',
                                'You can tap anywhere on screen',
                                '可点击屏幕任意位置',
                              ),
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (!_usesTargetCircle)
                  Center(
                    child: _ReactionTargetCircle(
                      diameter: diameter,
                      color: AppColors.success,
                      icon: Icons.touch_app_rounded,
                    ),
                  ),
                if (_usesTargetCircle && _targetTopLeft != null)
                  Positioned(
                    left: _targetTopLeft!.dx,
                    top: _targetTopLeft!.dy,
                    child: _ReactionTargetCircle(
                      diameter: diameter,
                      color: AppColors.success,
                      icon: _difficulty == _ReactionDifficulty.hard
                          ? Icons.track_changes_rounded
                          : Icons.adjust_rounded,
                    ),
                  ),
              ],
            );
          },
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

class _ReactionTargetCircle extends StatelessWidget {
  final double diameter;
  final Color color;
  final IconData icon;

  const _ReactionTargetCircle({
    required this.diameter,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.26),
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: diameter * 0.46),
    );
  }
}
