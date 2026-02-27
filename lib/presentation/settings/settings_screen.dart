import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/haptics.dart';
import '../../data/repositories/score_repository.dart';
import '../../data/repositories/analytics_repository.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          isAr ? 'الإعدادات' : 'Settings',
          style: AppTypography.headingMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ─── Sound & Haptics ──────────────────────────────────────
          _sectionHeader(isAr ? 'الصوت والاهتزاز' : 'Sound & Haptics'),
          _toggleTile(
            icon: profile.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            iconColor: AppColors.gold,
            title: isAr
                ? (profile.soundEnabled ? 'الصوت مفعّل' : 'الصوت معطّل')
                : (profile.soundEnabled ? 'Sound On' : 'Sound Off'),
            value: profile.soundEnabled,
            onChanged: (v) {
              Haptics.selection();
              ref.read(profileProvider.notifier).setSound(v);
            },
          ),
          _toggleTile(
            icon: profile.hapticsEnabled
                ? Icons.vibration_rounded
                : Icons.phone_android_rounded,
            iconColor: AppColors.sequenceMemory,
            title: isAr
                ? (profile.hapticsEnabled ? 'الاهتزاز مفعّل' : 'الاهتزاز معطّل')
                : (profile.hapticsEnabled ? 'Haptics On' : 'Haptics Off'),
            value: profile.hapticsEnabled,
            onChanged: (v) {
              ref.read(profileProvider.notifier).setHaptics(v);
            },
          ),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── Language ─────────────────────────────────────────────
          _sectionHeader(isAr ? 'اللغة' : 'Language'),
          _choiceTile(
            icon: Icons.language_rounded,
            iconColor: AppColors.reaction,
            title: isAr ? 'اللغة' : 'Language',
            value: profile.languageCode == 'ar'
                ? (isAr ? 'العربية' : 'Arabic')
                : (isAr ? 'الإنجليزية' : 'English'),
            onTap: () {
              Haptics.selection();
              _showLanguagePicker(context, ref, isAr, profile.languageCode);
            },
          ),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── Font Size ────────────────────────────────────────────
          _sectionHeader(isAr ? 'حجم الخط' : 'Font Size'),
          _fontSizeTile(context, ref, isAr, profile.fontScale),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── Data ─────────────────────────────────────────────────
          _sectionHeader(isAr ? 'البيانات' : 'Data'),
          _actionTile(
            icon: Icons.delete_outline_rounded,
            iconColor: AppColors.error,
            title: isAr ? 'إعادة تعيين البيانات' : 'Reset All Data',
            subtitle: isAr
                ? 'حذف جميع النتائج والسجلات'
                : 'Delete all scores and records',
            onTap: () => _confirmReset(context, ref, isAr),
          ),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── About ────────────────────────────────────────────────
          _sectionHeader(isAr ? 'عن التطبيق' : 'About'),
          _infoTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.textSecondary,
            title: isAr ? 'الإصدار' : 'Version',
            value: '1.0.0',
          ),
          _infoTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.textSecondary,
            title: isAr ? 'الخصوصية' : 'Privacy',
            value: isAr
                ? 'جميع البيانات على جهازك فقط'
                : 'All data stored locally only',
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(title, style: AppTypography.caption),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: _iconBox(icon, iconColor),
      title: Text(title, style: AppTypography.bodyMedium),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.gold,
        activeTrackColor: AppColors.goldVeryMuted,
        inactiveThumbColor: AppColors.textDisabled,
        inactiveTrackColor: AppColors.surfaceElevated,
      ),
    );
  }

  Widget _choiceTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: _iconBox(icon, iconColor),
      title: Text(title, style: AppTypography.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTypography.labelMedium),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: _iconBox(icon, iconColor),
      title: Text(title,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
      subtitle: Text(subtitle, style: AppTypography.caption),
      onTap: onTap,
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: _iconBox(icon, iconColor),
      title: Text(title, style: AppTypography.bodyMedium),
      trailing: Text(value, style: AppTypography.labelMedium),
    );
  }

  Widget _fontSizeTile(
      BuildContext context, WidgetRef ref, bool isAr, double currentScale) {
    final options = [
      (0.85, isAr ? 'صغير' : 'Small'),
      (1.0, isAr ? 'متوسط' : 'Medium'),
      (1.15, isAr ? 'كبير' : 'Large'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _iconBox(Icons.text_fields_rounded, AppColors.numberMemory),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: options.map((opt) {
                final selected = (opt.$1 - currentScale).abs() < 0.01;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () {
                      Haptics.selection();
                      ref
                          .read(profileProvider.notifier)
                          .setFontScale(opt.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? AppColors.gold : AppColors.border,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        opt.$2,
                        style: AppTypography.labelMedium.copyWith(
                          color:
                              selected ? AppColors.gold : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  void _showLanguagePicker(
      BuildContext context, WidgetRef ref, bool isAr, String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('العربية',
                    style: AppTypography.bodyMedium
                        .copyWith(color: current == 'ar' ? AppColors.gold : null)),
                trailing: current == 'ar'
                    ? const Icon(Icons.check_rounded, color: AppColors.gold)
                    : null,
                onTap: () {
                  Haptics.selection();
                  ref.read(profileProvider.notifier).setLanguage('ar');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: Text('English',
                    style: AppTypography.bodyMedium
                        .copyWith(color: current == 'en' ? AppColors.gold : null)),
                trailing: current == 'en'
                    ? const Icon(Icons.check_rounded, color: AppColors.gold)
                    : null,
                onTap: () {
                  Haptics.selection();
                  ref.read(profileProvider.notifier).setLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmReset(
      BuildContext context, WidgetRef ref, bool isAr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'إعادة تعيين' : 'Reset Data'),
        content: Text(
          isAr
              ? 'هل أنت متأكد؟ ستُحذف جميع النتائج والسجلات.'
              : 'Are you sure? All scores and records will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isAr ? 'نعم، أعد التعيين' : 'Yes, Reset',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ScoreRepository().clearAll();
      await AnalyticsRepository().clearAll();
      ref.read(abilityProvider.notifier).recompute();
    }
  }
}
