import '../security/logging_utility.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingVersionKey = 'onboarding_version';
  static const String _currentOnboardingVersion = '1.0.0';

  /// بررسی اینکه آیا کاربر onboarding را تکمیل کرده است
  static Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
      final version = prefs.getString(_onboardingVersionKey) ?? '';

      // اگر نسخه onboarding تغییر کرده، دوباره نمایش داده شود
      if (isCompleted && version != _currentOnboardingVersion) {
        await _markOnboardingIncomplete();
        return false;
      }

      return isCompleted;
    } catch (e) {
      logInfo('Error checking onboarding status: $e');
      return false;
    }
  }

  /// علامت‌گذاری onboarding به عنوان تکمیل شده
  static Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      await prefs.setString(_onboardingVersionKey, _currentOnboardingVersion);
      logInfo('✅ Onboarding marked as completed');
    } catch (e) {
      logInfo('❌ Error marking onboarding as completed: $e');
    }
  }

  /// علامت‌گذاری onboarding به عنوان تکمیل نشده
  static Future<void> _markOnboardingIncomplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, false);
      logInfo('🔄 Onboarding marked as incomplete due to version change');
    } catch (e) {
      logInfo('❌ Error marking onboarding as incomplete: $e');
    }
  }

  /// ریست کردن وضعیت onboarding (برای تست)
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingCompletedKey);
      await prefs.remove(_onboardingVersionKey);
      logInfo('🔄 Onboarding status reset');
    } catch (e) {
      logInfo('❌ Error resetting onboarding status: $e');
    }
  }

  /// دریافت نسخه فعلی onboarding
  static String getCurrentVersion() {
    return _currentOnboardingVersion;
  }
}
