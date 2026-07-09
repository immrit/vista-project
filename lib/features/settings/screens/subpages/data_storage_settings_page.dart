import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../../services/video_autoplay_service.dart';
import '../../../../services/media_upload_prefs.dart';
import '../../widgets/vista_settings_widgets.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// صفحه تنظیمات داده و ذخیره‌سازی - طراحی مشابه ویستا
class DataStorageSettingsPage extends StatefulWidget {
  const DataStorageSettingsPage({super.key});

  @override
  State<DataStorageSettingsPage> createState() =>
      _DataStorageSettingsPageState();
}

class _DataStorageSettingsPageState extends State<DataStorageSettingsPage> {
  // کیفیت آپلود
  String _uploadQuality = 'high'; // high, standard, data_saver

  // پخش ویدیو در فید
  bool _videoAutoPlay = false;
  bool _videoDataSaver = false;

  // وضعیت پاکسازی کش
  bool _isClearing = false;

  // اندازه کش (null = هنوز محاسبه نشده)
  int? _cacheSizeBytes;

  // کلیدهای SharedPreferences
  static const String _keyUploadQuality = 'data_upload_quality';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshCacheSize();
  }

  /// Total size of the app temp dir — the image/file cache manager stores
  /// its files there too, so one walk covers both.
  Future<void> _refreshCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      var total = 0;
      if (await tempDir.exists()) {
        await for (final entity
            in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              total += await entity.length();
            } catch (_) {
              // File vanished mid-walk — skip.
            }
          }
        }
      }
      if (mounted) setState(() => _cacheSizeBytes = total);
    } catch (_) {
      if (mounted) setState(() => _cacheSizeBytes = null);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes بایت';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} کیلوبایت';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} مگابایت';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} گیگابایت';
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uploadQuality = prefs.getString(_keyUploadQuality) ?? 'high';
      _videoAutoPlay = prefs.getBool('video_auto_play') ?? false;
      _videoDataSaver = prefs.getBool('video_data_saver') ?? false;
    });
  }

  Future<void> _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  String _getQualityLabel() {
    switch (_uploadQuality) {
      case 'high':
        return 'کیفیت بالا';
      case 'standard':
        return 'استاندارد';
      case 'data_saver':
        return 'صرفه‌جویی در داده';
      default:
        return 'کیفیت بالا';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.lightSurfaceVariant,
      appBar: AppBar(
        title: const Text('داده و ذخیره‌سازی'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // بخش پخش ویدیو در فید
            const VistaSettingsSection(title: 'پخش ویدیو در فید'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.play_circle_outline,
                  title: 'پخش خودکار ویدیو',
                  subtitle:
                      'ویدیوهای فید و پروفایل با اسکرول به‌صورت خودکار پخش شوند',
                  value: _videoAutoPlay,
                  onChanged: (value) async {
                    setState(() => _videoAutoPlay = value);
                    await VideoAutoplayService().setAutoPlay(value);
                  },
                ),
                VistaSettingsSwitch(
                  icon: Icons.data_usage_outlined,
                  title: 'صرفه‌جویی در اینترنت (ویدیو)',
                  subtitle:
                      'کیفیت پایین‌تر برای ویدیوها و پیش‌نمایش سبک‌تر',
                  value: _videoDataSaver,
                  onChanged: (value) async {
                    setState(() => _videoDataSaver = value);
                    await VideoAutoplayService().setDataSaver(value);
                  },
                ),
              ],
            ),

            // بخش کیفیت آپلود
            const VistaSettingsSection(title: 'کیفیت رسانه'),
            VistaSettingsGroup(
              children: [
                VistaSettingsTile(
                  icon: Icons.high_quality_outlined,
                  title: 'کیفیت آپلود',
                  subtitle: _getQualityLabel(),
                  onTap: () => _showQualitySheet(isDark),
                ),
              ],
            ),

            // بخش ذخیره‌سازی
            const VistaSettingsSection(title: 'ذخیره‌سازی'),
            VistaSettingsGroup(
              children: [
                VistaSettingsTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'پاکسازی کش',
                  subtitle: _cacheSizeBytes == null
                      ? 'حذف فایل‌های موقت و آزادسازی فضا'
                      : 'فضای اشغال‌شده: ${_formatBytes(_cacheSizeBytes!)}',
                  showArrow: false,
                  trailing: _isClearing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap:
                      _isClearing ? null : () => _showClearCacheDialog(isDark),
                ),
              ],
            ),

            // توضیحات
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'با پاکسازی کش، تصاویر و فایل‌های موقت حذف می‌شوند. این کار فضای ذخیره‌سازی را آزاد می‌کند.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualitySheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'کیفیت آپلود',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Divider(height: 1),
            _buildQualityOption(
                'high', 'کیفیت بالا', 'بهترین کیفیت، مصرف داده بیشتر', isDark),
            _buildQualityOption(
                'standard', 'استاندارد', 'تعادل بین کیفیت و مصرف داده', isDark),
            _buildQualityOption(
                'data_saver', 'صرفه‌جویی در داده', 'کمترین مصرف داده', isDark),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(
      String value, String title, String subtitle, bool isDark) {
    final isSelected = _uploadQuality == value;

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check,
              color: isDark ? Colors.white : Colors.black,
            )
          : null,
      onTap: () {
        setState(() => _uploadQuality = value);
        _saveStringSetting(_keyUploadQuality, value);
        // Update the in-memory cache the upload path reads immediately.
        MediaUploadPrefs.updateCache(value);
        Navigator.pop(context);
      },
    );
  }

  void _showClearCacheDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'پاکسازی کش',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'این کار تمام فایل‌های موقت را حذف می‌کند و فضای ذخیره‌سازی را آزاد می‌کند. آیا ادامه می‌دهید؟',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'انصراف',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearCache();
            },
            child: Text(
              'پاکسازی',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);

    try {
      // پاکسازی کش تصاویر
      await DefaultCacheManager().emptyCache();

      // پاکسازی بقیه فایل‌های موقت (مدیای دانلودشده چت، thumbnailها و …)
      // که cache manager از آن‌ها خبر ندارد.
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          await for (final entity
              in tempDir.list(recursive: false, followLinks: false)) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {
              // File busy/locked — skip it, clear the rest.
            }
          }
        }
      } catch (_) {}

      await _refreshCacheSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('کش با موفقیت پاکسازی شد'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در پاکسازی کش: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }
}
