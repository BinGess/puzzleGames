import '../../data/models/user_profile.dart';
import '../enums/game_type.dart';

class GameEconomyConfig {
  final int entryCost;
  final int baseCoinReward;
  final int baseXpReward;
  final List<int> difficultyCoinBonusByTier;
  final List<int> difficultyXpBonusByTier;

  const GameEconomyConfig({
    required this.entryCost,
    required this.baseCoinReward,
    required this.baseXpReward,
    required this.difficultyCoinBonusByTier,
    required this.difficultyXpBonusByTier,
  });
}

class EconomyClaimResult {
  final bool claimed;
  final int coinsGranted;
  final int balanceAfter;

  const EconomyClaimResult({
    required this.claimed,
    required this.coinsGranted,
    required this.balanceAfter,
  });
}

class EconomySettlement {
  final bool won;
  final int coinsGained;
  final int xpGained;
  final int oldLevel;
  final int newLevel;
  final int balanceAfter;
  final String rewardTier;
  final bool consolation;

  const EconomySettlement({
    required this.won,
    required this.coinsGained,
    required this.xpGained,
    required this.oldLevel,
    required this.newLevel,
    required this.balanceAfter,
    this.rewardTier = 'none',
    this.consolation = false,
  });

  bool get leveledUp => newLevel > oldLevel;
  bool get rewarded => coinsGained > 0 || xpGained > 0;
}

class EconomyProgress {
  final int level;
  final int xpInLevel;
  final int xpForNextLevel;
  final int totalXp;

  const EconomyProgress({
    required this.level,
    required this.xpInLevel,
    required this.xpForNextLevel,
    required this.totalXp,
  });
}

class EconomyService {
  static const int dailySupplyCoins = 50;

  static const Map<GameType, GameEconomyConfig> _config = {
    GameType.schulteGrid: GameEconomyConfig(
      entryCost: 6,
      baseCoinReward: 9,
      baseXpReward: 6,
      difficultyCoinBonusByTier: [0, 3, 7],
      difficultyXpBonusByTier: [0, 2, 4],
    ),
    GameType.reactionTime: GameEconomyConfig(
      entryCost: 6,
      baseCoinReward: 9,
      baseXpReward: 6,
      difficultyCoinBonusByTier: [0],
      difficultyXpBonusByTier: [0],
    ),
    GameType.numberMemory: GameEconomyConfig(
      entryCost: 7,
      baseCoinReward: 10,
      baseXpReward: 7,
      difficultyCoinBonusByTier: [0, 4, 8],
      difficultyXpBonusByTier: [0, 3, 6],
    ),
    GameType.stroopTest: GameEconomyConfig(
      entryCost: 8,
      baseCoinReward: 11,
      baseXpReward: 7,
      difficultyCoinBonusByTier: [0, 4, 9],
      difficultyXpBonusByTier: [0, 3, 6],
    ),
    GameType.visualMemory: GameEconomyConfig(
      entryCost: 8,
      baseCoinReward: 11,
      baseXpReward: 7,
      difficultyCoinBonusByTier: [0, 4, 9],
      difficultyXpBonusByTier: [0, 3, 6],
    ),
    GameType.sequenceMemory: GameEconomyConfig(
      entryCost: 8,
      baseCoinReward: 11,
      baseXpReward: 7,
      difficultyCoinBonusByTier: [0, 4, 9],
      difficultyXpBonusByTier: [0, 3, 6],
    ),
    GameType.numberMatrix: GameEconomyConfig(
      entryCost: 9,
      baseCoinReward: 12,
      baseXpReward: 8,
      difficultyCoinBonusByTier: [0, 5, 10, 14],
      difficultyXpBonusByTier: [0, 4, 7, 10],
    ),
    GameType.reverseMemory: GameEconomyConfig(
      entryCost: 9,
      baseCoinReward: 12,
      baseXpReward: 8,
      difficultyCoinBonusByTier: [0, 5, 10],
      difficultyXpBonusByTier: [0, 4, 7],
    ),
    GameType.slidingPuzzle: GameEconomyConfig(
      entryCost: 10,
      baseCoinReward: 13,
      baseXpReward: 8,
      difficultyCoinBonusByTier: [0, 5, 11],
      difficultyXpBonusByTier: [0, 4, 8],
    ),
    GameType.towerOfHanoi: GameEconomyConfig(
      entryCost: 10,
      baseCoinReward: 13,
      baseXpReward: 8,
      difficultyCoinBonusByTier: [0, 5, 11],
      difficultyXpBonusByTier: [0, 4, 8],
    ),
  };

  GameEconomyConfig configFor(GameType gameType) {
    return _config[gameType]!;
  }

  int entryCostFor(GameType gameType) => configFor(gameType).entryCost;

  bool canAfford(UserProfile profile, GameType gameType) {
    return profile.coins >= entryCostFor(gameType);
  }

  UserProfile consumeEntryCost(UserProfile profile, GameType gameType) {
    final cost = entryCostFor(gameType);
    if (profile.coins < cost) return profile;
    return profile.copyWith(
      coins: profile.coins - cost,
      lifetimeSpent: profile.lifetimeSpent + cost,
    );
  }

  bool canClaimDailySupply(UserProfile profile, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final last = profile.lastDailySupplyAt;
    if (last == null) return true;
    return !_isSameLocalDay(last, current);
  }

  EconomyClaimResult claimDailySupply(UserProfile profile, {DateTime? now}) {
    if (!canClaimDailySupply(profile, now: now)) {
      return EconomyClaimResult(
        claimed: false,
        coinsGranted: 0,
        balanceAfter: profile.coins,
      );
    }
    return EconomyClaimResult(
      claimed: true,
      coinsGranted: dailySupplyCoins,
      balanceAfter: profile.coins + dailySupplyCoins,
    );
  }

