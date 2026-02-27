import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/utils/haptics.dart';
import '../../domain/enums/game_type.dart';
import '../providers/app_providers.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const ResultScreen({super.key, required this.data});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
    if (widget.data['isNewRecord'] == true) {
      Haptics.success();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatScore(double score, String metric, bool isAr) {
    switch (metric) {
      case 'time':
        final s = (score / 1000).toStringAsFixed(1);
        return isAr ? '$s ث' : '${s}s';
      case 'ms':
        final ms = score.round();
        return isAr ? '$ms مللي' : '${ms}ms';
      case 'length':
        final n = score.toInt();
        return isAr
            ? '${n.toArabicDigits()} ${n == 1 ? 'رقم' : 'أرقام'}'
            : '$n digit${n == 1 ? '' : 's'}';
      case 'correct':
        final n = score.toInt();
        return isAr ? '${n.toArabicDigits()} صحيح' : '$n correct';
      case 'moves':
        final n = score.toInt();
        return isAr ? '${n.toArabicDigits()} حركة' : '$n moves';
      default:
        return score.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    final gameType = widget.data['gameType'] as GameType? ?? GameType.schulteGrid;
    final score = (widget.data['score'] as num?)?.toDouble() ?? 0;
    final metric = widget.data['metric'] as String? ?? 'time';
    final isNewRecord = widget.data['isNewRecord'] as bool? ?? false;

    final ability = ref.watch(abilityProvider);
    final accentColor = _accentForType(gameType);

    final gameName = isAr ? _nameAr(gameType) : _nameEn(gameType);
    final scoreLabel = _formatScore(score, metric, isAr);

    final best = ref.read(bestScoreProvider(gameType.id));
    String? bestLabel;
    if (best != null) {
      bestLabel = _formatScore(best.score, metric, isAr);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // ─── Header ─────────────────────────────────────
                  Align(
                    alignment: isAr
                        ? Alignment.topRight
                        : Alignment.topLeft,
                    child: Text(
                      gameName,
                      style: AppTypography.headingMedium,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ─── New record badge ────────────────────────────
                  if (isNewRecord) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              color: AppColors.gold, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            isAr ? 'رقم قياسي جديد! 🏆' : 'New Record! 🏆',
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ─── Score display ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 36),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withValues(alpha: 0.15),
                          accentColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          scoreLabel,
                          style: AppTypography.displayMedium.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isAr ? 'نتيجتك' : 'Your Score',
                          style: AppTypography.caption,
                          textAlign: TextAlign.center,
                        ),
                        if (bestLabel != null) ...[
                          const SizedBox(height: 16),
                          Divider(
                              color: accentColor.withValues(alpha: 0.2),
                              thickness: 0.5),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.gold, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                isAr
                                    ? 'أفضل نتيجة: $bestLabel'
                                    : 'Best: $bestLabel',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── LQ Score ────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.borderGold, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isAr ? 'مقياس المنطق LQ' : 'Logic Quotient LQ',
                          style: AppTypography.labelMedium,
                        ),
                        Text(
                          isAr
                              ? ability.lqScore.toStringAsFixed(1)
                                  .toArabicNumerals()
                              : ability.lqScore.toStringAsFixed(1),
                          style: AppTypography.headingMedium.copyWith(
                              color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ─── Action buttons ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Haptics.light();
                        context.pushReplacement(
                            AppRoutes.gameRoute(gameType));
                      },
                      child: Text(isAr ? 'العب مجددًا' : 'Play Again'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Haptics.light();
                        context.go(AppRoutes.dashboard);
                      },
                      child: Text(
                          isAr ? 'العودة للرئيسية' : 'Back to Dashboard'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _accentForType(GameType type) => switch (type) {
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
}
