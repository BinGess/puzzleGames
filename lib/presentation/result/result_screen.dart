import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/tr.dart';
import '../../data/models/ability_snapshot.dart';
import '../../data/models/score_record.dart';
import '../../domain/enums/game_type.dart';
import '../providers/app_providers.dart';

// ─── LQ Norm Table: LQ score → global percentile ──────────────────────────────
// Approximates normal distribution; human average LQ ≈ 50 → 44th percentile
const List<(double, int)> _kPercentileTable = [
  (0, 1),
  (10, 3),
  (20, 8),
  (30, 16),
  (40, 28),
  (50, 44),
  (60, 60),
  (70, 74),
  (80, 85),
  (90, 93),
  (95, 97),
  (100, 99),
];

int _lqToPercentile(double lq) {
  for (int i = 0; i < _kPercentileTable.length - 1; i++) {
    final lo = _kPercentileTable[i];
    final hi = _kPercentileTable[i + 1];
    if (lq <= hi.$1) {
      final t = (lq - lo.$1) / (hi.$1 - lo.$1);
      return (lo.$2 + t * (hi.$2 - lo.$2)).round().clamp(1, 99);
    }
  }
  return 99;
}

class _PercentileEstimate {
  final int global;
  final int age;
  final double confidence;

  const _PercentileEstimate({
    required this.global,
    required this.age,
    required this.confidence,
  });
}

bool _isBetterScore(double candidate, double reference, bool lowerIsBetter) {
  return lowerIsBetter ? candidate < reference : candidate > reference;
}

bool _isSameScore(double a, double b) {
  final epsilon = math.max(0.01, math.max(a.abs(), b.abs()) * 0.001);
  return (a - b).abs() <= epsilon;
}

double _avgScores(List<ScoreRecord> records) {
  if (records.isEmpty) return 0;
  final total = records.fold<double>(0, (sum, r) => sum + r.score);
  return total / records.length;
}

double _stdDevScores(List<ScoreRecord> records, double mean) {
  if (records.isEmpty) return 0;
  final variance = records
          .map((r) => math.pow(r.score - mean, 2).toDouble())
          .fold<double>(0, (sum, v) => sum + v) /
      records.length;
  return math.sqrt(variance);
}

_PercentileEstimate _estimatePercentiles({
  required GameType gameType,
  required double lq,
  required double currentScore,
  required bool lowerIsBetter,
  required List<ScoreRecord> history,
  required int? age,
  required int totalSessions,
}) {
  final baseGlobal = _lqToPercentile(lq);
  if (history.isEmpty) {
    return _PercentileEstimate(
      global: baseGlobal,
      age: baseGlobal,
      confidence: 0,
    );
  }

  final currentDifficulty = history.first.difficulty;
  final sameDifficulty = history
      .where((r) => r.difficulty == currentDifficulty)
      .toList(growable: false);
  final pool = sameDifficulty.length >= 4 ? sameDifficulty : history;

  final total = pool.length;
  final better = pool
      .where((r) => _isBetterScore(r.score, currentScore, lowerIsBetter))
      .length;
  final equal = pool.where((r) => _isSameScore(r.score, currentScore)).length;
  final empirical =
      (((total - better) - (equal * 0.5)) / total * 100).round().clamp(1, 99);

  double trendDelta = 0;
  final recentPrev = pool.skip(1).take(5).toList(growable: false);
  if (recentPrev.length >= 3) {
    final prevAvg = _avgScores(recentPrev);
    if (prevAvg.abs() > 1e-6) {
      final changeRatio = lowerIsBetter
          ? (prevAvg - currentScore) / prevAvg
          : (currentScore - prevAvg) / prevAvg;
      trendDelta = (changeRatio * 40).clamp(-10.0, 10.0);
    }
  }

  double consistencyDelta = 0;
  final recent = pool.take(6).toList(growable: false);
  if (recent.length >= 4) {
    final mean = _avgScores(recent);
    if (mean.abs() > 1e-6) {
      final cv = _stdDevScores(recent, mean) / mean.abs();
      consistencyDelta = ((0.30 - cv) * 25).clamp(-4.0, 4.0);
    }
  }

  final confidence = ((total - 1) / 14).clamp(0.0, 1.0).toDouble();
  final blendWeight = 0.30 + 0.55 * confidence;
  final modelPercentile =
      (empirical + trendDelta + consistencyDelta).clamp(1.0, 99.0);
  var global = (baseGlobal * (1 - blendWeight) + modelPercentile * blendWeight)
      .round()
      .clamp(1, 99);

  // Tower of Hanoi has a known optimal move count: 2^n - 1.
  // If user solves at theoretical optimum, percentile should never look mediocre.
  final hanoiOptimal = gameType == GameType.towerOfHanoi
      ? ((1 << (currentDifficulty + 2)) - 1).toDouble()
      : null;
  if (hanoiOptimal != null && currentScore <= hanoiOptimal + 1e-6) {
    global = math.max(global, 95).toInt();
  }

  int ageAdjust = 0;
  if (age != null) {
    if (age < 14) {
      ageAdjust = -3;
    } else if (age < 18) {
      ageAdjust = -2;
    } else if (age <= 40) {
      ageAdjust = 1;
    } else if (age > 60) {
      ageAdjust = -1;
    }
  }
  final experienceAdjust = math.min(
    4,
    (math.log(totalSessions + 1) / math.ln2).floor(),
  );
  final peerCentered = (50 + (global - 50) * 0.88).round();
  var agePercentile =
      (peerCentered + ageAdjust + (experienceAdjust * 0.5).round())
          .round()
          .clamp(1, 99);
  if (hanoiOptimal != null && currentScore <= hanoiOptimal + 1e-6) {
    agePercentile = math.max(agePercentile, 96).toInt();
  }

  return _PercentileEstimate(
    global: global,
    age: agePercentile,
    confidence: confidence,
  );
}

