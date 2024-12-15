import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/models.dart';

import 'appwriteProvider.dart';

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
  return AuthStateNotifier();
});

class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthStateNotifier() : super(const AsyncValue.data(null));

  // Example method to check current auth state
  Future<void> checkAuthState() async {
    // Add your logic here to check if a user is authenticated
    try {
      // Replace with actual Appwrite API logic to check user session
      final user = await fetchCurrentUser();
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<User?> fetchCurrentUser() async {
    // Placeholder for fetching the current user logic
    // Return User object if authenticated
    return null; // Replace with real user or null if not authenticated
  }
}

final isRedirectingProvider = StateProvider<bool>((ref) {
  return false; // Default initial value
});

final isLoadingProvider = StateProvider<bool>((ref) {
  return false; // مقدار ابتدایی، نشان‌دهنده این است که در حال بارگذاری نیست
});

// get the current user

final currentUserAccountProvider = FutureProvider<User>((ref) async {
  final account = ref.watch(accountProvider);
  try {
    final user = await account.get();
    return user;
  } catch (e) {
    throw Exception('خطا در دریافت اطلاعات کاربر');
  }
});

final currentUserIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(currentUserAccountProvider);
  return userAsync.whenData((user) => user.$id).value;
});
