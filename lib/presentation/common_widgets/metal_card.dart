import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Brushed dark-metal card base widget
class MetalCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor; // optional left border accent
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const MetalCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E2030), Color(0xFF12121C)],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: BorderDirectional(
            top: const BorderSide(color: AppColors.borderGold, width: 0.5),
            bottom: const BorderSide(color: AppColors.border, width: 0.5),
            start: BorderSide(
              color: accentColor ?? AppColors.borderGold,
              width: accentColor != null ? 3 : 0.5,
            ),
            end: const BorderSide(color: AppColors.borderGold, width: 0.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