  UserProfile applyDailySupply(UserProfile profile,
      {DateTime? now, required EconomyClaimResult claim}) {
    if (!claim.claimed) return profile;
    return profile.copyWith(
      coins: claim.balanceAfter,
      lifetimeEarned: profile.lifetimeEarned + claim.coinsGranted,
      lastDailySupplyAt: now ?? DateTime.now(),
    );
  }

  EconomySettlement settleGame({
    required UserProfile profile,
    required GameType gameType,
    required bool won,
    required int difficulty,
    required bool isNewRecord,
    required double performance,
  }) {
    final cfg = configFor(gameType);
    final tier = _resolveDifficultyTier(
      difficulty: difficulty,
      maxTier: cfg.difficultyCoinBonusByTier.length,
    );
    final diffCoinBonus = cfg.difficultyCoinBonusByTier[tier - 1];
    final diffXpBonus = cfg.difficultyXpBonusByTier[tier - 1];
    final perf = performance.clamp(0.0, 1.0).toDouble();

    final perfCoinBonus = (perf * 4).round();
    final perfXpBonus = (perf * 3).round();
    final recordCoinBonus = won && isNewRecord ? 2 : 0;
    final recordXpBonus = won && isNewRecord ? 1 : 0;

    int gainedCoins = 0;
    int gainedXp = 0;
    var rewardTier = 'none';
    var consolation = false;

    if (won) {
      final baseCoins =
          cfg.baseCoinReward + diffCoinBonus + perfCoinBonus + recordCoinBonus;
      final baseXp =
          cfg.baseXpReward + diffXpBonus + perfXpBonus + recordXpBonus;

      if (perf >= 0.90) {
        // Excellent clear
        rewardTier = 'clear_excellent';
        gainedCoins = (baseCoins * 1.15).round();
        gainedXp = (baseXp * 1.15).round();
      } else if (perf >= 0.70) {
        // Standard clear
        rewardTier = 'clear_standard';
        gainedCoins = baseCoins;
        gainedXp = baseXp;
      } else if (perf >= 0.50) {
        // Valid clear but modest performance
        rewardTier = 'clear_reduced';
        gainedCoins = (baseCoins * 0.82).round();
        gainedXp = (baseXp * 0.88).round();
      } else {
        // Slow/inefficient clear, still rewarded but reduced
        rewardTier = 'clear_low';
        gainedCoins = (baseCoins * 0.68).round();
        gainedXp = (baseXp * 0.78).round();
      }
      gainedCoins = gainedCoins.clamp(1, 9999).toInt();
      gainedXp = gainedXp.clamp(1, 9999).toInt();
    } else {
      // Lost runs: no random payouts. Only near-win gets small refund.
      if (perf >= 0.75) {
        rewardTier = 'near_win';
        consolation = true;
        gainedCoins = (cfg.entryCost * 0.60).round() + (tier - 1);
        gainedXp = (cfg.baseXpReward * 0.45).round() + (tier - 1);
      } else if (perf >= 0.55) {
        rewardTier = 'good_try';
        consolation = true;
        gainedCoins = (cfg.entryCost * 0.30).round();
        gainedXp = (cfg.baseXpReward * 0.25).round();
      } else {
        rewardTier = 'none';
        consolation = false;
        gainedCoins = 0;
        gainedXp = 0;
      }
      gainedCoins = gainedCoins.clamp(0, 9999).toInt();
      gainedXp = gainedXp.clamp(0, 9999).toInt();
    }

    final newTotalXp = profile.xp + gainedXp;
    final newLevel = levelFromTotalXp(newTotalXp);

    return EconomySettlement(
      won: won,
      coinsGained: gainedCoins,
      xpGained: gainedXp,
      oldLevel: profile.level,
      newLevel: newLevel,
      balanceAfter: profile.coins + gainedCoins,
      rewardTier: rewardTier,
      consolation: consolation,
    );
  }

  int _resolveDifficultyTier({
    required int difficulty,
    required int maxTier,
  }) {
    if (maxTier <= 1) return 1;
    return difficulty.clamp(1, maxTier);
  }

  UserProfile applySettlement(
      UserProfile profile, EconomySettlement settlement) {
    if (!settlement.rewarded && !settlement.leveledUp) return profile;
    return profile.copyWith(
      coins: settlement.balanceAfter,
      xp: profile.xp + settlement.xpGained,
      level: settlement.newLevel,
      lifetimeEarned: profile.lifetimeEarned + settlement.coinsGained,
    );
  }

  EconomyProgress progressFor(UserProfile profile) {
    final level = levelFromTotalXp(profile.xp);
    final passed = xpRequiredBeforeLevel(level);
    final totalForNext = xpRequiredForLevel(level);
    final inLevel = (profile.xp - passed).clamp(0, totalForNext);
    return EconomyProgress(
      level: level,
      xpInLevel: inLevel,
      xpForNextLevel: totalForNext,
      totalXp: profile.xp,
    );
  }

  int levelFromTotalXp(int totalXp) {
    var level = 1;
    var consumed = 0;
    while (true) {
      final need = xpRequiredForLevel(level);
      if (consumed + need > totalXp) break;
      consumed += need;
      level++;
    }
    return level;
  }

  int xpRequiredBeforeLevel(int level) {
    var total = 0;
    for (var lv = 1; lv < level; lv++) {
      total += xpRequiredForLevel(lv);
    }
    return total;
  }

  int xpRequiredForLevel(int level) {
    // Slow growth: progression stretches as levels rise.
    return 70 + ((level - 1) * 18) + (((level - 1) * (level - 1)) ~/ 2);
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
