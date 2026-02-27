import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/ability_snapshot.dart';
import '../../data/models/score_record.dart';
import '../../data/datasources/hive_datasource.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/score_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../domain/services/lq_calculator_service.dart';
import '../../domain/enums/game_type.dart';
import '../../core/utils/haptics.dart';

// ─── Repositories (singletons) ───────────────────────────────────────
final profileRepoProvider = Provider<ProfileRepository>(
  (_) => ProfileRepository(),
);

final scoreRepoProvider = Provider<ScoreRepository>(
  (_) => ScoreRepository(),
);

final analyticsRepoProvider = Provider<AnalyticsRepository>(
  (_) => AnalyticsRepository(),
);

final lqCalculatorProvider = Provider<LqCalculatorService>(
  (_) => LqCalculatorService(),
);

// ─── User Profile ────────────────────────────────────────────────────
final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile>(
  (ref) => ProfileNotifier(ref.read(profileRepoProvider)),
);

class ProfileNotifier extends StateNotifier<UserProfile> {
  final ProfileRepository _repo;

  ProfileNotifier(this._repo) : super(_repo.profile) {
    // Sync haptics state
    Haptics.setEnabled(state.hapticsEnabled);
  }

  Future<void> setLanguage(String code) async {
    await _repo.updateLanguage(code);
    state = _repo.profile;
  }

  Future<void> setSound(bool enabled) async {
    await _repo.updateSound(enabled);
    state = _repo.profile;
  }

  Future<void> setHaptics(bool enabled) async {
    await _repo.updateHaptics(enabled);
    Haptics.setEnabled(enabled);
    state = _repo.profile;
  }

  Future<void> setFontScale(double scale) async {
    await _repo.updateFontScale(scale);
    state = _repo.profile;
  }
}

// ─── Ability / LQ ────────────────────────────────────────────────────
final abilityProvider =
    StateNotifierProvider<AbilityNotifier, AbilitySnapshot>(
  (ref) => AbilityNotifier(
    ref.read(analyticsRepoProvider),
    ref.read(scoreRepoProvider),
    ref.read(lqCalculatorProvider),
  ),
);

class AbilityNotifier extends StateNotifier<AbilitySnapshot> {
  final AnalyticsRepository _analyticsRepo;
  final ScoreRepository _scoreRepo;
  final LqCalculatorService _lqService;

  AbilityNotifier(this._analyticsRepo, this._scoreRepo, this._lqService)
      : super(_analyticsRepo.latest);

  /// Recompute ability snapshot after a new game session
  Future<void> recompute() async {
    // Build scores map by game
    final scoresByGame = <String, List<ScoreRecord>>{};
    for (final type in GameType.values) {
      final scores = _scoreRepo.getScoresForGame(type.id);
      if (scores.isNotEmpty) scoresByGame[type.id] = scores;
    }

    final recentAll = _scoreRepo.getAllScores().take(10).toList();

    final snapshot = _lqService.compute(
      scoresByGame: scoresByGame,
      recentAllGames: recentAll,
    );

    await _analyticsRepo.saveSnapshot(snapshot);
    state = snapshot;
  }
}

// ─── Scores per game ─────────────────────────────────────────────────
final scoresChangedProvider = StreamProvider<int>((ref) async* {
  var revision = 0;
  yield revision;
  await for (final _ in scoresBox.watch()) {
    revision++;
    yield revision;
  }
});

final gameScoresProvider =
    Provider.family<List<ScoreRecord>, String>((ref, gameId) {
  ref.watch(scoresChangedProvider);
  return ref.read(scoreRepoProvider).getScoresForGame(gameId);
});

final bestScoreProvider =
    Provider.family<ScoreRecord?, String>((ref, gameId) {
  ref.watch(scoresChangedProvider);
  final gameType = GameType.values.firstWhere(
    (g) => g.id == gameId,
    orElse: () => GameType.schulteGrid,
  );
  return ref.read(scoreRepoProvider).getBestScore(
        gameId,
        lowerIsBetter: gameType.lowerIsBetter,
      );
});
