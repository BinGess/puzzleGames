import 'dart:ui';

abstract final class AppLocaleResolver {
  static const _supported = {'ar', 'en', 'zh'};

  static String resolve(String? preference, {Locale? systemLocale}) {
    if (preference != null && _supported.contains(preference)) {
      return preference;
    }

    final locale = systemLocale ?? PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode.toLowerCase();

    if (_supported.contains(languageCode)) {
      return languageCode;
    }

    // Fallback when system locale cannot be mapped.
    return 'en';
  }
}
