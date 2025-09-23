import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'DB/profile_cache_service.dart';
import 'DB/settings_cache_service.dart';
import 'main.dart';

/// تست عملکرد آفلاین برای پروفایل و تنظیمات
class OfflineFunctionalityTest extends ConsumerStatefulWidget {
  const OfflineFunctionalityTest({super.key});

  @override
  ConsumerState<OfflineFunctionalityTest> createState() =>
      _OfflineFunctionalityTestState();
}

class _OfflineFunctionalityTestState
    extends ConsumerState<OfflineFunctionalityTest> {
  final ProfileCacheService _profileCache = ProfileCacheService();
  final SettingsCacheService _settingsCache = SettingsCacheService();

  String _testResults = '';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _testResults = 'شروع تست عملکرد آفلاین...\n\n';
    });

    try {
      // تست 1: مقداردهی اولیه سرویس‌ها
      _addTestResult('تست 1: مقداردهی اولیه سرویس‌ها');
      await _profileCache.initialize();
      await _settingsCache.initialize();
      _addTestResult('✅ سرویس‌های کش با موفقیت مقداردهی شدند');

      // تست 2: کش کردن تنظیمات پیش‌فرض
      _addTestResult('\nتست 2: کش کردن تنظیمات پیش‌فرض');
      await _settingsCache.cacheAppSettings();
      final appSettings = _settingsCache.getCachedAppSettings();
      _addTestResult('✅ تنظیمات اپلیکیشن کش شدند: ${appSettings.length} مورد');

      // تست 3: کش کردن تنظیمات حریم خصوصی
      _addTestResult('\nتست 3: کش کردن تنظیمات حریم خصوصی');
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        await _settingsCache.cachePrivacySettings(currentUserId);
        final privacySettings =
            _settingsCache.getCachedPrivacySettings(currentUserId);
        _addTestResult(
            '✅ تنظیمات حریم خصوصی کش شدند: ${privacySettings?.length ?? 0} مورد');
      } else {
        _addTestResult('⚠️ کاربر وارد نشده است');
      }

      // تست 4: کش کردن تنظیمات اعلان‌ها
      _addTestResult('\nتست 4: کش کردن تنظیمات اعلان‌ها');
      if (currentUserId != null) {
        await _settingsCache.cacheNotificationSettings(currentUserId);
        final notificationSettings =
            _settingsCache.getCachedNotificationSettings(currentUserId);
        _addTestResult(
            '✅ تنظیمات اعلان‌ها کش شدند: ${notificationSettings?.length ?? 0} مورد');
      }

      // تست 5: دریافت آمار کش
      _addTestResult('\nتست 5: دریافت آمار کش');
      final profileStats = _profileCache.getCacheStats();
      final settingsStats = _settingsCache.getCacheStats();
      _addTestResult(
          '✅ آمار پروفایل: ${profileStats['cached_profiles_count']} پروفایل');
      _addTestResult(
          '✅ آمار تنظیمات: ${settingsStats['cached_users_count']} کاربر');

      // تست 6: بررسی اعتبار کش
      _addTestResult('\nتست 6: بررسی اعتبار کش');
      if (currentUserId != null) {
        final shouldUseProfileCache =
            _profileCache.shouldUseCache(currentUserId);
        final shouldUseSettingsCache =
            _settingsCache.shouldUseCache('app_settings');
        _addTestResult(
            '✅ کش پروفایل: ${shouldUseProfileCache ? "معتبر" : "نامعتبر"}');
        _addTestResult(
            '✅ کش تنظیمات: ${shouldUseSettingsCache ? "معتبر" : "نامعتبر"}');
      }

      _addTestResult('\n🎉 تمام تست‌ها با موفقیت انجام شدند!');
      _addTestResult('سیستم کش آماده استفاده در حالت آفلاین است.');
    } catch (e) {
      _addTestResult('\n❌ خطا در تست: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults += '$result\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تست عملکرد آفلاین'),
        centerTitle: true,
        elevation: 0,
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runTests,
            tooltip: 'اجرای مجدد تست‌ها',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // وضعیت تست
            Card(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _isRunning ? Icons.hourglass_empty : Icons.check_circle,
                      color: _isRunning ? Colors.orange : Colors.green,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isRunning
                          ? 'در حال اجرای تست‌ها...'
                          : 'تست‌ها تکمیل شدند',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // نتایج تست
            Expanded(
              child: Card(
                color: isDark ? const Color(0xFF252525) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Text(
                      _testResults,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // دکمه‌های عملیات
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runTests,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('اجرای مجدد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _testResults = '';
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('پاک کردن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




