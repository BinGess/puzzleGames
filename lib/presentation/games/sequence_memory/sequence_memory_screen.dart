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

enum _SeqPhase { config, playing, inputting, feedback }

class SequenceMemoryScreen extends ConsumerStatefulWidget {
  const SequenceMemoryScreen({super.key});

  @override
  ConsumerState<SequenceMemoryScreen> createState() =>
      _SequenceMemoryScreenState();
}

class _SequenceMemoryScreenState extends ConsumerState<SequenceMemoryScreen> {
  final _rng = Random();
  _SeqPhase _phase = _SeqPhase.config;

  int _gridSize = 3; // 3x3, 4x4, 5x5
  int _difficulty = 1; // 0 easy, 1 medium, 2 hard

  List<int> _sequence = []; // the target sequence
  int _playbackIndex = 0; // which cell is currently lit during playback
  int _inputIndex = 0; // how many cells user has tapped
  int? _litCell; // cell index currently lit
  bool _litCellIsError =
      false; // whether current lit cell should render as error
  bool? _lastFeedbackCorrect; // null=none, true=correct, false=wrong
  int _maxLength = 0;
  bool _isRoundTransitioning = false;
  int _flashToken = 0;

  Timer? _playbackTimer;

  int get _gridCells => _gridSize * _gridSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.setSoundGameId(GameType.sequenceMemory.id);
      GameRulesHelper.ensureShownOnce(context, GameType.sequenceMemory);
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _sequence = _buildRandomSequence(_initialLength());
      _maxLength = 0;
      _phase = _SeqPhase.config;
      _litCellIsError = false;
      _lastFeedbackCorrect = null;
      _inputIndex = 0;
      _litCell = null;
      _isRoundTransitioning = false;
    });
    _playSequence();
  }

  void _playSequence() {
    setState(() {
      _phase = _SeqPhase.playing;
      _playbackIndex = 0;
      _litCell = null;
      _litCellIsError = false;
      _lastFeedbackCorrect = null;
      _isRoundTransitioning = false;
    });

    _playbackTimer?.cancel();
    _playStep();
  }

  void _playStep() {
    if (_playbackIndex >= _sequence.length) {
      // Done — wait briefly then let user input
      _playbackTimer = Timer(Duration(milliseconds: _roundGapMs), () {
        if (mounted) setState(() => _phase = _SeqPhase.inputting);
      });
      return;
    }

    final cell = _sequence[_playbackIndex];
    setState(() {
      _litCell = cell;
      _litCellIsError = false;
    });
    Haptics.selection();

    _playbackTimer = Timer(Duration(milliseconds: _flashOnMs), () {
      setState(() {
        _litCell = null;
        _litCellIsError = false;
      });
      _playbackTimer = Timer(Duration(milliseconds: _flashOffMs), () {
        _playbackIndex++;
        _playStep();
      });
    });
  }

  void _onCellTap(int index) {
    if (_phase != _SeqPhase.inputting || _isRoundTransitioning) return;
    if (_inputIndex >= _sequence.length) return;

    final expected = _sequence[_inputIndex];
    if (index == expected) {
      Haptics.light();
      final token = ++_flashToken;
      setState(() {
        _litCell = index;
        _litCellIsError = false;
        _inputIndex++;
      });
      Future.delayed(const Duration(milliseconds: 130), () {
        if (!mounted || _flashToken != token) return;
        if (_phase == _SeqPhase.inputting) {
          setState(() => _litCell = null);
        }
      });

      if (_inputIndex >= _sequence.length) {
        // Round completed: lock input immediately to avoid fast-tap drop/race.
        Haptics.success();
        _isRoundTransitioning = true;
        _maxLength = _sequence.length;
        _sequence.add(_nextRandomCell(lastCell: _sequence.last, seq: _sequence));
        _inputIndex = 0;
        setState(() {
          _phase = _SeqPhase.feedback;
          _lastFeedbackCorrect = true;
        });
        Future.delayed(Duration(milliseconds: _roundGapMs), () {
          if (mounted) _playSequence();
        });
      }
    } else {
      // Wrong
      Haptics.medium();
      setState(() {
        _litCell = index;
        _litCellIsError = true;
        _lastFeedbackCorrect = false;
        _phase = _SeqPhase.feedback;
        _isRoundTransitioning = true;
      });
      Future.delayed(const Duration(milliseconds: 1000), _finishGame);
    }
  }

  Future<void> _finishGame() async {
    _playbackTimer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.sequenceMemory.id,
      score: _maxLength.toDouble(),
      timestamp: DateTime.now(),
      difficulty: _difficulty + 1,
      metadata: {
        'maxLength': _maxLength,
        'gridSize': _gridSize,
        'difficulty': _difficulty,
      },
    );

    await ref.read(scoreRepoProvider).saveScore(record);
    await ref.read(abilityProvider.notifier).recompute();

    final best = ref.read(bestScoreProvider(GameType.sequenceMemory.id));
    final isNewRecord = best == null || _maxLength >= best.score;

    if (!mounted) return;
    context.pushReplacement(AppRoutes.result, extra: {
      'gameType': GameType.sequenceMemory,
      'score': _maxLength.toDouble(),
      'metric': 'length',
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
          tr(context, 'تسلسل', 'Sequence Memory', '序列记忆'),
          style: AppTypography.headingMedium,
        ),
        actions: [
          if (_phase != _SeqPhase.config)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  useArabicDigits(context)
                      ? '${_sequence.length.toArabicDigits()} مربعات'
                      : '${_sequence.length} ${tr(context, 'مربعات', 'squares', '格')}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.sequenceMemory),
                ),
              ),
            ),
          IconButton(
            icon:
                const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () => GameRulesHelper.showRulesDialog(
                context, GameType.sequenceMemory),
          ),
        ],
      ),
      body: switch (_phase) {
        _SeqPhase.config => _buildConfig(context),
        _ => _buildGame(context),
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
            const Icon(Icons.apps, color: AppColors.sequenceMemory, size: 64),
            const SizedBox(height: 24),
            Text(
              tr(context, 'تسلسل', 'Sequence Memory', '序列记忆'),
              style: AppTypography.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'كرّر التسلسل الذي أضاءت به المربعات',
                'Repeat the sequence in which the squares lit up',
                '重复亮起方格的序列',
              ),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SizeBtn(
                  label: '3×3',
                  selected: _gridSize == 3,
                  color: AppColors.sequenceMemory,
                  onTap: () => setState(() => _gridSize = 3),
                ),
                const SizedBox(width: 10),
                _SizeBtn(
                  label: '4×4',
                  selected: _gridSize == 4,
                  color: AppColors.sequenceMemory,
                  onTap: () => setState(() => _gridSize = 4),
                ),
                const SizedBox(width: 10),
                _SizeBtn(
                  label: '5×5',
                  selected: _gridSize == 5,
                  color: AppColors.sequenceMemory,
                  onTap: () => setState(() => _gridSize = 5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _DifficultyBtn(
                  label: tr(context, 'سهل', 'Easy', '简单'),
                  selected: _difficulty == 0,
                  color: AppColors.sequenceMemory,
                  onTap: () => setState(() => _difficulty = 0),
                ),
                _DifficultyBtn(
                  label: tr(context, 'متوسط', 'Medium', '中等'),
                  selected: _difficulty == 1,
                  color: AppColors.sequenceMemory,
                  onTap: () => setState(() => _difficulty = 1),
                ),
                _DifficultyBtn(
                  label: tr(context, 'صعب', 'Hard', '困难'),
                  selected: _difficulty == 2,
                  color: AppColors.sequenceMemory,
                  onTap: () => setState(() => _difficulty = 2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr(
                context,
                'سرعة الإضاءة: ${_speedLabel(context)}',
                'Flash speed: ${_speedLabel(context)}',
                '闪烁速度：${_speedLabel(context)}',
              ),
              style: AppTypography.caption,
            ),
            const SizedBox(height: 34),
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

  Widget _buildGame(BuildContext context) {
    final isPlayback = _phase == _SeqPhase.playing;
    final isInput = _phase == _SeqPhase.inputting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPlayback
                  ? tr(context, 'انظر...', 'Watch...', '看...')
                  : (isInput
                      ? tr(
                          context, 'كرر التسلسل', 'Repeat the sequence', '重复序列')
                      : (_lastFeedbackCorrect == false
                          ? tr(context, 'خطأ!', 'Wrong!', '错误！')
                          : tr(context, 'صحيح!', 'Correct!', '正确！'))),
              style: AppTypography.labelMedium.copyWith(
                color: _phase == _SeqPhase.feedback
                    ? (_lastFeedbackCorrect == false
                        ? AppColors.error
                        : AppColors.success)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _gridCells,
                itemBuilder: (ctx, i) {
                  final isLit = _litCell == i;
                  final litColor = _litCellIsError
                      ? AppColors.error
                      : AppColors.sequenceMemory;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: isInput ? (_) => _onCellTap(i) : null,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: _difficulty == 2 ? 110 : 150),
                      decoration: BoxDecoration(
                        color: isLit
                            ? litColor.withValues(alpha: 0.7)
                            : const Color(0xFF1A1A26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLit ? litColor : AppColors.border,
                          width: isLit ? 1.5 : 0.5,
                        ),
                        boxShadow: isLit
                            ? [
                                BoxShadow(
                                  color: litColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isInput ? 1 : 0,
                child: Center(
                  child: Text(
                    useArabicDigits(context)
                        ? '${_inputIndex.toArabicDigits()} / ${_sequence.length.toArabicDigits()}'
                        : '$_inputIndex / ${_sequence.length}',
                    style: AppTypography.caption,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _initialLength() {
    final bySize = _gridSize == 3 ? 2 : (_gridSize == 4 ? 3 : 4);
    final byDifficulty = _difficulty == 2 ? 1 : 0;
    return (bySize + byDifficulty).clamp(2, 5);
  }

  int get _flashOnMs => switch (_difficulty) {
        0 => 700,
        1 => 520,
        _ => 360,
      };

  int get _flashOffMs => switch (_difficulty) {
        0 => 260,
        1 => 180,
        _ => 120,
      };

  int get _roundGapMs => switch (_difficulty) {
        0 => 520,
        1 => 420,
        _ => 320,
      };

  String _speedLabel(BuildContext context) => switch (_difficulty) {
        0 => tr(context, 'بطيء', 'Slow', '慢'),
        1 => tr(context, 'متوازن', 'Balanced', '均衡'),
        _ => tr(context, 'سريع', 'Fast', '快'),
      };

  List<int> _buildRandomSequence(int len) {
    final seq = <int>[];
    for (int i = 0; i < len; i++) {
      seq.add(_nextRandomCell(lastCell: seq.isEmpty ? null : seq.last, seq: seq));
    }
    return seq;
  }

  int _nextRandomCell({int? lastCell, List<int>? seq}) {
    final recentWindow = switch (_difficulty) {
      0 => 2,
      1 => 3,
      _ => 4,
    };
    final recent = <int>{
      ...?seq?.skip(max(0, seq.length - recentWindow)),
    };

    List<int> pool = List.generate(_gridCells, (i) => i)
        .where((i) => i != lastCell && !recent.contains(i))
        .toList();
    if (pool.isEmpty) {
      pool =
          List.generate(_gridCells, (i) => i).where((i) => i != lastCell).toList();
    }

    if (lastCell != null && _difficulty >= 1) {
      final jumpPool = pool.where((i) => !_isNeighbor(i, lastCell)).toList();
      if (jumpPool.isNotEmpty && (_difficulty == 2 || _rng.nextBool())) {
        pool = jumpPool;
      }
    }
    return pool[_rng.nextInt(pool.length)];
  }

  bool _isNeighbor(int a, int b) {
    final ar = a ~/ _gridSize;
    final ac = a % _gridSize;
    final br = b ~/ _gridSize;
    final bc = b % _gridSize;
    final dr = (ar - br).abs();
    final dc = (ac - bc).abs();
    return dr <= 1 && dc <= 1;
  }
}

class _SizeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SizeBtn({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.16) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.4 : 0.6,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DifficultyBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _DifficultyBtn({
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.2 : 0.6,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
