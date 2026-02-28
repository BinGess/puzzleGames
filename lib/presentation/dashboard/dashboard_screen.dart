import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/haptics.dart';
import '../../domain/enums/game_type.dart';
import '../providers/app_providers.dart';
import 'widgets/game_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    ref.watch(scoresChangedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _DashboardBackground()),
          CustomScrollView(
            slivers: [
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
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
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

  static const _displayOrder = [
    GameType.schulteGrid,
    GameType.stroopTest,
    GameType.reverseMemory,
    GameType.sequenceMemory,
    GameType.towerOfHanoi,
    GameType.reactionTime,
    GameType.numberMemory,
    GameType.visualMemory,
    GameType.numberMatrix,
    GameType.slidingPuzzle,
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
          Positioned(
            top: -140,
            right: -100,
            child: _GlowBlob(
              size: 340,
              color: AppColors.sequenceMemory.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -140,
            child: _GlowBlob(
              size: 380,
              color: AppColors.reaction.withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            top: 260,
            right: -60,
            child: _GlowBlob(
              size: 220,
              color: AppColors.gold.withValues(alpha: 0.055),
            ),
          ),
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

    final scanPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

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
