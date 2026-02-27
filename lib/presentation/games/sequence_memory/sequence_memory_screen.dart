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

class _SequenceMemoryScreenState
    extends ConsumerState<SequenceMemoryScreen> {
  static const _gridCells = 9; // 3×3

  final _rng = Random();
  _SeqPhase _phase = _SeqPhase.config;

  List<int> _sequence = []; // the target sequence
  int _playbackIndex = 0; // which cell is currently lit during playback
  int _inputIndex = 0; // how many cells user has tapped
  int? _litCell; // cell index currently lit
  int _maxLength = 0;

  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
      _sequence = [_rng.nextInt(_gridCells), _rng.nextInt(_gridCells)];
      _maxLength = 0;
      _phase = _SeqPhase.config;
    });
    _playSequence();
  }

  void _playSequence() {
    setState(() {
      _phase = _SeqPhase.playing;
      _playbackIndex = 0;
      _litCell = null;
    });

    _playbackTimer?.cancel();
    _playStep();
  }

  void _playStep() {
    if (_playbackIndex >= _sequence.length) {
      // Done — wait briefly then let user input
      _playbackTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _phase = _SeqPhase.inputting);
      });
      return;
    }

    final cell = _sequence[_playbackIndex];
    setState(() => _litCell = cell);
    Haptics.selection();

    _playbackTimer = Timer(const Duration(milliseconds: 600), () {
      setState(() => _litCell = null);
      _playbackTimer = Timer(const Duration(milliseconds: 200), () {
        _playbackIndex++;
        _playStep();
      });
    });
  }

  void _onCellTap(int index) {
    if (_phase != _SeqPhase.inputting) return;

    final expected = _sequence[_inputIndex];
    if (index == expected) {
      Haptics.light();
      setState(() {
        _litCell = index;
        _inputIndex++;
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _litCell = null);

        if (_inputIndex >= _sequence.length) {
          // Correct! Extend sequence
          _maxLength = _sequence.length;
          _sequence.add(_rng.nextInt(_gridCells));
          _inputIndex = 0;
          setState(() => _phase = _SeqPhase.feedback);
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) _playSequence();
          });
        }
      });
    } else {
      // Wrong
      Haptics.medium();
      setState(() {
        _litCell = index;
        _phase = _SeqPhase.feedback;
      });
      Future.delayed(const Duration(milliseconds: 800), _finishGame);
    }
  }

  Future<void> _finishGame() async {
    _playbackTimer?.cancel();
    final record = ScoreRecord(
      gameId: GameType.sequenceMemory.id,
      score: _maxLength.toDouble(),
      timestamp: DateTime.now(),
      difficulty: 1,
      metadata: {'maxLength': _maxLength},
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
            icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
            onPressed: () =>
                GameRulesHelper.showRulesDialog(context, GameType.sequenceMemory),
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
              tr(context,
                  'كرّر التسلسل الذي أضاءت به المربعات',
                  'Repeat the sequence in which the squares lit up',
                  '重复亮起方格的序列'),
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
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
                      ? tr(context, 'كرر التسلسل', 'Repeat the sequence', '重复序列')
                      : tr(context, 'صحيح!', 'Correct!', '正确！')),
              style: AppTypography.labelMedium,
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _gridCells,
                itemBuilder: (ctx, i) {
                  final isLit = _litCell == i;

                  return GestureDetector(
                    onTap: isInput ? () => _onCellTap(i) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isLit
                            ? AppColors.sequenceMemory.withValues(alpha: 0.7)
                            : const Color(0xFF1A1A26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLit
                              ? AppColors.sequenceMemory
                              : AppColors.border,
                          width: isLit ? 1.5 : 0.5,
                        ),
                        boxShadow: isLit
                            ? [
                                BoxShadow(
                                  color: AppColors.sequenceMemory
                                      .withValues(alpha: 0.4),
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
            if (isInput)
              Text(
                useArabicDigits(context)
                    ? '${_inputIndex.toArabicDigits()} / ${_sequence.length.toArabicDigits()}'
                    : '$_inputIndex / ${_sequence.length}',
                style: AppTypography.caption,
              ),
          ],
        ),
      ),
    );
  }
}
