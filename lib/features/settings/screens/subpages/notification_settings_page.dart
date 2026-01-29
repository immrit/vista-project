import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/vista_settings_widgets.dart';

/// صفحه تنظیمات اعلان‌ها - طراحی ساده و تمیز
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // تنظیمات اعلان
  bool _showNotifications = true;
  bool _inAppSound = true;
  bool _vibrate = true;
  bool _showPreview = true;

  // کلیدهای SharedPreferences
  static const String _keyShowNotifications = 'notification_show';
  static const String _keyInAppSound = 'notification_sound';
  static const String _keyVibrate = 'notification_vibrate';
  static const String _keyShowPreview = 'notification_preview';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showNotifications = prefs.getBool(_keyShowNotifications) ?? true;
      _inAppSound = prefs.getBool(_keyInAppSound) ?? true;
      _vibrate = prefs.getBool(_keyVibrate) ?? true;
      _showPreview = prefs.getBool(_keyShowPreview) ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('اعلان‌ها'),
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
            // بخش کلی
            const VistaSettingsSection(title: 'عمومی'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.notifications_active_outlined,
                  title: 'نمایش اعلان‌ها',
                  subtitle: 'فعال کردن اعلان‌های برنامه',
                  value: _showNotifications,
                  onChanged: (value) {
                    setState(() => _showNotifications = value);
                    _saveSetting(_keyShowNotifications, value);
                  },
                ),
              ],
            ),

            // بخش صدا و لرزش
            const VistaSettingsSection(title: 'صدا و لرزش'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.volume_up_outlined,
                  title: 'صدای برنامه',
                  subtitle: 'پخش صدا هنگام دریافت پیام',
                  value: _inAppSound,
                  onChanged: _showNotifications
                      ? (value) {
                          setState(() => _inAppSound = value);
                          _saveSetting(_keyInAppSound, value);
                        }
                      : null,
                ),
                VistaSettingsSwitch(
                  icon: Icons.vibration_outlined,
                  title: 'لرزش',
                  subtitle: 'لرزش هنگام دریافت اعلان',
                  value: _vibrate,
                  onChanged: _showNotifications
                      ? (value) {
                          setState(() => _vibrate = value);
                          _saveSetting(_keyVibrate, value);
                        }
                      : null,
                ),
              ],
            ),

            // بخش پیش‌نمایش
            const VistaSettingsSection(title: 'پیش‌نمایش'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.visibility_outlined,
                  title: 'نمایش پیش‌نمایش پیام',
                  subtitle: 'نمایش محتوای پیام در اعلان',
                  value: _showPreview,
                  onChanged: _showNotifications
                      ? (value) {
                          setState(() => _showPreview = value);
                          _saveSetting(_keyShowPreview, value);
                        }
                      : null,
                ),
              ],
            ),

            // توضیحات
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'با غیرفعال کردن اعلان‌ها، هیچ پیام یا هشداری دریافت نخواهید کرد.',
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
}
