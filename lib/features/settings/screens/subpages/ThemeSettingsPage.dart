import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Vista/DB/advanced_settings_service.dart';
import 'package:Vista/features/chat/performance/adaptive_effects_provider.dart';
import 'package:Vista/provider/settings_providers.dart';
import 'package:Vista/provider/theme_provider.dart';
import 'package:Vista/services/animation_controller_service.dart';
import '../../widgets/vista_settings_widgets.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final performanceAsync = ref.watch(performanceSettingsProvider);
    final appSettingsAsync = ref.watch(advancedAppSettingsProvider);
    final adaptiveEffects = ref.watch(adaptiveEffectsProvider);
    final frameBudgetService = ref.watch(frameBudgetServiceProvider);

    final performanceSettings = performanceAsync.value ?? {};
    final appSettings = appSettingsAsync.value ?? {};
    final animations =
        performanceSettings['animations'] as Map<String, dynamic>? ?? {};
    final appearance = appSettings['appearance'] as Map<String, dynamic>? ?? {};

    final reduceMotion = animations['reduce_motion'] as bool? ?? false;
    final chatEntryMode =
        (animations['chat_entry_mode'] as String?) ?? 'adaptive';
    final emojiStyle = (appearance['emoji_style'] as String?) ?? 'custom';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('ظاهر'),
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
            const VistaSettingsSection(
              title: 'پوسته',
              padding: EdgeInsets.fromLTRB(32, 0, 32, 8),
            ),
            VistaSettingsGroup(
              children: [
                VistaSettingsChoice<ThemeMode>(
                  icon: Icons.palette_outlined,
                  title: 'حالت نمایش',
                  value: themeMode,
                  options: const [
                    VistaChoiceOption(
                      value: ThemeMode.system,
                      label: 'پیروی از سیستم',
                    ),
                    VistaChoiceOption(
                      value: ThemeMode.light,
                      label: 'روشن',
                    ),
                    VistaChoiceOption(
                      value: ThemeMode.dark,
                      label: 'تاریک',
                    ),
                  ],
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).updateThemeMode(value);
                  },
                ),
              ],
            ),
            const VistaSettingsSection(title: 'تجربه کاربری'),
            VistaSettingsGroup(
              children: [
                VistaSettingsSwitch(
                  icon: Icons.accessibility_new_outlined,
                  title: 'کاهش حرکت',
                  subtitle: 'کم کردن انیمیشن‌ها برای راحتی چشم',
                  value: reduceMotion,
                  onChanged: (value) async {
                    await _updateAnimationSettings({
                      ...animations,
                      'reduce_motion': value,
                    });
                    ref.invalidate(performanceSettingsProvider);
                    await AnimationControllerService().loadSettings();
                  },
                ),
                VistaSettingsChoice<String>(
                  icon: Icons.chat_bubble_outline,
                  title: 'انیمیشن ورود پیام',
                  value: _mapChatEntryModeForUi(chatEntryMode),
                  options: const [
                    VistaChoiceOption(value: 'adaptive', label: 'تطبیقی'),
                    VistaChoiceOption(value: 'minimal', label: 'کم'),
                    VistaChoiceOption(value: 'off', label: 'خاموش'),
                  ],
                  onChanged: (value) async {
                    await _updateAnimationSettings({
                      ...animations,
                      'chat_entry_mode': value,
                    });
                    ref.invalidate(performanceSettingsProvider);
                  },
                ),
                VistaSettingsChoice<String>(
                  icon: Icons.emoji_emotions_outlined,
                  title: 'استایل ایموجی',
                  value: emojiStyle.toLowerCase() == 'system'
                      ? 'system'
                      : 'custom',
                  options: const [
                    VistaChoiceOption(value: 'custom', label: 'اختصاصی'),
                    VistaChoiceOption(value: 'system', label: 'سیستمی'),
                  ],
                  onChanged: (value) async {
                    await _updateAppearanceSettings({
                      ...appearance,
                      'emoji_style': value,
                    });
                    ref.invalidate(advancedAppSettingsProvider);
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'بهینه‌سازی‌های فنی مثل GPU، تاری و تنظیمات عملکرد در پس‌زمینه و به‌صورت خودکار انجام می‌شوند.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            ),
            if (kDebugMode) ...[
              const VistaSettingsSection(title: 'عیب‌یابی Auto-Optimize'),
              VistaSettingsGroup(
                children: [
                  VistaSettingsTile(
                    icon: Icons.speed_outlined,
                    title: 'سطح افکت',
                    subtitle: adaptiveEffects.effectsLevel.name,
                    showArrow: false,
                    onTap: () {},
                  ),
                  VistaSettingsTile(
                    icon: Icons.auto_graph_outlined,
                    title: 'دلیل تصمیم',
                    subtitle: adaptiveEffects.optimizationReason,
                    showArrow: false,
                    onTap: () {},
                  ),
                  VistaSettingsTile(
                    icon: Icons.blur_on_outlined,
                    title: 'Blur Sigma',
                    subtitle: adaptiveEffects.blurSigma.toStringAsFixed(1),
                    showArrow: false,
                    onTap: () {},
                  ),
                  VistaSettingsTile(
                    icon: Icons.swap_vert_outlined,
                    title: 'حالت ورود پیام',
                    subtitle: adaptiveEffects.chatEntryMode.name,
                    showArrow: false,
                    onTap: () {},
                  ),
                  VistaSettingsTile(
                    icon: Icons.stacked_line_chart_outlined,
                    title: 'پروفایل فریم',
                    subtitle:
                        '${adaptiveEffects.profile.name} | p95: ${adaptiveEffects.budgetSnapshot.p95Ms.toStringAsFixed(1)}ms | jank: ${(adaptiveEffects.budgetSnapshot.jankRatio * 100).toStringAsFixed(1)}%',
                    showArrow: false,
                    onTap: () {},
                  ),
                  VistaSettingsTile(
                    icon: Icons.phone_android_outlined,
                    title: 'Warm-start tier',
                    subtitle:
                        '${frameBudgetService.deviceTier.name} | ${frameBudgetService.warmStartReason}',
                    showArrow: false,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateAnimationSettings(Map<String, dynamic> animations) async {
    final service = AdvancedSettingsService();
    await service.updatePerformanceSettings({
      'animations': animations,
    });
  }

  Future<void> _updateAppearanceSettings(
      Map<String, dynamic> appearance) async {
    final service = AdvancedSettingsService();
    await service.updateAdvancedAppSettings({
      'appearance': appearance,
    });
  }

  String _mapChatEntryModeForUi(String mode) {
    if (mode == 'off') return 'off';
    if (mode == 'minimal') return 'minimal';
    return 'adaptive';
  }
}
