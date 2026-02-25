import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../widgets/vista_settings_widgets.dart';

/// صفحه تنظیمات داده و ذخیره‌سازی - طراحی مشابه ویستا
class DataStorageSettingsPage extends StatefulWidget {
  const DataStorageSettingsPage({super.key});

  @override
  State<DataStorageSettingsPage> createState() =>
      _DataStorageSettingsPageState();
}

class _DataStorageSettingsPageState extends State<DataStorageSettingsPage> {
  // تنظیمات دانلود خودکار
  bool _mobileDataPhotos = true;
  bool _mobileDataVideos = false;
  bool _wifiPhotos = true;
  bool _wifiVideos = true;

  // کیفیت آپلود
  String _uploadQuality = 'high'; // high, standard, data_saver

  // وضعیت پاکسازی کش
  bool _isClearing = false;

  // کلیدهای SharedPreferences
  static const String _keyMobilePhotos = 'data_mobile_photos';
  static const String _keyMobileVideos = 'data_mobile_videos';
  static const String _keyWifiPhotos = 'data_wifi_photos';
  static const String _keyWifiVideos = 'data_wifi_videos';
  static const String _keyUploadQuality = 'data_upload_quality';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mobileDataPhotos = prefs.getBool(_keyMobilePhotos) ?? true;
      _mobileDataVideos = prefs.getBool(_keyMobileVideos) ?? false;
      _wifiPhotos = prefs.getBool(_keyWifiPhotos) ?? true;
      _wifiVideos = prefs.getBool(_keyWifiVideos) ?? true;
      _uploadQuality = prefs.getString(_keyUploadQuality) ?? 'high';
    });
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
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
            // بخش دانلود خودکار - داده موبایل
            const VistaSettingsSection(title: 'دانلود خودکار - داده موبایل'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.photo_outlined,
                  title: 'تصاویر',
                  subtitle: 'دانلود خودکار تصاویر با داده موبایل',
                  value: _mobileDataPhotos,
                  onChanged: (value) {
                    setState(() => _mobileDataPhotos = value);
                    _saveBoolSetting(_keyMobilePhotos, value);
                  },
                ),
                VistaSettingsSwitch(
                  icon: Icons.videocam_outlined,
                  title: 'ویدیوها',
                  subtitle: 'دانلود خودکار ویدیوها با داده موبایل',
                  value: _mobileDataVideos,
                  onChanged: (value) {
                    setState(() => _mobileDataVideos = value);
                    _saveBoolSetting(_keyMobileVideos, value);
                  },
                ),
              ],
            ),

            // بخش دانلود خودکار - وای‌فای
            const VistaSettingsSection(title: 'دانلود خودکار - وای‌فای'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.photo_outlined,
                  title: 'تصاویر',
                  subtitle: 'دانلود خودکار تصاویر با وای‌فای',
                  value: _wifiPhotos,
                  onChanged: (value) {
                    setState(() => _wifiPhotos = value);
                    _saveBoolSetting(_keyWifiPhotos, value);
                  },
                ),
                VistaSettingsSwitch(
                  icon: Icons.videocam_outlined,
                  title: 'ویدیوها',
                  subtitle: 'دانلود خودکار ویدیوها با وای‌فای',
                  value: _wifiVideos,
                  onChanged: (value) {
                    setState(() => _wifiVideos = value);
                    _saveBoolSetting(_keyWifiVideos, value);
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
                  subtitle: 'حذف فایل‌های موقت و آزادسازی فضا',
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
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
        Navigator.pop(context);
      },
    );
  }

  void _showClearCacheDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
