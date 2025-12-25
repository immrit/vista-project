// lib/provider/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_api_service.dart';

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

// کلاس Notifier برای مدیریت منطق
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _apiService;

  AuthNotifier(this._apiService) : super(AuthState());

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _apiService.sendOtp(phone);
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
      await _apiService.verifyOtp(phone, token, isUpdateMode: isUpdateMode);

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

// تعریف نهایی پروایدر که در editeProfile.dart استفاده شده
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthApiService());
});
