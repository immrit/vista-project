import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appwriteProvider.dart';

final authProvider = Provider((ref) {
  return AuthService(ref);
});

class AuthService {
  final Ref ref;
  late final Account account;

  AuthService(this.ref) {
    final client = ref.read(appwriteClientProvider);
    account = Account(client);
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
      );
    } catch (e) {
      print(e);
      throw Exception('خطا در ثبت‌نام: $e');
    }
  }
}
