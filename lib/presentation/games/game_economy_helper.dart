import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/utils/tr.dart';
import '../../domain/enums/game_type.dart';
import '../../domain/services/economy_service.dart';
import '../providers/app_providers.dart';

class GameEconomyHelper {
  static Future<bool> consumeEntryCost(
    BuildContext context,
    WidgetRef ref,
    GameType gameType,
  ) async {
    final notifier = ref.read(profileProvider.notifier);
    final success = await notifier.consumeEntryCost(gameType);
    if (success) return true;

    if (!context.mounted) return false;
    final profile = ref.read(profileProvider);
    final needed = notifier.entryCostFor(gameType);
    final neededText =
        useArabicDigits(context) ? needed.toArabicDigits() : needed.toString();
    final currentText = useArabicDigits(context)
        ? profile.coins.toArabicDigits()
        : profile.coins.toString();

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(milliseconds: 1700),
        backgroundColor: const Color(0xFF2B1D1D),
        content: Text(
          tr(
            context,
            'العملات غير كافية. تحتاج $neededText (لديك $currentText).',
            'Not enough coins. Need $neededText (you have $currentText).',
            '金币不足，需要 $neededText（当前 $currentText）。',
          ),
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
    return false;
  }

  static Future<EconomySettlement> settleGame(
    WidgetRef ref, {
    required GameType gameType,
    required bool won,
    required int difficulty,
    required bool isNewRecord,
    required double performance,
  }) {
    return ref.read(profileProvider.notifier).settleGame(
          gameType: gameType,
          won: won,
          difficulty: difficulty,
          isNewRecord: isNewRecord,
          performance: performance,
        );
  }

  static String? buildRewardLabel(BuildContext context, EconomySettlement s) {
    if (!s.won || s.coinsGained <= 0) return null;
    final coinsText = useArabicDigits(context)
        ? s.coinsGained.toArabicDigits()
        : s.coinsGained.toString();
    final xpText = useArabicDigits(context)
        ? s.xpGained.toArabicDigits()
        : '${s.xpGained}';
    return tr(
      context,
      'مكافأة: +$coinsText عملة · +$xpText XP',
      'Reward: +$coinsText coins · +$xpText XP',
      '奖励：+$coinsText 金币 · +$xpText 经验',
    );
  }

  static String? buildRewardTip(BuildContext context, EconomySettlement s) {
    if (s.won) {
      if (!s.leveledUp) return null;
      final levelText = useArabicDigits(context)
          ? s.newLevel.toArabicDigits()
          : '${s.newLevel}';
      return tr(
        context,
        'ترقية! وصلت إلى المستوى $levelText.',
        'Level up! You reached level $levelText.',
        '升级了！你已达到 Lv.$levelText。',
      );
    }
    return tr(
      context,
      'هذه الجولة ليست فوزًا: لا مكافأة عملات.',
      'No win this run: no coin reward.',
      '本局未获胜：不发放金币奖励。',
    );
  }
}
