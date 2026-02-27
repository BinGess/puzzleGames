import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/tr.dart';
import '../../../data/models/ability_snapshot.dart';
import '../../../domain/enums/lq_tier.dart';
import '../../common_widgets/metal_card.dart';

class HomeGameInfo {
  final int totalGames;
  final int playedGames;
  final int totalSessions;

  const HomeGameInfo({
    required this.totalGames,
    required this.playedGames,
    required this.totalSessions,
  });
}

/// Large LQ score + tier badge hero widget shown on dashboard
class LqHero extends StatelessWidget {
  final AbilitySnapshot snapshot;
  final HomeGameInfo gameInfo;

  const LqHero({
    super.key,
    required this.snapshot,
    required this.gameInfo,
  });

  @override
  Widget build(BuildContext context) {
    final tier = LqTierRange.fromScore(snapshot.lqScore);
    final tierLabel = _tierLabel(context, tier);
    final hasData = snapshot.lqScore > 0;

    return MetalCard(
      accentColor: AppColors.goldMuted,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'نظرة عامة', 'Overview', '概览'),
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(context, 'مقياس المنطق', 'Logic Quotient', '逻辑商数'),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasData ? snapshot.lqScore.toStringAsFixed(1) : '--',
                style: AppTypography.displayLarge,
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TierBadge(label: tierLabel, hasData: hasData),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'معلومات اللعبة الأساسية', 'Game Basics', '游戏基础'),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.sports_esports_outlined,
                label: tr(context, 'الألعاب', 'Games', '游戏'),
                value: '${gameInfo.totalGames}',
              ),
              _InfoPill(
                icon: Icons.check_circle_outline,
                label: tr(context, 'المجرّبة', 'Played', '已玩'),
                value: '${gameInfo.playedGames}/${gameInfo.totalGames}',
              ),
              _InfoPill(
                icon: Icons.bolt_outlined,
                label: tr(context, 'الجلسات', 'Sessions', '会话'),
                value: '${gameInfo.totalSessions}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _tierLabel(BuildContext context, LqTier tier) {
    return switch (tier) {
      LqTier.beginner => tr(context, 'مبتدئ', 'Beginner', '入门'),
      LqTier.intermediate => tr(context, 'متوسط', 'Intermediate', '中级'),
      LqTier.professional => tr(context, 'محترف', 'Professional', '专业'),
      LqTier.master => tr(context, 'معلم', 'Master', '大师'),
    };
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.goldMuted),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String label;
  final bool hasData;

  const _TierBadge({required this.label, required this.hasData});

  @override
  Widget build(BuildContext context) {
    if (!hasData) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldVeryMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldMuted, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.tierBadge,
      ),
    );
  }
}
