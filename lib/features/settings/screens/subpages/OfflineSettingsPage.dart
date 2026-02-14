import '../../../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../DB/settings_cache_service.dart';
import '../../../../utils/const.dart';

/// صفحه تنظیمات آفلاین که بدون نیاز به اینترنت کار می‌کند
class OfflineSettingsPage extends ConsumerStatefulWidget {
  const OfflineSettingsPage({super.key});

  @override
  ConsumerState<OfflineSettingsPage> createState() =>
      _OfflineSettingsPageState();
}

class _OfflineSettingsPageState extends ConsumerState<OfflineSettingsPage> {
  final SettingsCacheService _settingsCache = SettingsCacheService();
  bool _isLoading = true;
  Map<String, dynamic> _appSettings = {};
  Map<String, dynamic> _privacySettings = {};
  Map<String, dynamic> _notificationSettings = {};

  @override
  void initState() {
    super.initState();
    _loadOfflineSettings();
  }

  Future<void> _loadOfflineSettings() async {
    try {
      setState(() => _isLoading = true);

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }

      // بارگذاری تنظیمات از کش
      _appSettings = _settingsCache.getCachedAppSettings();
      _privacySettings =
          _settingsCache.getCachedPrivacySettings(currentUserId) ?? {};
      _notificationSettings =
          _settingsCache.getCachedNotificationSettings(currentUserId) ?? {};

      setState(() => _isLoading = false);
    } catch (e) {
      logInfo('⚠️ Failed to load offline settings: $e');
      setState(() => _isLoading = false);

      // نمایش پیام خطا
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در بارگذاری تنظیمات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تنظیمات آفلاین'),
        centerTitle: true,
        elevation: 0,
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOfflineSettings,
            tooltip: 'به‌روزرسانی',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOfflineSettings,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // وضعیت آفلاین
                  _buildOfflineStatusCard(isDark, colorScheme),

                  const SizedBox(height: 20),

                  // تنظیمات اپلیکیشن
                  _buildAppSettingsSection(isDark, colorScheme),

                  const SizedBox(height: 20),

                  // تنظیمات حریم خصوصی
                  _buildPrivacySettingsSection(isDark, colorScheme),

                  const SizedBox(height: 20),

                  // تنظیمات اعلان‌ها
                  _buildNotificationSettingsSection(isDark, colorScheme),

                  const SizedBox(height: 20),

                  // آمار کش
                  _buildCacheStatsSection(isDark, colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildOfflineStatusCard(bool isDark, ColorScheme colorScheme) {
    return Card(
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'حالت آفلاین',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'این تنظیمات از کش محلی بارگذاری شده‌اند و بدون نیاز به اینترنت قابل دسترسی هستند.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettingsSection(bool isDark, ColorScheme colorScheme) {
    return Card(
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تنظیمات اپلیکیشن',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              'تم',
              _appSettings['theme'] ?? 'system',
              Icons.palette,
              isDark,
            ),
            _buildSettingItem(
              'زبان',
              _appSettings['language'] ?? 'fa',
              Icons.language,
              isDark,
            ),
            _buildSettingItem(
              'پخش خودکار ویدیو',
              _appSettings['auto_play_videos'] == true ? 'فعال' : 'غیرفعال',
              Icons.play_circle,
              isDark,
            ),
            _buildSettingItem(
              'دانلود خودکار رسانه',
              _appSettings['auto_download_media'] == true ? 'فعال' : 'غیرفعال',
              Icons.download,
              isDark,
            ),
            _buildSettingItem(
              'حداکثر حجم کش',
              '${_appSettings['max_cache_size_mb'] ?? 200} مگابایت',
              Icons.storage,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettingsSection(bool isDark, ColorScheme colorScheme) {
    return Card(
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تنظیمات حریم خصوصی',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              'حساب خصوصی',
              _privacySettings['is_private'] == true ? 'فعال' : 'غیرفعال',
              Icons.lock,
              isDark,
            ),
            _buildSettingItem(
              'نمایش وضعیت آنلاین',
              _privacySettings['show_online_status'] == true
                  ? 'فعال'
                  : 'غیرفعال',
              Icons.online_prediction,
              isDark,
            ),
            _buildSettingItem(
              'اجازه درخواست پیام',
              _privacySettings['allow_message_requests'] == true
                  ? 'فعال'
                  : 'غیرفعال',
              Icons.message,
              isDark,
            ),
            _buildSettingItem(
              'نمایش آخرین بازدید',
              _privacySettings['show_last_seen'] == true ? 'فعال' : 'غیرفعال',
              Icons.visibility,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsSection(
      bool isDark, ColorScheme colorScheme) {
    return Card(
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تنظیمات اعلان‌ها',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              'اعلان‌های فوری',
              _notificationSettings['push_notifications'] == true
                  ? 'فعال'
                  : 'غیرفعال',
              Icons.notifications,
              isDark,
            ),
            _buildSettingItem(
              'اعلان پیام‌ها',
              _notificationSettings['message_notifications'] == true
                  ? 'فعال'
                  : 'غیرفعال',
              Icons.chat,
              isDark,
            ),
            _buildSettingItem(
              'اعلان لایک‌ها',
              _notificationSettings['like_notifications'] == true
                  ? 'فعال'
                  : 'غیرفعال',
              Icons.favorite,
              isDark,
            ),
            _buildSettingItem(
              'اعلان کامنت‌ها',
              _notificationSettings['comment_notifications'] == true
                  ? 'فعال'
                  : 'غیرفعال',
              Icons.comment,
              isDark,
            ),
            _buildSettingItem(
              'صدا',
              _notificationSettings['sound_enabled'] == true
                  ? 'فعال'
                  : 'غیرفعال',
              Icons.volume_up,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStatsSection(bool isDark, ColorScheme colorScheme) {
    final cacheStats = _settingsCache.getCacheStats();

    return Card(
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آمار کش',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              'تعداد کاربران کش شده',
              '${cacheStats['cached_users_count'] ?? 0}',
              Icons.people,
              isDark,
            ),
            _buildSettingItem(
              'حجم کل کش',
              '${(cacheStats['total_cache_size_mb'] ?? 0.0).toStringAsFixed(2)} مگابایت',
              Icons.storage,
              isDark,
            ),
            _buildSettingItem(
              'تنظیمات اپلیکیشن',
              '${cacheStats['app_settings_count'] ?? 0} مورد',
              Icons.settings,
              isDark,
            ),
            _buildSettingItem(
              'تنظیمات حریم خصوصی',
              '${cacheStats['privacy_settings_count'] ?? 0} مورد',
              Icons.privacy_tip,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
      String title, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? Colors.grey[300] : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
