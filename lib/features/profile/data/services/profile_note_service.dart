import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_note_model.dart';

/// سرویس مدیریت وضعیت پروفایل
class ProfileNoteService {
  final SupabaseClient _supabase;

  ProfileNoteService(this._supabase);

  /// دریافت وضعیت فعال یک کاربر
  Future<ProfileNoteModel?> getActiveNote(String userId) async {
    try {
      final response = await _supabase
          .rpc('get_active_profile_note', params: {'p_user_id': userId});

      if (response == null || (response as List).isEmpty) {
        return null;
      }

      return ProfileNoteModel.fromJson(response[0] as Map<String, dynamic>);
    } catch (e) {
      // اگر تابع RPC وجود نداشت، از کوئری مستقیم استفاده کن
      try {
        final response = await _supabase
            .from('profile_notes')
            .select()
            .eq('user_id', userId)
            .gt('expires_at', DateTime.now().toIso8601String())
            .maybeSingle();

        if (response == null) return null;
        return ProfileNoteModel.fromJson(response);
      } catch (e2) {
        return null;
      }
    }
  }

  /// ایجاد یا بروزرسانی وضعیت
  Future<ProfileNoteModel?> upsertNote(String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // اعتبارسنجی طول محتوا
    if (content.isEmpty || content.length > 60) {
      throw Exception('Content must be between 1 and 60 characters');
    }

    try {
      // سعی کن از تابع RPC استفاده کنی
      final response = await _supabase.rpc(
        'upsert_profile_note',
        params: {
          'p_user_id': userId,
          'p_content': content,
        },
      );

      if (response == null || (response as List).isEmpty) {
        return null;
      }

      return ProfileNoteModel.fromJson(response[0] as Map<String, dynamic>);
    } catch (e) {
      // اگر تابع RPC وجود نداشت، از upsert مستقیم استفاده کن
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      final response = await _supabase
          .from('profile_notes')
          .upsert(
            {
              'user_id': userId,
              'content': content,
              'created_at': DateTime.now().toIso8601String(),
              'expires_at': expiresAt.toIso8601String(),
            },
            onConflict: 'user_id',
          )
          .select()
          .single();

      return ProfileNoteModel.fromJson(response);
    }
  }

  /// حذف وضعیت کاربر فعلی
  Future<void> deleteNote() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _supabase.rpc('delete_profile_note', params: {'p_user_id': userId});
    } catch (e) {
      // اگر تابع RPC وجود نداشت، از delete مستقیم استفاده کن
      await _supabase.from('profile_notes').delete().eq('user_id', userId);
    }
  }

  /// دریافت وضعیت چند کاربر (برای نمایش در لیست)
  Future<Map<String, ProfileNoteModel>> getNotesForUsers(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      final response = await _supabase
          .from('profile_notes')
          .select()
          .inFilter('user_id', userIds)
          .gt('expires_at', DateTime.now().toIso8601String());

      final notes = <String, ProfileNoteModel>{};
      for (final row in response as List) {
        final note = ProfileNoteModel.fromJson(row as Map<String, dynamic>);
        notes[note.userId] = note;
      }
      return notes;
    } catch (e) {
      return {};
    }
  }
}

/// Provider برای سرویس وضعیت پروفایل
final profileNoteServiceProvider = Provider<ProfileNoteService>((ref) {
  return ProfileNoteService(Supabase.instance.client);
});
