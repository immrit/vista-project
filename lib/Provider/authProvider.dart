import 'package:flutter_riverpod/flutter_riverpod.dart';

// final authProvider = Provider((ref) {
//   return AuthService(ref);
// });

// class AuthService {
//   final Ref ref;
//   late final Account account;

//   AuthService(this.ref) {
//     final client = ref.read(appwriteClientProvider);
//     account = Account(client);
//   }

//   Future<void> signUp({
//     required String email,
//     required String password,
//   }) async {
//     try {
//       await account.create(
//         userId: ID.unique(),
//         email: email,
//         password: password,
//       );
//     } catch (e) {
//       print(e);
//       throw Exception('خطا در ثبت‌نام: $e');
//     }
//   }
// }

import 'package:appwrite/models.dart';

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
