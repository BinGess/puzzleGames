import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/haptics.dart';
import '../../domain/enums/game_type.dart';
import '../providers/app_providers.dart';
import 'widgets/ability_radar_chart.dart';
import 'widgets/lq_hero.dart';
import 'widgets/game_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ability = ref.watch(abilityProvider);
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Text(
              isAr ? 'مختبر المنطق' : 'Logic Lab',
              style: AppTypography.headingMedium,
            ),
            actions: [
              // Settings (leading = rightmost in RTL app bar)
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.textSecondary),
                onPressed: () {
                  Haptics.selection();
                  context.push(AppRoutes.settings);
                },
              ),
            ],
            leading: IconButton(
              icon: const Icon(Icons.bar_chart_rounded,
                  color: AppColors.textSecondary),
              onPressed: () {
                Haptics.selection();
                context.push(AppRoutes.analytics);
              },
            ),
          ),

          // ─── LQ Hero + Radar Chart ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  LqHero(snapshot: ability),
                  const SizedBox(height: 16),
                  AbilityRadarChart(snapshot: ability, size: 240),
                  const SizedBox(height: 24),
                  // Section divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: AppColors.border, thickness: 0.5),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          isAr ? 'الألعاب' : 'Games',
                          style: AppTypography.labelMedium,
                        ),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.border, thickness: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ─── Game Grid ────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cardData = _buildCardData(
                    GameType.values[index],
                    ref,
                  );
                  return GameCard(
                    data: cardData,
                    onTap: () => context.push(
                      AppRoutes.gameRoute(GameType.values[index]),
                    ),
                  );
                },
                childCount: GameType.values.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  GameCardData _buildCardData(GameType type, WidgetRef ref) {
    final best = ref.read(bestScoreProvider(type.id));
    return GameCardData(
      type: type,
      nameAr: _nameAr(type),
      nameEn: _nameEn(type),
      icon: _icon(type),
      accentColor: _accent(type),
      bestScore: best,
    );
  }

  String _nameAr(GameType type) => switch (type) {
    GameType.schulteGrid => 'شبكة شولت',
    GameType.reactionTime => 'وقت التفاعل',
    GameType.numberMemory => 'ذاكرة الأرقام',
    GameType.stroopTest => 'اختبار ستروب',
    GameType.visualMemory => 'ذاكرة بصرية',
    GameType.sequenceMemory => 'تسلسل',
    GameType.numberMatrix => 'مصفوفة الأرقام',
    GameType.reverseMemory => 'ذاكرة العكس',
    GameType.slidingPuzzle => 'لغز الأرقام',
    GameType.towerOfHanoi => 'برج هانو',
  };

  String _nameEn(GameType type) => switch (type) {
    GameType.schulteGrid => 'Schulte Grid',
    GameType.reactionTime => 'Reaction Time',
    GameType.numberMemory => 'Number Memory',
    GameType.stroopTest => 'Stroop Test',
    GameType.visualMemory => 'Visual Memory',
    GameType.sequenceMemory => 'Sequence Memory',
    GameType.numberMatrix => 'Number Matrix',
    GameType.reverseMemory => 'Reverse Memory',
    GameType.slidingPuzzle => 'Sliding Puzzle',
    GameType.towerOfHanoi => 'Tower of Hanoi',
  };

  IconData _icon(GameType type) => switch (type) {
    GameType.schulteGrid => Icons.grid_3x3,
    GameType.reactionTime => Icons.bolt,
    GameType.numberMemory => Icons.pin,
    GameType.stroopTest => Icons.format_color_text,
    GameType.visualMemory => Icons.grid_view,
    GameType.sequenceMemory => Icons.apps,
    GameType.numberMatrix => Icons.touch_app,
    GameType.reverseMemory => Icons.swap_horiz,
    GameType.slidingPuzzle => Icons.extension,
    GameType.towerOfHanoi => Icons.layers,
  };

  Color _accent(GameType type) => switch (type) {
    GameType.schulteGrid => AppColors.schulte,
    GameType.reactionTime => AppColors.reaction,
    GameType.numberMemory => AppColors.numberMemory,
    GameType.stroopTest => AppColors.stroop,
    GameType.visualMemory => AppColors.visualMemory,
    GameType.sequenceMemory => AppColors.sequenceMemory,
    GameType.numberMatrix => AppColors.numberMatrix,
    GameType.reverseMemory => AppColors.reverseMemory,
    GameType.slidingPuzzle => AppColors.slidingPuzzle,
    GameType.towerOfHanoi => AppColors.towerOfHanoi,
  };
}
