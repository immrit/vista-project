import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// سرویس مدیریت امنیت و احراز هویت کاربران
class SecurityProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isAuthenticated = false;
  User? _currentUser;
  bool _isLoading = false;
  String? _lastError;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  // ============================================================================
  // بخش اصلی: مدیریت احراز هویت
  // ============================================================================

  /// ورود کاربر با ایمیل و رمز عبور
  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      _setLoading(true);

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _currentUser = response.user;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('خطا در ورود: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// خروج کاربر
  Future<bool> signOut() async {
    try {
      _setLoading(true);
      await _supabase.auth.signOut();

      _currentUser = null;
      _isAuthenticated = false;

      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('خطا در خروج: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// بررسی وضعیت احراز هویت
  Future<void> checkAuthStatus() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session?.user != null) {
        _currentUser = session!.user;
        _isAuthenticated = true;
      } else {
        _currentUser = null;
        _isAuthenticated = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('خطا در بررسی وضعیت احراز هویت: $e');
    }
  }

// ============================================================================
  // بخش کمکی: توابع داخلی
// ============================================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// تمیز کردن خطاها
  void clearErrors() {
    _lastError = null;
    notifyListeners();
  }

// ============================================================================
  // بخش جدید: مدیریت کاربران مسدود شده
// ============================================================================

  /// دریافت تعداد کاربران مسدود شده
  Future<int> getBlockedUsersCount() async {
    try {
      if (_currentUser == null) return 0;

      final response = await _supabase
          .from('blocked_users')
          .select('id')
          .eq('user_id', _currentUser!.id);

      return response.length;
    } catch (e) {
      debugPrint('خطا در دریافت تعداد کاربران مسدود شده: $e');
      return 0;
    }
  }

  /// بررسی اینکه آیا کاربر مسدود شده است
  Future<bool> isUserBlocked(String userId) async {
    try {
      if (_currentUser == null) return false;

      final response = await _supabase
          .from('blocked_users')
          .select('id')
          .eq('user_id', _currentUser!.id)
          .eq('blocked_user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('خطا در بررسی وضعیت مسدودیت کاربر: $e');
      return false;
    }
  }
}

// Provider برای مدیریت امنیت
final securityProvider = ChangeNotifierProvider<SecurityProvider>((ref) {
  return SecurityProvider();
});

// Provider برای وضعیت احراز هویت فعلی
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Provider برای کاربر فعلی
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (authState) => authState.session?.user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Provider برای تعداد کاربران مسدود شده
final blockedUsersCountProvider = FutureProvider<int>((ref) async {
  final securityNotifier = ref.read(securityProvider.notifier);
  return await securityNotifier.getBlockedUsersCount();
});
