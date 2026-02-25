import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../security/logging_utility.dart';

class ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final response = await _supabase.from('profiles').select('''
            *,
            verification_type,
            account_type,
            role
          ''').eq('id', userId).maybeSingle();

      if (response == null) {
        throw 'پروفایل کاربر یافت نشد';
      }
      return response;
    } catch (e) {
      logError('Fetch Profile Error', error: e);
      throw 'خطا در دریافت اطلاعات پروفایل';
    }
  }

  Future<void> updateProfile(
      String userId, Map<String, dynamic> updatedData) async {
    try {
      // 1. Sanitize the data to avoid sending 'null' or empty strings for critical fields.
      final sanitizedData = Map<String, dynamic>.from(updatedData);
      sanitizedData.removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) {
          // Keep empty strings for allowed fields like 'bio' if intended by your design,
          // but usually null/empty strings shouldn't overwrite existing valid data.
          // For now, if it's empty, we don't send it unless explicitly required.
          if (['username', 'email', 'full_name', 'phone_number']
              .contains(key)) {
            return true;
          }
        }
        return false;
      });

      if (sanitizedData.isEmpty) return;

      await _supabase.from('profiles').update(sanitizedData).eq('id', userId);
    } catch (e) {
      logError('Update Profile Error', error: e);
      throw 'خطا در بروزرسانی پروفایل';
    }
  }
}
