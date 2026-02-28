import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/ability_snapshot.dart';

/// Cognitive ability radar chart — 5 dimensions
/// RTL-ordered: Speed → Memory → SpaceLogic → Focus → Perception
class AbilityRadarChart extends StatelessWidget {
  final AbilitySnapshot snapshot;
  final double size;

  const AbilityRadarChart({
    super.key,
    required this.snapshot,
    this.size = 260,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: AppTypography.caption.copyWith(
            color: AppColors.textDisabled,
            fontSize: 10,
          ),
          tickBorderData: const BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
          gridBorderData: const BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
          radarBorderData: const BorderSide(color: Colors.transparent),
          getTitle: (index, angle) {
            final labels = _getLabels(context);
            return RadarChartTitle(
              text: labels[index],
              angle: angle,
            );
          },
          titleTextStyle: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
          titlePositionPercentageOffset: 0.2,
          dataSets: [
            RadarDataSet(
              fillColor: AppColors.goldGlow,
              borderColor: AppColors.gold,
              borderWidth: 2,
              entryRadius: 4,
              dataEntries: _getDataEntries(),
            ),
          ],
        ),
      ),
    );
  }

  List<RadarEntry> _getDataEntries() {
    // RTL order: Speed, Memory, SpaceLogic, Focus, Perception
    return [
      RadarEntry(value: snapshot.speedScore),
      RadarEntry(value: snapshot.memoryScore),
      RadarEntry(value: snapshot.spaceLogicScore),
      RadarEntry(value: snapshot.focusScore),
      RadarEntry(value: snapshot.perceptionScore),
    ];
  }

  List<String> _getLabels(BuildContext context) {
    final l10n = AppL10n.of(context);
    return [
      l10n.dimensionSpeed,
      l10n.dimensionMemory,
      l10n.dimensionSpaceLogic,
      l10n.dimensionFocus,
      l10n.dimensionPerception,
    ];
  }
}
