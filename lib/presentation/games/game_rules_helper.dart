import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/utils/tr.dart';
import '../../domain/enums/game_type.dart';

class GameRulesHelper {
  static const String _rulesBox = 'game_rules_seen';

  static Future<void> ensureShownOnce(
    BuildContext context,
    GameType gameType,
  ) async {
    final box = await _openBox();
    final key = _seenKey(gameType);
    final seen = box.get(key, defaultValue: false) ?? false;
    if (seen || !context.mounted) return;

    await showRulesDialog(context, gameType);
    await box.put(key, true);
  }

  static Future<void> showRulesDialog(
    BuildContext context,
    GameType gameType,
  ) async {
    final lang = Localizations.localeOf(context).languageCode;
    final content = _ruleContent(context, gameType);
    final diagram = _ruleDiagram(context, gameType);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Text(
            lang == 'ar'
                ? 'قواعد اللعبة'
                : (lang == 'zh' ? '游戏规则' : 'Game Rules'),
            style: AppTypography.headingSmall,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                if (diagram != null) ...[
                  const SizedBox(height: 14),
                  diagram,
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                lang == 'ar' ? 'حسنًا' : (lang == 'zh' ? '知道了' : 'Got it'),
                style: AppTypography.labelLarge.copyWith(color: AppColors.gold),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<Box<bool>> _openBox() async {
    if (Hive.isBoxOpen(_rulesBox)) {
      return Hive.box<bool>(_rulesBox);
    }
    return Hive.openBox<bool>(_rulesBox);
  }

  static String _seenKey(GameType gameType) => 'seen_${gameType.id}';

  static Widget? _ruleDiagram(BuildContext context, GameType type) {
    return switch (type) {
      GameType.towerOfHanoi => _TowerOfHanoiRuleDiagram(
          state1Label: tr(context, 'الحالة 1', 'State 1', '状态 1'),
          state2Label: tr(context, 'الحالة 2', 'State 2', '状态 2'),
          successLabel: tr(
            context,
            'نجاح = كل الأقراص على العمود الأيمن',
            'Success = all discs on right peg',
            '成功 = 所有圆盘在右侧柱子',
          ),
        ),
      GameType.slidingPuzzle => _SlidingPuzzleRuleDiagram(
          title: tr(context, 'شكل النجاح', 'Success Pattern', '成功示意'),
          note: tr(
            context,
            '١→٨ بالترتيب، والخانة الأخيرة فارغة',
            'Arrange 1→8 in order, keep last cell empty',
            '1→8 按顺序，最后一格留空',
          ),
        ),
      _ => null,
    };
  }

  static String _ruleContent(BuildContext context, GameType type) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'ar') {
      return switch (type) {
        GameType.schulteGrid => 'الهدف: اضغط الأرقام تصاعديًا بأسرع وقت.\n'
            'القواعد:\n'
            '• ابدأ من الرقم ١ ثم ٢ ثم ٣...\n'
            '• الضغط الخاطئ لا ينهي اللعبة لكنه يضيع الوقت.\n'
            '• سجلك الأفضل هو أقل زمن.',
        GameType.reactionTime => 'الهدف: اختبر سرعة تفاعلك مع تأثير ستروب.\n'
            'القواعد:\n'
            '• تظهر كلمة لون بلون مختلف.\n'
            '• اضغط زر لون الخط الحقيقي وليس معنى الكلمة.\n'
            '• النتيجة هي متوسط زمن الاستجابة بالأجزاء من الثانية.',
        GameType.numberMemory =>
          'الهدف: تذكر سلسلة أرقام وإدخالها بنفس الترتيب.\n'
              'القواعد:\n'
              '• احفظ الرقم الظاهر حتى يختفي.\n'
              '• أدخل نفس التسلسل تمامًا.\n'
              '• كل إجابة صحيحة تزيد طول السلسلة.',
        GameType.stroopTest => 'الهدف: التركيز تحت التعارض اللوني.\n'
            'القواعد:\n'
            '• ستظهر كلمة لون بلون مختلف.\n'
            '• اختر لون الحبر الحقيقي.\n'
            '• نتيجتك بعدد الإجابات الصحيحة.',
        GameType.visualMemory => 'الهدف: تذكر مواقع المربعات المضيئة.\n'
            'القواعد:\n'
            '• شاهد المربعات التي أضاءت.\n'
            '• بعد اختفائها اضغط نفس المواقع.\n'
            '• كل جولة صحيحة تزيد عدد المربعات.',
        GameType.sequenceMemory => 'الهدف: إعادة تسلسل الإضاءة بدقة.\n'
            'القواعد:\n'
            '• راقب ترتيب المربعات المضيئة.\n'
            '• اضغط بنفس الترتيب تمامًا.\n'
            '• كل نجاح يضيف خطوة جديدة للتسلسل.',
        GameType.numberMatrix => 'الهدف: اضغط الأرقام من ١ إلى ٢٥ بالترتيب.\n'
            'القواعد:\n'
            '• اضغط دائمًا الرقم المطلوب التالي.\n'
            '• السرعة مهمة مع الحفاظ على التسلسل الصحيح.\n'
            '• النتيجة الأفضل هي أقل زمن.',
        GameType.reverseMemory => 'الهدف: تذكر الأرقام ثم إدخالها بالعكس.\n'
            'القواعد:\n'
            '• احفظ التسلسل كما يظهر.\n'
            '• أدخله بترتيب معكوس (مثال: 123 ← 321).\n'
            '• كل إجابة صحيحة تزيد الطول.',
        GameType.slidingPuzzle => 'الهدف: ترتيب القطع في شكلها الصحيح.\n'
            'القواعد:\n'
            '• يمكنك تحريك القطعة المجاورة للمربع الفارغ فقط.\n'
            '• رتّب الأرقام من اليسار لليمين ومن الأعلى للأسفل.\n'
            '• شكل النجاح (٣×٣):\n'
            '  ١ ٢ ٣\n'
            '  ٤ ٥ ٦\n'
            '  ٧ ٨ [ ]\n'
            '• الأفضلية لأقل عدد حركات.',
        GameType.towerOfHanoi => 'الهدف: نقل جميع الأقراص إلى العمود الأخير.\n'
            'القواعد:\n'
            '• انقل قرصًا واحدًا فقط في كل حركة.\n'
            '• لا تضع قرصًا كبيرًا فوق قرص أصغر.\n'
            '• الأفضلية لأقل عدد حركات.',
      };
    }
    if (lang == 'zh') {
      return switch (type) {
        GameType.schulteGrid => '目标：按升序快速点击数字。\n'
            '规则：\n'
            '• 从 1 开始，然后 2、3...\n'
            '• 点错不会结束游戏，但会浪费时间。\n'
            '• 最佳成绩为最短时间。',
        GameType.reactionTime => '目标：在斯特鲁普式挑战中测试反应速度。\n'
            '规则：\n'
            '• 会出现颜色词，字体颜色不同。\n'
            '• 点击字体颜色对应的按钮，而非文字含义。\n'
            '• 成绩为平均反应时间。',
        GameType.numberMemory => '目标：记住数字序列并按相同顺序输入。\n'
            '规则：\n'
            '• 在消失前记住显示的序列。\n'
            '• 输入完全相同的序列。\n'
            '• 每答对一次，序列长度增加。',
        GameType.stroopTest => '目标：在颜色-文字干扰下保持专注。\n'
            '规则：\n'
            '• 会看到颜色词，墨水颜色不匹配。\n'
            '• 选择真实的墨水颜色。\n'
            '• 成绩为答对总数。',
        GameType.visualMemory => '目标：记住哪些格子被点亮。\n'
            '规则：\n'
            '• 观察高亮的格子。\n'
            '• 消失后点击相同位置。\n'
            '• 答对越多，难度越高。',
        GameType.sequenceMemory => '目标：正确重复显示的序列。\n'
            '规则：\n'
            '• 观察高亮格子的顺序。\n'
            '• 按完全相同顺序点击。\n'
            '• 每次成功增加一步。',
        GameType.numberMatrix => '目标：按顺序从 1 到 25 点击数字。\n'
            '规则：\n'
            '• 始终点击下一个目标数字。\n'
            '• 速度重要，同时保持顺序正确。\n'
            '• 最佳成绩为最短时间。',
        GameType.reverseMemory => '目标：记住数字并按倒序输入。\n'
            '规则：\n'
            '• 记住显示的序列。\n'
            '• 按倒序输入（如 123 → 321）。\n'
            '• 每答对一次，序列长度增加。',
        GameType.slidingPuzzle => '目标：将方块排列成正确顺序。\n'
            '规则：\n'
            '• 只能移动空格相邻的方块。\n'
            '• 按从左到右、从上到下排列。\n'
            '• 成功示例（3×3）：\n'
            '  1 2 3\n'
            '  4 5 6\n'
            '  7 8 [ ]\n'
            '• 最佳成绩为最少步数。',
        GameType.towerOfHanoi => '目标：将所有圆盘移到最后一柱。\n'
            '规则：\n'
            '• 每次只能移动一个圆盘。\n'
            '• 大盘不能放在小盘上。\n'
            '• 最佳成绩为最少步数。',
      };
    }
    return switch (type) {
      GameType.schulteGrid =>
        'Goal: Tap numbers in ascending order as fast as possible.\n'
            'Rules:\n'
            '• Start from 1, then 2, then 3...\n'
            '• Wrong taps do not end the game, but cost time.\n'
            '• Best score is the lowest time.',
      GameType.reactionTime =>
        'Goal: Test your reaction speed with a Stroop-style challenge.\n'
            'Rules:\n'
            '• A color word appears in a different font color.\n'
            '• Tap the button for the font color, not the word meaning.\n'
            '• Score is your average response time.',
      GameType.numberMemory =>
        'Goal: Memorize digits and enter them in the same order.\n'
            'Rules:\n'
            '• Remember the shown sequence before it disappears.\n'
            '• Enter exactly the same sequence.\n'
            '• Sequence length increases after each correct answer.',
      GameType.stroopTest => 'Goal: Focus under color-word interference.\n'
          'Rules:\n'
          '• You will see a color word in mismatched ink.\n'
          '• Choose the real ink color.\n'
          '• Score is total correct answers.',
      GameType.visualMemory => 'Goal: Remember which cells were lit.\n'
          'Rules:\n'
          '• Watch the highlighted cells.\n'
          '• Tap the same cells after they disappear.\n'
          '• More correct rounds increase difficulty.',
      GameType.sequenceMemory => 'Goal: Repeat the shown sequence correctly.\n'
          'Rules:\n'
          '• Watch the order of highlighted cells.\n'
          '• Tap in exactly the same order.\n'
          '• Each success adds one more step.',
      GameType.numberMatrix => 'Goal: Tap numbers from 1 to 25 in order.\n'
          'Rules:\n'
          '• Always tap the next target number.\n'
          '• Speed matters while keeping sequence correct.\n'
          '• Best score is the lowest time.',
      GameType.reverseMemory =>
        'Goal: Memorize digits and enter them in reverse.\n'
            'Rules:\n'
            '• Remember the sequence as shown.\n'
            '• Enter it in reverse order (e.g. 123 -> 321).\n'
            '• Sequence length increases after each correct answer.',
      GameType.slidingPuzzle => 'Goal: Arrange tiles into the correct order.\n'
          'Rules:\n'
          '• Only tiles next to the empty space can move.\n'
          '• Arrange left-to-right, top-to-bottom.\n'
          '• Success pattern (3×3):\n'
          '  1 2 3\n'
          '  4 5 6\n'
          '  7 8 [ ]\n'
          '• Best score is the fewest moves.',
      GameType.towerOfHanoi => 'Goal: Move all disks to the last peg.\n'
          'Rules:\n'
          '• Move only one disk at a time.\n'
          '• A larger disk cannot be placed on a smaller disk.\n'
          '• Best score is the fewest moves.',
    };
  }
}

class _TowerOfHanoiRuleDiagram extends StatelessWidget {
  final String state1Label;
  final String state2Label;
  final String successLabel;

