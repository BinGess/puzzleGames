import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_font_scale.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/utils/app_locale_resolver.dart';
import 'presentation/providers/app_providers.dart';

class LogicLabApp extends ConsumerWidget {
  const LogicLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final languageCode = AppLocaleResolver.resolve(profile.languageCode);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context).appName,
      debugShowCheckedModeBanner: false,

      // ─── Theme ────────────────────────────────────────────────────
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // ─── Localization + RTL ───────────────────────────────────────
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: const [
        Locale('ar', 'SA'), // Arabic (Gulf)
        Locale('en', 'US'), // English
        Locale('zh', 'CN'), // Chinese (Simplified)
      ],
      locale: Locale(languageCode),

      // ─── Navigation ───────────────────────────────────────────────
      routerConfig: appRouter,

      // ─── Builder: enforce RTL + font scale ────────────────────────
      builder: (context, child) {
        final fontScale = AppFontScale.normalize(profile.fontScale);
        return Directionality(
          textDirection:
              languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontScale),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
