import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

// سیستم لاگ گذاری
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

class ProfileService {
  static final supabase = Supabase.instance.client;

  /// دریافت پروفایل کاربر از جدول profiles
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      logger.d('شروع دریافت پروفایل برای کاربر: $userId');

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      logger.d('پاسخ دریافت پروفایل: ${response}');
      return response;
    } on PostgrestException catch (e) {
      // اگر کاربر جدید است و هنوز در جدول profiles نیست
      if (e.code == 'PGRST116') {
        logger.i('کاربر جدید است و هیچ رکوردی در پروفایل ندارد');
        return null;
      }
      logger.e('خطای Postgrest در دریافت پروفایل ${e.message}');
      throw 'خطا در دریافت اطلاعات پروفایل: ${e.message}';
    } catch (e) {
      logger.e('$e خطای عمومی در دریافت پروفایل');
      throw 'خطا در دریافت اطلاعات پروفایل: $e';
    }
  }

  /// ایجاد یا به‌روزرسانی پروفایل کاربر
  static Future<void> upsertProfile(Map<String, dynamic> updates) async {
    try {
      logger.d(
        'شروع ذخیره‌سازی/بروزرسانی پروفایل با داده: $updates',
      );

      // تبدیل کلیدها به فرمت snake_case برای پایگاه داده
      final payload = {
        ...updates,
        // اطمینان از وجود کلیدهای ضروری
        'id': updates['id'],
        'username': updates['username'],
        'full_name': updates['full_name'],
        'bio': updates['bio'] ?? '',
        'birth_date': updates['birth_date'] ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from('profiles')
          .upsert(payload)
          .timeout(const Duration(seconds: 10));

      logger.i('پروفایل با موفقیت ذخیره شد');
      return;
    } on PostgrestException catch (e) {
      logger.e('خطای Postgrest در ذخیره‌سازی پروفایل ${e.message}');

      // بررسی خطاهای رایج
      if (e.code == '23505') {
        throw 'نام کاربری قبلاً انتخاب شده است. لطفاً نام کاربری دیگری را امتحان کنید.';
      }

      throw 'خطا در ذخیره پروفایل: ${e.message}';
    } catch (e) {
      logger.e(
        '$e خطای عمومی در ذخیره‌سازی پروفایل',
      );
      throw 'خطا در ذخیره پروفایل: $e';
    }
  }

  /// بروزرسانی تصویر پروفایل
  static Future<void> updateAvatar(String userId, String avatarUrl) async {
    try {
      logger.d(
          'شروع بروزرسانی تصویر پروفایل برای کاربر: $userId با URL: $avatarUrl');

      await supabase
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId)
          .timeout(const Duration(seconds: 10));

      logger.i('تصویر پروفایل با موفقیت به‌روزرسانی شد');
      return;
    } catch (e) {
      logger.e('$e خطا در بروزرسانی تصویر پروفایل');
      throw 'خطا در به‌روزرسانی تصویر پروفایل: $e';
    }
  }

  /// بررسی کامل بودن پروفایل
  static Future<bool> isProfileComplete(String userId) async {
    try {
      logger.d('بررسی تکمیل بودن پروفایل برای کاربر: $userId');

      final profile = await getProfile(userId);
      final isComplete = profile != null &&
          profile['username'] != null &&
          profile['username'].toString().isNotEmpty &&
          profile['full_name'] != null &&
          profile['full_name'].toString().isNotEmpty;

      logger.d('نتیجه بررسی تکمیل پروفایل: $isComplete');
      return isComplete;
    } catch (e) {
      logger.e('$e خطا در بررسی تکمیل پروفایل');
      return false;
    }
  }
}
