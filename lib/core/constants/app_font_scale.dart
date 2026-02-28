abstract final class AppFontScale {
  // New readable scale presets for mobile.
  static const double small = 1.20;
  static const double medium = 1.30;
  static const double large = 1.40;

  static const double min = small;
  static const double max = large;

  // Backward compatibility for historical persisted values.
  static double normalize(double raw) {
    if ((raw - 1.20).abs() < 0.02) return small;
    if ((raw - 1.30).abs() < 0.02) return medium;
    if ((raw - 1.40).abs() < 0.02) return large;
    
    // Historical values mapping
    if (raw < 1.25) return small; // 1.0, 1.12, 1.2, 1.24 -> small (1.20)
    if (raw < 1.35) return medium; // 1.3 -> medium (1.30)
    
    return large;
  }
}
