import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/tr.dart';
import '../../../data/models/score_record.dart';
import '../../../domain/enums/game_type.dart';
import '../game_rules_helper.dart';
import '../../providers/app_providers.dart';

// ─── Disc colour palette (index 0 = size 1 = smallest) ───────────────────────
const _kDiskColors = [
  Color(0xFF5AC8FA), // 1 – sky blue
  Color(0xFF30D158), // 2 – mint green
  Color(0xFFFFD60A), // 3 – gold
  Color(0xFFFF9F0A), // 4 – orange
  Color(0xFFFF453A), // 5 – red
];

Color _diskColor(int size) =>
    _kDiskColors[(size - 1).clamp(0, _kDiskColors.length - 1)];

// ─── Layout constants ─────────────────────────────────────────────────────────
const _kDiscHeight = 36.0;
const _kDiscGap = 6.0;
const _kPoleWidth = 14.0;
const _kBaseHeight = 18.0;
const _kFloatOffset = 34.0;
const _kMoveDuration = Duration(milliseconds: 200);
const _kAnimDuration = Duration(milliseconds: 190);

// ─── Screen ───────────────────────────────────────────────────────────────────

class TowerOfHanoiScreen extends ConsumerStatefulWidget {
  const TowerOfHanoiScreen({super.key});

  @override
  ConsumerState<TowerOfHanoiScreen> createState() => _TowerOfHanoiScreenState();
}

