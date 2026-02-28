abstract final class AppFontScale {
  // New readable scale presets for mobile.
  static const double small = 1.00;
  static const double medium = 1.12;
  static const double large = 1.24;

  static const double min = small;
  static const double max = large;

  // Backward compatibility for historical persisted values.
  static double normalize(double raw) {
    if ((raw - 0.85).abs() < 0.02) return small;
    if ((raw - 1.00).abs() < 0.02) return medium;
    if ((raw - 1.15).abs() < 0.02) return large;
    return raw.clamp(min, max).toDouble();
  }
}
