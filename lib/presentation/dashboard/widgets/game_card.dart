import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/enums/game_type.dart';
import '../../../data/models/score_record.dart';

/// Data for a single game card on the dashboard
class GameCardData {
  final GameType type;
  final String nameAr;
  final String nameEn;
  final IconData icon;
  final Color accentColor;
  final ScoreRecord? bestScore;

  const GameCardData({
    required this.type,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.accentColor,
    this.bestScore,
  });
}

class GameCard extends StatelessWidget {
  final GameCardData data;
  final VoidCallback onTap;

  const GameCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1C28), Color(0xFF111118)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            // Leading edge (right in RTL) shows accent color
            right: BorderSide(color: data.accentColor, width: 3),
            top: const BorderSide(color: AppColors.borderGold, width: 0.5),
            bottom: const BorderSide(color: AppColors.border, width: 0.5),
            left: const BorderSide(color: AppColors.borderGold, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Icon + name row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Score (bottom left in LTR = bottom right in RTL)
                if (data.bestScore != null)
                  _ScoreBadge(
                    score: data.bestScore!.score,
                    metric: data.type.scoreMetric,
                    lowerIsBetter: data.type.lowerIsBetter,
                    color: data.accentColor,
                  )
                else
                  Text(
                    isAr ? 'جديد' : 'New',
                    style: AppTypography.caption.copyWith(
                      color: data.accentColor,
                    ),
                  ),
                // Icon circle
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.accentColor.withValues(alpha: 0.15),
                    border: Border.all(
                      color: data.accentColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    data.icon,
                    color: data.accentColor,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Game name
            Text(
              isAr ? data.nameAr : data.nameEn,
              style: AppTypography.labelLarge,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isAr ? data.nameEn : data.nameAr,
              style: AppTypography.caption,
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final String metric;
  final bool lowerIsBetter;
  final Color color;

  const _ScoreBadge({
    required this.score,
    required this.metric,
    required this.lowerIsBetter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    String display;
    switch (metric) {
      case 'time':
        display = '${(score / 1000).toStringAsFixed(1)}s';
        break;
      case 'ms':
        display = '${score.round()}ms';
        break;
      case 'length':
        display = '${score.toInt()}';
        break;
      case 'correct':
        display = '${score.toInt()}';
        break;
      case 'moves':
        display = '${score.toInt()}';
        break;
      default:
        display = score.toStringAsFixed(0);
    }

    return Text(
      display,
      style: AppTypography.labelMedium.copyWith(color: color),
    );
  }
}
