import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/tr.dart';
import '../../domain/enums/game_type.dart';
import '../providers/app_providers.dart';
import 'widgets/game_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    ref.watch(scoresChangedProvider);
    final allScores = ref.read(scoreRepoProvider).getAllScores();
    final totalSessions = allScores.length;
    final playedGames = allScores.map((s) => s.gameId).toSet().length;
    final featuredType = _displayOrder.first;
    final featuredData = _buildCardData(featuredType, ref);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DashboardBackground()),
          CustomScrollView(
            slivers: [
              // ─── App Bar ──────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Text(
                  l10n.appName,
                  style: AppTypography.headingMedium,
                ),
                actions: [
                  _GlassIconButton(
                    icon: Icons.settings_outlined,
                    onTap: () {
                      Haptics.selection();
                      context.push(AppRoutes.settings);
                    },
                  ),
                  const SizedBox(width: 12),
                ],
                leading: _GlassIconButton(
                  icon: Icons.bar_chart_rounded,
                  onTap: () {
                    Haptics.selection();
                    context.push(AppRoutes.analytics);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _FeaturedMixCard(
                    featuredData: featuredData,
                    totalSessions: totalSessions,
                    onStart: () =>
                        context.push(AppRoutes.gameRoute(featuredType)),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: 20),
                  child: _ModeChipRow(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.gamesSection,
                        style: AppTypography.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        tr(
                          context,
                          '$playedGames/${GameType.values.length} ألعاب',
                          '$playedGames/${GameType.values.length} tracks ready',
                          '已解锁 $playedGames/${GameType.values.length} 项',
                        ),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Game Grid ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final crossAxisCount = width >= 1160
                        ? 5
                        : width >= 900
                            ? 4
                            : width >= 640
                                ? 3
                                : 2;
                    const spacing = 12.0;
                    final cardWidth = (width - (crossAxisCount - 1) * spacing) /
                        crossAxisCount;
                    final cardAspectRatio = cardWidth >= 220 ? 0.98 : 0.88;

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: cardAspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final type = _displayOrder[index];
                          final cardData = _buildCardData(type, ref);
                          return GameCard(
                            data: cardData,
                            onTap: () =>
                                context.push(AppRoutes.gameRoute(type)),
                          );
                        },
                        childCount: _displayOrder.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Display order follows recommendation priority ────────────────
  // (Hive IDs remain unchanged so score history is unaffected)
  static const _displayOrder = [
    GameType.schulteGrid, // #1  首选 — 视觉搜索
    GameType.stroopTest, // #2  次选 — 抗干扰
    GameType.reverseMemory, // #3  倒序记忆
    GameType.sequenceMemory, // #4  序列/Simon Says
    GameType.towerOfHanoi, // #5  汉诺塔
    GameType.reactionTime, // #6  反应时间
    GameType.numberMemory, // #7  数字记忆
    GameType.visualMemory, // #8  视觉记忆
    GameType.numberMatrix, // #10 猩猩测试 (Chimp Test)
    GameType.slidingPuzzle, // #11 数字华容道
  ];

  GameCardData _buildCardData(GameType type, WidgetRef ref) {
    final best = ref.watch(bestScoreProvider(type.id));
    return GameCardData(
      type: type,
      nameAr: _nameAr(type),
      nameEn: _nameEn(type),
      nameZh: _nameZh(type),
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
        GameType.numberMatrix => 'اختبار الشمبانزي',
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
        GameType.numberMatrix => 'Chimp Test',
        GameType.reverseMemory => 'Reverse Memory',
        GameType.slidingPuzzle => 'Sliding Puzzle',
        GameType.towerOfHanoi => 'Tower of Hanoi',
      };

  String _nameZh(GameType type) => switch (type) {
        GameType.schulteGrid => '舒尔特方格',
        GameType.reactionTime => '反应时间',
        GameType.numberMemory => '数字记忆',
        GameType.stroopTest => '斯特鲁普测试',
        GameType.visualMemory => '视觉记忆',
        GameType.sequenceMemory => '序列记忆',
        GameType.numberMatrix => '猩猩测试',
        GameType.reverseMemory => '数字倒序',
        GameType.slidingPuzzle => '数字华容道',
        GameType.towerOfHanoi => '汉诺塔',
      };

  IconData _icon(GameType type) => switch (type) {
        GameType.schulteGrid => Icons.grid_3x3,
        GameType.reactionTime => Icons.bolt,
        GameType.numberMemory => Icons.pin,
        GameType.stroopTest => Icons.format_color_text,
        GameType.visualMemory => Icons.grid_view,
        GameType.sequenceMemory => Icons.apps,
        GameType.numberMatrix => Icons.psychology,
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

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Deep dark base gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF060710),
                  Color(0xFF0A0B16),
                  Color(0xFF0E1122),
                  Color(0xFF111022),
                ],
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
          // Gold glow — top right
          Positioned(
            top: -140,
            right: -100,
            child: _GlowBlob(
              size: 340,
              color: AppColors.sequenceMemory.withValues(alpha: 0.14),
            ),
          ),
          // Purple/blue glow — bottom left
          Positioned(
            bottom: -200,
            left: -140,
            child: _GlowBlob(
              size: 380,
              color: AppColors.reaction.withValues(alpha: 0.13),
            ),
          ),
          // Mid accent glow — center
          Positioned(
            top: 260,
            right: -60,
            child: _GlowBlob(
              size: 220,
              color: AppColors.gold.withValues(alpha: 0.055),
            ),
          ),
          // Full-screen texture
          const Positioned.fill(
            child: CustomPaint(
              painter: _TexturePainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _TexturePainter extends CustomPainter {
  const _TexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // ── Diagonal hatching lines ──────────────────────────────────────────
    final linePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.14)
      ..strokeWidth = 0.5;
    const lineSpacing = 34.0;
    for (double x = -size.height; x < size.width; x += lineSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }

    // ── Horizontal scan lines (subtle, every 60px) ───────────────────────
    final scanPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // ── Vinyl rings (music streaming motif) ─────────────────────────────
    final ringPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.05)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final centers = [
      Offset(size.width * 0.88, size.height * 0.12),
      Offset(size.width * 0.10, size.height * 0.78),
    ];
    for (final center in centers) {
      for (int i = 1; i <= 5; i++) {
        canvas.drawCircle(center, i * 22.0, ringPaint);
      }
    }

    // ── Subtle grain dots ───────────────────────────────────────────────
    final dotPaint = Paint()..color = AppColors.gold.withValues(alpha: 0.050);
    const dotSpacing = 28.0;
    for (double y = 10; y < size.height; y += dotSpacing) {
      final rowOffset = ((y ~/ dotSpacing).isEven ? 0.0 : dotSpacing / 2);
      for (double x = rowOffset; x < size.width; x += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.gold.withValues(alpha: 0.10),
          highlightColor: AppColors.gold.withValues(alpha: 0.06),
          onTap: onTap,
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }
}

class _FeaturedMixCard extends StatelessWidget {
  final GameCardData featuredData;
  final int totalSessions;
  final VoidCallback onStart;

  const _FeaturedMixCard({
    required this.featuredData,
    required this.totalSessions,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr(
        context,
        'مزيج اليوم. ابدأ ${featuredData.nameAr}',
        'Daily mix. Start ${featuredData.nameEn}',
        '今日精选，开始${featuredData.nameZh}',
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            Haptics.light();
            onStart();
          },
          borderRadius: BorderRadius.circular(22),
          splashColor: featuredData.accentColor.withValues(alpha: 0.12),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF13182D),
                  Color(0xFF191838),
                  Color(0xFF121321),
                ],
              ),
              border: Border.all(
                color: featuredData.accentColor.withValues(alpha: 0.35),
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color: featuredData.accentColor.withValues(alpha: 0.20),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -6,
                  top: -18,
                  child: Icon(
                    featuredData.icon,
                    size: 94,
                    color: featuredData.accentColor.withValues(alpha: 0.22),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.reaction.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.reaction.withValues(alpha: 0.45),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        tr(context, 'مزيج معرفي يومي', 'DAILY COGNITIVE MIX',
                            '每日认知精选'),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.reaction,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr(context, 'تدريب بنَفَس موسيقي',
                          'Train in a Streaming Flow', '像听歌一样训练'),
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        'ابدأ بـ ${featuredData.nameAr} وتابع جلسة مركّزة.',
                        'Start with ${featuredData.nameEn} and keep the focus rhythm.',
                        '从${featuredData.nameZh}开始，进入专注节奏。',
                      ),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: featuredData.accentColor
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: featuredData.accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr(context, 'ابدأ الآن', 'Start Mix', '立即开始'),
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          tr(
                            context,
                            '$totalSessions جلسة',
                            '$totalSessions sessions',
                            '$totalSessions 次训练',
                          ),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChipRow extends StatelessWidget {
  const _ModeChipRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ModeChip(
            icon: Icons.auto_graph_rounded,
            label: tr(context, 'تركيز', 'Focus', '专注'),
            active: true,
          ),
          _ModeChip(
            icon: Icons.memory_rounded,
            label: tr(context, 'ذاكرة', 'Memory', '记忆'),
          ),
          _ModeChip(
            icon: Icons.bolt_rounded,
            label: tr(context, 'سرعة', 'Speed', '速度'),
          ),
          _ModeChip(
            icon: Icons.account_tree_rounded,
            label: tr(context, 'منطق', 'Logic', '逻辑'),
          ),
          _ModeChip(
            icon: Icons.extension_rounded,
            label: tr(context, 'تحدي', 'Challenge', '挑战'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _ModeChip({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.reaction : AppColors.textSecondary;
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? AppColors.reaction.withValues(alpha: 0.15)
            : AppColors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? AppColors.reaction.withValues(alpha: 0.45)
              : AppColors.border.withValues(alpha: 0.7),
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
