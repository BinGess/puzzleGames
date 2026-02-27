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

  String _t(String ar, String en, String zh, String lang) {
    switch (lang) {
      case 'ar':
        return ar;
      case 'zh':
        return zh;
      default:
        return en;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final lang = profile.languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          _t('الإعدادات', 'Settings', '设置', lang),
          style: AppTypography.headingMedium,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ─── Sound & Haptics ──────────────────────────────────────
          _sectionHeader(_t('الصوت والاهتزاز', 'Sound & Haptics', '声音与震动', lang)),
          _toggleTile(
            icon: profile.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            iconColor: AppColors.gold,
            title: profile.soundEnabled
                ? _t('الصوت مفعّل', 'Sound On', '声音开', lang)
                : _t('الصوت معطّل', 'Sound Off', '声音关', lang),
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
            title: profile.hapticsEnabled
                ? _t('الاهتزاز مفعّل', 'Haptics On', '震动开', lang)
                : _t('الاهتزاز معطّل', 'Haptics Off', '震动关', lang),
            value: profile.hapticsEnabled,
            onChanged: (v) {
              ref.read(profileProvider.notifier).setHaptics(v);
            },
          ),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── Language ─────────────────────────────────────────────
          _sectionHeader(_t('اللغة', 'Language', '语言', lang)),
          _choiceTile(
            icon: Icons.language_rounded,
            iconColor: AppColors.reaction,
            title: _t('اللغة', 'Language', '语言', lang),
            value: profile.languageCode == 'ar'
                ? _t('العربية', 'Arabic', '阿拉伯语', lang)
                : profile.languageCode == 'zh'
                    ? _t('中文', 'Chinese', '中文', lang)
                    : _t('الإنجليزية', 'English', '英语', lang),
            onTap: () {
              Haptics.selection();
              _showLanguagePicker(context, ref, lang, profile.languageCode);
            },
          ),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── Font Size ────────────────────────────────────────────
          _sectionHeader(_t('حجم الخط', 'Font Size', '字号', lang)),
          _fontSizeTile(context, ref, lang, profile.fontScale),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── Data ─────────────────────────────────────────────────
          _sectionHeader(_t('البيانات', 'Data', '数据', lang)),
          _actionTile(
            icon: Icons.delete_outline_rounded,
            iconColor: AppColors.error,
            title: _t('إعادة تعيين البيانات', 'Reset All Data', '重置所有数据', lang),
            subtitle: _t(
                'حذف جميع النتائج والسجلات',
                'Delete all scores and records',
                '删除所有分数和记录',
                lang),
            onTap: () => _confirmReset(context, ref, lang),
          ),

          const Divider(color: AppColors.border, thickness: 0.5, height: 32),

          // ─── About ────────────────────────────────────────────────
          _sectionHeader(_t('عن التطبيق', 'About', '关于', lang)),
          _infoTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.textSecondary,
            title: _t('الإصدار', 'Version', '版本', lang),
            value: '1.0.0',
          ),
          _infoTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.textSecondary,
            title: _t('الخصوصية', 'Privacy', '隐私', lang),
            value: _t(
                'جميع البيانات على جهازك فقط',
                'All data stored locally only',
                '所有数据仅保存在您的设备上',
                lang),
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
      BuildContext context, WidgetRef ref, String lang, double currentScale) {
    final options = [
      (0.85, _t('صغير', 'Small', '小', lang)),
      (1.0, _t('متوسط', 'Medium', '中', lang)),
      (1.15, _t('كبير', 'Large', '大', lang)),
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
                  padding: const EdgeInsetsDirectional.only(start: 8),
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
      BuildContext context, WidgetRef ref, String lang, String current) {
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
              ListTile(
                title: Text('中文',
                    style: AppTypography.bodyMedium
                        .copyWith(color: current == 'zh' ? AppColors.gold : null)),
                trailing: current == 'zh'
                    ? const Icon(Icons.check_rounded, color: AppColors.gold)
                    : null,
                onTap: () {
                  Haptics.selection();
                  ref.read(profileProvider.notifier).setLanguage('zh');
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
      BuildContext context, WidgetRef ref, String lang) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('إعادة تعيين', 'Reset Data', '重置数据', lang)),
        content: Text(
          _t(
            'هل أنت متأكد؟ ستُحذف جميع النتائج والسجلات.',
            'Are you sure? All scores and history will be deleted.',
            '确定吗？所有分数和历史记录将被删除。',
            lang,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('إلغاء', 'Cancel', '取消', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _t('نعم، أعد التعيين', 'Yes, Reset', '确认重置', lang),
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
