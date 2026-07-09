import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('fa')
  ];

  /// The title of the application
  ///
  /// In fa, this message translates to:
  /// **'ویستا'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In fa, this message translates to:
  /// **'تنظیمات'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In fa, this message translates to:
  /// **'زبان'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب زبان'**
  String get selectLanguage;

  /// No description provided for @theme.
  ///
  /// In fa, this message translates to:
  /// **'ظاهر'**
  String get theme;

  /// No description provided for @notifications.
  ///
  /// In fa, this message translates to:
  /// **'اعلان‌ها'**
  String get notifications;

  /// No description provided for @home.
  ///
  /// In fa, this message translates to:
  /// **'خانه'**
  String get home;

  /// No description provided for @explore.
  ///
  /// In fa, this message translates to:
  /// **'جستجو'**
  String get explore;

  /// No description provided for @profile.
  ///
  /// In fa, this message translates to:
  /// **'پروفایل'**
  String get profile;

  /// No description provided for @chat.
  ///
  /// In fa, this message translates to:
  /// **'چت'**
  String get chat;

  /// No description provided for @cancel.
  ///
  /// In fa, this message translates to:
  /// **'لغو'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره'**
  String get save;

  /// No description provided for @account.
  ///
  /// In fa, this message translates to:
  /// **'حساب کاربری'**
  String get account;

  /// No description provided for @privacySecurity.
  ///
  /// In fa, this message translates to:
  /// **'حریم خصوصی و امنیت'**
  String get privacySecurity;

  /// No description provided for @dataStorage.
  ///
  /// In fa, this message translates to:
  /// **'داده و ذخیره‌سازی'**
  String get dataStorage;

  /// No description provided for @savedItems.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره‌شده‌ها'**
  String get savedItems;

  /// No description provided for @requestBlueTick.
  ///
  /// In fa, this message translates to:
  /// **'درخواست تیک آبی'**
  String get requestBlueTick;

  /// No description provided for @changePassword.
  ///
  /// In fa, this message translates to:
  /// **'تغییر گذرواژه'**
  String get changePassword;

  /// No description provided for @termsAndConditions.
  ///
  /// In fa, this message translates to:
  /// **'قوانین و مقررات'**
  String get termsAndConditions;

  /// No description provided for @aboutVista.
  ///
  /// In fa, this message translates to:
  /// **'درباره ویستا'**
  String get aboutVista;

  /// No description provided for @logout.
  ///
  /// In fa, this message translates to:
  /// **'خروج از حساب'**
  String get logout;

  /// No description provided for @logoutDialog.
  ///
  /// In fa, this message translates to:
  /// **'آیا برای خروج اطمینان دارید؟'**
  String get logoutDialog;

  /// No description provided for @yes.
  ///
  /// In fa, this message translates to:
  /// **'بله'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In fa, this message translates to:
  /// **'خیر'**
  String get no;

  /// No description provided for @forYou.
  ///
  /// In fa, this message translates to:
  /// **'برای شما'**
  String get forYou;

  /// No description provided for @following.
  ///
  /// In fa, this message translates to:
  /// **'دنبال شده‌ها'**
  String get following;

  /// No description provided for @noPostsReady.
  ///
  /// In fa, this message translates to:
  /// **'هنوز پستی برای شما آماده نشده'**
  String get noPostsReady;

  /// No description provided for @followToPersonalize.
  ///
  /// In fa, this message translates to:
  /// **'با دنبال‌کردن کاربران جدید، فید شما سریع‌تر شخصی‌سازی می‌شود.'**
  String get followToPersonalize;

  /// No description provided for @searchUsers.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی کاربران'**
  String get searchUsers;

  /// No description provided for @noFollowingPosts.
  ///
  /// In fa, this message translates to:
  /// **'پستی از دنبال‌شده‌ها پیدا نشد'**
  String get noFollowingPosts;

  /// No description provided for @followMorePeople.
  ///
  /// In fa, this message translates to:
  /// **'افراد بیشتری را دنبال کنید یا کمی بعد دوباره بررسی کنید.'**
  String get followMorePeople;

  /// No description provided for @refreshFeed.
  ///
  /// In fa, this message translates to:
  /// **'تازه‌سازی فید'**
  String get refreshFeed;

  /// No description provided for @loadSuggestedFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری پست‌های پیشنهادی ناموفق بود.'**
  String get loadSuggestedFailed;

  /// No description provided for @loadFollowingFailed.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری پست‌های دنبال‌شده ناموفق بود.'**
  String get loadFollowingFailed;

  /// No description provided for @retry.
  ///
  /// In fa, this message translates to:
  /// **'تلاش مجدد'**
  String get retry;

  /// No description provided for @noInternetConnection.
  ///
  /// In fa, this message translates to:
  /// **'اتصال اینترنت برقرار نیست'**
  String get noInternetConnection;

  /// No description provided for @recheck.
  ///
  /// In fa, this message translates to:
  /// **'بررسی مجدد'**
  String get recheck;

  /// No description provided for @requested.
  ///
  /// In fa, this message translates to:
  /// **'درخواست شد'**
  String get requested;

  /// No description provided for @follow.
  ///
  /// In fa, this message translates to:
  /// **'دنبال کردن'**
  String get follow;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In fa, this message translates to:
  /// **'تایید شماره موبایل'**
  String get verifyPhoneTitle;

  /// No description provided for @verifyPhoneDesc.
  ///
  /// In fa, this message translates to:
  /// **'برای ادامه فعالیت و امنیت بیشتر حساب کاربری، لطفاً شماره موبایل خود را تایید کنید.'**
  String get verifyPhoneDesc;

  /// No description provided for @remindLater.
  ///
  /// In fa, this message translates to:
  /// **'بعداً یادآوری کن'**
  String get remindLater;

  /// No description provided for @sendCode.
  ///
  /// In fa, this message translates to:
  /// **'ارسال کد'**
  String get sendCode;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In fa, this message translates to:
  /// **'برای خروج دوباره دکمه بازگشت را بزنید'**
  String get pressBackAgainToExit;

  /// No description provided for @messages.
  ///
  /// In fa, this message translates to:
  /// **'پیام‌ها'**
  String get messages;

  /// No description provided for @closeSearch.
  ///
  /// In fa, this message translates to:
  /// **'بستن جستجو'**
  String get closeSearch;

  /// No description provided for @search.
  ///
  /// In fa, this message translates to:
  /// **'جستجو'**
  String get search;

  /// No description provided for @archivedChats.
  ///
  /// In fa, this message translates to:
  /// **'گفتگوهای بایگانی'**
  String get archivedChats;

  /// No description provided for @newSecretChat.
  ///
  /// In fa, this message translates to:
  /// **'گفتگوی محرمانه جدید'**
  String get newSecretChat;

  /// No description provided for @searchInMessagesAndChannels.
  ///
  /// In fa, this message translates to:
  /// **'جستجو در پیام‌ها و کانال‌ها...'**
  String get searchInMessagesAndChannels;

  /// No description provided for @errorLoadingConversations.
  ///
  /// In fa, this message translates to:
  /// **'خطا در بارگذاری گفتگوها'**
  String get errorLoadingConversations;

  /// No description provided for @noConversations.
  ///
  /// In fa, this message translates to:
  /// **'هیچ گفتگویی وجود ندارد'**
  String get noConversations;

  /// No description provided for @noResultsFound.
  ///
  /// In fa, this message translates to:
  /// **'نتیجه‌ای یافت نشد'**
  String get noResultsFound;

  /// No description provided for @messageRequests.
  ///
  /// In fa, this message translates to:
  /// **'درخواست پیام'**
  String get messageRequests;

  /// No description provided for @pinned.
  ///
  /// In fa, this message translates to:
  /// **'پین شده'**
  String get pinned;

  /// No description provided for @allConversations.
  ///
  /// In fa, this message translates to:
  /// **'همه گفتگوها'**
  String get allConversations;

  /// No description provided for @deleteConversation.
  ///
  /// In fa, this message translates to:
  /// **'حذف گفتگو'**
  String get deleteConversation;

  /// No description provided for @delete.
  ///
  /// In fa, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @conversationDeleted.
  ///
  /// In fa, this message translates to:
  /// **'گفتگو با موفقیت حذف شد'**
  String get conversationDeleted;

  /// No description provided for @conversationDeleteFailed.
  ///
  /// In fa, this message translates to:
  /// **'حذف گفتگو انجام نشد'**
  String get conversationDeleteFailed;

  /// No description provided for @post.
  ///
  /// In fa, this message translates to:
  /// **'پست'**
  String get post;

  /// No description provided for @followers.
  ///
  /// In fa, this message translates to:
  /// **'دنبال‌کننده'**
  String get followers;

  /// No description provided for @followingCount.
  ///
  /// In fa, this message translates to:
  /// **'دنبال‌شونده'**
  String get followingCount;

  /// No description provided for @noPostsYet.
  ///
  /// In fa, this message translates to:
  /// **'هنوز پستی نیست'**
  String get noPostsYet;

  /// No description provided for @shareFirstPost.
  ///
  /// In fa, this message translates to:
  /// **'اولین پست خود را به اشتراک بگذارید'**
  String get shareFirstPost;

  /// No description provided for @userHasNoPosts.
  ///
  /// In fa, this message translates to:
  /// **'این کاربر هنوز پستی منتشر نکرده'**
  String get userHasNoPosts;

  /// No description provided for @errorLoadingPosts.
  ///
  /// In fa, this message translates to:
  /// **'خطا در بارگذاری پست‌ها'**
  String get errorLoadingPosts;

  /// No description provided for @errorLoading.
  ///
  /// In fa, this message translates to:
  /// **'خطا در بارگذاری'**
  String get errorLoading;

  /// No description provided for @noReelsYet.
  ///
  /// In fa, this message translates to:
  /// **'هنوز کلیپی نیست'**
  String get noReelsYet;

  /// No description provided for @shareFirstReel.
  ///
  /// In fa, this message translates to:
  /// **'اولین کلیپ خود را به اشتراک بگذارید'**
  String get shareFirstReel;

  /// No description provided for @userHasNoReels.
  ///
  /// In fa, this message translates to:
  /// **'این کاربر هنوز کلیپی منتشر نکرده'**
  String get userHasNoReels;

  /// No description provided for @errorLoadingReels.
  ///
  /// In fa, this message translates to:
  /// **'خطا در بارگذاری کلیپ‌ها'**
  String get errorLoadingReels;

  /// No description provided for @noMusicYet.
  ///
  /// In fa, this message translates to:
  /// **'هنوز موزیکی نیست'**
  String get noMusicYet;

  /// No description provided for @addMusicToPosts.
  ///
  /// In fa, this message translates to:
  /// **'برای پست‌هایتان موزیک اضافه کنید'**
  String get addMusicToPosts;

  /// No description provided for @userHasNoMusic.
  ///
  /// In fa, this message translates to:
  /// **'این کاربر هنوز موزیکی منتشر نکرده'**
  String get userHasNoMusic;

  /// No description provided for @errorLoadingMusic.
  ///
  /// In fa, this message translates to:
  /// **'خطا در بارگذاری موزیک‌ها'**
  String get errorLoadingMusic;

  /// No description provided for @shareProfile.
  ///
  /// In fa, this message translates to:
  /// **'اشتراک‌گذاری پروفایل'**
  String get shareProfile;

  /// No description provided for @usernameNotAvailable.
  ///
  /// In fa, this message translates to:
  /// **'نام کاربری در دسترس نیست'**
  String get usernameNotAvailable;

  /// No description provided for @copyProfileLink.
  ///
  /// In fa, this message translates to:
  /// **'کپی لینک پروفایل'**
  String get copyProfileLink;

  /// No description provided for @profileLinkCopied.
  ///
  /// In fa, this message translates to:
  /// **'لینک پروفایل کپی شد'**
  String get profileLinkCopied;

  /// No description provided for @report.
  ///
  /// In fa, this message translates to:
  /// **'گزارش'**
  String get report;

  /// No description provided for @userReportSubmitted.
  ///
  /// In fa, this message translates to:
  /// **'گزارش کاربر ثبت شد'**
  String get userReportSubmitted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
