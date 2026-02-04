import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionDebugService {
  static Future<void> logSessionStatus() async {
    if (!kDebugMode) return;
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 SESSION DEBUG INFO');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = session.expiresAt ?? 0;
      final timeUntilExpiry = expiresAt - now;

      print('�... Session Active');
      print('👤 User: ${session.user.email}');
      print('🆔 User ID: ${session.user.id}');
      print('�... Created: ${session.user.createdAt}');
      print(
          '⏰ Expires in: ${Duration(seconds: timeUntilExpiry).inMinutes} minutes');
      final token = session.accessToken;
      final maskedAccess = token.length > 10
          ? '${token.substring(0, 6)}...${token.substring(token.length - 4)}'
          : '***';
      final refresh = session.refreshToken;
      final maskedRefresh = (refresh != null && refresh.length > 10)
          ? '${refresh.substring(0, 6)}...${refresh.substring(refresh.length - 4)}'
          : 'N/A';
      print('🔑 Access Token: $maskedAccess');
      print('🔄 Refresh Token: $maskedRefresh');
    } else {
      print('❌ No Active Session');

      // بررسی SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final authKeys =
          keys.where((k) => k.contains('supabase') || k.contains('auth'));

      print('🔍 Auth-related keys in storage:');
      for (var key in authKeys) {
        print('  - $key');
      }
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}


