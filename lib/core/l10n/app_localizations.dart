import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('zh')
  ];

  /// App name
  ///
  /// In ar, this message translates to:
  /// **'مختبر المنطق'**
  String get appName;

  /// No description provided for @startTest.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الاختبار'**
  String get startTest;

  /// No description provided for @playAgain.
  ///
  /// In ar, this message translates to:
  /// **'العب مجددًا'**
  String get playAgain;

  /// No description provided for @backToDashboard.
  ///
  /// In ar, this message translates to:
  /// **'العودة للرئيسية'**
  String get backToDashboard;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @analytics.
  ///
  /// In ar, this message translates to:
  /// **'التحليل'**
  String get analytics;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'ملفي'**
  String get profile;

  /// No description provided for @lqScore.
  ///
  /// In ar, this message translates to:
  /// **'مقياس المنطق'**
  String get lqScore;

  /// No description provided for @lqScoreLabel.
  ///
  /// In ar, this message translates to:
  /// **'LQ'**
  String get lqScoreLabel;

  /// No description provided for @tierBeginner.
  ///
  /// In ar, this message translates to:
  /// **'مبتدئ'**
  String get tierBeginner;

  /// No description provided for @tierIntermediate.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get tierIntermediate;

  /// No description provided for @tierProfessional.
  ///
  /// In ar, this message translates to:
  /// **'محترف'**
  String get tierProfessional;

  /// No description provided for @tierMaster.
  ///
  /// In ar, this message translates to:
  /// **'معلم'**
  String get tierMaster;

  /// No description provided for @dimensionSpeed.
  ///
  /// In ar, this message translates to:
  /// **'السرعة'**
  String get dimensionSpeed;

  /// No description provided for @dimensionMemory.
  ///
  /// In ar, this message translates to:
  /// **'الذاكرة'**
  String get dimensionMemory;

  /// No description provided for @dimensionSpaceLogic.
  ///
  /// In ar, this message translates to:
  /// **'المنطق والمساحة'**
  String get dimensionSpaceLogic;

  /// No description provided for @dimensionFocus.
  ///
  /// In ar, this message translates to:
  /// **'التركيز'**
  String get dimensionFocus;

  /// No description provided for @dimensionPerception.
  ///
  /// In ar, this message translates to:
  /// **'الإدراك'**
  String get dimensionPerception;

  /// No description provided for @gamesSection.
  ///
  /// In ar, this message translates to:
  /// **'الألعاب'**
  String get gamesSection;

  /// No description provided for @personalBest.
  ///
  /// In ar, this message translates to:
  /// **'أفضل نتيجة'**
  String get personalBest;

  /// No description provided for @latestScore.
  ///
  /// In ar, this message translates to:
  /// **'آخر نتيجة'**
  String get latestScore;

  /// No description provided for @average.
  ///
  /// In ar, this message translates to:
  /// **'المعدل'**
  String get average;

  /// No description provided for @schulteGridName.
  ///
  /// In ar, this message translates to:
  /// **'شبكة شولت'**
  String get schulteGridName;

  /// No description provided for @schulteGridNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Schulte Grid'**
  String get schulteGridNameEn;

  /// No description provided for @schulteGridDesc.
  ///
  /// In ar, this message translates to:
  /// **'اضغط الأرقام بالترتيب من ١ إلى الأكبر بأسرع وقت ممكن'**
  String get schulteGridDesc;

  /// No description provided for @reactionTimeName.
  ///
  /// In ar, this message translates to:
  /// **'وقت التفاعل'**
  String get reactionTimeName;

  /// No description provided for @reactionTimeNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Reaction Time'**
  String get reactionTimeNameEn;

  /// No description provided for @reactionTimeDesc.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على اللون الصحيح بناءً على لون الخط — لا على معنى الكلمة'**
  String get reactionTimeDesc;

  /// No description provided for @numberMemoryName.
  ///
  /// In ar, this message translates to:
  /// **'ذاكرة الأرقام'**
  String get numberMemoryName;

  /// No description provided for @numberMemoryNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Number Memory'**
  String get numberMemoryNameEn;

  /// No description provided for @numberMemoryDesc.
  ///
  /// In ar, this message translates to:
  /// **'احفظ الأرقام التي ظهرت ثم أدخلها بنفس الترتيب'**
  String get numberMemoryDesc;

  /// No description provided for @stroopTestName.
  ///
  /// In ar, this message translates to:
  /// **'اختبار ستروب'**
  String get stroopTestName;

  /// No description provided for @stroopTestNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Stroop Test'**
  String get stroopTestNameEn;

  /// No description provided for @stroopTestDesc.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على لون الخط، وليس على معنى الكلمة'**
  String get stroopTestDesc;

  /// No description provided for @visualMemoryName.
  ///
  /// In ar, this message translates to:
  /// **'ذاكرة بصرية'**
  String get visualMemoryName;

  /// No description provided for @visualMemoryNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Visual Memory'**
  String get visualMemoryNameEn;

  /// No description provided for @visualMemoryDesc.
  ///
  /// In ar, this message translates to:
  /// **'تذكّر المربعات التي أضاءت وحدد مواقعها'**
  String get visualMemoryDesc;

  /// No description provided for @sequenceMemoryName.
  ///
  /// In ar, this message translates to:
  /// **'تسلسل'**
  String get sequenceMemoryName;

  /// No description provided for @sequenceMemoryNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Sequence Memory'**
  String get sequenceMemoryNameEn;

  /// No description provided for @sequenceMemoryDesc.
  ///
  /// In ar, this message translates to:
  /// **'كرّر التسلسل الذي أضاءت به المربعات'**
  String get sequenceMemoryDesc;

  /// No description provided for @numberMatrixName.
  ///
  /// In ar, this message translates to:
  /// **'اختبار المصفوفة الرقمية'**
  String get numberMatrixName;

  /// No description provided for @numberMatrixNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Number Matrix'**
  String get numberMatrixNameEn;

  /// No description provided for @numberMatrixDesc.
  ///
  /// In ar, this message translates to:
  /// **'اضغط الأرقام بالترتيب من ١ إلى ٢٥ بأسرع وقت'**
  String get numberMatrixDesc;

  /// No description provided for @reverseMemoryName.
  ///
  /// In ar, this message translates to:
  /// **'ذاكرة العكس'**
  String get reverseMemoryName;

  /// No description provided for @reverseMemoryNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Reverse Memory'**
  String get reverseMemoryNameEn;

  /// No description provided for @reverseMemoryDesc.
  ///
  /// In ar, this message translates to:
  /// **'احفظ الأرقام ثم أدخلها بالترتيب المعكوس'**
  String get reverseMemoryDesc;

  /// No description provided for @slidingPuzzleName.
  ///
  /// In ar, this message translates to:
  /// **'لغز الأرقام'**
  String get slidingPuzzleName;

  /// No description provided for @slidingPuzzleNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Sliding Puzzle'**
  String get slidingPuzzleNameEn;

  /// No description provided for @slidingPuzzleDesc.
  ///
  /// In ar, this message translates to:
  /// **'رتّب الأرقام بالترتيب الصحيح بأقل عدد من الحركات'**
  String get slidingPuzzleDesc;

  /// No description provided for @towerOfHanoiName.
  ///
  /// In ar, this message translates to:
  /// **'برج هانو'**
  String get towerOfHanoiName;

  /// No description provided for @towerOfHanoiNameEn.
  ///
  /// In ar, this message translates to:
  /// **'Tower of Hanoi'**
  String get towerOfHanoiNameEn;

  /// No description provided for @towerOfHanoiDesc.
  ///
  /// In ar, this message translates to:
  /// **'انقل جميع الأقراص من العمود الأيسر إلى الأيمن'**
  String get towerOfHanoiDesc;

  /// No description provided for @tapByFontColor.
  ///
  /// In ar, this message translates to:
  /// **'اضغط حسب لون الخط'**
  String get tapByFontColor;

  /// No description provided for @correctLabel.
  ///
  /// In ar, this message translates to:
  /// **'صحيح'**
  String get correctLabel;

  /// No description provided for @wrongLabel.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get wrongLabel;

  /// No description provided for @timeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوقت'**
  String get timeLabel;

  /// No description provided for @movesLabel.
  ///
  /// In ar, this message translates to:
  /// **'الحركات'**
  String get movesLabel;

  /// No description provided for @lengthLabel.
  ///
  /// In ar, this message translates to:
  /// **'الطول'**
  String get lengthLabel;

  /// No description provided for @gameOver.
  ///
  /// In ar, this message translates to:
  /// **'انتهت اللعبة'**
  String get gameOver;

  /// No description provided for @congratulations.
  ///
  /// In ar, this message translates to:
  /// **'مبروك! 🎉'**
  String get congratulations;

  /// No description provided for @newRecord.
  ///
  /// In ar, this message translates to:
  /// **'رقم قياسي جديد! 🏆'**
  String get newRecord;

  /// No description provided for @showingIn.
  ///
  /// In ar, this message translates to:
  /// **'يظهر خلال'**
  String get showingIn;

  /// No description provided for @tapWhenReady.
  ///
  /// In ar, this message translates to:
  /// **'اضغط عند ظهور اللون'**
  String get tapWhenReady;

  /// No description provided for @enterDigits.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الأرقام'**
  String get enterDigits;

  /// No description provided for @enterDigitsReverse.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الأرقام معكوسة'**
  String get enterDigitsReverse;

  /// No description provided for @difficultyEasy.
  ///
  /// In ar, this message translates to:
  /// **'سهل'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In ar, this message translates to:
  /// **'صعب'**
  String get difficultyHard;

  /// No description provided for @soundEnabled.
  ///
  /// In ar, this message translates to:
  /// **'الأصوات مفعّلة'**
  String get soundEnabled;

  /// No description provided for @soundDisabled.
  ///
  /// In ar, this message translates to:
  /// **'الأصوات معطّلة'**
  String get soundDisabled;

  /// No description provided for @hapticsEnabled.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز مفعّل'**
  String get hapticsEnabled;

  /// No description provided for @hapticsDisabled.
  ///
  /// In ar, this message translates to:
  /// **'الاهتزاز معطّل'**
  String get hapticsDisabled;

  /// No description provided for @languageLabel.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get languageLabel;

  /// No description provided for @fontSizeLabel.
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط'**
  String get fontSizeLabel;

  /// No description provided for @fontSizeSmall.
  ///
  /// In ar, this message translates to:
  /// **'صغير'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeMedium.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get fontSizeMedium;

  /// No description provided for @fontSizeLarge.
  ///
  /// In ar, this message translates to:
  /// **'كبير'**
  String get fontSizeLarge;

  /// No description provided for @resetData.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين البيانات'**
  String get resetData;

  /// No description provided for @resetDataConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد؟ ستُحذف جميع النتائج والسجلات.'**
  String get resetDataConfirm;

  /// No description provided for @resetDataConfirmButton.
  ///
  /// In ar, this message translates to:
  /// **'نعم، أعد التعيين'**
  String get resetDataConfirmButton;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @aboutApp.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get aboutApp;

  /// No description provided for @privacyNote.
  ///
  /// In ar, this message translates to:
  /// **'جميع البيانات محفوظة على جهازك فقط — لا نجمع أي معلومات.'**
  String get privacyNote;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get version;

  /// No description provided for @seconds.
  ///
  /// In ar, this message translates to:
  /// **'ثانية'**
  String get seconds;

  /// No description provided for @milliseconds.
  ///
  /// In ar, this message translates to:
  /// **'مللي ثانية'**
  String get milliseconds;

  /// No description provided for @digits.
  ///
  /// In ar, this message translates to:
  /// **'أرقام'**
  String get digits;

  /// No description provided for @noDataYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات بعد — العب أولاً!'**
  String get noDataYet;

  /// No description provided for @recentSessions.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات الأخيرة'**
  String get recentSessions;

  /// No description provided for @allGames.
  ///
  /// In ar, this message translates to:
  /// **'جميع الألعاب'**
  String get allGames;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppL10nAr();
    case 'en':
      return AppL10nEn();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
