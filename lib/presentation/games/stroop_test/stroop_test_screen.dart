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

// ─── Color entries for Stroop ─────────────────────────────────────────────────
class _StroopColor {
  final String nameAr;
  final String nameEn;
  final String nameZh;
  final Color value;

  const _StroopColor(this.nameAr, this.nameEn, this.nameZh, this.value);
}

const _stroopColors = [
  _StroopColor('أحمر', 'Red', '红', AppColors.colorRed),
  _StroopColor('أزرق', 'Blue', '蓝', AppColors.colorBlue),
  _StroopColor('أخضر', 'Green', '绿', AppColors.colorGreen),
  _StroopColor('أصفر', 'Yellow', '黄', AppColors.colorYellow),
  _StroopColor('برتقالي', 'Orange', '橙', Color(0xFFFF9500)),
  _StroopColor('بنفسجي', 'Purple', '紫', Color(0xFFAF52DE)),
];

enum _StroopPhase { config, playing, done }

class StroopTestScreen extends ConsumerStatefulWidget {
  const StroopTestScreen({super.key});

  @override
  ConsumerState<StroopTestScreen> createState() => _StroopTestScreenState();
}

class _StroopTestScreenState extends ConsumerState<StroopTestScreen> {
  final _rng = Random();
  _StroopPhase _phase = _StroopPhase.config;
  int _difficulty = 1; // 0 easy, 1 medium, 2 hard

  // Current stimulus
  late _StroopColor _word; // the word displayed (meaning = distractor)
  late _StroopColor _ink; // the actual ink color (correct answer)
  bool _useWordMeaningRule = false; // hard mode: rule can switch

  // Scoring
  int _correct = 0;
  int _current = 0;
  final List<double> _reactionTimes = [];

  // Timer
  final Stopwatch _stopwatch = Stopwatch();

