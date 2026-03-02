import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/haptics.dart';

class DifficultyOption<T> {
  final T value;
  final String badge;
  final String title;
  final String subtitle;
  final String? details;

  const DifficultyOption({
    required this.value,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.details,
  });
}

class DifficultyOptionList<T> extends StatelessWidget {
  final List<DifficultyOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final Color accentColor;
  final double spacing;

  const DifficultyOptionList({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    required this.accentColor,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          _DifficultyOptionTile<T>(
            option: options[i],
            selected: options[i].value == selectedValue,
            accentColor: accentColor,
            onTap: () {
              Haptics.selection();
              onChanged(options[i].value);
            },
          ),
          if (i != options.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class _DifficultyOptionTile<T> extends StatelessWidget {
  final DifficultyOption<T> option;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DifficultyOptionTile({
    required this.option,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = selected ? accentColor : AppColors.textPrimary;
    final subtitleColor =
        selected ? accentColor.withValues(alpha: 0.9) : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.22),
                    accentColor.withValues(alpha: 0.08),
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFF1C1C28), Color(0xFF111118)],
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
            width: selected ? 1.4 : 0.7,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? accentColor.withValues(alpha: 0.16)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? accentColor.withValues(alpha: 0.75)
                      : AppColors.border,
                  width: selected ? 1.2 : 0.6,
                ),
              ),
              child: Text(
                option.badge,
                style: AppTypography.headingSmall.copyWith(
                  color: highlight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: AppTypography.labelLarge.copyWith(
                      color: highlight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: subtitleColor,
                    ),
                  ),
                  if (option.details != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      option.details!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? accentColor : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
