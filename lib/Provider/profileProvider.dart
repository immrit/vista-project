import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appwriteProvider.dart';
import 'authProvider.dart';

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final databases = ref.read(databasesProvider);
  final currentUser = ref.watch(authStateProvider).when(
        data: (user) => user,
        loading: () => null,
        error: (err, stack) => null,
      );

  if (currentUser == null) {
    throw Exception('User is not logged in');
  }

  try {
    // دریافت سند پروفایل از دیتابیس
    final response = await databases.getDocument(
      databaseId: 'vista_db', // آیدی دیتابیس خود را وارد کنید
      collectionId: 'profiles', // آیدی مجموعه پروفایل‌ها
      documentId: currentUser.$id, // شناسه کاربر
    );

    return response.data; // داده‌های پروفایل کاربر را باز می‌گرداند
  } catch (e) {
    throw Exception('Profile not found: $e');
  }
});
