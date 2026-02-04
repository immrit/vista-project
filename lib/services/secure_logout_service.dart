import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/data/cache/cache_repository.dart';
import '../features/auth/screens/auth_wizard_screen.dart';
import '../security/logging_utility.dart';
import '../security/secure_kv_store.dart';
import 'advanced_security_service.dart';
import 'session_manager_service_v2.dart';

/// Service responsible for securely logging out the user and wiping all local data.
class SecureLogoutService {
  /// Performs a complete secure logout.
  ///
  /// 1. Stops background services.
  /// 2. Wipes Isar database.
  /// 3. Clears SharedPreferences.
  /// 4. Clears File Cache (flutter_cache_manager).
  /// 5. Signs out from Supabase (Server Sided).
  /// 6. Navigates to AuthScreen.
  static Future<void> performLogout(BuildContext context, WidgetRef ref) async {
    logInfo('🔒 Starting Secure Logout sequence...');

    try {
      // 1. Stop background services & Release resources
      // Add any specific service stopping logic here if needed (e.g. DownloadManager)

      // 2. Wipe Database (Critical)
      await CacheRepository().wipeAllData();

      // 3. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      logInfo('✅ SharedPreferences cleared.');

      // 3.1 Clear Secure Storage (tokens/keys)
      try {
        await SecureKeyValueStore.deleteAll();
        await AdvancedSecurityService.clearAllSecurityData();
        logInfo('✅ Secure storage cleared.');
      } catch (e) {
        logWarning('⚠️ Failed to clear secure storage', error: e);
      }

      // 4. Clear File Cache
      try {
        await DefaultCacheManager().emptyCache();
        logInfo('✅ DefaultCacheManager cleared.');
      } catch (e) {
        logWarning('⚠️ Failed to clear DefaultCacheManager', error: e);
      }

      // 5. Backend Logout & Session Termination
      // SessionManagerV2 handles hard delete from server
      await SessionManagerServiceV2().userLogout();
      // Note: userLogout internally calls supabase.auth.signOut(),
      // but we call it explicitly just in case SessionManager fails locally.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      logInfo('✅ Secure Logout completed successfully.');

      // 6. Navigation
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWizardScreen()),
          (route) => false,
        );
      }
    } catch (e, stack) {
      logError('❌ CRITICAL ERROR during Secure Logout',
          error: e, stackTrace: stack);

      // Attempt to force navigation even if something failed
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWizardScreen()),
          (route) => false,
        );
      }
    }
  }
}