class _TowerOfHanoiScreenState extends ConsumerState<TowerOfHanoiScreen>
    with SingleTickerProviderStateMixin {
  // ─── State ──────────────────────────────────────────────────────────────────
  int _diskCount = 3;
  bool _showingConfig = true;

  List<List<int>> _pegs = [[], [], []]; // each list: [largest, ..., smallest]
  int? _selectedPeg;
  int _moves = 0;
  bool _gameActive = false;
  bool _isMoving = false; // block taps during move animation

  // Shake feedback
  int _shakePeg = -1;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.towerOfHanoi.id);
      GameRulesHelper.ensureShownOnce(context, GameType.towerOfHanoi);
    });

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ─── Game logic ─────────────────────────────────────────────────────────────

  void _startGame() {
    // Peg 0 = all discs: [diskCount, diskCount-1, ..., 1] (bottom to top)
    final discs = List.generate(_diskCount, (i) => _diskCount - i);
    setState(() {
      _pegs = [discs, [], []];
      _selectedPeg = null;
      _moves = 0;
      _gameActive = true;
      _showingConfig = false;
      _shakePeg = -1;
      _isMoving = false;
    });
  }

  void _onPegTap(int peg) {
    if (!_gameActive || _isMoving) return;

    if (_selectedPeg == null) {
      // Select a source peg
      if (_pegs[peg].isEmpty) {
        _shake(peg);
        return;
      }
      Haptics.selection();
      setState(() => _selectedPeg = peg);
    } else {
      if (_selectedPeg == peg) {
        // Deselect
        Haptics.selection();
        setState(() => _selectedPeg = null);
        return;
      }

      final src = _selectedPeg!;
      final topDisc = _pegs[src].last; // smallest value = smallest disc
      final dstTop = _pegs[peg].isEmpty ? null : _pegs[peg].last;

      if (dstTop != null && dstTop < topDisc) {
        // Invalid: can't place larger on smaller
        Haptics.medium();
        _shake(peg);
        _showInvalidMoveToast();
        setState(() => _selectedPeg = null);
        return;
      }

      _doMove(src, peg);
    }
  }

  void _shake(int peg) {
    setState(() => _shakePeg = peg);
    _shakeCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _shakePeg = -1);
    });
  }

  void _showInvalidMoveToast() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(milliseconds: 1400),
        backgroundColor: const Color(0xFF2B1D1D),
        content: Text(
          tr(
            context,
            'لا يمكن وضع قرص أكبر فوق قرص أصغر',
            'You can only place it on a bigger disk',
            '只能放在比它更大的盘子上',
          ),
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Future<void> _doMove(int src, int dst) async {
    Haptics.light();
    setState(() => _isMoving = true);

    // Let the float animation fully render before moving
    await Future.delayed(_kMoveDuration);
    if (!mounted) return;

    setState(() {
      _pegs[dst].add(_pegs[src].removeLast());
      _moves++;
      _selectedPeg = null;
      _isMoving = false;
    });

    // Win check: peg 2 (last) is the target
    if (_pegs[2].length == _diskCount) {
      _gameActive = false;
      Haptics.success();
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    final record = ScoreRecord(
      gameId: GameType.towerOfHanoi.id,
      score: _moves.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _diskCount - 2,
      metadata: {'diskCount': _diskCount, 'moves': _moves},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.towerOfHanoi.id));
    final isNewRecord = best == null || _moves <= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.towerOfHanoi,
      'score': _moves.toDouble(),
      'metric': 'moves',
      'lowerIsBetter': true,
      'isNewRecord': isNewRecord,
    });
  }

  String _difficultyLabel(BuildContext context, int diskCount) {
    return switch (diskCount) {
      3 => tr(context, 'عادي', 'Normal', '普通'),
      4 => tr(context, 'صعب', 'Hard', '高难度'),
      _ => tr(context, 'تحدي', 'Challenge', '挑战'),
    };
  }

  String _difficultyDetail(BuildContext context, int diskCount) {
    final count = useArabicDigits(context)
        ? diskCount.toArabicDigits()
        : diskCount.toString();
    return switch (diskCount) {
      3 => tr(context, '$count أقراص · مناسب للبداية',
          '$count discs · beginner friendly', '$count 盘 · 适合入门'),
      4 => tr(context, '$count أقراص · يتطلب تخطيطًا',
          '$count discs · needs planning', '$count 盘 · 需要规划'),
      _ => tr(context, '$count أقراص · اختبار كامل',
          '$count discs · full challenge', '$count 盘 · 进阶挑战'),
    };
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          tr(context, 'برج هانو', 'Tower of Hanoi', '汉诺塔'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_gameActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_moves.toArabicDigits()} ${tr(context, 'حركة', 'moves', '步')}'
                      : '$_moves ${tr(context, 'حركة', 'moves', '步')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.towerOfHanoi),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.towerOfHanoi),
          ),
        ],
      ),
      body: _showingConfig ? _buildConfig(context) : _buildGame(context),
    );
  }

  // ─── Config screen ──────────────────────────────────────────────────────────

  Widget _buildConfig(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated mini preview
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _MiniTowerPreview(
                key: ValueKey(_diskCount),
                diskCount: _diskCount,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              tr(context, 'برج هانو', 'Tower of Hanoi', '汉诺塔'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                context,
                'انقل جميع الأقراص إلى العمود الأخير بأقل الحركات',
                'Move all discs to the last peg in the fewest moves',
                '用最少步数将所有圆盘移到最后一根柱子',
              ),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Difficulty selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [3, 4, 5].map((n) {
                final sel = _diskCount == n;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () {
                      Haptics.selection();
                      setState(() => _diskCount = n);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 106,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: sel
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.towerOfHanoi
                                      .withValues(alpha: 0.28),
                                  AppColors.towerOfHanoi
                                      .withValues(alpha: 0.10),
                                ],
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF1C1C28),
                                  Color(0xFF111118),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              sel ? AppColors.towerOfHanoi : AppColors.border,
                          width: sel ? 1.5 : 0.5,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: AppColors.towerOfHanoi
                                      .withValues(alpha: 0.28),
                                  blurRadius: 14,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _difficultyLabel(context, n),
                            style: AppTypography.labelLarge.copyWith(
                              color: sel
                                  ? AppColors.towerOfHanoi
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _difficultyDetail(context, n),
                            style: AppTypography.caption.copyWith(
                              color: sel
                                  ? AppColors.towerOfHanoi
                                  : AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                child: Text(tr(context, 'ابدأ', 'Start', '开始')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Game screen ────────────────────────────────────────────────────────────

  Widget _buildGame(BuildContext context) {
    return Column(
      children: [
        // Sub-header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tr(context, 'الصعوبة: ', 'Difficulty: ', '难度：')}${_difficultyLabel(context, _diskCount)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.towerOfHanoi.withValues(alpha: 0.65),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  key: ValueKey(_selectedPeg != null),
                  _selectedPeg != null
                      ? tr(context, 'اختر العمود المستهدف ↓',
                          'Choose destination ↓', '选择目标柱 ↓')
                      : tr(context, 'اضغط على عمود للاختيار', 'Tap a peg',
                          '点击柱子选择'),
                  style: AppTypography.caption.copyWith(
                    color: _selectedPeg != null
                        ? AppColors.gold
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Board
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: _HanoiBoard(
              pegs: _pegs,
              diskCount: _diskCount,
              selectedPeg: _selectedPeg,
              shakePeg: _shakePeg,
              shakeAnim: _shakeAnim,
              onPegTap: _onPegTap,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Board ────────────────────────────────────────────────────────────────────

class _HanoiBoard extends StatelessWidget {
  final List<List<int>> pegs;
  final int diskCount;
  final int? selectedPeg;
  final int shakePeg;
  final Animation<double> shakeAnim;
  final ValueChanged<int> onPegTap;

  const _HanoiBoard({
    required this.pegs,
    required this.diskCount,
    required this.selectedPeg,
    required this.shakePeg,
    required this.shakeAnim,
    required this.onPegTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cs) {
      final totalW = cs.maxWidth;
      final totalH = cs.maxHeight;
      final pegColW = totalW / 3;
      const boardLift = 24.0;
      // Max disc width within a column, leaving a little side breathing room
      final maxDiscW = pegColW - 12.0;
      const minDiscW = 54.0;
      // Pole height covers all discs + some breathing room above
      final poleH = min(
        diskCount * (_kDiscHeight + _kDiscGap) + 58.0,
        totalH - _kBaseHeight - boardLift - 16.0,
      );

      return Stack(
        children: [
          // ── Base platform ─────────────────────────────────────────────
          Positioned(
            bottom: boardLift,
            left: 0,
            right: 0,
            child: Container(
              height: _kBaseHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2A2A3E),
                    Color(0xFF1E1E2C),
                    Color(0xFF2A2A3E),
                  ],
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: AppColors.towerOfHanoi.withValues(alpha: 0.30),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.towerOfHanoi.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // ── Three peg columns ─────────────────────────────────────────
          ...List.generate(3, (i) {
            Widget peg = _PegColumn(
              pegIndex: i,
              discs: pegs[i],
              diskCount: diskCount,
              isSelected: selectedPeg == i,
              hasSelection: selectedPeg != null,
              maxDiscW: maxDiscW,
              minDiscW: minDiscW,
              poleH: poleH,
              isTarget: i == 2,
              onTap: () => onPegTap(i),
            );

            // Wrap with shake animation if needed
            if (shakePeg == i) {
              peg = AnimatedBuilder(
                animation: shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(shakeAnim.value, 0),
                  child: child,
                ),
                child: peg,
              );
            }

            return Positioned(
              left: i * pegColW,
              top: 0,
              width: pegColW,
              bottom: _kBaseHeight + boardLift,
              child: peg,
            );
          }),
        ],
      );
    });
  }
}

// ─── Peg Column ───────────────────────────────────────────────────────────────

class _PegColumn extends StatelessWidget {
  final int pegIndex;
  final List<int> discs; // [largest, ..., smallest], last = top
  final int diskCount;
  final bool isSelected;
  final bool hasSelection;
  final double maxDiscW;
  final double minDiscW;
  final double poleH;
  final bool isTarget;
  final VoidCallback onTap;

  const _PegColumn({
    required this.pegIndex,
    required this.discs,
    required this.diskCount,
    required this.isSelected,
    required this.hasSelection,
    required this.maxDiscW,
    required this.minDiscW,
    required this.poleH,
    required this.isTarget,
    required this.onTap,
  });

  double _discW(int size) {
    if (diskCount <= 1) return maxDiscW;
    final t = (size - 1) / (diskCount - 1);
    return minDiscW + t * (maxDiscW - minDiscW);
  }

  @override
  Widget build(BuildContext context) {
    final isDropTarget = hasSelection && !isSelected;
    const accentColor = AppColors.towerOfHanoi;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(builder: (_, cs) {
        final w = cs.maxWidth;
        final cx = w / 2; // center x

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Top label / indicator ────────────────────────────────────
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isDropTarget
                      // Drop target arrow
                      ? _LabelChip(
                          key: const ValueKey('drop'),
                          icon: Icons.keyboard_arrow_down_rounded,
                          color: AppColors.gold,
                          backgroundColor:
                              AppColors.gold.withValues(alpha: 0.14),
                          borderColor: AppColors.gold.withValues(alpha: 0.45),
                        )
                      : isSelected
                          // Selected peg
                          ? _LabelChip(
                              key: const ValueKey('selected'),
                              icon: Icons.open_with_rounded,
                              color: AppColors.gold,
                              backgroundColor:
                                  AppColors.gold.withValues(alpha: 0.18),
                              borderColor:
                                  AppColors.gold.withValues(alpha: 0.55),
                            )
                          : isTarget
                              // Goal label
                              ? _TextChip(
                                  key: const ValueKey('goal'),
                                  label: tr(context, 'هدف', 'GOAL', '目标'),
                                  color: accentColor,
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ),

            // ── Peg pole ─────────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: cx - _kPoleWidth / 2,
              width: _kPoleWidth,
              height: poleH,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isSelected
                        ? [AppColors.gold, AppColors.goldMuted]
                        : isTarget
                            ? [
                                accentColor.withValues(alpha: 0.80),
                                accentColor.withValues(alpha: 0.35),
                              ]
                            : [
                                const Color(0xFF3E3E58),
                                const Color(0xFF222230),
                              ],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.45),
                            blurRadius: 16,
                          ),
                        ]
                      : isTarget
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.22),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                ),
              ),
            ),

            // ── Discs ─────────────────────────────────────────────────────
            // discs[0] = bottom/largest, discs[n-1] = top/smallest
            ...discs.asMap().entries.map((entry) {
              final stackIdx = entry.key;
              final size = entry.value;
              final isTopDisc = stackIdx == discs.length - 1;
              final isFloating = isSelected && isTopDisc;

              final dw = _discW(size);
              final baseBottom = stackIdx * (_kDiscHeight + _kDiscGap);
              final bottom = isFloating
                  ? baseBottom + _kFloatOffset
                  : baseBottom.toDouble();

              return AnimatedPositioned(
                key: ValueKey('p${pegIndex}_d$size'),
                duration: _kAnimDuration,
                curve: Curves.easeOutCubic,
                bottom: bottom,
                left: cx - dw / 2,
                width: dw,
                height: _kDiscHeight,
                child: _DiscWidget(
                  size: size,
                  diskCount: diskCount,
                  isFloating: isFloating,
                ),
              );
            }),
          ],
        );
      }),
    );
  }
}

