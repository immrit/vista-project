import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionDebugService {
  static Future<void> logSessionStatus() async {
    if (!kDebugMode) return;

    const sep = '----------------------------------------';
    print(sep);
    print('SESSION DEBUG INFO');
    print(sep);

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = session.expiresAt ?? 0;
      final timeUntilExpiry = expiresAt - now;

      print('Session active');
      print('User: ${session.user.email}');
      print('User ID: ${session.user.id}');
      print('Created: ${session.user.createdAt}');
      print('Expires in: ${Duration(seconds: timeUntilExpiry).inMinutes} minutes');

      final accessToken = session.accessToken;
      final maskedAccess = accessToken.length > 10
          ? '${accessToken.substring(0, 6)}...${accessToken.substring(accessToken.length - 4)}'
          : '***';

      final refreshToken = session.refreshToken;
      final maskedRefresh = (refreshToken != null && refreshToken.length > 10)
          ? '${refreshToken.substring(0, 6)}...${refreshToken.substring(refreshToken.length - 4)}'
          : 'N/A';

      print('Access Token: $maskedAccess');
      print('Refresh Token: $maskedRefresh');
    } else {
      print('No active session');

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final authKeys = keys.where(
        (k) => k.contains('supabase') || k.contains('auth'),
      );

      print('Auth-related keys in storage:');
      for (final key in authKeys) {
        print(' - $key');
      }
    }

    print('$sep\n');
  }
}