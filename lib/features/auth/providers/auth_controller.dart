import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

// وضعیت (State) برای مدیریت لاگین و OTP
class AuthState {
  final bool isLoading;
  final String? error;
  final bool codeSent;
  final bool isLoggedIn;

  AuthState({
    this.isLoading = false,
    this.error,
    this.codeSent = false,
    this.isLoggedIn = false,
  });

  AuthState copyWith(
      {bool? isLoading, String? error, bool? codeSent, bool? isLoggedIn}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // اگر نال پاس داده شود، ارور پاک می‌شود
      codeSent: codeSent ?? this.codeSent,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

// کلاس Controller (Notifier) برای مدیریت منطق احراز هویت
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(AuthState());

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _repository.sendOtp(phone);
      if (success) {
        state = state.copyWith(isLoading: false, codeSent: true);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'ارسال ناموفق بود');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp(
      {required String phone,
      required String token,
      bool isUpdateMode = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.verifyOtp(phone, token, isUpdateMode: isUpdateMode);

      if (!isUpdateMode) {
        state = state.copyWith(isLoading: false, isLoggedIn: true);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

// پروایدر اصلی کنترلر احراز هویت
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(AuthRepository());
});

// پروایدرهای استریم و وضعیت فعلی کاربر (انتقال یافته از provider.dart)
final userAuthStateProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session?.user);
});

// پروایدر تغییر رمزعبور
final changePasswordProvider =
    FutureProvider.family<void, String>((ref, newPassword) async {
  try {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  } catch (e) {
    throw 'خطا در تغییر رمز عبور';
  }
});

final authProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});
