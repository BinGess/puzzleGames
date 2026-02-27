import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/providers/app_providers.dart';

class LogicLabApp extends ConsumerWidget {
  const LogicLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final languageCode = profile.languageCode;

    return MaterialApp.router(
      title: 'مختبر المنطق',
      debugShowCheckedModeBanner: false,

      // ─── Theme ────────────────────────────────────────────────────
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // ─── Localization + RTL ───────────────────────────────────────
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'), // Arabic (Gulf)
        Locale('en', 'US'), // English
      ],
      locale: Locale(languageCode),

      // ─── Navigation ───────────────────────────────────────────────
      routerConfig: appRouter,

      // ─── Builder: enforce RTL + font scale ────────────────────────
      builder: (context, child) {
        final fontScale = profile.fontScale;
        return Directionality(
          textDirection: languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
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
