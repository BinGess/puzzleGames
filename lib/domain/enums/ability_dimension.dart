/// Five cognitive ability dimensions
enum AbilityDimension {
  speed,       // 反应力 / السرعة — 25%
  memory,      // 记忆力 / الذاكرة — 25%
  spaceLogic,  // 空间逻辑 / المنطق والمساحة — 30%
  focus,       // 注意力 / التركيز — 15%
  perception,  // 感知力 / الإدراك — 5% (fixed 50 in MVP)
}

extension AbilityDimensionWeight on AbilityDimension {
  /// Weight in the LQ formula (sums to 1.0)
  double get weight => switch (this) {
    AbilityDimension.speed => 0.25,
    AbilityDimension.memory => 0.25,
    AbilityDimension.spaceLogic => 0.30,
    AbilityDimension.focus => 0.15,
    AbilityDimension.perception => 0.05,
  };

  String get key => switch (this) {
    AbilityDimension.speed => 'speed',
    AbilityDimension.memory => 'memory',
    AbilityDimension.spaceLogic => 'space_logic',
    AbilityDimension.focus => 'focus',
    AbilityDimension.perception => 'perception',
  };
}
