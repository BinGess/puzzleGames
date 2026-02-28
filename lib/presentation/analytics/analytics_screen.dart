import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/tr.dart';
import '../../data/models/ability_snapshot.dart';
import '../../data/models/score_record.dart';
import '../../domain/enums/game_type.dart';
import '../providers/app_providers.dart';
import '../dashboard/widgets/ability_radar_chart.dart';
import '../dashboard/widgets/lq_hero.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(abilityProvider);
    final history = ref.read(analyticsRepoProvider).getLqHistory();
    final scoreRepo = ref.read(scoreRepoProvider);
    final allScores = scoreRepo.getAllScores();
    final playedGames = allScores.map((s) => s.gameId).toSet().length;
    final gameInfo = HomeGameInfo(
      totalGames: GameType.values.length,
      playedGames: playedGames,
      totalSessions: allScores.length,
    );

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
          tr(context, 'التحليلات', 'Analytics', '分析'),
          style: AppTypography.headingMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ─── Overview (moved from dashboard) ──────────────────────
          LqHero(snapshot: snapshot, gameInfo: gameInfo),
          const SizedBox(height: 20),

          // ─── LQ History Chart (only if ≥ 2 data points) ────────────
          if (history.length >= 2) ...[
            _sectionLabel(tr(context, 'سجل المقياس', 'LQ History', 'LQ 历史')),
            const SizedBox(height: 10),
            _buildChart(history),
            const SizedBox(height: 20),
          ],

          AbilityRadarChart(snapshot: snapshot, size: 240),
          const SizedBox(height: 20),

          // ─── Per-game stats ─────────────────────────────────────────
          _sectionLabel(
              tr(context, 'إحصائيات الألعاب', 'Game Statistics', '游戏统计')),
          const SizedBox(height: 10),
          _buildGames(context, gameStats),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: AppTypography.caption);

  // ─── LQ History Line Chart ──────────────────────────────────────────────
  Widget _buildChart(List<AbilitySnapshot> history) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.lqScore))
        .toList();

    return Container(
      height: 160,
      padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 12, 8),
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
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
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

  // ─── Game Stats Grid ────────────────────────────────────────────────────
  Widget _buildGames(BuildContext context, List<_GameStat> stats) {
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
      itemBuilder: (ctx, i) => _GameCard(stat: stats[i]),
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

  const _GameCard({required this.stat});

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

  static String _nameZh(GameType g) => switch (g) {
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
    final name = tr(context, _nameAr(g), _nameEn(g), _nameZh(g));
    final bestStr = _bestStr(stat.best, g);
    final plays = stat.playCount;
    final hasPlayed = plays > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPlayed ? color.withValues(alpha: 0.3) : AppColors.border,
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
                    tr(context, 'الأفضل', 'Best', '最佳'),
                    style: AppTypography.caption.copyWith(fontSize: 11),
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
                    tr(context, 'جلسات', 'Plays', '局'),
                    style: AppTypography.caption.copyWith(fontSize: 11),
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