  const _TowerOfHanoiRuleDiagram({
    required this.state1Label,
    required this.state2Label,
    required this.successLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10121E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.towerOfHanoi.withValues(alpha: 0.35),
          width: 0.7,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _RuleTowerState(
                  label: state1Label,
                  discsOnLeft: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
              Expanded(
                child: _RuleTowerState(
                  label: state2Label,
                  discsOnLeft: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            successLabel,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleTowerState extends StatelessWidget {
  final String label;
  final bool discsOnLeft;

  const _RuleTowerState({
    required this.label,
    required this.discsOnLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 58,
          child: Stack(
            children: [
              Positioned(
                left: 6,
                right: 6,
                bottom: 0,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.towerOfHanoi.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              ...List.generate(3, (peg) {
                return Positioned(
                  left: 14.0 + peg * 24.0,
                  bottom: 7,
                  width: 4,
                  height: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
              ..._buildDiscs(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDiscs() {
    final targetPeg = discsOnLeft ? 0 : 2;
    final widths = [22.0, 16.0, 10.0];
    return List.generate(3, (i) {
      final width = widths[i];
      final left = 16.0 + targetPeg * 24.0 - (width / 2 - 2);
      return Positioned(
        left: left,
        bottom: 8.0 + i * 8.0,
        width: width,
        height: 7,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.towerOfHanoi.withValues(alpha: 0.85 - i * 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    });
  }
}

class _SlidingPuzzleRuleDiagram extends StatelessWidget {
  final String title;
  final String note;

  const _SlidingPuzzleRuleDiagram({
    required this.title,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10121E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.slidingPuzzle.withValues(alpha: 0.35),
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: AppColors.slidingPuzzle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 124,
            height: 124,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 9,
              itemBuilder: (context, i) {
                final value = i == 8 ? 0 : i + 1;
                final isEmpty = value == 0;
                return Container(
                  decoration: BoxDecoration(
                    color: isEmpty
                        ? Colors.transparent
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isEmpty
                          ? AppColors.border.withValues(alpha: 0.55)
                          : AppColors.slidingPuzzle.withValues(alpha: 0.34),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isEmpty
                          ? tr(context, 'فارغ', 'Empty', '空')
                          : (useArabicDigits(context)
                              ? value.toArabicDigits()
                              : '$value'),
                      style: AppTypography.caption.copyWith(
                        color: isEmpty
                            ? AppColors.textDisabled
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
