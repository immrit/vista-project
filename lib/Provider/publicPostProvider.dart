import 'dart:io';

import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:path/path.dart' as path;
import 'appwriteProvider.dart';
import 'authProvider.dart';

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

// اضافه کردن متد جدید برای مدیریت لایک‌ها
Future<List<Map<String, dynamic>>> fetchPostsWithProfiles(Ref ref) async {
  try {
    final database = ref.read(databasesProvider);
    final currentUser = await ref.read(currentUserAccountProvider.future);

    final postsResponse = await database.listDocuments(
      databaseId: 'vista_db',
      collectionId: 'public_posts',
    );

    // دریافت لایک‌های کاربر فعلی
    final userLikes = await database.listDocuments(
      databaseId: 'vista_db',
      collectionId: 'post_likes',
      queries: [
        Query.equal('user_id', currentUser.$id),
      ],
    );

    // ساخت مپ از پست‌های لایک شده
    final likedPosts = Map.fromEntries(
      userLikes.documents.map((doc) => MapEntry(doc.data['post_id'], true)),
    );

    final postsWithProfiles = postsResponse.documents.map((post) {
      final userProfile = post.data['user_id'];

      return {
        'id': post.$id,
        'content': post.data['content'] ?? '',
        'createdAt': post.data['createdAt'],
        'username': userProfile['username'] ?? 'بدون نام',
        'full_name': userProfile['full_name'] ?? 'کاربر ناشناس',
        'avatar_url': userProfile['avatar_url'] ?? '',
        'userId': userProfile['userId'],
        'likeCount': post.data['like_count'] ?? 0,
        'isLiked': likedPosts[post.$id] ?? false,
      };
    }).toList();

    return postsWithProfiles;
  } catch (e) {
    print("خطا: $e");
    throw Exception("خطا در دریافت پست‌ها: $e");
  }
}

// پروایدر جدید برای مدیریت لایک‌ها
class LikePostNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  LikePostNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> toggleLike(String postId) async {
    try {
      final database = ref.read(databasesProvider);
      final currentUser = await ref.read(currentUserAccountProvider.future);

      // چک کردن وجود لایک
      final likes = await database.listDocuments(
        databaseId: 'vista_db',
        collectionId: 'post_likes',
        queries: [
          Query.equal('post_id', postId),
          Query.equal('user_id', currentUser.$id),
        ],
      );

      // دریافت پست فعلی برای گرفتن تعداد لایک‌های فعلی
      final post = await database.getDocument(
        databaseId: 'vista_db',
        collectionId: 'public_posts',
        documentId: postId,
      );

      final currentLikeCount = post.data['like_count'] ?? 0;

      if (likes.documents.isEmpty) {
        // افزودن لایک
        await database.createDocument(
          databaseId: 'vista_db',
          collectionId: 'post_likes',
          documentId: ID.unique(),
          data: {
            'post_id': postId,
            'user_id': currentUser.$id,
            'created_at': DateTime.now().toIso8601String(),
          },
        );

        // افزایش تعداد لایک‌ها
        await database.updateDocument(
          databaseId: 'vista_db',
          collectionId: 'public_posts',
          documentId: postId,
          data: {
            'like_count': currentLikeCount + 1,
          },
        );
      } else {
        // حذف لایک
        await database.deleteDocument(
          databaseId: 'vista_db',
          collectionId: 'post_likes',
          documentId: likes.documents.first.$id,
        );

        // کاهش تعداد لایک‌ها
        await database.updateDocument(
          databaseId: 'vista_db',
          collectionId: 'public_posts',
          documentId: postId,
          data: {
            'like_count': currentLikeCount - 1,
          },
        );
      }

      // بروزرسانی لیست پست‌ها
      ref.refresh(postsWithProfilesProvider);
    } catch (e) {
      print("خطا در لایک/آنلایک: $e");
      throw Exception(e);
    }
  }
}

final likePostProvider =
    StateNotifierProvider<LikePostNotifier, AsyncValue<void>>((ref) {
  return LikePostNotifier(ref);
});

class ImageUploadService {
  static final s3 = S3(
    region: 'default', // منطقه پیش‌فرض لیارا
    credentials: AwsClientCredentials(
        accessKey: '0tomnmstnnlt47dd',
        secretKey: '1f1107c2-f14f-4a98-9045-31dbcd4befe4'),
    endpointUrl: 'https://storage.c2.liara.space', // آدرس استوریج لیارا
  );

  static const String bucketName = 'coffevista';

  // آپلود فایل و دریافت URL
  static Future<String?> uploadImage(File file) async {
    try {
      final fileName =
          'avatars/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';

      await s3.putObject(
        bucket: bucketName,
        key: fileName,
        body: await file.readAsBytes(),
        contentType: 'image/jpeg',
      );

      return 'https://storage.c2.liara.space/$bucketName/$fileName';
    } catch (e) {
      print('خطا در آپلود فایل: $e');
      return null;
    }
  }

  // حذف فایل
  static Future<bool> deleteImage(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key =
          uri.pathSegments.sublist(1).join('/'); // حذف بخش اول که نام باکت است

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      return true;
    } catch (e) {
      print('خطا در حذف فایل: $e');
      return false;
    }
  }
}