// ─── LQ Tier ──────────────────────────────────────────────────────────────────
({String ar, String en, String zh, Color color, IconData icon}) _lqTier(
    double lq) {
  if (lq >= 90) {
    return (
      ar: 'معلم',
      en: 'Master',
      zh: '天才级',
      color: AppColors.gold,
      icon: Icons.auto_awesome_rounded,
    );
  }
  if (lq >= 70) {
    return (
      ar: 'محترف',
      en: 'Professional',
      zh: '学者级',
      color: const Color(0xFF60CDFF),
      icon: Icons.psychology_rounded,
    );
  }
  if (lq >= 50) {
    return (
      ar: 'متوسط',
      en: 'Intermediate',
      zh: '进阶级',
      color: const Color(0xFF4CD964),
      icon: Icons.trending_up_rounded,
    );
  }
  return (
    ar: 'مبتدئ',
    en: 'Beginner',
    zh: '入门级',
    color: AppColors.textSecondary,
    icon: Icons.school_rounded,
  );
}

// ─── ResultScreen ─────────────────────────────────────────────────────────────
class ResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const ResultScreen({super.key, required this.data});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers
  late AnimationController _entryCtrl;
  late AnimationController _lqCountCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _barCtrl;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _lqCountAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _barAnim;

  // ── UI state
  bool _lqExpanded = false;

  // ── Cached data
  late GameType _gameType;
  late double _score;
  late String _metric;
  late bool _isNewRecord;
  late Color _accent;

  @override
  void initState() {
    super.initState();

    _gameType = widget.data['gameType'] as GameType? ?? GameType.schulteGrid;
    _score = (widget.data['score'] as num?)?.toDouble() ?? 0;
    _metric = widget.data['metric'] as String? ?? 'time';
    _isNewRecord = widget.data['isNewRecord'] as bool? ?? false;
    _accent = _accentForType(_gameType);
    Haptics.setSoundGameId(_gameType.id);

    // Entry animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    // LQ count-up (starts 400ms after entry)
    _lqCountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _lqCountAnim =
        CurvedAnimation(parent: _lqCountCtrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _lqCountCtrl.forward();
    });

    // New record pulse (repeating)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    if (_isNewRecord) {
      _pulseCtrl.repeat(reverse: true);
      Haptics.success();
    } else {
      Haptics.light();
    }

    // Percentile bar fill (starts 700ms after entry)
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _lqCountCtrl.dispose();
    _pulseCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatScore(double score, String metric) {
    switch (metric) {
      case 'time':
        final s = (score / 1000).toStringAsFixed(1);
        return tr(context, '$s ث', '${s}s', '$s秒');
      case 'ms':
        final ms = score.round();
        return tr(context, '$ms مللي', '${ms}ms', '$ms毫秒');
      case 'length':
        final n = score.toInt();
        return useArabicDigits(context)
            ? '${n.toArabicDigits()} ${n == 1 ? 'رقم' : 'أرقام'}'
            : '$n ${tr(context, n == 1 ? 'رقم' : 'أرقام', n == 1 ? 'digit' : 'digits', '位')}';
      case 'correct':
        final n = score.toInt();
        return useArabicDigits(context)
            ? '${n.toArabicDigits()} صحيح'
            : '$n ${tr(context, 'صحيح', 'correct', '正确')}';
      case 'moves':
        final n = score.toInt();
        return useArabicDigits(context)
            ? '${n.toArabicDigits()} حركة'
            : '$n ${tr(context, 'حركة', 'moves', '步')}';
      default:
        return score.toStringAsFixed(0);
    }
  }

  String _gameNameAr() => switch (_gameType) {
        GameType.schulteGrid => 'شبكة شولت',
        GameType.reactionTime => 'وقت التفاعل',
        GameType.numberMemory => 'ذاكرة الأرقام',
        GameType.stroopTest => 'اختبار ستروب',
        GameType.visualMemory => 'ذاكرة بصرية',
        GameType.sequenceMemory => 'تسلسل',
        GameType.numberMatrix => 'مصفوفة الأرقام',
        GameType.reverseMemory => 'ذاكرة العكس',
        GameType.slidingPuzzle => 'لغز الأرقام',
        GameType.towerOfHanoi => 'برج هانو',
      };

  String _gameNameTr() => tr(
        context,
        _gameNameAr(),
        switch (_gameType) {
          GameType.schulteGrid => 'Schulte Grid',
          GameType.reactionTime => 'Reaction Time',
          GameType.numberMemory => 'Number Memory',
          GameType.stroopTest => 'Stroop Test',
          GameType.visualMemory => 'Visual Memory',
          GameType.sequenceMemory => 'Sequence Memory',
          GameType.numberMatrix => 'Number Matrix',
          GameType.reverseMemory => 'Reverse Memory',
          GameType.slidingPuzzle => 'Sliding Puzzle',
          GameType.towerOfHanoi => 'Tower of Hanoi',
        },
        switch (_gameType) {
          GameType.schulteGrid => '舒尔特方格',
          GameType.reactionTime => '反应时间',
          GameType.numberMemory => '数字记忆',
          GameType.stroopTest => '斯特鲁普测试',
          GameType.visualMemory => '视觉记忆',
          GameType.sequenceMemory => '序列记忆',
          GameType.numberMatrix => '数字矩阵',
          GameType.reverseMemory => '数字倒序',
          GameType.slidingPuzzle => '数字华容道',
          GameType.towerOfHanoi => '汉诺塔',
        },
      );

  String _dimensionTr() => tr(
        context,
        switch (_gameType) {
          GameType.schulteGrid => 'السرعة والتركيز',
          GameType.reactionTime => 'السرعة',
          GameType.numberMemory => 'الذاكرة',
          GameType.stroopTest => 'التركيز',
          GameType.visualMemory => 'الذاكرة البصرية',
          GameType.sequenceMemory => 'الذاكرة والمنطق',
          GameType.numberMatrix => 'المنطق والتركيز',
          GameType.reverseMemory => 'الذاكرة',
          GameType.slidingPuzzle => 'التفكير المنطقي',
          GameType.towerOfHanoi => 'المنطق الفراغي',
        },
        switch (_gameType) {
          GameType.schulteGrid => 'Speed & Focus',
          GameType.reactionTime => 'Speed',
          GameType.numberMemory => 'Memory',
          GameType.stroopTest => 'Focus',
          GameType.visualMemory => 'Visual Memory',
          GameType.sequenceMemory => 'Memory & Logic',
          GameType.numberMatrix => 'Logic & Focus',
          GameType.reverseMemory => 'Memory',
          GameType.slidingPuzzle => 'Space Logic',
          GameType.towerOfHanoi => 'Spatial Logic',
        },
        switch (_gameType) {
          GameType.schulteGrid => '速度和专注力',
          GameType.reactionTime => '速度',
          GameType.numberMemory => '记忆力',
          GameType.stroopTest => '专注力',
          GameType.visualMemory => '视觉记忆',
          GameType.sequenceMemory => '记忆和逻辑',
          GameType.numberMatrix => '逻辑和专注力',
          GameType.reverseMemory => '记忆力',
          GameType.slidingPuzzle => '空间逻辑',
          GameType.towerOfHanoi => '空间逻辑',
        },
      );

  static Color _accentForType(GameType type) => switch (type) {
        GameType.schulteGrid => AppColors.schulte,
        GameType.reactionTime => AppColors.reaction,
        GameType.numberMemory => AppColors.numberMemory,
        GameType.stroopTest => AppColors.stroop,
        GameType.visualMemory => AppColors.visualMemory,
        GameType.sequenceMemory => AppColors.sequenceMemory,
        GameType.numberMatrix => AppColors.numberMatrix,
        GameType.reverseMemory => AppColors.reverseMemory,
        GameType.slidingPuzzle => AppColors.slidingPuzzle,
        GameType.towerOfHanoi => AppColors.towerOfHanoi,
      };

  // ─── Share ───────────────────────────────────────────────────────────────────

  void _showShareSheet(AbilitySnapshot ability, int globalPercentile) {
    Haptics.selection();
    final l10n = AppL10n.of(context);
    final lq = ability.lqScore;
    final tier = _lqTier(lq);
    final scoreLabel = _formatScore(_score, _metric);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SharePreviewSheet(
        gameName: _gameNameTr(),
        appName: l10n.appName,
        scoreLabel: scoreLabel,
        lq: lq,
        tier: tier,
        percentile: globalPercentile,
        ability: ability,
        accent: _accent,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ability = ref.watch(abilityProvider);
    final profile = ref.watch(profileProvider);
    final gameScores = ref.watch(gameScoresProvider(_gameType.id));
    final allScoresCount = ref.read(scoreRepoProvider).getAllScores().length;
    final bestByDifficulty = widget.data['bestByDifficulty'] as bool? ?? false;
    final scopedDifficulty = (widget.data['difficulty'] as num?)?.toInt();
    final bestPool = (bestByDifficulty && scopedDifficulty != null)
        ? gameScores
            .where((s) => s.difficulty == scopedDifficulty)
            .toList(growable: false)
        : gameScores;
    final ScoreRecord? best = bestPool.isEmpty
        ? null
        : bestPool.reduce((a, b) => _gameType.lowerIsBetter
            ? (a.score < b.score ? a : b)
            : (a.score > b.score ? a : b));
    final lq = ability.lqScore;
    final percentileEstimate = _estimatePercentiles(
      gameType: _gameType,
      lq: lq,
      currentScore: _score,
      lowerIsBetter: _gameType.lowerIsBetter,
      history: gameScores,
      age: profile.age,
      totalSessions: allScoresCount,
    );
    final tier = _lqTier(lq);
    final scoreLabel = _formatScore(_score, _metric);
    final bonusLabel = widget.data['bonusLabel'] as String?;
    final challengeTip = widget.data['challengeTip'] as String?;
    final economyLabel = widget.data['economyLabel'] as String?;
    final economyTip = widget.data['economyTip'] as String?;
    final economyWon = widget.data['economyWon'] as bool? ?? false;
    final economyCoins = (widget.data['economyCoins'] as num?)?.toInt() ?? 0;
    final economyXp = (widget.data['economyXp'] as num?)?.toInt() ?? 0;
    final economyLevel = (widget.data['economyLevel'] as num?)?.toInt();

    // Gap-to-best label
    String? gapLabel;
    if (!_isNewRecord && best != null && (best.score - _score).abs() > 0.01) {
      final gap = _gameType.lowerIsBetter
          ? best.score - _score // negative = current is worse
          : _score - best.score;
      gapLabel = _formatScore(gap.abs(), _metric);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────────────
          _ResultBackground(accent: _accent),

          // ── Main Content ──────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isNewRecord) ...[
                              _NewRecordBanner(
                                pulseAnim: _pulseAnim,
                                gameName: _gameNameTr(),
                              ),
                              const SizedBox(height: 14),
                            ],
                            _ScoreCard(
                              score: scoreLabel,
                              gameName: _gameNameTr(),
                              bestLabel: best != null
                                  ? _formatScore(best.score, _metric)
                                  : null,
                              gapLabel: gapLabel,
                              economyLabel: economyLabel,
                              economyTip: economyTip,
                              economyWon: economyWon,
                              economyCoins: economyCoins,
                              economyXp: economyXp,
                              economyLevel: economyLevel,
                              bonusLabel: bonusLabel,
                              challengeTip: challengeTip,
                              isNewRecord: _isNewRecord,
                              accent: _accent,
                            ),
                            const SizedBox(height: 20),
                            _LQSection(
                              lq: lq,
                              tier: tier,
                              percentile: percentileEstimate.global,
                              agePercentile: percentileEstimate.age,
                              lqAnim: _lqCountAnim,
                              barAnim: _barAnim,
                              dimensionHint: _dimensionTr(),
                              expanded: _lqExpanded,
                              onToggle: () =>
                                  setState(() => _lqExpanded = !_lqExpanded),
                            ),
                            const SizedBox(height: 20),
                            _RadarCard(ability: ability),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomButtons(ability, percentileEstimate.global),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _gameNameTr(),
              style: AppTypography.headingMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Haptics.selection();
              context.go(AppRoutes.dashboard);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(AbilitySnapshot ability, int globalPercentile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ],
        ),
      ),
      child: Row(
        children: [
          // Share
          Expanded(
            child: GestureDetector(
              onTap: () => _showShareSheet(ability, globalPercentile),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderGold),
                  color: AppColors.surfaceElevated,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_rounded,
                        color: AppColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'مشاركة', 'Share', '分享'),
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Play Again
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                Haptics.selection();
                context.pushReplacement(AppRoutes.gameRoute(_gameType));
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [AppColors.goldBright, AppColors.gold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: AppColors.textOnGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'العب مجددًا', 'Play Again', '再玩一次'),
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textOnGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _ResultBackground ────────────────────────────────────────────────────────
class _ResultBackground extends StatelessWidget {
  final Color accent;
  const _ResultBackground({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF07070F),
                Color(0xFF0A0A14),
                Color(0xFF0D0B1A),
                Color(0xFF0F0C1E),
              ],
              stops: [0, 0.3, 0.65, 1],
            ),
          ),
        ),
        // Accent glow — top
        Positioned(
          top: -60,
          left: -80,
          child: _GlowBlob(color: accent, size: 260, alpha: 0.07),
        ),
        // Gold glow — center-right
        const Positioned(
          top: 220,
          right: -60,
          child: _GlowBlob(color: AppColors.gold, size: 220, alpha: 0.06),
        ),
        // Accent glow — bottom
        Positioned(
          bottom: -40,
          left: 40,
          child: _GlowBlob(color: accent, size: 200, alpha: 0.05),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double alpha;
  const _GlowBlob(
      {required this.color, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), Colors.transparent],
        ),
      ),
    );
  }
}

