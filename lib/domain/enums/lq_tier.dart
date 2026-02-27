/// LQ score tiers / brain levels
enum LqTier {
  beginner,      // 0-49
  intermediate,  // 50-69
  professional,  // 70-89
  master,        // 90-100
}

extension LqTierRange on LqTier {
  static LqTier fromScore(double score) {
    if (score >= 90) return LqTier.master;
    if (score >= 70) return LqTier.professional;
    if (score >= 50) return LqTier.intermediate;
    return LqTier.beginner;
  }

  String get key => switch (this) {
    LqTier.beginner => 'beginner',
    LqTier.intermediate => 'intermediate',
    LqTier.professional => 'professional',
    LqTier.master => 'master',
  };

  double get minScore => switch (this) {
    LqTier.beginner => 0,
    LqTier.intermediate => 50,
    LqTier.professional => 70,
    LqTier.master => 90,
  };

  double get maxScore => switch (this) {
    LqTier.beginner => 49,
    LqTier.intermediate => 69,
    LqTier.professional => 89,
    LqTier.master => 100,
  };
}