  // Flash feedback
  Color? _flashColor;
  int _ruleSwitchCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.stroopTest.id);
      GameRulesHelper.ensureShownOnce(context, GameType.stroopTest);
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _phase = _StroopPhase.playing;
      _correct = 0;
      _current = 0;
      _reactionTimes.clear();
      _flashColor = null;
      _ruleSwitchCount = 0;
      _useWordMeaningRule = false;
    });
    _nextStimulus();
  }

  int get _totalStimuli => switch (_difficulty) {
        0 => 20,
        1 => 24,
        _ => 28,
      };

  int get _transitionMs => switch (_difficulty) {
        0 => 320,
        1 => 250,
        _ => 180,
      };

  List<_StroopColor> get _activePalette => switch (_difficulty) {
        0 => _stroopColors.take(4).toList(growable: false),
        _ => _stroopColors.take(6).toList(growable: false),
      };

  void _nextStimulus() {
    // Generate a mismatched pair
    final shuffled = List.of(_activePalette)..shuffle(_rng);
    _word = shuffled[0];
    _ink = shuffled.firstWhere((c) => c != _word);
    _useWordMeaningRule = _difficulty == 2 && _rng.nextDouble() < 0.35;
    if (_useWordMeaningRule) _ruleSwitchCount++;

    setState(() => _flashColor = null);
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _onColorTap(Color tappedColor) {
    if (_phase != _StroopPhase.playing) return;
    _stopwatch.stop();
    final ms = _stopwatch.elapsedMilliseconds.toDouble();

    final expectedColor = _useWordMeaningRule ? _word.value : _ink.value;
    final isCorrect = tappedColor == expectedColor;

    if (isCorrect) {
      Haptics.light();
      _correct++;
      _reactionTimes.add(ms);
      setState(() => _flashColor = expectedColor);
    } else {
      Haptics.medium();
      setState(() => _flashColor = AppColors.error);
    }

    _current++;

    if (_current >= _totalStimuli) {
      Haptics.success();
      Future.delayed(Duration(milliseconds: _transitionMs), _finishGame);
    } else {
      Future.delayed(Duration(milliseconds: _transitionMs), () {
        if (mounted) _nextStimulus();
      });
    }
  }

  Future<void> _finishGame() async {
    final record = ScoreRecord(
      gameId: GameType.stroopTest.id,
      score: _correct.toDouble(),
      accuracy: _totalStimuli > 0 ? _correct / _totalStimuli : 0,
      timestamp: DateTime.now(),
      difficulty: _difficulty + 1,
      metadata: {
        'total': _totalStimuli,
        'correct': _correct,
        'difficulty': _difficulty,
        'palette': _activePalette.length,
        'ruleSwitches': _ruleSwitchCount,
        'avgMs': _reactionTimes.isEmpty
            ? 0
            : _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length,
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.stroopTest.id));
    final isNewRecord = best == null || _correct >= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.stroopTest,
      'score': _correct.toDouble(),
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
          tr(context, 'اختبار ستروب', 'Stroop Test', '斯特鲁普测试'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase == _StroopPhase.playing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_correct.toArabicDigits()}/${_current.toArabicDigits()}'
                      : '$_correct/$_current',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.stroop),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.stroopTest),
          ),
        ],
      ),
      body: switch (_phase) {
        _StroopPhase.config => _buildConfig(context),
        _StroopPhase.playing => _buildPlaying(context),
        _StroopPhase.done => _buildConfig(context),
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
            const Icon(Icons.format_color_text,
                color: AppColors.stroop, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'اختبار ستروب', 'Stroop Test', '斯特鲁普测试'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                  context,
                  'اضغط الزر الذي يطابق لون الخط — لا معنى الكلمة!',
                  'Tap the button matching the font color — not the word meaning!',
                  '点击与字体颜色匹配的按钮，而非文字含义'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _DifficultyChip(
                  label: tr(context, 'سهل', 'Easy', '简单'),
                  selected: _difficulty == 0,
                  color: AppColors.stroop,
                  onTap: () => setState(() => _difficulty = 0),
                ),
                _DifficultyChip(
                  label: tr(context, 'متوسط', 'Medium', '中等'),
                  selected: _difficulty == 1,
                  color: AppColors.stroop,
                  onTap: () => setState(() => _difficulty = 1),
                ),
                _DifficultyChip(
                  label: tr(context, 'صعب', 'Hard', '困难'),
                  selected: _difficulty == 2,
                  color: AppColors.stroop,
                  onTap: () => setState(() => _difficulty = 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                '$_totalStimuli سؤال • ${_activePalette.length} ألوان',
                '$_totalStimuli questions • ${_activePalette.length} colors',
                '$_totalStimuli 题 • ${_activePalette.length} 种颜色',
              ),
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            if (_difficulty == 2) ...[
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  'الصعب: أحيانًا ستتغير القاعدة إلى معنى الكلمة',
                  'Hard: rule can switch to word meaning',
                  '困难：规则会随机切换到词义',
                ),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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

  Widget _buildPlaying(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: _current / _totalStimuli,
          backgroundColor: AppColors.border,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.stroop),
          minHeight: 2,
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_useWordMeaningRule
                            ? AppColors.warning
                            : AppColors.stroop)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (_useWordMeaningRule
                              ? AppColors.warning
                              : AppColors.stroop)
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    _useWordMeaningRule
                        ? tr(context, 'القاعدة: معنى الكلمة', 'Rule: Word meaning',
                            '规则：词义')
                        : tr(context, 'القاعدة: لون الخط', 'Rule: Ink color',
                            '规则：字体颜色'),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(32),
                  decoration: _flashColor != null
                      ? BoxDecoration(
                          color: _flashColor!.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        )
                      : null,
                  child: Text(
                    tr(context, _word.nameAr, _word.nameEn, _word.nameZh),
                    style: AppTypography.stroopWord.copyWith(color: _ink.value),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: _buildColorButtons(context),
          ),
        ),
      ],
    );
  }

  Widget _buildColorButtons(BuildContext context) {
    final colors = _activePalette;
    final crossAxisCount = colors.length <= 4 ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: colors.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: colors.length <= 4 ? 2.2 : 2.0,
      ),
      itemBuilder: (context, index) {
        final c = colors[index];
        return _colorBtn(
          context,
          c.value,
          c.nameAr,
          c.nameEn,
          c.nameZh,
        );
      },
    );
  }

  Widget _colorBtn(
      BuildContext context, Color color, String ar, String en, String zh) {
    final label = tr(context, ar, en, zh);
    return GestureDetector(
      onTap: () => _onColorTap(color),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 4,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.16) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.2 : 0.6,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