// ─── _NewRecordBanner ─────────────────────────────────────────────────────────
class _NewRecordBanner extends StatelessWidget {
  final Animation<double> pulseAnim;
  final String gameName;
  const _NewRecordBanner({required this.pulseAnim, required this.gameName});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) {
        final glow = pulseAnim.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.22 + glow * 0.08),
                AppColors.goldMuted.withValues(alpha: 0.14 + glow * 0.06),
              ],
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.5 + glow * 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.15 + glow * 0.15),
                blurRadius: 20 + glow * 10,
                spreadRadius: glow * 3,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: AppColors.gold,
                size: 26 + glow * 2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'رقم قياسي جديد! 🏆', 'New Record! 🏆',
                          '新纪录！🏆'),
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textOnGold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(
                        context,
                        'تجاوزت أفضل نتيجتك السابقة',
                        'You beat your personal best',
                        '超越了你的历史最佳成绩',
                      ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textOnGold.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── _ScoreCard ───────────────────────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final String score;
  final String gameName;
  final String? bestLabel;
  final String? gapLabel;
  final String? economyLabel;
  final String? economyTip;
  final bool economyWon;
  final int economyCoins;
  final int economyXp;
  final int? economyLevel;
  final String? bonusLabel;
  final String? challengeTip;
  final bool isNewRecord;
  final Color accent;

  const _ScoreCard({
    required this.score,
    required this.gameName,
    required this.bestLabel,
    required this.gapLabel,
    required this.economyLabel,
    required this.economyTip,
    required this.economyWon,
    required this.economyCoins,
    required this.economyXp,
    required this.economyLevel,
    required this.bonusLabel,
    required this.challengeTip,
    required this.isNewRecord,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tipText = [
      if (challengeTip != null) challengeTip!,
      if (economyTip != null) economyTip!,
    ].join('  ');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Label
            Text(
              tr(context, 'نتيجتك', 'Your Score', '本局成绩'),
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Score value
            Text(
              score,
              style: AppTypography.displayMedium.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 44,
              ),
              textAlign: TextAlign.center,
            ),
            // Best score row
            if (bestLabel != null) ...[
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: accent.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    tr(context, 'أفضل نتيجة: ', 'Personal Best: ', '历史最佳：') +
                        bestLabel!,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.90),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (gapLabel != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flag_rounded,
                        color: AppColors.textSecondary, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      tr(context, 'الفجوة عن الأفضل: ', 'Gap to best: ',
                              '距最佳还差：') +
                          gapLabel!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (economyLabel != null) ...[
              const SizedBox(height: 8),
              if (economyWon && (economyCoins > 0 || economyXp > 0))
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 950),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, progress, _) {
                    final coinsNow = (economyCoins * progress).round();
                    final xpNow = (economyXp * progress).round();
                    final levelUp = economyLevel != null && economyLevel! > 1;
                    return Transform.scale(
                      scale: 0.96 + (progress * 0.04),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          _RewardChip(
                            icon: Icons.monetization_on_rounded,
                            text: '+$coinsNow',
                            color: AppColors.gold,
                          ),
                          _RewardChip(
                            icon: Icons.bolt_rounded,
                            text: '+$xpNow XP',
                            color: const Color(0xFF69C6FF),
                          ),
                          if (levelUp)
                            _RewardChip(
                              icon: Icons.workspace_premium_rounded,
                              text: 'Lv.${economyLevel!}',
                              color: AppColors.sequenceMemory,
                            ),
                        ],
                      ),
                    );
                  },
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: AppColors.gold, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      economyLabel!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.90),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
            if (bonusLabel != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.gold, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    bonusLabel!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.90),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            if (tipText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: accent.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        tipText,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _RewardChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _LQSection ───────────────────────────────────────────────────────────────
class _LQSection extends StatelessWidget {
  final double lq;
  final ({String ar, String en, String zh, Color color, IconData icon}) tier;
  final int percentile;
  final int agePercentile;
  final Animation<double> lqAnim;
  final Animation<double> barAnim;
  final String dimensionHint;
  final bool expanded;
  final VoidCallback onToggle;

  const _LQSection({
    required this.lq,
    required this.tier,
    required this.percentile,
    required this.agePercentile,
    required this.lqAnim,
    required this.barAnim,
    required this.dimensionHint,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tierLabel = tr(context, tier.ar, tier.en, tier.zh);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGold, width: 0.8),
      ),
      child: Column(
        children: [
          // ── Top: LQ score + tier ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LQ count-up circle
                AnimatedBuilder(
                  animation: lqAnim,
                  builder: (context, _) {
                    final displayLq = (lq * lqAnim.value).round();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: (lq / 100) * lqAnim.value,
                            strokeWidth: 5,
                            backgroundColor: AppColors.border,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(tier.color),
                          ),
                        ),
                        Text(
                          useArabicDigits(context)
                              ? displayLq.toArabicDigits()
                              : '$displayLq',
                          style: AppTypography.headingLarge.copyWith(
                            color: tier.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'مقياس المنطق LQ', 'Logic Quotient LQ',
                            '逻辑商数 LQ'),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Tier badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: tier.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: tier.color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tier.icon, color: tier.color, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              tierLabel,
                              style: AppTypography.labelMedium
                                  .copyWith(color: tier.color),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Percentile text
                      RichText(
                        text: TextSpan(
                          style: AppTypography.bodySmall.copyWith(
                            color:
                                AppColors.textPrimary.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: tr(context, 'تجاوزت ', 'Beats ', '超过了全球'),
                            ),
                            TextSpan(
                              text: useArabicDigits(context)
                                  ? '${percentile.toArabicDigits()}٪'
                                  : '$percentile%',
                              style: AppTypography.labelLarge
                                  .copyWith(color: AppColors.gold),
                            ),
                            TextSpan(
                              text:
                                  tr(context, ' من الناس', ' of people', ' 的人'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Percentile bars ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _PercentileBar(
                  label: tr(context, 'عالميًا', 'Global Rank', '全球排名'),
                  percentile: percentile,
                  anim: barAnim,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 10),
                _PercentileBar(
                  label: tr(context, 'نفس العمر', 'Age Group', '同龄人'),
                  percentile: agePercentile,
                  anim: barAnim,
                  color: tier.color,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(
                context,
                'تقدير مبني على نتائجك الأخيرة',
                'Estimate based on your recent results',
                '基于你最近成绩估算',
              ),
              style: AppTypography.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1, thickness: 0.5),

          // ── Dimension hint ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(context, 'يحسّن هذا النشاط لديك: ',
                            'This improves your: ', '本局提升：') +
                        dimensionHint,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Text(
                  tr(
                    context,
                    'ارجع للرئيسية لترى تغيرات الرادار',
                    'Return to see radar chart updates',
                    '返回首页查看能力雷达图变化',
                  ),
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1, thickness: 0.5),

          // ── "What is LQ?" expandable ───────────────────────────────
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(context, 'ما هو مقياس LQ؟', 'What is LQ?',
                          '什么是逻辑商数 LQ？'),
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.gold),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.borderGold, width: 0.5),
                      ),
                      child: Text(
                        tr(
                          context,
                          'LQ (Logic Quotient) مقياس المنطق هو تقييم شامل لقدراتك في خمسة أبعاد: السرعة، الذاكرة، المنطق الفراغي، التركيز، والإدراك. أقصى درجة هي ١٠٠، ومتوسط الإنسان ٥٠.',
                          'LQ (Logic Quotient) is a composite score across 5 cognitive dimensions: Speed, Memory, Spatial Logic, Focus, and Perception. Max score is 100. Human average is 50.',
                          'LQ（逻辑商数）是对你反应力、记忆力、空间逻辑、注意力、感知力五项能力的综合评分。满分100分，人类平均分约为50分。',
                        ),
                        style: AppTypography.bodySmall.copyWith(height: 1.6),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── _PercentileBar ───────────────────────────────────────────────────────────
class _PercentileBar extends StatelessWidget {
  final String label;
  final int percentile;
  final Animation<double> anim;
  final Color color;

  const _PercentileBar({
    required this.label,
    required this.percentile,
    required this.anim,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
            AnimatedBuilder(
              animation: anim,
              builder: (context, _) {
                final display = (percentile * anim.value).round();
                return Text(
                  useArabicDigits(context)
                      ? '${display.toArabicDigits()}٪'
                      : '$display%',
                  style: AppTypography.labelMedium.copyWith(color: color),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              // Track
              Container(
                height: 6,
                color: AppColors.border,
              ),
              // Fill
              AnimatedBuilder(
                animation: anim,
                builder: (context, _) {
                  return FractionallySizedBox(
                    widthFactor: (percentile / 100) * anim.value,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.7),
                            color,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── _RadarCard ───────────────────────────────────────────────────────────────
class _RadarCard extends StatelessWidget {
  final AbilitySnapshot ability;
  const _RadarCard({required this.ability});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    final dimLabels = lang == 'ar'
        ? ['السرعة', 'الذاكرة', 'المنطق', 'التركيز', 'الإدراك']
        : lang == 'zh'
            ? ['速度', '记忆', '逻辑', '专注', '感知']
            : ['Speed', 'Memory', 'Logic', 'Focus', 'Perc.'];

    final dimScores = [
      ability.speedScore,
      ability.memoryScore,
      ability.spaceLogicScore,
      ability.focusScore,
      ability.perceptionScore,
    ];
    final dimColors = [
      AppColors.dimensionSpeed,
      AppColors.dimensionMemory,
      AppColors.dimensionSpaceLogic,
      AppColors.dimensionFocus,
      AppColors.dimensionPerception,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGold, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.radar_rounded,
                    color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  tr(context, 'قدراتك الخمس', '5D Ability Radar', '五维能力雷达'),
                  style: AppTypography.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Radar chart
                SizedBox(
                  width: 160,
                  height: 160,
                  child: RadarChart(
                    RadarChartData(
                      dataSets: [
                        RadarDataSet(
                          dataEntries: dimScores
                              .map((s) => RadarEntry(value: math.max(s, 2.0)))
                              .toList(),
                          fillColor: AppColors.gold.withValues(alpha: 0.15),
                          borderColor: AppColors.gold,
                          borderWidth: 2,
                          entryRadius: 3,
                        ),
                      ],
                      radarShape: RadarShape.polygon,
                      tickCount: 4,
                      ticksTextStyle: const TextStyle(
                          color: Colors.transparent, fontSize: 0),
                      radarBorderData: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          width: 1),
                      gridBorderData: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          width: 0.5),
                      radarBackgroundColor: Colors.transparent,
                      getTitle: (index, angle) => RadarChartTitle(
                        text: dimLabels[index],
                        angle: angle,
                      ),
                      titlePositionPercentageOffset: 0.15,
                      titleTextStyle: const TextStyle(
                        color: Color(0xCCF5F5F5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Dimension list
                Expanded(
                  child: Column(
                    children: List.generate(5, (i) {
                      final v = dimScores[i].clamp(0.0, 100.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dimLabels[i],
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  useArabicDigits(context)
                                      ? v.toInt().toArabicDigits()
                                      : '${v.toInt()}',
                                  style: AppTypography.caption.copyWith(
                                      color: dimColors[i],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 4,
                                    color: AppColors.border,
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: v / 100,
                                    child: Container(
                                      height: 4,
                                      color: dimColors[i],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _SharePreviewSheet ───────────────────────────────────────────────────────
// Bottom sheet showing a visible, scaled preview of the share card.
// Using a visible RepaintBoundary (not Offstage) ensures toImage() captures correctly.
class _SharePreviewSheet extends StatefulWidget {
  final String appName;
  final String gameName;
  final String scoreLabel;
  final double lq;
  final ({String ar, String en, String zh, Color color, IconData icon}) tier;
  final int percentile;
  final AbilitySnapshot ability;
  final Color accent;

  const _SharePreviewSheet({
    required this.appName,
    required this.gameName,
    required this.scoreLabel,
    required this.lq,
    required this.tier,
    required this.percentile,
    required this.ability,
    required this.accent,
  });

  @override
  State<_SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<_SharePreviewSheet> {
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSaving = false;
  bool _isSharing = false;

  Rect? _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<Uint8List?> _capturePosterBytes() async {
    final boundary = _shareCardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    await Future.delayed(const Duration(milliseconds: 120));
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  Future<File> _writeTempPng(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = widget.appName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final file = File('${tempDir.path}/${safeName}_result_$timestamp.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _handleSave() async {
    if (_isSaving || _isSharing) return;
    setState(() => _isSaving = true);
    Haptics.selection();
    final l10n = AppL10n.of(context);

    final saveSuccess = l10n.saveImageSuccess;
    final saveFail = l10n.saveImageFailed;

    try {
      final bytes = await _capturePosterBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(saveFail)),
        );
        return;
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name:
            '${widget.appName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}_result_$timestamp',
      );
      final ok = switch (result) {
        {'isSuccess': true} => true,
        {'success': true} => true,
        {'isSuccess': 1} => true,
        {'success': 1} => true,
        _ => false,
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? saveSuccess : saveFail)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saveFail)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isSharing || _isSaving) return;
    if (!mounted) return;
    setState(() => _isSharing = true);
    Haptics.selection();

    final shareSubject = tr(
      context,
      'شاركت نتيجتي في ${widget.appName}',
      'My result from ${widget.appName}',
      '${widget.appName} 成绩分享',
    );
    final shareText = tr(
      context,
      'حصلت على ${widget.lq.toStringAsFixed(1)} نقطة LQ في ${widget.gameName}.',
      'I scored ${widget.lq.toStringAsFixed(1)} LQ in ${widget.gameName}.',
      '我在${widget.gameName}中获得了${widget.lq.toStringAsFixed(1)}分LQ。',
    );
    final shareFail = tr(
      context,
      'تعذر فتح لوحة المشاركة',
      'Unable to open share panel',
      '无法打开分享面板',
    );
    final shareOrigin = _sharePositionOrigin();

    try {
      final bytes = await _capturePosterBytes();
      if (bytes != null) {
        final file = await _writeTempPng(bytes);
        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType: 'image/png',
              name:
                  '${widget.appName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}_result.png',
            )
          ],
          subject: shareSubject,
          text: shareText,
          sharePositionOrigin: shareOrigin,
        );
        return;
      }

      await Share.share(
        shareText,
        subject: shareSubject,
        sharePositionOrigin: shareOrigin,
      );
    } catch (_) {
      try {
        await Share.share(
          shareText,
          subject: shareSubject,
          sharePositionOrigin: shareOrigin,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(shareFail)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // Available width for card: 32px padding each side
    final availableWidth = screenWidth - 64;
    // Card natural size: 300×533. Compute display size preserving aspect ratio.
    final cardDisplayWidth = availableWidth.clamp(200.0, 340.0);
    final cardDisplayHeight = cardDisplayWidth * 533 / 300;
    final sheetHeight = (screenHeight * 0.92).clamp(560.0, 920.0);

    return SafeArea(
      top: false,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Header: drag handle + close button ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centered drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Close button — top-right
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        Haptics.selection();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Title / subtitle ────────────────────────────────────────────
            Text(
              tr(context, 'شارك نتيجتك', 'Share Your Result', '分享你的成绩'),
              style: AppTypography.headingSmall,
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'تحدَّ أصدقاءك واجعلهم يختبرون ذكاءهم',
                'Challenge friends to test their intelligence',
                '挑战好友，一起测试智力',
              ),
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            // ── Share card preview (vertically centered) ────────────────────
            Expanded(
              child: Center(
                child: SizedBox(
                  width: cardDisplayWidth,
                  height: cardDisplayHeight,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: RepaintBoundary(
                      key: _shareCardKey,
                      child: _ShareCardWidget(
                        appName: widget.appName,
                        gameName: widget.gameName,
                        scoreLabel: widget.scoreLabel,
                        lq: widget.lq,
                        tier: widget.tier,
                        percentile: widget.percentile,
                        ability: widget.ability,
                        accent: widget.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Save + Share buttons ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isSaving || _isSharing ? null : _handleSave,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderGold),
                          color: AppColors.surfaceElevated,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSaving)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.gold,
                                ),
                              )
                            else
                              const Icon(Icons.save_alt_rounded,
                                  color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tr(context, 'حفظ الصورة', 'Save Image', '保存图片'),
                              style: AppTypography.labelLarge
                                  .copyWith(color: AppColors.gold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isSharing || _isSaving ? null : _handleShare,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [widget.accent, AppColors.gold],
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSharing)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textOnGold,
                                ),
                              )
                            else
                              const Icon(Icons.share_rounded,
                                  color: AppColors.textOnGold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tr(context, 'مشاركة', 'Share', '分享'),
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.textOnGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _ShareCardWidget ─────────────────────────────────────────────────────────
// 9:16 ratio: 300 × 533 @1x → 900 × 1600 @3x (high-res for social media)
// Designed for viral sharing: brag-worthy layout with challenge CTA
class _ShareCardWidget extends StatelessWidget {
  final String appName;
  final String gameName;
  final String scoreLabel;
  final double lq;
  final ({String ar, String en, String zh, Color color, IconData icon}) tier;
  final int percentile;
  final AbilitySnapshot ability;
  final Color accent;

  const _ShareCardWidget({
    required this.appName,
    required this.gameName,
    required this.scoreLabel,
    required this.lq,
    required this.tier,
    required this.percentile,
    required this.ability,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final lqRounded = lq.round();
    final tierLabel = tr(context, tier.ar, tier.en, tier.zh);

    return SizedBox(
      width: 300,
      height: 533,
      child: Stack(
        children: [
          // Dark luxury background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF07070F),
                  Color(0xFF0A0A16),
                  Color(0xFF0E0B1E),
                ],
              ),
            ),
          ),
          // Subtle grid texture
          Positioned.fill(
            child: CustomPaint(painter: _ShareBgPainter()),
          ),
          // Accent glow top-left
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Gold glow bottom-right
          Positioned(
            bottom: -20,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content layout
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent color stripe
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, AppColors.gold, accent],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // App branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.psychology_rounded,
                                color: AppColors.textOnGold, size: 13),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            appName,
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.gold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Game name badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          gameName,
                          style: AppTypography.labelMedium
                              .copyWith(color: accent, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Score — HERO element
                      Text(
                        scoreLabel,
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // LQ circle + radar + percentile row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // LQ circle
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: tier.color.withValues(alpha: 0.65),
                                  width: 2),
                              gradient: RadialGradient(
                                colors: [
                                  tier.color.withValues(alpha: 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$lqRounded',
                                  style: AppTypography.headingLarge.copyWith(
                                    color: tier.color,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  'LQ',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.goldMuted,
                                    fontSize: 9,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Radar chart
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: CustomPaint(
                              painter: _MiniRadarPainter(
                                values: [
                                  ability.speedScore,
                                  ability.memoryScore,
                                  ability.spaceLogicScore,
                                  ability.focusScore,
                                  ability.perceptionScore,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Tier badge + percentile column
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: tier.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          tier.color.withValues(alpha: 0.50)),
                                ),
                                child: Text(
                                  tierLabel,
                                  style: AppTypography.caption.copyWith(
                                    color: tier.color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr(context, 'تجاوزت', 'Beats', '超过'),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                              Text(
                                useArabicDigits(context)
                                    ? '${percentile.toArabicDigits()}٪'
                                    : '$percentile%',
                                style: AppTypography.headingMedium.copyWith(
                                  color: AppColors.gold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                tr(context, 'من البشر', 'of people', '的人'),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Thin gold divider
                      Container(
                        height: 0.5,
                        color: AppColors.gold.withValues(alpha: 0.22),
                      ),
                      const SizedBox(height: 12),
                      // Challenge CTA — viral hook
                      Text(
                        tr(
                          context,
                          'هل تستطيع التفوق عليّ؟ 🔥',
                          'Can you beat me? 🔥',
                          '你能超越我吗？🔥',
                        ),
                        style: AppTypography.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Percentile progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 6,
                              color: const Color(0xFF1E1E2C),
                            ),
                            FractionallySizedBox(
                              widthFactor: percentile / 100,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [accent, AppColors.gold],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          context,
                          'اختبر مستوى ذكاءك الآن',
                          'Test your logic level now',
                          '立即测试你的逻辑水平',
                        ),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.goldMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      const SizedBox(height: 4),
                      // Footer brand
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.psychology_outlined,
                              color: AppColors.textDisabled, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            appName,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textDisabled,
                              fontSize: 9,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── _ShareBgPainter ─────────────────────────────────────────────────────────
class _ShareBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = AppColors.gold.withValues(alpha: 0.06);
    final paint = Paint()
      ..color = gold
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Corner arcs top-left
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: i * 60.0, height: i * 60.0),
        0,
        math.pi / 2,
        false,
        paint..color = gold.withValues(alpha: 0.08 - i * 0.015),
      );
    }
    // Corner arcs bottom-right
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(size.width, size.height),
            width: i * 60.0,
            height: i * 60.0),
        math.pi,
        math.pi / 2,
        false,
        paint..color = gold.withValues(alpha: 0.08 - i * 0.015),
      );
    }
    // Horizontal divider lines
    paint
      ..color = AppColors.gold.withValues(alpha: 0.08)
      ..strokeWidth = 0.3;
    for (var y = 60.0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ShareBgPainter old) => false;
}

// ─── _MiniRadarPainter ────────────────────────────────────────────────────────
class _MiniRadarPainter extends CustomPainter {
  final List<double> values; // 5 values, 0-100

  const _MiniRadarPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 * 0.82;
    const n = 5;

    Offset pt(int i, double radius) {
      final angle = (i * 2 * math.pi / n) - math.pi / 2;
      return Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    }

    // Grid rings
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.gold.withValues(alpha: 0.2);
    for (var ring = 1; ring <= 4; ring++) {
      final ringR = r * ring / 4;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = pt(i, ringR);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axes
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, pt(i, r), gridPaint);
    }

    // Data polygon
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final val = values[i].clamp(0.0, 100.0) / 100;
      final p = pt(i, r * val);
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.gold.withValues(alpha: 0.2),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.gold
        ..strokeWidth = 1.5,
    );

    // Vertex dots
    for (var i = 0; i < n; i++) {
      final val = values[i].clamp(0.0, 100.0) / 100;
      canvas.drawCircle(
        pt(i, r * val),
        3,
        Paint()..color = AppColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniRadarPainter old) => old.values != values;
}
