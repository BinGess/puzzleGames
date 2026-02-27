import 'dart:async';
import 'dart:math';
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

enum _VisPhase { config, showing, recalling, feedback }

class VisualMemoryScreen extends ConsumerStatefulWidget {
  const VisualMemoryScreen({super.key});

  @override
  ConsumerState<VisualMemoryScreen> createState() => _VisualMemoryScreenState();
}

class _VisualMemoryScreenState extends ConsumerState<VisualMemoryScreen> {
  int _gridSize = 3;
  _VisPhase _phase = _VisPhase.config;

  final _rng = Random();

  // Round state
  int _numLit = 3; // cells to remember (grows)
  Set<int> _litIndices = {};
  Set<int> _tappedIndices = {};
  int _maxCorrect = 0;

  Timer? _showTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameRulesHelper.ensureShownOnce(context, GameType.visualMemory);
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _phase = _VisPhase.config;
      _numLit = 3;
      _maxCorrect = 0;
    });
    _startRound();
  }

  void _startRound() {
    final total = _gridSize * _gridSize;
    final indices = List.generate(total, (i) => i)..shuffle(_rng);
    final lit = indices.take(_numLit).toSet();

    setState(() {
      _litIndices = lit;
      _tappedIndices = {};
      _phase = _VisPhase.showing;
    });

    // Show for 1.5s (decreases with more cells)
    final showMs = max(800, 1500 - (_numLit - 3) * 100);
    _showTimer = Timer(Duration(milliseconds: showMs), () {
      if (mounted) setState(() => _phase = _VisPhase.recalling);
    });
  }

  void _onCellTap(int index) {
    if (_phase != _VisPhase.recalling) return;
    if (_tappedIndices.contains(index)) return;

    final isCorrect = _litIndices.contains(index);
    Haptics.light();

    setState(() => _tappedIndices.add(index));

    if (!isCorrect) {
      // Wrong tap — end
      Haptics.medium();
      setState(() => _phase = _VisPhase.feedback);
      Future.delayed(const Duration(milliseconds: 1000), _finishGame);
      return;
    }

    // Check if all lit cells tapped
    if (_tappedIndices.containsAll(_litIndices)) {
      _maxCorrect = _numLit;
      _numLit = min(_numLit + 1, _gridSize * _gridSize - 1);
      setState(() => _phase = _VisPhase.feedback);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _startRound();
      });
    }
  }

  Future<void> _finishGame() async {
    _showTimer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.visualMemory.id,
      score: _maxCorrect.toDouble(),
      accuracy: 1.0,
      timestamp: DateTime.now(),
      difficulty: _gridSize - 2,
      metadata: {'gridSize': _gridSize, 'maxCells': _maxCorrect},
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.visualMemory.id));
    final isNewRecord = best == null || _maxCorrect >= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.visualMemory,
      'score': _maxCorrect.toDouble(),
      'metric': 'correct',
      'lowerIsBetter': false,
      'isNewRecord': isNewRecord,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          tr(context, 'ذاكرة بصرية', 'Visual Memory', '视觉记忆'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _VisPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_numLit.toArabicDigits()} خلايا'
                      : '$_numLit ${tr(context, 'خلايا', 'cells', '格')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.visualMemory),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.visualMemory),
          ),
        ],
      ),
      body: switch (_phase) {
        _VisPhase.config => _buildConfig(context),
        _VisPhase.showing => _buildGrid(context, showLit: true),
        _VisPhase.recalling => _buildGrid(context, showLit: false),
        _VisPhase.feedback => _buildGrid(context, showLit: true),
      },
    );
  }

  Widget _buildConfig(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view, color: AppColors.visualMemory, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'ذاكرة بصرية', 'Visual Memory', '视觉记忆'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(context,
                  'تذكّر المربعات التي أضاءت وحدد مواقعها',
                  'Remember which squares lit up and tap them',
                  '记住亮起的方格并点击它们'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SizeBtn(
                    label: tr(context, '٣×٣', '3×3', '3×3'),
                    sublabel: tr(context, 'سهل', 'Easy', '简单'),
                    selected: _gridSize == 3,
                    color: AppColors.visualMemory,
                    onTap: () => setState(() => _gridSize = 3)),
                const SizedBox(width: 12),
                _SizeBtn(
                    label: tr(context, '٤×٤', '4×4', '4×4'),
                    sublabel: tr(context, 'متوسط', 'Medium', '中等'),
                    selected: _gridSize == 4,
                    color: AppColors.visualMemory,
                    onTap: () => setState(() => _gridSize = 4)),
                const SizedBox(width: 12),
                _SizeBtn(
                    label: tr(context, '٥×٥', '5×5', '5×5'),
                    sublabel: tr(context, 'صعب', 'Hard', '困难'),
                    selected: _gridSize == 5,
                    color: AppColors.visualMemory,
                    onTap: () => setState(() => _gridSize = 5)),
              ],
            ),
            const SizedBox(height: 48),
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

  Widget _buildGrid(BuildContext context, {required bool showLit}) {
    final total = _gridSize * _gridSize;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _phase == _VisPhase.showing
                  ? tr(context, 'تذكّر!', 'Memorize!', '记住！')
                  : (_phase == _VisPhase.recalling
                      ? tr(context, 'اضغط المربعات', 'Tap the squares', '点击方格')
                      : (_tappedIndices.any((i) => !_litIndices.contains(i))
                          ? tr(context, 'خطأ!', 'Wrong!', '错误！')
                          : tr(context, 'صحيح!', 'Correct!', '正确！'))),
              style: AppTypography.labelMedium.copyWith(
                color: _phase == _VisPhase.feedback
                    ? (_tappedIndices.any((i) => !_litIndices.contains(i))
                        ? AppColors.error
                        : AppColors.success)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: total,
                itemBuilder: (ctx, i) {
                  final isLit = _litIndices.contains(i);
                  final isTapped = _tappedIndices.contains(i);
                  final isCorrectTap = isTapped && isLit;
                  final isWrongTap = isTapped && !isLit;

                  Color bgColor;
                  if (showLit && isLit) {
                    bgColor = AppColors.visualMemory.withValues(alpha: 0.7);
                  } else if (isCorrectTap) {
                    bgColor = AppColors.visualMemory.withValues(alpha: 0.4);
                  } else if (isWrongTap) {
                    bgColor = AppColors.error.withValues(alpha: 0.4);
                  } else {
                    bgColor = const Color(0xFF1A1A26);
                  }

                  return GestureDetector(
                    onTap: _phase == _VisPhase.recalling
                        ? () => _onCellTap(i)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: showLit && isLit
                              ? AppColors.visualMemory
                              : AppColors.border,
                          width: showLit && isLit ? 1.5 : 0.5,
                        ),
                        boxShadow: showLit && isLit
                            ? [
                                BoxShadow(
                                  color: AppColors.visualMemory
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeBtn extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SizeBtn({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [color.withValues(alpha: 0.25), color.withValues(alpha: 0.1)]
                : [const Color(0xFF1C1C28), const Color(0xFF111118)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.headingSmall
                  .copyWith(color: selected ? color : AppColors.textPrimary),
            ),
            Text(
              sublabel,
              style: AppTypography.caption
                  .copyWith(color: selected ? color : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
