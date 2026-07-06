import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/providers/auth_controller.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../../../features/profile/providers/profile_controller.dart';
import '../../../../model/messagePrivacyModel.dart';
import '../../../../provider/settings_providers.dart';
import '../../../../services/advanced_security_service.dart';
import '../../../../services/current_user_service.dart';
import '../../../../services/modern_read_receipt_service.dart';
import '../../widgets/vista_settings_widgets.dart';
import 'ActiveSessionsScreen.dart';
import 'BlockedUsersPage.dart';

class PrivacySecurityPage extends ConsumerStatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  ConsumerState<PrivacySecurityPage> createState() =>
      _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends ConsumerState<PrivacySecurityPage> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _biometricLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await AdvancedSecurityService.isBiometricAvailable();
    final enabled = await AdvancedSecurityService.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _biometricLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId =
        ref.watch(activeUserProvider)?.id ?? CurrentUserService.cachedUserId;
    final settingsAsync = userId != null
        ? ref.watch(mergedPrivacySettingsProvider(userId))
        : const AsyncValue.data(<String, dynamic>{});
    final settings = settingsAsync.value ?? <String, dynamic>{};

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F6F8),
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
            const VistaSettingsSection(title: 'حریم خصوصی'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.lock_outline,
                  title: 'حساب خصوصی',
                  value: settings['is_private'] as bool? ?? false,
                  onChanged: (value) => _updateIsPrivate(userId, value),
                ),
                VistaSettingsChoice<String>(
                  icon: Icons.access_time_outlined,
                  title: 'آخرین بازدید',
                  value: (settings['last_seen_visibility'] as String?) ??
                      'everyone',
                  options: const [
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                    VistaChoiceOption(
                      value: 'my_contacts',
                      label: 'فقط مخاطبین',
                    ),
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                  ],
                  onChanged: (value) =>
                      _updateSetting(userId, 'last_seen_visibility', value),
                ),
                VistaSettingsChoice<String>(
                  icon: Icons.chat_bubble_outline,
                  title: 'پیام از طرف',
                  value: (settings['message_privacy'] as String?) ??
                      MessagePrivacyLevel.everyone.value,
                  options: const [
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                    VistaChoiceOption(
                      value: 'friends',
                      label: 'دوستان من',
                    ),
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                  ],
                  onChanged: (value) =>
                      _updateSetting(userId, 'message_privacy', value),
                ),
                VistaSettingsChoice<String>(
                  icon: Icons.group_add_outlined,
                  title: 'افزودن به گروه',
                  value:
                      (settings['group_add_privacy'] as String?) ?? 'everyone',
                  options: const [
                    VistaChoiceOption(value: 'everyone', label: 'همه'),
                    VistaChoiceOption(
                      value: 'following',
                      label: 'فقط دنبال‌کننده‌ها',
                    ),
                    VistaChoiceOption(value: 'nobody', label: 'هیچکس'),
                  ],
                  onChanged: (value) =>
                      _updateSetting(userId, 'group_add_privacy', value),
                ),
                VistaSettingsSwitch(
                  icon: Icons.done_all,
                  title: 'تیک خوانده‌شدن',
                  value: settings['send_read_receipts'] as bool? ?? true,
                  onChanged: (value) {
                    _updateSetting(userId, 'send_read_receipts', value);
                    ModernReadReceiptService().invalidateSettingsCache();
                  },
                ),
                VistaSettingsSwitch(
                  icon: Icons.photo_size_select_large_outlined,
                  title: 'بزرگنمایی تصویر پروفایل',
                  subtitle:
                      'اگر غیرفعال باشد، دیگران نمی‌توانند عکس پروفایل شما را بزرگ کنند',
                  value: settings['allow_profile_zoom'] as bool? ?? true,
                  onChanged: (value) async {
                    await _updateSetting(userId, 'allow_profile_zoom', value);
                    if (userId != null) {
                      ref.invalidate(userSettingsByIdProvider(userId));
                    }
                  },
                ),
                VistaSettingsTile(
                  icon: Icons.block_outlined,
                  title: 'کاربران مسدود شده',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersPage(),
                    ),
                  ),
                ),
              ],
            ),
            const VistaSettingsSection(title: 'امنیت'),
            VistaSettingsGroup(
              children: [
                VistaSettingsTile(
                  icon: Icons.devices_outlined,
                  title: 'نشست‌های فعال',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ActiveSessionsScreen(),
                    ),
                  ),
                ),
                VistaSettingsSwitch(
                  icon: Icons.fingerprint_outlined,
                  title: 'ورود بیومتریک',
                  subtitle:
                      _biometricAvailable ? null : 'این دستگاه بیومتریک ندارد',
                  value: _biometricEnabled,
                  onChanged: (_biometricLoading || !_biometricAvailable)
                      ? null
                      : (value) => _toggleBiometric(value),
                ),
                // NOTE: the "two-factor" toggle was removed. It only wrote a
                // bool into the privacy blob; real 2FA needs the
                // /auth/2fa/setup password-enrolment flow (Set2FAPassword),
                // otherwise enabling it either locks the user out or does
                // nothing. Re-add wired to that flow when 2FA UI ships.
                VistaSettingsSwitch(
                  icon: Icons.lock_clock_outlined,
                  title: 'قفل خودکار',
                  value: settings['auto_lock_enabled'] as bool? ?? true,
                  onChanged: (value) =>
                      _updateSetting(userId, 'auto_lock_enabled', value),
                ),
                VistaSettingsChoice<int>(
                  icon: Icons.timer_outlined,
                  title: 'زمان قفل',
                  value: settings['auto_lock_timeout_minutes'] as int? ?? 5,
                  options: const [
                    VistaChoiceOption(value: 1, label: '۱ دقیقه'),
                    VistaChoiceOption(value: 5, label: '۵ دقیقه'),
                    VistaChoiceOption(value: 15, label: '۱۵ دقیقه'),
                    VistaChoiceOption(value: 30, label: '۳۰ دقیقه'),
                  ],
                  onChanged: (value) => _updateSetting(
                      userId, 'auto_lock_timeout_minutes', value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSetting(String? userId, String key, dynamic value) async {
    if (userId == null) return;
    await ref
        .read(mergedPrivacySettingsProvider(userId).notifier)
        .updateSetting(key, value);
  }

  /// «حساب خصوصی» باید روی ستون `profiles.is_private` بنشیند — همان جایی که
  /// سرور برای گیت‌کردن پست‌ها/فالو استفاده می‌کند. نوشتنش فقط در blob
  /// تنظیمات، حساب را در UI «خصوصی» و در سرور عمومی می‌گذاشت (نشت حریم
  /// خصوصی). blob هم برای سازگاری UI به‌روز می‌شود.
  Future<void> _updateIsPrivate(String? userId, bool value) async {
    if (userId == null) return;
    final notifier = ref.read(mergedPrivacySettingsProvider(userId).notifier);
    await notifier.updateSetting('is_private', value);
    try {
      await ProfileRepository().updateProfile(userId, {'is_private': value});
      ref.invalidate(profileProvider);
    } catch (e) {
      // سرور ثبت نکرد — toggle را برگردان تا UI دروغ نگوید.
      await notifier.updateSetting('is_private', !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تغییر حالت حساب خصوصی ثبت نشد. دوباره تلاش کنید'),
          ),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _biometricLoading = true);
    try {
      if (value) {
        final ok = await AdvancedSecurityService.enableBiometric();
        if (!ok) {
          if (!mounted) return;
          setState(() => _biometricLoading = false);
          return;
        }
      } else {
        await AdvancedSecurityService.disableBiometric();
      }
      if (!mounted) return;
      setState(() {
        _biometricEnabled = value;
        _biometricLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _biometricLoading = false);
    }
  }
}