// ─── Disc Widget ──────────────────────────────────────────────────────────────

class _DiscWidget extends StatelessWidget {
  final int size;
  final int diskCount;
  final bool isFloating;

  const _DiscWidget({
    required this.size,
    required this.diskCount,
    required this.isFloating,
  });

  @override
  Widget build(BuildContext context) {
    final color = _diskColor(size);

    return AnimatedContainer(
      duration: _kAnimDuration,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isFloating ? color : color.withValues(alpha: 0.92),
            isFloating
                ? color.withValues(alpha: 0.75)
                : color.withValues(alpha: 0.60),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFloating ? AppColors.gold : color.withValues(alpha: 0.60),
          width: isFloating ? 1.5 : 0.5,
        ),
        boxShadow: isFloating
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.65),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.28),
                  blurRadius: 10,
                ),
              ]
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
    );
  }
}

// ─── Label Chips ──────────────────────────────────────────────────────────────

class _LabelChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  const _LabelChip({
    super.key,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

class _TextChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TextChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.38), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Mini Tower Preview (config screen) ──────────────────────────────────────

class _MiniTowerPreview extends StatelessWidget {
  final int diskCount;

  const _MiniTowerPreview({super.key, required this.diskCount});

  @override
  Widget build(BuildContext context) {
    const previewW = 130.0;
    const discH = 18.0;
    const discGap = 3.0;
    const minW = 24.0;
    const maxW = previewW - 12.0;
    const poleW = 7.0;
    const baseH = 12.0;

    final poleHeight = diskCount * (discH + discGap) + 16.0;
    final totalH = poleHeight + baseH + 8.0;

    return Container(
      width: previewW,
      height: totalH,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.towerOfHanoi.withValues(alpha: 0.25),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.towerOfHanoi.withValues(alpha: 0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Base
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              height: baseH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.towerOfHanoi.withValues(alpha: 0.22),
                    AppColors.towerOfHanoi.withValues(alpha: 0.10),
                    AppColors.towerOfHanoi.withValues(alpha: 0.22),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.towerOfHanoi.withValues(alpha: 0.30),
                  width: 0.5,
                ),
              ),
            ),
          ),
          // Pole
          Positioned(
            bottom: 8 + baseH,
            left: previewW / 2 - poleW / 2,
            width: poleW,
            height: poleHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.towerOfHanoi.withValues(alpha: 0.80),
                    AppColors.towerOfHanoi.withValues(alpha: 0.35),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.towerOfHanoi.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // Discs
          ...List.generate(diskCount, (i) {
            // i=0 → bottom/largest, i=diskCount-1 → top/smallest
            final size = diskCount - i; // size: N down to 1
            final t =
                diskCount <= 1 ? 1.0 : (size - 1) / (diskCount - 1).toDouble();
            final dw = minW + t * (maxW - minW);
            final color = _diskColor(size);
            final bottom = 8.0 + baseH + i * (discH + discGap);

            return Positioned(
              bottom: bottom,
              left: previewW / 2 - dw / 2,
              width: dw,
              height: discH,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.92),
                      color.withValues(alpha: 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
