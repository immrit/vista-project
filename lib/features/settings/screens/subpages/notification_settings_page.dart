import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/providers/auth_controller.dart';
import '../../../../provider/settings_providers.dart';
import '../../../../services/current_user_service.dart';
import '../../widgets/vista_settings_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId =
        ref.watch(activeUserProvider)?.id ?? CurrentUserService.cachedUserId;
    final settingsAsync = userId != null
        ? ref.watch(notificationSettingsProvider(userId))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final settings = settingsAsync.value ?? {};

    final pushEnabled = settings['push_notifications'] as bool? ?? true;
    final messagesEnabled = settings['message_notifications'] as bool? ?? true;
    final mentionsEnabled = settings['mention_notifications'] as bool? ?? true;
    final socialEnabled = _isSocialEnabled(settings);
    final suggestEnabled = settings['suggest_notifications'] as bool? ?? true;
    final previewEnabled = settings['show_message_preview'] as bool? ?? true;
    final chatSoundEnabled = settings['in_app_chat_sounds'] as bool? ?? true;
    final soundEnabled = settings['sound_enabled'] as bool? ?? true;
    final vibrationEnabled = settings['vibration_enabled'] as bool? ?? true;
    final quietHoursEnabled = settings['quiet_hours_enabled'] as bool? ?? false;
    final quietHoursStart = settings['quiet_hours_start'] as String? ?? '22:00';
    final quietHoursEnd = settings['quiet_hours_end'] as String? ?? '08:00';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('اعلان‌ها'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        top: false,
        child: settingsAsync.when(
          data: (_) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const VistaSettingsSection(title: 'اعلان‌ها'),
              VistaSettingsGroup(
                children: [
                  VistaSettingsSwitch(
                    icon: Icons.notifications_active_outlined,
                    title: 'اعلان‌های پوش',
                    value: pushEnabled,
                    onChanged: (value) => _updateSettings(
                      ref,
                      userId,
                      settings,
                      {'push_notifications': value},
                    ),
                  ),
                  VistaSettingsSwitch(
                    icon: Icons.message_outlined,
                    title: 'پیام‌ها',
                    value: messagesEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {'message_notifications': value},
                            )
                        : null,
                  ),
                  VistaSettingsSwitch(
                    icon: Icons.alternate_email_outlined,
                    title: 'منشن‌ها',
                    value: mentionsEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {'mention_notifications': value},
                            )
                        : null,
                  ),
                  VistaSettingsSwitch(
                    icon: Icons.favorite_border,
                    title: 'تعاملات اجتماعی',
                    subtitle: 'لایک، کامنت، فالو و استوری',
                    value: socialEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {
                                'like_notifications': value,
                                'comment_notifications': value,
                                'follow_notifications': value,
                                'story_notifications': value,
                              },
                            )
                        : null,
                  ),
                  VistaSettingsSwitch(
                    icon: Icons.auto_awesome_outlined,
                    title: 'پیشنهادها',
                    subtitle: 'پست‌ها و کاربران پیشنهادی',
                    value: suggestEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {'suggest_notifications': value},
                            )
                        : null,
                  ),
                  VistaSettingsSwitch(
                    icon: Icons.visibility_outlined,
                    title: 'پیش‌نمایش پیام',
                    value: previewEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {'show_message_preview': value},
                            )
                        : null,
                  ),
                ],
              ),
              const VistaSettingsSection(title: 'صدا'),
              VistaSettingsGroup(
                children: [
                  VistaSettingsSwitch(
                    icon: Icons.chat_bubble_outline,
                    title: 'صدای پیام درون برنامه',
                    value: chatSoundEnabled,
                    onChanged: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('in_app_chat_sounds', value);
                      if (context.mounted) {
                        _updateSettings(
                          ref,
                          userId,
                          settings,
                          {'in_app_chat_sounds': value},
                        );
                      }
                    },
                  ),
                  VistaSettingsSwitch(
                    icon: Icons.volume_up_outlined,
                    title: 'صدای اعلان',
                    value: soundEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {'sound_enabled': value},
                            )
                        : null,
                  ),
                  VistaSettingsSwitch(
                    icon: Icons.vibration_outlined,
                    title: 'لرزش',
                    value: vibrationEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {'vibration_enabled': value},
                            )
                        : null,
                  ),
                ],
              ),
              const VistaSettingsSection(title: 'ساعات سکوت'),
              VistaSettingsGroup(
                children: [
                  VistaSettingsSwitch(
                    icon: Icons.nightlight_outlined,
                    title: 'فعال‌سازی ساعات سکوت',
                    subtitle: '$quietHoursStart تا $quietHoursEnd',
                    value: quietHoursEnabled,
                    onChanged: pushEnabled
                        ? (value) => _updateSettings(
                              ref,
                              userId,
                              settings,
                              {'quiet_hours_enabled': value},
                            )
                        : null,
                  ),
                  VistaSettingsTile(
                    icon: Icons.schedule_outlined,
                    title: 'زمان شروع/پایان',
                    subtitle: '$quietHoursStart - $quietHoursEnd',
                    onTap: !pushEnabled || !quietHoursEnabled
                        ? null
                        : () => _selectQuietHours(
                              context,
                              ref,
                              userId,
                              settings,
                              quietHoursStart,
                              quietHoursEnd,
                            ),
                  ),
                ],
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text('خطا در بارگذاری اعلان‌ها')),
        ),
      ),
    );
  }

  bool _isSocialEnabled(Map<String, dynamic> settings) {
    final like = settings['like_notifications'] as bool? ?? true;
    final comment = settings['comment_notifications'] as bool? ?? true;
    final follow = settings['follow_notifications'] as bool? ?? true;
    final story = settings['story_notifications'] as bool? ?? true;
    return like && comment && follow && story;
  }

  Future<void> _updateSettings(
    WidgetRef ref,
    String? userId,
    Map<String, dynamic> currentSettings,
    Map<String, dynamic> patch,
  ) async {
    if (userId == null) return;
    final merged = <String, dynamic>{...currentSettings, ...patch};
    await ref
        .read(notificationSettingsProvider(userId).notifier)
        .updateSettings(merged);
  }

  Future<void> _selectQuietHours(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    Map<String, dynamic> currentSettings,
    String start,
    String end,
  ) async {
    final startTime = await showTimePicker(
      context: context,
      initialTime: _parseTime(start),
    );
    if (startTime == null) return;
    if (!context.mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: _parseTime(end),
    );
    if (endTime == null) return;
    if (!context.mounted) return;

    await _updateSettings(ref, userId, currentSettings, {
      'quiet_hours_start': _formatTime(startTime),
      'quiet_hours_end': _formatTime(endTime),
    });
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 22, minute: 0);
    final hour = int.tryParse(parts[0]) ?? 22;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
