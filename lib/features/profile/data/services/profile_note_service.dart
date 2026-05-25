import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../security/logging_utility.dart';
import '../../../auth/providers/auth_controller.dart';
import '../models/profile_note_model.dart';

/// سرویس مدیریت وضعیت پروفایل
class ProfileNoteService {
  static String get _backendUrl =>
      EnvConfig.apiBaseUrl ?? 'http://10.0.2.2:8080';

  late final Dio _dio;

  ProfileNoteService() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_backendUrl/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw 'User is not logged in';
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// دریافت وضعیت فعال یک کاربر
  Future<ProfileNoteModel?> getActiveNote(String userId) async {
    try {
      final storedUserId = await TokenStorage.getUserId();
      final isSelf = storedUserId == userId;

      // فعلا برای سادگی فرض می‌کنیم برای کاربر خودش را می‌گیرد،
      // اما اگر بخواهیم یادداشت دیگران را بگیریم نیاز به route جدید داریم.
      // با توجه به کدهای قبلی که get_active_profile_note داشتیم، الان فقط me را داریم.
      // بنابراین برای BatchGet استفاده می‌کنیم یا از مسیر /me/note.

      if (!isSelf) {
        final notes = await getNotesForUsers([userId]);
        return notes[userId];
      }

      final response = await _dio.get(
        '/me/note',
        options: await _authOptions(),
      );

      if (response.data == null) return null;
      return ProfileNoteModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // یادداشتی یافت نشد
      }
      logError('Get Active Note Error', error: e);
      return null;
    } catch (e) {
      logError('Get Active Note Error', error: e);
      return null;
    }
  }

  /// ایجاد یا بروزرسانی وضعیت
  Future<ProfileNoteModel?> upsertNote(String content) async {
    if (content.isEmpty || content.length > 60) {
      throw Exception('محتوای یادداشت باید بین ۱ تا ۶۰ کاراکتر باشد');
    }

    try {
      final response = await _dio.post(
        '/me/note',
        data: {'content': content},
        options: await _authOptions(),
      );

      if (response.data == null) return null;
      return ProfileNoteModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      logError('Upsert Note Error', error: e);
      return null;
    }
  }

  /// حذف وضعیت کاربر فعلی
  Future<void> deleteNote() async {
    try {
      await _dio.delete(
        '/me/note',
        options: await _authOptions(),
      );
    } catch (e) {
      logError('Delete Note Error', error: e);
    }
  }

  /// دریافت وضعیت چند کاربر (برای نمایش در لیست)
  Future<Map<String, ProfileNoteModel>> getNotesForUsers(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      final response = await _dio.post(
        '/profiles/notes/batch',
        data: {'user_ids': userIds},
        options: await _authOptions(),
      );

      final notes = <String, ProfileNoteModel>{};
      final dataMap = response.data as Map<String, dynamic>;

      for (final key in dataMap.keys) {
        notes[key] =
            ProfileNoteModel.fromJson(dataMap[key] as Map<String, dynamic>);
      }
      return notes;
    } catch (e) {
      logError('Batch Get Notes Error', error: e);
      return {};
    }
  }
}

/// Provider برای سرویس وضعیت پروفایل
final profileNoteServiceProvider = Provider<ProfileNoteService>((ref) {
  return ProfileNoteService();
});
