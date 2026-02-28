// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '大脑健身房';

  @override
  String get startTest => '开始测试';

  @override
  String get playAgain => '再玩一次';

  @override
  String get backToDashboard => '返回首页';

  @override
  String get settings => '设置';

  @override
  String get analytics => '分析';

  @override
  String get profile => '我的';

  @override
  String get lqScore => '逻辑商数';

  @override
  String get lqScoreLabel => 'LQ';

  @override
  String get tierBeginner => '入门';

  @override
  String get tierIntermediate => '中级';

  @override
  String get tierProfessional => '专业';

  @override
  String get tierMaster => '大师';

  @override
  String get dimensionSpeed => '速度';

  @override
  String get dimensionMemory => '记忆';

  @override
  String get dimensionSpaceLogic => '空间与逻辑';

  @override
  String get dimensionFocus => '专注';

  @override
  String get dimensionPerception => '感知';

  @override
  String get gamesSection => '游戏';

  @override
  String get personalBest => '最佳';

  @override
  String get latestScore => '最近';

  @override
  String get average => '平均';

  @override
  String get schulteGridName => '舒尔特方格';

  @override
  String get schulteGridNameEn => 'Schulte Grid';

  @override
  String get schulteGridDesc => '按顺序从 1 到最大数字快速点击';

  @override
  String get reactionTimeName => '反应时间';

  @override
  String get reactionTimeNameEn => 'Reaction Time';

  @override
  String get reactionTimeDesc => '根据字体颜色点击正确按钮，而非文字含义';

  @override
  String get numberMemoryName => '数字记忆';

  @override
  String get numberMemoryNameEn => 'Number Memory';

  @override
  String get numberMemoryDesc => '记住数字序列并按顺序输入';

  @override
  String get stroopTestName => '斯特鲁普测试';

  @override
  String get stroopTestNameEn => 'Stroop Test';

  @override
  String get stroopTestDesc => '点击与字体颜色匹配的按钮，而非文字';

  @override
  String get visualMemoryName => '视觉记忆';

  @override
  String get visualMemoryNameEn => 'Visual Memory';

  @override
  String get visualMemoryDesc => '记住亮起的方格并点击它们';

  @override
  String get sequenceMemoryName => '序列记忆';

  @override
  String get sequenceMemoryNameEn => 'Sequence Memory';

  @override
  String get sequenceMemoryDesc => '重复亮起方格的序列';

  @override
  String get numberMatrixName => '数字矩阵';

  @override
  String get numberMatrixNameEn => 'Number Matrix';

  @override
  String get numberMatrixDesc => '按顺序从 1 到 25 快速点击数字';

  @override
  String get reverseMemoryName => '数字倒序';

  @override
  String get reverseMemoryNameEn => 'Reverse Memory';

  @override
  String get reverseMemoryDesc => '记住数字并按倒序输入';

  @override
  String get slidingPuzzleName => '数字华容道';

  @override
  String get slidingPuzzleNameEn => 'Sliding Puzzle';

  @override
  String get slidingPuzzleDesc => '用最少步数将数字按顺序排列';

  @override
  String get towerOfHanoiName => '汉诺塔';

  @override
  String get towerOfHanoiNameEn => 'Tower of Hanoi';

  @override
  String get towerOfHanoiDesc => '将所有圆盘从左柱移到右柱';

  @override
  String get tapByFontColor => '按字体颜色点击';

  @override
  String get correctLabel => '正确';

  @override
  String get wrongLabel => '错误';

  @override
  String get timeLabel => '时间';

  @override
  String get movesLabel => '步数';

  @override
  String get lengthLabel => '长度';

  @override
  String get gameOver => '游戏结束';

  @override
  String get congratulations => '恭喜！🎉';

  @override
  String get newRecord => '新纪录！🏆';

  @override
  String get showingIn => '显示于';

  @override
  String get tapWhenReady => '颜色出现时点击';

  @override
  String get enterDigits => '输入数字';

  @override
  String get enterDigitsReverse => '倒序输入数字';

  @override
  String get difficultyEasy => '简单';

  @override
  String get difficultyMedium => '中等';

  @override
  String get difficultyHard => '困难';

  @override
  String get soundEnabled => '声音开';

  @override
  String get soundDisabled => '声音关';

  @override
  String get saveImageSuccess => '已保存到相册';

  @override
  String get saveImageFailed => '保存图片失败';

  @override
  String get hapticsEnabled => '震动开';

  @override
  String get hapticsDisabled => '震动关';

  @override
  String get languageLabel => '语言';

  @override
  String get fontSizeLabel => '字号';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeMedium => '中';

  @override
  String get fontSizeLarge => '大';

  @override
  String get resetData => '重置所有数据';

  @override
  String get resetDataConfirm => '确定吗？所有分数和历史记录将被删除。';

  @override
  String get resetDataConfirmButton => '确认重置';

  @override
  String get cancel => '取消';

  @override
  String get aboutApp => '关于';

  @override
  String get privacyNote => '所有数据仅保存在您的设备上，我们不会收集任何信息。';

  @override
  String get version => '版本';

  @override
  String get seconds => '秒';

  @override
  String get milliseconds => '毫秒';

  @override
  String get digits => '位';

  @override
  String get noDataYet => '暂无数据 — 先玩一局吧！';

  @override
  String get recentSessions => '最近会话';

  @override
  String get allGames => '所有游戏';

  @override
  String dashboardTracksReady(int played, int total) {
    return '$played/$total 个项目已解锁';
  }

  @override
  String featuredMixSemantics(Object gameName) {
    return '精选训练：$gameName';
  }

  @override
  String get featuredMixChip => '精选组合';

  @override
  String get featuredMixTitle => '今日训练组合';

  @override
  String featuredMixSubtitle(Object gameName) {
    return '从「$gameName」开始，进入专注节奏。';
  }

  @override
  String get featuredMixStart => '开始训练';

  @override
  String featuredMixSessions(int count) {
    return '累计 $count 次训练';
  }

  @override
  String get featuredContinueTitle => '继续上次训练';

  @override
  String featuredContinueSubtitle(Object gameName, Object score) {
    return '$gameName · 上次 $score';
  }

  @override
  String get featuredNoHistory => '暂无历史记录';

  @override
  String get featuredRecentTrend => '最近成绩趋势';

  @override
  String get trendImproving => '上升';

  @override
  String get trendDeclining => '下降';

  @override
  String get trendStable => '稳定';

  @override
  String get modeFocus => '专注';

  @override
  String get modeMemory => '记忆';

  @override
  String get modeSpeed => '速度';

  @override
  String get modeLogic => '逻辑';

  @override
  String get modeChallenge => '挑战';

  @override
  String gameCardSemantics(Object name, Object tagline) {
    return '$name，$tagline';
  }

  @override
  String get dashboardTapToPlay => '点击开始';

  @override
  String get dashboardNewLabel => '新';

  @override
  String get gameCategoryVisualScan => '视觉搜索';

  @override
  String get gameCategoryReflex => '反应';

  @override
  String get gameCategoryMemory => '记忆';

  @override
  String get gameCategoryFocus => '专注';

  @override
  String get gameCategoryVisualMem => '视觉记忆';

  @override
  String get gameCategorySequence => '序列';

  @override
  String get gameCategoryCognition => '认知';

  @override
  String get gameCategoryReverse => '倒序';

  @override
  String get gameCategorySpatial => '空间';

  @override
  String get gameCategoryStrategy => '策略';

  @override
  String get taglineSchulte => '按顺序定位数字，保持稳定节奏';

  @override
  String get taglineReaction => '捕捉信号变化，快速作答';

  @override
  String get taglineNumberMemory => '短时记住数字并准确复现';

  @override
  String get taglineStroop => '只看字体颜色，忽略文字含义';

  @override
  String get taglineVisual => '记住闪现方块并准确回忆';

  @override
  String get taglineSequence => '跟随亮点路径，保持次序';

  @override
  String get taglineMatrix => '在干扰中追踪位置变化';

  @override
  String get taglineReverse => '在压力下完成倒序回忆';

  @override
  String get taglineSliding => '滑动拼块，恢复完整顺序';

  @override
  String get taglineHanoi => '规划最少步数完成迁移';
}
