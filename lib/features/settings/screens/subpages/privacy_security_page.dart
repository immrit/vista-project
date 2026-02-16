import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/vista_settings_widgets.dart';
import 'ActiveSessionsScreen.dart';
import 'BlockedUsersPage.dart';
import '../../../../provider/settings_providers.dart';
import '../../../../model/messagePrivacyModel.dart';
import '../../../../services/telegram_read_receipt_service.dart';

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

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final settingsAsync = userId != null
        ? ref.watch(mergedPrivacySettingsProvider(userId))
        : const AsyncValue.data(<String, dynamic>{});

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
                  subtitle: 'فقط دنبال‌کننده‌ها می‌توانند محتوای شما را ببینند',
                  value: (settingsAsync.value?['is_private'] as bool?) ?? false,
                  onChanged: (value) {
                    final uid = userId;
                    if (uid == null) return;
                    ref
                        .read(mergedPrivacySettingsProvider(uid).notifier)
                        .updateSetting('is_private', value);
                  },
                ),
                // اجازه بزرگنمایی پروفایل
                VistaSettingsSwitch(
                  icon: Icons.zoom_in,
                  title: 'اجازه بزرگنمایی پروفایل',
                  subtitle: 'دیگران بتوانند عکس پروفایل شما را بزرگنمایی کنند',
                  value: settingsAsync.value?['allow_profile_zoom'] as bool? ??
                      true,
                  onChanged: (value) {
                    final uid = userId;
                    if (uid == null) return;
                    ref
                        .read(mergedPrivacySettingsProvider(uid).notifier)
                        .updateSetting('allow_profile_zoom', value);
                  },
                ),
                // آخرین بازدید
                VistaSettingsChoice<String>(
                  icon: Icons.access_time_outlined,
                  title: 'آخرین بازدید',
                  value: (settingsAsync.value?['last_seen_visibility']
                          as String?) ??
                      'everyone',
                  options: const [
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                    VistaChoiceOption(
                        value: 'my_contacts', label: 'فقط مخاطبین'),
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                  ],
                  onChanged: (value) {
                    final uid = userId;
                    if (uid == null) return;
                    ref
                        .read(mergedPrivacySettingsProvider(uid).notifier)
                        .updateSetting('last_seen_visibility', value);
                  },
                ),
                // عکس پروفایل
                VistaSettingsChoice<String>(
                  icon: Icons.chat_bubble_outline,
                  title: 'پیام‌ها',
                  value: (settingsAsync.value?['message_privacy'] as String?) ??
                      MessagePrivacyLevel.everyone.value,
                  options: const [
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                    VistaChoiceOption(
                        value: 'followers', label: 'فقط دنبال‌کننده‌ها'),
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                  ],
                  onChanged: (value) {
                    final uid = userId;
                    if (uid == null) return;
                    ref
                        .read(mergedPrivacySettingsProvider(uid).notifier)
                        .updateSetting('message_privacy', value);
                  },
                ),
                VistaSettingsSwitch(
                  icon: Icons.done_all,
                  title: 'ارسال تیک خوانده‌شدن',
                  subtitle: 'اگر خاموش باشد، تیک خوانده‌شدن ارسال نمی‌شود',
                  value:
                      (settingsAsync.value?['send_read_receipts'] as bool?) ??
                          true,
                  onChanged: (value) {
                    final uid = userId;
                    if (uid == null) return;
                    ref
                        .read(mergedPrivacySettingsProvider(uid).notifier)
                        .updateSetting('send_read_receipts', value);
                    TelegramReadReceiptService().invalidateSettingsCache();
                  },
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
                  onChanged: (value) async {
                    setState(() => _profilePhoto = value);
                    await _saveStringSetting(_keyProfilePhoto, value);
                    if (mounted) {
                      _showInfo('تنظیمات نمایش عکس پروفایل ذخیره شد');
                    }
                  },
                ),
                // پیام‌های فوروارد شده
                VistaSettingsSwitch(
                  icon: Icons.forward_to_inbox_outlined,
                  title: 'لینک پیام‌های فوروارد شده',
                  subtitle: 'کنترل نمایش لینک بازگشت به پیام اصلی',
                  value: _forwardedMessages,
                  onChanged: (value) async {
                    setState(() => _forwardedMessages = value);
                    await _saveBoolSetting(_keyForwardedMessages, value);
                  },
                ),
                // اجازه اضافه شدن به گروه
                VistaSettingsChoice<String>(
                  icon: Icons.group_add_outlined,
                  title: 'اضافه شدن به گروه',
                  value:
                      (settingsAsync.value?['group_add_privacy'] as String?) ??
                          'everyone',
                  options: const [
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                    VistaChoiceOption(
                        value: 'following', label: 'فقط دنبال‌کننده‌ها'),
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                  ],
                  onChanged: (value) {
                    final uid = userId;
                    if (uid == null) return;
                    ref
                        .read(mergedPrivacySettingsProvider(uid).notifier)
                        .updateSetting('group_add_privacy', value);
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
                  onChanged: (value) async {
                    setState(() => _twoStepVerification = value);
                    await _saveBoolSetting(_keyTwoStep, value);
                    if (value) {
                      _showTwoStepSetupDialog(isDark);
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
                      'در حال حاضر تایید دو مرحله‌ای به‌صورت رمز دوم محلی فعال است. برای فعال‌سازی سراسری حساب از ایمیل و شماره تاییدشده استفاده کنید.',
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
