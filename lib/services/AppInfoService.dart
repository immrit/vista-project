import 'package:package_info_plus/package_info_plus.dart';

/// سرویس دریافت اطلاعات اپلیکیشن
class AppInfoService {
  static const String _bazaarAppId = 'ir.coffevista.vista';
  static const String _bazaarWebUrl = 'https://cafebazaar.ir/app/$_bazaarAppId';

  // اطلاعات واقعی از کافه‌بازار
  static const String _currentVersion = '2.1.0';
  static const String _buildNumber = '36';
  static const String _lastUpdateDate = '۱۳ مرداد ۱۴۰۴';
  static const String _appSize = '۷۷ مگابایت';
  static const String _installCount = '+۲ هزار';
  static const String _rating = '۳.۸';
  static const String _ratingCount = '۲۸ رأی';
  static const String _category = 'شبکه‌های اجتماعی';

  /// دریافت اطلاعات بسته اپلیکیشن
  static Future<PackageInfo> getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// دریافت نسخه فعلی اپلیکیشن
  static Future<String> getCurrentVersion() async {
    final packageInfo = await getPackageInfo();
    return packageInfo.version;
  }

  /// دریافت نسخه دقیق pubspec (فرمت: version+build)
  static Future<String> getPubspecVersion() async {
    final packageInfo = await getPackageInfo();
    final version = packageInfo.version.trim();
    final buildNumber = packageInfo.buildNumber.trim();
    if (buildNumber.isEmpty) return version;
    return '$version+$buildNumber';
  }

  /// دریافت شماره ساخت
  static Future<String> getBuildNumber() async {
    final packageInfo = await getPackageInfo();
    return packageInfo.buildNumber;
  }

  /// دریافت نام اپلیکیشن
  static Future<String> getAppName() async {
    final packageInfo = await getPackageInfo();
    return packageInfo.appName;
  }

  /// دریافت نام پکیج
  static Future<String> getPackageName() async {
    final packageInfo = await getPackageInfo();
    return packageInfo.packageName;
  }

  /// دریافت اطلاعات کامل اپلیکیشن
  static Future<Map<String, String>> getAppInfo() async {
    final packageInfo = await getPackageInfo();
    return {
      'appName': packageInfo.appName,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'packageName': packageInfo.packageName,
      'bazaarAppId': _bazaarAppId,
      'bazaarWebUrl': _bazaarWebUrl,
      'lastUpdateDate': _lastUpdateDate,
      'appSize': _appSize,
      'installCount': _installCount,
      'rating': _rating,
      'ratingCount': _ratingCount,
      'category': _category,
    };
  }

  /// دریافت اطلاعات کافه‌بازار
  static Map<String, String> getBazaarInfo() {
    return {
      'appId': _bazaarAppId,
      'webUrl': _bazaarWebUrl,
      'version': _currentVersion,
      'buildNumber': _buildNumber,
      'lastUpdateDate': _lastUpdateDate,
      'appSize': _appSize,
      'installCount': _installCount,
      'rating': _rating,
      'ratingCount': _ratingCount,
      'category': _category,
    };
  }

  /// بررسی نیاز به به‌روزرسانی
  static bool needsUpdate(String latestVersion) {
    final currentVersion = _currentVersion;
    return _compareVersions(currentVersion, latestVersion) < 0;
  }

  /// مقایسه نسخه‌ها
  static int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    final maxLength =
        v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;

    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;

      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }

    return 0;
  }

  /// دریافت متن کامل اطلاعات نسخه
  static String getVersionInfoText() {
    return 'نسخه: $_currentVersion\n'
        'ساخت: $_buildNumber\n'
        'تاریخ انتشار: $_lastUpdateDate\n'
        'حجم: $_appSize\n'
        'نصب: $_installCount\n'
        'امتیاز: $_rating از ۵ ($_ratingCount)';
  }

  /// دریافت متن کوتاه اطلاعات نسخه
  static String getShortVersionInfo() {
    return '$_currentVersion ($_installCount)';
  }
}

