import '../models/ability_snapshot.dart';
import '../datasources/hive_datasource.dart';

class AnalyticsRepository {
  /// Save a new ability snapshot (after each game session)
  Future<void> saveSnapshot(AbilitySnapshot snapshot) async {
    await abilityBox.add(snapshot);
  }

  /// Get the most recent snapshot (current ability state)
  AbilitySnapshot get latest {
    if (abilityBox.isEmpty) return AbilitySnapshot.empty;
    final all = abilityBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.first;
  }

  /// Get LQ history (last N snapshots), oldest first
  List<AbilitySnapshot> getLqHistory({int n = 30}) {
    final all = abilityBox.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (all.length > n) return all.sublist(all.length - n);
    return all;
  }

  /// Clear all ability data (reset)
  Future<void> clearAll() async {
    await abilityBox.clear();
  }
}
