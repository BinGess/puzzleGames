import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/ability_snapshot.dart';
import '../../data/models/score_record.dart';
import '../../domain/enums/game_type.dart';
import '../providers/app_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final snapshot = ref.watch(abilityProvider);
    final history = ref.read(analyticsRepoProvider).getLqHistory();
    final scoreRepo = ref.read(scoreRepoProvider);

    // Pre-compute per-game stats
    final gameStats = GameType.values.map((g) {
      final scores = scoreRepo.getScoresForGame(g.id);
      final ScoreRecord? best = scores.isEmpty
          ? null
          : g.lowerIsBetter
              ? scores.reduce((a, b) => a.score < b.score ? a : b)
              : scores.reduce((a, b) => a.score > b.score ? a : b);
      return _GameStat(type: g, best: best, playCount: scores.length);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          isAr ? 'التحليلات' : 'Analytics',
          style: AppTypography.headingMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ─── LQ Score Card ──────────────────────────────────────────
          _buildLQCard(isAr, snapshot),
          const SizedBox(height: 20),

          // ─── LQ History Chart (only if ≥ 2 data points) ────────────
          if (history.length >= 2) ...[
            _sectionLabel(isAr ? 'سجل المقياس' : 'LQ History'),
            const SizedBox(height: 10),
            _buildChart(history),
            const SizedBox(height: 20),
          ],

          // ─── Five Dimensions ────────────────────────────────────────
          _sectionLabel(isAr ? 'الأبعاد الخمسة' : 'Five Dimensions'),
          const SizedBox(height: 10),
          _buildDimensions(isAr, snapshot),
          const SizedBox(height: 20),

          // ─── Per-game stats ─────────────────────────────────────────
          _sectionLabel(isAr ? 'إحصائيات الألعاب' : 'Game Statistics'),
          const SizedBox(height: 10),
          _buildGames(isAr, gameStats),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      Text(text, style: AppTypography.caption);

  // ─── LQ Card ────────────────────────────────────────────────────────────
  Widget _buildLQCard(bool isAr, AbilitySnapshot s) {
    final lq = s.lqScore;
    final Color tierColor;
    final String tierLabel;

    if (lq >= 90) {
      tierColor = AppColors.gold;
      tierLabel = isAr ? 'معلم' : 'Master';
    } else if (lq >= 70) {
      tierColor = AppColors.goldMuted;
      tierLabel = isAr ? 'محترف' : 'Professional';
    } else if (lq >= 50) {
      tierColor = AppColors.reaction;
      tierLabel = isAr ? 'متوسط' : 'Intermediate';
    } else {
      tierColor = AppColors.textSecondary;
      tierLabel = isAr ? 'مبتدئ' : 'Beginner';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.surfaceElevated, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGold, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'مقياس المنطق (LQ)' : 'Logic Quotient (LQ)',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  lq.toStringAsFixed(1),
                  style: AppTypography.displayLarge,
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tierColor, width: 1),
            ),
            child: Text(
              tierLabel,
              style: AppTypography.labelMedium.copyWith(color: tierColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─── LQ History Line Chart ──────────────────────────────────────────────
  Widget _buildChart(List<AbilitySnapshot> history) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.lqScore))
        .toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.gold,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: spots.length <= 10),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.25),
                    AppColors.gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 32,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: AppTypography.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (history.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
        ),
      ),
    );
  }

  // ─── Dimension Progress Bars ────────────────────────────────────────────
  Widget _buildDimensions(bool isAr, AbilitySnapshot s) {
    final dims = [
      (isAr ? 'السرعة' : 'Speed', s.speedScore, AppColors.dimensionSpeed),
      (
        isAr ? 'الذاكرة' : 'Memory',
        s.memoryScore,
        AppColors.dimensionMemory
      ),
      (
        isAr ? 'المنطق' : 'Space & Logic',
        s.spaceLogicScore,
        AppColors.dimensionSpaceLogic
      ),
      (
        isAr ? 'التركيز' : 'Focus',
        s.focusScore,
        AppColors.dimensionFocus
      ),
      (
        isAr ? 'الإدراك' : 'Perception',
        s.perceptionScore,
        AppColors.dimensionPerception
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: dims.map((d) {
          final (name, score, color) = d;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(name, style: AppTypography.caption),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    score.toStringAsFixed(0),
                    style:
                        AppTypography.labelMedium.copyWith(color: color),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Game Stats Grid ────────────────────────────────────────────────────
  Widget _buildGames(bool isAr, List<_GameStat> stats) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _GameCard(stat: stats[i], isAr: isAr),
    );
  }
}

// ─── Data class ──────────────────────────────────────────────────────────────
class _GameStat {
  final GameType type;
  final ScoreRecord? best;
  final int playCount;

  _GameStat({
    required this.type,
    required this.best,
    required this.playCount,
  });
}

// ─── Game Card Widget ────────────────────────────────────────────────────────
class _GameCard extends StatelessWidget {
  final _GameStat stat;
  final bool isAr;

  const _GameCard({required this.stat, required this.isAr});

  static String _nameAr(GameType g) => switch (g) {
        GameType.schulteGrid => 'شبكة شولت',
        GameType.reactionTime => 'وقت التفاعل',
        GameType.numberMemory => 'ذاكرة الأرقام',
        GameType.stroopTest => 'اختبار ستروب',
        GameType.visualMemory => 'ذاكرة بصرية',
        GameType.sequenceMemory => 'تسلسل',
        GameType.numberMatrix => 'اختبار المصفوفة',
        GameType.reverseMemory => 'ذاكرة العكس',
        GameType.slidingPuzzle => 'لغز الأرقام',
        GameType.towerOfHanoi => 'برج هانو',
      };

  static String _nameEn(GameType g) => switch (g) {
        GameType.schulteGrid => 'Schulte Grid',
        GameType.reactionTime => 'Reaction Time',
        GameType.numberMemory => 'Number Memory',
        GameType.stroopTest => 'Stroop Test',
        GameType.visualMemory => 'Visual Memory',
        GameType.sequenceMemory => 'Sequence',
        GameType.numberMatrix => 'Number Matrix',
        GameType.reverseMemory => 'Reverse Mem.',
        GameType.slidingPuzzle => 'Sliding Puzzle',
        GameType.towerOfHanoi => 'Tower of Hanoi',
      };

  static Color _color(GameType g) => switch (g) {
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

  static String _bestStr(ScoreRecord? best, GameType g) {
    if (best == null) return '---';
    final s = best.score;
    return switch (g.scoreMetric) {
      'time' => '${(s / 1000).toStringAsFixed(1)}s',
      'ms' => '${s.toInt()}ms',
      _ => s.toInt().toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = stat.type;
    final color = _color(g);
    final name = isAr ? _nameAr(g) : _nameEn(g);
    final bestStr = _bestStr(stat.best, g);
    final plays = stat.playCount;
    final hasPlayed = plays > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPlayed
              ? color.withValues(alpha: 0.3)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Game name with color dot
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hasPlayed ? color : AppColors.textDisabled,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: AppTypography.caption.copyWith(
                    color: hasPlayed
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Best score + play count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'الأفضل' : 'Best',
                    style: AppTypography.caption.copyWith(fontSize: 9),
                  ),
                  Text(
                    bestStr,
                    style: AppTypography.labelMedium.copyWith(
                      color: hasPlayed ? color : AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isAr ? 'جلسات' : 'Plays',
                    style: AppTypography.caption.copyWith(fontSize: 9),
                  ),
                  Text(
                    '$plays',
                    style: AppTypography.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
