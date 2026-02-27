import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/ability_snapshot.dart';
import '../../../domain/enums/lq_tier.dart';

/// Large LQ score + tier badge hero widget shown on dashboard
class LqHero extends StatelessWidget {
  final AbilitySnapshot snapshot;

  const LqHero({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final tier = LqTierRange.fromScore(snapshot.lqScore);
    final tierLabel = _tierLabel(tier, isAr);
    final hasData = snapshot.lqScore > 0;

    return Column(
      children: [
        Text(
          isAr ? 'مقياس المنطق' : 'Logic Quotient',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
      ],
    );
  }

  String _tierLabel(LqTier tier, bool isAr) {
    if (isAr) {
      return switch (tier) {
        LqTier.beginner => 'مبتدئ',
        LqTier.intermediate => 'متوسط',
        LqTier.professional => 'محترف',
        LqTier.master => 'معلم',
      };
    }
    return switch (tier) {
      LqTier.beginner => 'Beginner',
      LqTier.intermediate => 'Intermediate',
      LqTier.professional => 'Professional',
      LqTier.master => 'Master',
    };
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
