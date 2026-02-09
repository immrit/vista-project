import '../../../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../provider/provider.dart';
import '../../../../provider/settings_providers.dart';
import '../../../../DB/advanced_settings_service.dart';
import '../../../../services/auto_lock_service.dart';
import '../../../../model/messagePrivacyModel.dart';
import 'BlockedUsersPage.dart';

class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تنظیمات حریم خصوصی'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          children: [
            // بخش حریم خصوصی پروفایل
            _buildPrivacySection(context, ref),

            const SizedBox(height: 20),

            // بخش مسدودسازی و گزارش
            _buildBlockingSection(context, ref),

            const SizedBox(height: 20),

            // بخش امنیت
            _buildSecuritySection(context, ref),

            const SizedBox(height: 20),

            // بخش داده‌ها و حفظ حریم خصوصی
            _buildDataSection(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appSettingsAsync = ref.watch(advancedAppSettingsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: appSettingsAsync.when(
        data: (settings) {
          final security = settings['security'] as Map<String, dynamic>? ?? {};

          return PrivacySwitchItem(
            icon: Icons.lock_rounded,
            iconColor: Colors.red,
            title: 'قفل خودکار',
            subtitle: security['auto_lock_enabled'] == true
                ? '${security['auto_lock_timeout_minutes'] ?? 5} دقیقه'
                : 'غیرفعال',
            value: security['auto_lock_enabled'] as bool? ?? false,
            onChanged: (bool value) async {
              final service = AdvancedSettingsService();
              await service.updateAdvancedAppSettings({
                'security': {...security, 'auto_lock_enabled': value}
              });
              ref.invalidate(advancedAppSettingsProvider);
              // به‌روزرسانی AutoLockService
              AutoLockService().refreshSettings();
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('خطا: $error'),
        ),
      ),
    );
  }

  Widget _buildPrivacySection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Consumer(builder: (context, ref, _) {
            final settingsAsync = ref.watch(currentUserSettingsProvider);
            final value =
                settingsAsync.value?['allow_profile_zoom'] as bool? ?? true;
            return PrivacySwitchItem(
              icon: Icons.zoom_in,
              iconColor: Colors.blue,
              title: 'اجازه بزرگنمایی پروفایل',
              subtitle: 'دیگران بتوانند عکس پروفایل شما را بزرگنمایی کنند',
              value: value,
              onChanged: (bool next) async {
                await _upsertUserSetting(
                    context, ref, 'allow_profile_zoom', next);
              },
            );
          }),
          _buildDivider(),
          Consumer(builder: (context, ref, _) {
            final settingsAsync = ref.watch(currentUserSettingsProvider);
            final isPrivate =
                settingsAsync.value?['is_private'] as bool? ?? false;
            return PrivacySwitchItem(
              icon: Icons.lock,
              iconColor: Colors.deepPurple,
              title: 'حساب خصوصی',
              subtitle: 'فقط دنبال شده ها تایید شده محتوای شما را میبینند',
              value: isPrivate,
              onChanged: (bool next) async {
                await _upsertUserSetting(context, ref, 'is_private', next);
              },
            );
          }),
          _buildDivider(),
          PrivacySettingsItem(
            icon: Icons.message,
            iconColor: Colors.orange,
            title: 'حریم خصوصی پیام‌ها',
            subtitle: 'کنترل اینکه چه کسانی می‌توانند به شما پیام ارسال کنند',
            onTap: () => _showMessagePrivacyDialog(context, ref),
          ),
          _buildDivider(),
          PrivacySettingsItem(
            icon: Icons.group_add_outlined,
            iconColor: Colors.teal,
            title: 'اضافه شدن به گروه',
            subtitle:
                'کنترل اینکه چه کسانی می‌توانند شما را به گروه اضافه کنند',
            onTap: () => _showGroupAddPrivacyDialog(context, ref),
          ),
          _buildDivider(),
          PrivacySettingsItem(
            icon: Icons.visibility,
            iconColor: Colors.green,
            title: 'آخرین بازدید',
            subtitle: 'کنترل نمایش آخرین بازدید شما',
            onTap: () => _showLastSeenDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockingSection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Consumer(
            builder: (context, ref, _) {
              final blockedCountAsync = ref.watch(blockedUsersCountProvider);
              return blockedCountAsync.when(
                data: (count) => PrivacySettingsItem(
                  icon: Icons.block,
                  iconColor: Colors.brown,
                  title: 'کاربران مسدود شده',
                  subtitle: count > 0
                      ? '$count کاربر مسدود شده'
                      : 'مدیریت لیست کاربران مسدود شده',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BlockedUsersPage(),
                      ),
                    );
                  },
                ),
                loading: () => PrivacySettingsItem(
                  icon: Icons.block,
                  iconColor: Colors.brown,
                  title: 'کاربران مسدود شده',
                  subtitle: 'در حال بارگذاری...',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BlockedUsersPage(),
                      ),
                    );
                  },
                ),
                error: (_, __) => PrivacySettingsItem(
                  icon: Icons.block,
                  iconColor: Colors.brown,
                  title: 'کاربران مسدود شده',
                  subtitle: 'خطا در بارگذاری',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BlockedUsersPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          PrivacySettingsItem(
            icon: Icons.download,
            iconColor: Colors.indigo,
            title: 'دانلود اطلاعات من',
            subtitle: 'دریافت کپی از اطلاعات حساب شما',
            onTap: () {
              _showComingSoon(
                  context, 'قابلیت دانلود اطلاعات به زودی اضافه خواهد شد!');
            },
          ),
          _buildDivider(),
          PrivacySettingsItem(
            icon: Icons.account_circle,
            iconColor: Colors.grey,
            title: 'حذف حساب کاربری',
            subtitle: 'حذف دائمی حساب و اطلاعات شما',
            onTap: () {
              _showDeleteAccountDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(left: 68.0),
          height: 0.5,
          color: isDark ? Colors.grey[700] : Colors.grey[200],
        );
      },
    );
  }

  // Helper methods
  // بروزرسانی تنظیمات در جدول user_settings (در صورت نبود رکورد، ایجاد میشود)
  Future<void> _upsertUserSetting(BuildContext context, WidgetRef ref,
      String setting, dynamic value) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('user_settings').upsert({
        'user_id': user.id,
        setting: value,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Mirror a subset into `privacy_settings` for backward compatibility.
      if (setting == 'is_private' || setting == 'group_add_privacy') {
        await Supabase.instance.client.from('privacy_settings').upsert({
          'user_id': user.id,
          setting: value,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      final _ = ref.refresh(currentUserSettingsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تنظیمات با موفقیت به‌روزرسانی شد'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در به‌روزرسانی: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMessagePrivacyDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.message,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'حریم خصوصی پیام‌ها',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MessagePrivacyLevel.allLevels.map((level) {
            return Consumer(
              builder: (context, ref, _) {
                final settingsAsync = ref.watch(currentUserSettingsProvider);
                final currentLevel =
                    settingsAsync.value?['message_privacy'] as String? ??
                        'everyone';
                final isSelected = currentLevel == level.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.orange
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Colors.orange
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    title: Text(
                      level.title,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      level.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context, level.value);
                    },
                  ),
                );
              },
            );
          }).toList(),
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
        ],
      ),
    ).then((value) {
      if (value != null && context.mounted) {
        _upsertUserSetting(context, ref, 'message_privacy', value);
      }
    });
  }

  void _showGroupAddPrivacyDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.group_add_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'اضافه شدن به گروه',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Consumer(
          builder: (context, ref, _) {
            final settingsAsync =
                ref.watch(mergedPrivacySettingsProvider(userId));
            final currentValue =
                settingsAsync.value?['group_add_privacy'] as String? ??
                    'everyone';
            final options = const [
              {
                'value': 'nobody',
                'title': 'هیچکس',
                'desc': 'هیچ‌کس نتواند شما را اضافه کند'
              },
              {
                'value': 'following',
                'title': 'فقط دنبال‌کننده‌ها',
                'desc': 'فقط افرادی که شما را دنبال می‌کنند'
              },
              {
                'value': 'everyone',
                'title': 'همه',
                'desc': 'همه بتوانند شما را اضافه کنند'
              },
            ];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                final isSelected = currentValue == opt['value'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? Colors.teal.withOpacity(0.2)
                            : Colors.teal.withOpacity(0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.teal
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Colors.teal
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    title: Text(
                      opt['title'] as String,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      opt['desc'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    onTap: () async {
                      await ref
                          .read(mergedPrivacySettingsProvider(userId).notifier)
                          .updateSetting('group_add_privacy', opt['value']);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              }).toList(),
            );
          },
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
        ],
      ),
    );
  }

  void _showLastSeenDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('آخرین بازدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('همه'),
              onTap: () => Navigator.pop(context, 'everyone'),
            ),
            ListTile(
              title: const Text('مخاطبین من'),
              onTap: () => Navigator.pop(context, 'my_contacts'),
            ),
            ListTile(
              title: const Text('هیچکس'),
              onTap: () => Navigator.pop(context, 'nobody'),
            ),
          ],
        ),
      ),
    ).then((value) {
      if (value != null && context.mounted) {
        _upsertUserSetting(context, ref, 'last_seen_visibility', value);
      }
    });
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('حذف حساب کاربری'),
          ],
        ),
        content: const Text(
          'برای حذف حساب کاربری خود، لطفاً به صفحه تنظیمات وب سایت مراجعه کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _launchWebSettings();
            },
            child: const Text('رفتن به تنظیمات وب'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWebSettings() async {
    final Uri url = Uri.parse('https://cafevista.ir/settings');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      logInfo('Could not launch $url');
    }
  }
}

// Widget برای آیتم‌های تنظیمات
class PrivacySettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PrivacySettingsItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget برای آیتم‌های Switch
class PrivacySwitchItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const PrivacySwitchItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: iconColor,
          ),
        ],
      ),
    );
  }
}
