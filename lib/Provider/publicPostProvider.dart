import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

import 'appwriteProvider.dart';

// Provider های Appwrite
Future<List<Map<String, dynamic>>> fetchPostsWithProfiles(Ref ref) async {
  try {
    final database = ref.read(databasesProvider);

    // واکشی لیست پست‌ها
    final postsResponse = await database.listDocuments(
      databaseId: 'vista_db',
      collectionId: 'public_posts',
    );

    print("تعداد پست‌های دریافت شده: ${postsResponse.documents.length}");

    final posts = postsResponse.documents;

    // واکشی اطلاعات پروفایل برای هر پست
    final postsWithProfiles = await Future.wait<Map<String, dynamic>>(
      posts.map((post) async {
        print("داده‌های خام پست: ${post.data}"); // چاپ داده‌های پست

        // دریافت مستقیم پروفایل از کالکشن پروفایل‌ها
        try {
          final profilesResponse = await database.listDocuments(
            databaseId: 'vista_db',
            collectionId: '6759a45a0035156253ce',
            queries: [
              Query.limit(1),
            ],
          );

          print(
              "پاسخ پروفایل: ${profilesResponse.documents.first.data}"); // چاپ داده‌های پروفایل

          if (profilesResponse.documents.isNotEmpty) {
            final userProfile = profilesResponse.documents.first.data;

            return {
              'id': post.$id,
              'content': post.data['content'] ?? '',
              'createdAt': post.data['createdAt'],
              'username': userProfile['username'],
              'full_name': userProfile['full_name'],
              'avatar_url': userProfile['avatar_url'],
            };
          }
        } catch (e) {
          print("خطا در دریافت پروفایل: $e");
        }

        // مقادیر پیش‌فرض در صورت خطا
        return {
          'id': post.$id,
          'content': post.data['content'] ?? '',
          'createdAt': post.data['createdAt'],
          'username': 'Unknown',
          'full_name': 'Unknown User',
          'avatar_url': '',
        };
      }),
    );

    print("نتیجه نهایی: $postsWithProfiles"); // چاپ نتیجه نهایی
    return postsWithProfiles;
  } catch (e) {
    print("خطای اصلی: $e");
    throw Exception("Failed to fetch posts with profiles: $e");
  }
}

final postsWithProfilesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return fetchPostsWithProfiles(ref);
});
