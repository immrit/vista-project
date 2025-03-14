import 'dart:io';
import 'package:path/path.dart';
import '/main.dart';
import '/model/MusicModel.dart';

class MusicService {
  static const _bucketName = 'music-files';
  static const _coverBucketName = 'music-covers';

  // آپلود فایل موزیک
  Future<String> uploadMusic(File file) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}';
      final response = await supabase.storage
          .from(_bucketName)
          .upload('public/$fileName', file);

      final String musicUrl =
          supabase.storage.from(_bucketName).getPublicUrl('public/$fileName');

      return musicUrl;
    } catch (e) {
      throw Exception('خطا در آپلود موزیک: $e');
    }
  }

  // آپلود کاور موزیک
  Future<String?> uploadCover(File file) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}';
      final response = await supabase.storage
          .from(_coverBucketName)
          .upload('public/$fileName', file);

      final String coverUrl = supabase.storage
          .from(_coverBucketName)
          .getPublicUrl('public/$fileName');

      return coverUrl;
    } catch (e) {
      print('خطا در آپلود کاور: $e');
      return null;
    }
  }

  // انتشار موزیک جدید
  Future<MusicModel> publishMusic({
    required String title,
    required String artist,
    required String musicUrl,
    String? coverUrl,
    required List<String> genres,
  }) async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('music')
          .insert({
            'user_id': userId,
            'title': title,
            'artist': artist,
            'music_url': musicUrl,
            'cover_url': coverUrl,
            'genres': genres,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('*, profiles(*)')
          .single();

      return MusicModel.fromMap(response);
    } catch (e) {
      throw Exception('خطا در انتشار موزیک: $e');
    }
  }

  // دریافت لیست موزیک‌ها
  Future<List<MusicModel>> fetchMusics({int limit = 20, int offset = 0}) async {
    try {
      final response = await supabase
          .from('music')
          .select('*, profiles(*)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((data) => MusicModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت موزیک‌ها: $e');
    }
  }

  // افزایش تعداد پخش
  Future<void> incrementPlayCount(String musicId) async {
    try {
      // تغییر از rpc به update مستقیم
      await supabase
          .from('music')
          .update({'play_count': supabase.rpc('increment')}).eq('id', musicId);
    } catch (e) {
      print('خطا در افزایش تعداد پخش: $e');
      // عدم throw خطا برای جلوگیری از توقف پخش موزیک
    }
  }
}
