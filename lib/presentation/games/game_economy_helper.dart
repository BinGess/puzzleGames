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
    if (s.coinsGained <= 0 && s.xpGained <= 0) return null;
    final coinsText = useArabicDigits(context)
        ? s.coinsGained.toArabicDigits()
        : s.coinsGained.toString();
    final xpText = useArabicDigits(context)
        ? s.xpGained.toArabicDigits()
        : '${s.xpGained}';
    if (s.consolation) {
      return tr(
        context,
        'تعويض: +$coinsText عملة · +$xpText XP',
        'Consolation: +$coinsText coins · +$xpText XP',
        '保底返还：+$coinsText 金币 · +$xpText 经验',
      );
    }
    if (s.rewardTier == 'clear_excellent') {
      return tr(
        context,
        'مكافأة مميزة: +$coinsText عملة · +$xpText XP',
        'Excellent reward: +$coinsText coins · +$xpText XP',
        '卓越奖励：+$coinsText 金币 · +$xpText 经验',
      );
    }
    return tr(
      context,
      'مكافأة: +$coinsText عملة · +$xpText XP',
      'Reward: +$coinsText coins · +$xpText XP',
      '奖励：+$coinsText 金币 · +$xpText 经验',
    );
  }

  static String? buildRewardTip(BuildContext context, EconomySettlement s) {
    final tipParts = <String>[];

    final levelText = useArabicDigits(context)
        ? s.newLevel.toArabicDigits()
        : '${s.newLevel}';
    if (s.leveledUp) {
      tipParts.add(
        tr(
          context,
          'ترقية! وصلت إلى المستوى $levelText.',
          'Level up! You reached level $levelText.',
          '升级了！你已达到 Lv.$levelText。',
        ),
      );
    }

    switch (s.rewardTier) {
      case 'clear_excellent':
        tipParts.add(
          tr(
            context,
            'أداء ممتاز: تم تطبيق مكافأة إضافية.',
            'Excellent clear: bonus multiplier applied.',
            '表现优秀：已触发额外奖励加成。',
          ),
        );
        break;
      case 'clear_reduced':
      case 'clear_low':
        tipParts.add(
          tr(
            context,
            'تم اجتياز الجولة، لكن المكافأة خُفِّضت حسب الأداء.',
            'Cleared, but rewards were reduced due to performance.',
            '已通关，但奖励会按表现下调。',
          ),
        );
        break;
      case 'near_win':
        tipParts.add(
          tr(
            context,
            'كنت قريبًا من الفوز: تم منح تعويض بسيط.',
            'Near win: small consolation granted.',
            '接近通关：已发放少量保底返还。',
          ),
        );
        break;
      case 'good_try':
        tipParts.add(
          tr(
            context,
            'محاولة جيدة: تم منح تعويض تدريبي بسيط.',
            'Good try: small training consolation granted.',
            '本局表现尚可：发放基础训练返还。',
          ),
        );
        break;
      case 'none':
        if (!s.won && !s.rewarded) {
          tipParts.add(
            tr(
              context,
              'هذه الجولة لم تحقق شرط المكافأة.',
              'No reward for this run.',
              '本局未达到奖励条件。',
            ),
          );
        }
        break;
      default:
        break;
    }

    if (tipParts.isEmpty) return null;
    return tipParts.join('  ');
  }
}
