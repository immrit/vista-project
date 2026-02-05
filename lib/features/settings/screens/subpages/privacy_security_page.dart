import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/vista_settings_widgets.dart';
import 'ActiveSessionsScreen.dart';
import 'BlockedUsersPage.dart';
import '../../../../provider/provider.dart';
import '../../../../provider/settings_providers.dart';
import '../../../../model/messagePrivacyModel.dart';

/// صفحه تنظیمات حریم خصوصی و امنیت - طراحی مدرن و یکپارچه
class PrivacySecurityPage extends ConsumerStatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  ConsumerState<PrivacySecurityPage> createState() =>
      _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends ConsumerState<PrivacySecurityPage> {
  // تنظیمات حریم خصوصی
  String _profilePhoto = 'everyone'; // everyone, contacts, nobody
  bool _forwardedMessages = true;

  // تنظیمات امنیت
  bool _twoStepVerification = false;

  // کلیدهای SharedPreferences
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final privacySettingsAsync = userId != null
        ? ref.watch(privacySettingsProvider(userId))
        : const AsyncValue.data(null);
    final userSettingsAsync = ref.watch(currentUserSettingsProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('حریم خصوصی و امنیت'),
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
            // بخش حریم خصوصی
            const VistaSettingsSection(title: 'حریم خصوصی'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.lock_outline,
                  title: 'قفل کردن پیج',
                  subtitle:
                      'فقط دنبال‌کننده‌ها می‌توانند محتوای شما را ببینند',
                  value:
                      (userSettingsAsync.value?['is_private'] as bool?) ?? false,
                  onChanged: (value) {
                    _upsertUserSetting('is_private', value);

                    final uid = userId;
                    if (uid != null) {
                      _updatePrivacySetting(
                        uid,
                        privacySettingsAsync.value ?? const <String, dynamic>{},
                        {'is_private': value},
                      );
                    }
                  },
                ),
                // اجازه بزرگنمایی پروفایل
                VistaSettingsSwitch(
                  icon: Icons.zoom_in,
                  title: 'اجازه بزرگنمایی پروفایل',
                  subtitle:
                      'دیگران بتوانند عکس پروفایل شما را بزرگنمایی کنند',
                  value: userSettingsAsync.value?['allow_profile_zoom'] as bool? ??
                      true,
                  onChanged: (value) =>
                      _upsertUserSetting('allow_profile_zoom', value),
                ),
                // آخرین بازدید
                VistaSettingsChoice<String>(
                  icon: Icons.access_time_outlined,
                  title: 'آخرین بازدید',
                  value: (userSettingsAsync.value?['last_seen_visibility']
                          as String?) ??
                      'everyone',
                  options: const [
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                    VistaChoiceOption(value: 'my_contacts', label: 'فقط مخاطبین'),
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                  ],
                  onChanged: (value) =>
                      _upsertUserSetting('last_seen_visibility', value),
                ),
                // عکس پروفایل
                VistaSettingsChoice<String>(
                  icon: Icons.chat_bubble_outline,
                  title: 'پیام‌ها',
                  value:
                      (userSettingsAsync.value?['message_privacy'] as String?) ??
                          MessagePrivacyLevel.everyone.value,
                  options: const [
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                    VistaChoiceOption(
                        value: 'followers', label: 'فقط دنبال‌کننده‌ها'),
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                  ],
                  onChanged: (value) =>
                      _upsertUserSetting('message_privacy', value),
                ),
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
                // اجازه اضافه شدن به گروه
                VistaSettingsChoice<String>(
                  icon: Icons.group_add_outlined,
                  title: 'اضافه شدن به گروه',
                  value: (privacySettingsAsync.value?['group_add_privacy']
                          as String?) ??
                      'everyone',
                  options: const [
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                    VistaChoiceOption(
                        value: 'following', label: 'فقط دنبال‌کننده‌ها'),
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                  ],
                  onChanged: (value) {
                    if (userId == null) return;
                    _updatePrivacySetting(
                      userId,
                      privacySettingsAsync.value ?? {},
                      {'group_add_privacy': value},
                    );
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

  Future<void> _upsertUserSetting(String key, dynamic value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('user_settings').upsert({
        'user_id': user.id,
        key: value,
        'updated_at': DateTime.now().toIso8601String(),
      });
      ref.invalidate(currentUserSettingsProvider);
    } catch (_) {}
  }

  Future<void> _updatePrivacySetting(
    String userId,
    Map<String, dynamic> currentSettings,
    Map<String, dynamic> updates,
  ) async {
    final merged = {...currentSettings, ...updates};
    await ref
        .read(privacySettingsProvider(userId).notifier)
        .updateSettings(merged);
  }
}
