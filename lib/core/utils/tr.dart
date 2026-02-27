import 'package:flutter/material.dart';

/// Returns localized string based on current app locale.
/// Use for inline translations when AppL10n getters are not available.
String tr(BuildContext context, String ar, String en, String zh) {
  final lang = Localizations.localeOf(context).languageCode;
  switch (lang) {
    case 'ar':
      return ar;
    case 'zh':
      return zh;
    default:
      return en;
  }
}

/// Whether current locale uses RTL (Arabic only).
bool isRtl(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar';
}

/// Whether to use Arabic-Indic digits (٠١٢٣...) for numbers.
bool useArabicDigits(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar';
}
