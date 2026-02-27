import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/haptics.dart';

/// Primary CTA button — gold gradient, dark text
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isFullWidth;
  final double? minWidth;

  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isFullWidth = true,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : minWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.goldBright, AppColors.gold, AppColors.goldMuted],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: AppColors.goldGlow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Haptics.light();
            onPressed();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textOnGold,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary ghost button — outlined gold
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isFullWidth;

  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: () {
          Haptics.selection();
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.goldMuted, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.gold,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}
