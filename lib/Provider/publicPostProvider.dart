import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:uuid/uuid.dart';

import 'appwriteProvider.dart';
import 'authProvider.dart';

// Provider های Appwrite
Future<List<Map<String, dynamic>>> fetchPostsWithProfiles(Ref ref) async {
  try {
    final database = ref.read(databasesProvider);

    final postsResponse = await database.listDocuments(
      databaseId: 'vista_db',
      collectionId: 'public_posts',
    );

    print("تعداد پست‌های دریافت شده: ${postsResponse.documents.length}");

    final postsWithProfiles = postsResponse.documents.map((post) {
      final userProfile = post.data['user_id'];

      return {
        'id': post.$id,
        'content': post.data['content'] ?? '',
        'createdAt': post.data['createdAt'],
        'username': userProfile['username'] ?? 'بدون نام',
        'full_name': userProfile['full_name'] ?? 'کاربر ناشناس',
        'avatar_url': userProfile['avatar_url'] ?? '',
        'userId': userProfile['userId'], // تغییر از $id به userId
      };
    }).toList();

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

//create post
class CreatePostNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  CreatePostNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> createPost({
    required String content,
  }) async {
    state = const AsyncValue.loading();

    try {
      final database = ref.read(databasesProvider);
      final userAsync = await ref.read(currentUserAccountProvider.future);

      // ساخت ID با فرمت جدید
      final now = DateTime.now();
      final String uniqueId =
          '${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}_${now.millisecond}';

      final result = await database.createDocument(
        databaseId: 'vista_db',
        collectionId: 'public_posts',
        documentId: uniqueId,
        data: {
          'content': content,
          'user_id': userAsync.$id,
          'createdAt': now.toIso8601String(),
        },
      );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      print("خطای ایجاد پست: $e");
      if (e is AppwriteException) {
        print("کد خطا: ${e.code}");
        print("پیام خطا: ${e.message}");
        print("نوع خطا: ${e.type}");
        // print("ID تولید شده: $uniqueId");
      }
      state = AsyncValue.error(e, st);
    }
  }
}

final createPostProvider =
    StateNotifierProvider<CreatePostNotifier, AsyncValue<void>>((ref) {
  return CreatePostNotifier(ref);
});
