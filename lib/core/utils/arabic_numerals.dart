/// Utilities for Arabic numeral display
/// Eastern Arabic numerals: ٠١٢٣٤٥٦٧٨٩
/// Western Arabic numerals: 0123456789
library;

const _westernToArabic = {
  '0': '٠',
  '1': '١',
  '2': '٢',
  '3': '٣',
  '4': '٤',
  '5': '٥',
  '6': '٦',
  '7': '٧',
  '8': '٨',
  '9': '٩',
};

const _arabicToWestern = {
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
};

extension ArabicNumeralString on String {
  /// Convert Western digits (0-9) to Eastern Arabic digits (٠-٩)
  String toArabicNumerals() {
    return splitMapJoin(
      RegExp(r'\d'),
      onMatch: (m) => _westernToArabic[m.group(0)!] ?? m.group(0)!,
      onNonMatch: (s) => s,
    );
  }

  /// Convert Eastern Arabic digits (٠-٩) back to Western digits (0-9)
  String toWesternNumerals() {
    return splitMapJoin(
      RegExp(r'[٠١٢٣٤٥٦٧٨٩]'),
      onMatch: (m) => _arabicToWestern[m.group(0)!] ?? m.group(0)!,
      onNonMatch: (s) => s,
    );
  }
}

extension ArabicNumeralInt on int {
  /// Format as Eastern Arabic numeral string
  String toArabicDigits() => toString().toArabicNumerals();
}

/// Build an Arabic numeral sequence string for a list of digits
/// e.g. [4, 2, 7] → "٤٢٧"
String buildArabicDigitString(List<int> digits) {
  return digits.map((d) => d.toArabicDigits()).join();
}

/// Parse a string of Arabic numerals into a list of ints
/// e.g. "٤٢٧" → [4, 2, 7]
List<int> parseArabicDigits(String s) {
  return s
      .toWesternNumerals()
      .split('')
      .where((c) => RegExp(r'\d').hasMatch(c))
      .map(int.parse)
      .toList();
}

/// The 9 Eastern Arabic numeral characters, indexed 0-9
const List<String> arabicDigitChars = [
  '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩',
];
