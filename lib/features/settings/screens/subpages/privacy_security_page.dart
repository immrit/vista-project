import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/vista_settings_widgets.dart';
import 'ActiveSessionsScreen.dart';
import 'BlockedUsersPage.dart';

/// صفحه تنظیمات حریم خصوصی و امنیت - طراحی مدرن و یکپارچه
class PrivacySecurityPage extends ConsumerStatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  ConsumerState<PrivacySecurityPage> createState() =>
      _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends ConsumerState<PrivacySecurityPage> {
  // تنظیمات حریم خصوصی
  String _lastSeen = 'everyone'; // everyone, contacts, nobody
  String _profilePhoto = 'everyone'; // everyone, contacts, nobody
  bool _forwardedMessages = true;

  // تنظیمات امنیت
  bool _twoStepVerification = false;

  // کلیدهای SharedPreferences
  static const String _keyLastSeen = 'privacy_last_seen';
  static const String _keyProfilePhoto = 'privacy_profile_photo';
  static const String _keyForwardedMessages = 'privacy_forwarded_messages';
  static const String _keyTwoStep = 'security_two_step';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSeen = prefs.getString(_keyLastSeen) ?? 'everyone';
      _profilePhoto = prefs.getString(_keyProfilePhoto) ?? 'everyone';
      _forwardedMessages = prefs.getBool(_keyForwardedMessages) ?? true;
      _twoStepVerification = prefs.getBool(_keyTwoStep) ?? false;
    });
  }

  Future<void> _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('حریم خصوصی و امنیت'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // بخش حریم خصوصی
          const VistaSettingsSection(title: 'حریم خصوصی'),
          VistaSettingsGroup(
            children: [
              // آخرین بازدید
              VistaSettingsChoice<String>(
                icon: Icons.access_time_outlined,
                title: 'آخرین بازدید',
                value: _lastSeen,
                options: const [
                  VistaChoiceOption(value: 'everyone', label: 'همه'),
                  VistaChoiceOption(value: 'contacts', label: 'فقط مخاطبین'),
                  VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                ],
                onChanged: (value) {
                  setState(() => _lastSeen = value);
                  _saveStringSetting(_keyLastSeen, value);
                },
              ),
              // عکس پروفایل
              VistaSettingsChoice<String>(
                icon: Icons.photo_camera_outlined,
                title: 'عکس پروفایل',
                value: _profilePhoto,
                options: const [
                  VistaChoiceOption(value: 'everyone', label: 'همه'),
                  VistaChoiceOption(value: 'contacts', label: 'فقط مخاطبین'),
                  VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                ],
                onChanged: (value) {
                  setState(() => _profilePhoto = value);
                  _saveStringSetting(_keyProfilePhoto, value);
                },
              ),
              // پیام‌های فوروارد شده
              VistaSettingsSwitch(
                icon: Icons.forward_to_inbox_outlined,
                title: 'لینک پیام‌های فوروارد شده',
                subtitle: 'اجازه لینک به پروفایل شما در پیام‌های فوروارد شده',
                value: _forwardedMessages,
                onChanged: (value) {
                  setState(() => _forwardedMessages = value);
                  _saveBoolSetting(_keyForwardedMessages, value);
                },
              ),
            ],
          ),

          // بخش امنیت
          const VistaSettingsSection(title: 'امنیت'),
          VistaSettingsGroup(
            children: [
              // نشست‌های فعال
              VistaSettingsTile(
                icon: Icons.devices_outlined,
                title: 'نشست‌های فعال',
                subtitle: 'مدیریت دستگاه‌های متصل',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActiveSessionsScreen(),
                  ),
                ),
              ),
              // تایید دو مرحله‌ای
              VistaSettingsSwitch(
                icon: Icons.security_outlined,
                title: 'تایید دو مرحله‌ای',
                subtitle: 'افزایش امنیت با رمز دوم',
                value: _twoStepVerification,
                onChanged: (value) {
                  if (value) {
                    _showTwoStepSetupDialog(isDark);
                  } else {
                    setState(() => _twoStepVerification = false);
                    _saveBoolSetting(_keyTwoStep, false);
                  }
                },
              ),
            ],
          ),

          // بخش اتصالات
          const VistaSettingsSection(title: 'اتصالات'),
          VistaSettingsGroup(
            children: [
              // کاربران مسدود شده
              VistaSettingsTile(
                icon: Icons.block_outlined,
                title: 'کاربران مسدود شده',
                subtitle: 'مدیریت کاربران مسدود شده',
                iconColor: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BlockedUsersPage(),
                  ),
                ),
              ),
            ],
          ),

          // توضیحات
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'تنظیمات حریم خصوصی شما تعیین می‌کند چه کسانی می‌توانند اطلاعات شما را مشاهده کنند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTwoStepSetupDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.security_outlined,
              color: isDark ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 12),
            Text(
              'تایید دو مرحله‌ای',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'با فعال کردن تایید دو مرحله‌ای، علاوه بر رمز عبور، یک کد تایید نیز نیاز خواهید داشت.',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'این قابلیت به زودی فعال می‌شود',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'متوجه شدم',
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
}
