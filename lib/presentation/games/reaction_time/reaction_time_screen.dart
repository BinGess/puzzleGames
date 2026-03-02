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
  Rect _targetArenaRect = Rect.zero;
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
    final target = switch (difficulty) {
      _ReactionDifficulty.easy =>
        tr(context, 'لمس أي مكان', 'Tap anywhere', '可点击任意位置'),
      _ReactionDifficulty.medium =>
        tr(context, 'دائرة ثابتة', 'Static target', '静止目标'),
      _ReactionDifficulty.hard =>
        tr(context, 'دائرة متحركة', 'Moving target', '移动目标'),
    };
    return '$rounds · $target';
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
      _targetArenaRect = Rect.zero;
    });
    _scheduleReady();
  }

  void _scheduleReady() {
    _stopTargetMovement();
    _targetTopLeft = null;
    _readyAreaSize = Size.zero;
    _targetArenaRect = Rect.zero;
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

  void _stopTargetMovement({bool resetVelocity = true}) {
    _targetMoveTimer?.cancel();
    _targetMoveTimer = null;
    if (resetVelocity) _targetVelocity = Offset.zero;
  }

  void _maybeInitTarget(Rect arenaRect) {
    if (!_usesTargetCircle || _phase != _Phase.ready) return;
    _targetArenaRect = arenaRect;
    final size = arenaRect.size;
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
    const outerPadding = 10.0;
    final freeX = max(0.0, area.width - diameter - outerPadding * 2);
    final freeY = max(0.0, area.height - diameter - outerPadding * 2);
    return Offset(
      outerPadding + (freeX == 0 ? 0 : _rng.nextDouble() * freeX),
      outerPadding + (freeY == 0 ? 0 : _rng.nextDouble() * freeY),
    );
  }

  Offset _randomTargetVelocity() {
    final angle = _rng.nextDouble() * pi * 2;
    final speed = 1.4 + _rng.nextDouble() * 0.8;
    return Offset(cos(angle) * speed, sin(angle) * speed);
  }

  void _startTargetMovement() {
    _stopTargetMovement(resetVelocity: false);
    if (_difficulty != _ReactionDifficulty.hard ||
        _targetTopLeft == null ||
        _readyAreaSize == Size.zero) {
      return;
    }
    if (_targetVelocity.distanceSquared < 0.0001) {
      _targetVelocity = _randomTargetVelocity();
    }

    _targetMoveTimer = Timer.periodic(const Duration(milliseconds: 18), (t) {
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

      if (_rng.nextDouble() < 0.018) {
        final angle = atan2(vy, vx) + ((_rng.nextDouble() - 0.5) * 0.28);
        final speed = sqrt(vx * vx + vy * vy);
        vx = cos(angle) * speed;
        vy = sin(angle) * speed;
      }

      setState(() {
        _targetTopLeft = Offset(nextX, nextY);
        _targetVelocity = Offset(vx, vy);
      });
    });
  }

  bool _isTapOnTarget(Offset localPosition) {
    if (_targetTopLeft == null || _targetArenaRect == Rect.zero) return false;
    if (!_targetArenaRect.contains(localPosition)) return false;
    final diameter = _targetDiameterFor(_difficulty);
    final localInArena = localPosition - _targetArenaRect.topLeft;
    final center = _targetTopLeft! + Offset(diameter / 2, diameter / 2);
    return (localInArena - center).distance <= diameter / 2;
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
        // Keep result visible for at least 1 second.
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
        color: AppColors.error.withValues(alpha: 0.06),
        child: Center(
          child: _buildStateCard(
            icon: Icons.hourglass_empty_rounded,
            accent: AppColors.error,
            title: tr(context, 'انتظر اللون الأخضر...', 'Wait for green...',
                '等待变绿...'),
            subtitle: tr(context, 'لا تضغط الآن!', "Don't tap yet!", '先不要点击！'),
            footer: tr(context, 'أي ضغط مبكر سيعيد الجولة',
                'Early tap resets round', '提前点击会重置本轮'),
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
        color: AppColors.success.withValues(alpha: 0.08),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalPadding = 20.0;
            final topSectionHeight =
                (constraints.maxHeight * 0.30).clamp(170.0, 210.0);
            const bottomPadding = 28.0;
            final arenaRect = Rect.fromLTWH(
              horizontalPadding,
              topSectionHeight,
              max(0, constraints.maxWidth - horizontalPadding * 2),
              max(0, constraints.maxHeight - topSectionHeight - bottomPadding),
            );
            _maybeInitTarget(arenaRect);
            final diameter = _targetDiameterFor(_difficulty);

            return Stack(
              children: [
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Text(
                          tr(
                            context,
                            'الجولة ${(_currentRound + 1).toArabicDigits()} / ${_totalRounds.toArabicDigits()}',
                            'Round ${_currentRound + 1} / $_totalRounds',
                            '第 ${_currentRound + 1} / $_totalRounds 轮',
                          ),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _readyPrompt(context),
                        style: AppTypography.headingLarge.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
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
                Positioned(
                  left: arenaRect.left,
                  top: arenaRect.top,
                  width: arenaRect.width,
                  height: arenaRect.height,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceElevated.withValues(alpha: 0.9),
                          AppColors.surface.withValues(alpha: 0.75),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                if (!_usesTargetCircle)
                  Positioned(
                    left: arenaRect.left + (arenaRect.width - diameter) / 2,
                    top: arenaRect.top + (arenaRect.height - diameter) / 2,
                    child: _ReactionTargetCircle(
                      diameter: diameter,
                      color: AppColors.success,
                      icon: Icons.touch_app_rounded,
                    ),
                  ),
                if (_usesTargetCircle && _targetTopLeft != null)
                  Positioned(
                    left: arenaRect.left + _targetTopLeft!.dx,
                    top: arenaRect.top + _targetTopLeft!.dy,
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
        color: AppColors.warning.withValues(alpha: 0.06),
        child: Center(
          child: _buildStateCard(
            icon: Icons.warning_amber_rounded,
            accent: AppColors.warning,
            title: tr(context, 'مبكر جداً!', 'Too early!', '太早了！'),
            subtitle: tr(
                context, 'اضغط للمحاولة مرة أخرى', 'Tap to try again', '点击重试'),
            footer: tr(context, 'انتظر الإشارة الخضراء أولاً',
                'Wait for the green signal first', '请先等待绿色信号'),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundResult(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(context, 'نتيجة الجولة', 'Round Result', '本轮结果'),
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  useArabicDigits(context)
                      ? _lastMs.toInt().toArabicDigits()
                      : '${_lastMs.toInt()}',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.reaction,
                    fontSize: 58,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tr(context, 'مللي ثانية', 'ms', '毫秒'),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                ..._roundMs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ms = entry.value;
                  final isLast = idx == _roundMs.length - 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      useArabicDigits(context)
                          ? '${tr(context, 'جولة', 'Round', '第')}${(idx + 1).toArabicDigits()}: ${ms.toInt().toArabicDigits()} ${tr(context, 'مللي ثانية', 'ms', '毫秒')}'
                          : 'Round ${idx + 1}: ${ms.toInt()} ms',
                      style: AppTypography.bodySmall.copyWith(
                        color: isLast
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Text(
                  tr(
                    context,
                    'الانتقال تلقائياً للجولة التالية...',
                    'Next round starts automatically...',
                    '即将自动进入下一轮...',
                  ),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required String footer,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 44),
              const SizedBox(height: 14),
              Text(
                title,
                style: AppTypography.headingSmall.copyWith(color: accent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                footer,
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
