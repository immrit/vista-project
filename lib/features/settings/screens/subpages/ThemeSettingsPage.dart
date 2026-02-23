import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Vista/provider/theme_provider.dart';
import 'package:Vista/provider/settings_providers.dart';
import 'package:Vista/DB/advanced_settings_service.dart';
import 'package:Vista/services/animation_controller_service.dart';
import '../widgets/SettingsListItem.dart';

class ThemeSettingsPage extends ConsumerStatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  ConsumerState<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends ConsumerState<ThemeSettingsPage> {
  @override
  Widget build(BuildContext context) {
    // Removed selectedColor usage
    final brightness = ref.watch(brightnessProvider);
    final currentTheme = ref.watch(dynamicThemeProvider);
    final isDark = currentTheme.brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ظاهر و شخصی‌سازی'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          children: [
            // سوییچ تاریک/روشن با طراحی بهبود یافته
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SwitchListTile(
                title: Row(
                  children: [
                    const Text(
                      'حالت تاریک',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: brightness == Brightness.dark
                            ? Colors.grey.withValues(
                                alpha:
                                    0.2) // Changed from amber to grey for monochrome
                            : Colors.grey
                                .withValues(alpha: 0.2), // Changed from blue
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        brightness == Brightness.dark ? 'شب' : 'روز',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : Colors.black, // Monochrome text
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  brightness == Brightness.dark
                      ? 'تم تاریک برای استفاده راحت در شب'
                      : 'تم روشن برای استفاده در روز',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                value: brightness == Brightness.dark,
                onChanged: (value) {
                  ref.read(brightnessProvider.notifier).updateBrightness(
                      value ? Brightness.dark : Brightness.light);
                },
                secondary: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: brightness == Brightness.dark
                          ? [Colors.grey[800]!, Colors.black]
                          : [Colors.grey[300]!, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      brightness == Brightness.dark
                          ? Icons.nightlight_round
                          : Icons.wb_sunny,
                      key: ValueKey(brightness == Brightness.dark),
                      color: isDark ? Colors.white : Colors.black,
                      size: 24,
                    ),
                  ),
                ),
                activeThumbColor: isDark ? Colors.white : Colors.black,
                activeTrackColor: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            // REMOVED: Color Selection Container

            // تنظیمات عملکرد و انیمیشن
            _buildPerformanceSettingsCard(context, isDark, colorScheme),

            const SizedBox(height: 20),

            // تنظیمات دسترسی‌پذیری
            _buildAccessibilitySettingsCard(context, isDark, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSettingsCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final performanceAsync = ref.watch(performanceSettingsProvider);
    final appSettingsAsync = ref.watch(advancedAppSettingsProvider);
    final appearance =
        appSettingsAsync.value?['appearance'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.speed_rounded,
                      color: isDark ? Colors.white : Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'تنظیمات عملکرد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          performanceAsync.when(
            data: (settings) {
              final animations =
                  settings['animations'] as Map<String, dynamic>? ?? {};
              final rendering =
                  settings['rendering'] as Map<String, dynamic>? ?? {};
              final featureFlags =
                  settings['feature_flags'] as Map<String, dynamic>? ?? {};

              return Column(
                children: [
                  SettingsListItem(
                    icon: Icons.animation_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'انیمیشن‌ها',
                    subtitle: 'فعال/غیرفعال کردن انیمیشن‌ها',
                    trailing: Switch(
                      value: animations['enabled'] as bool? ?? true,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'animations': {...animations, 'enabled': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        await AnimationControllerService().loadSettings();
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.speed_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'سرعت انیمیشن',
                    subtitle: animations['speed'] == 'slow'
                        ? 'کند'
                        : animations['speed'] == 'fast'
                            ? 'سریع'
                            : 'عادی',
                    onTap: () => _showAnimationSpeedDialog(context, animations),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.accessibility_new_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'کاهش حرکت',
                    subtitle: 'برای کاربران حساس به حرکت',
                    trailing: Switch(
                      value: animations['reduce_motion'] as bool? ?? false,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'animations': {...animations, 'reduce_motion': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        await AnimationControllerService().loadSettings();
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.memory_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'شتاب‌دهی GPU',
                    subtitle: 'کنترل افکت‌های سنگین و بهبود روانی رندر',
                    trailing: Switch(
                      value:
                          rendering['enable_gpu_acceleration'] as bool? ?? true,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'rendering': {
                            ...rendering,
                            'enable_gpu_acceleration': value
                          }
                        });
                        ref.invalidate(performanceSettingsProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'افکت‌های پویا',
                    subtitle: 'تنظیم خودکار تاری و حرکت بر اساس فریم‌ریت',
                    trailing: Switch(
                      value: rendering['dynamic_effects'] as bool? ?? true,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'rendering': {...rendering, 'dynamic_effects': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.blur_on_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'حداکثر شدت تاری',
                    subtitle:
                        (rendering['max_blur_sigma'] as num? ?? 10).toString(),
                    onTap: () => _showMaxBlurSigmaDialog(context, rendering),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'انیمیشن ورود به چت',
                    subtitle: _chatEntryModeLabel(
                      (animations['chat_entry_mode'] as String?) ?? 'adaptive',
                    ),
                    onTap: () => _showChatEntryModeDialog(context, animations),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.emoji_emotions_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'استایل ایموجی',
                    subtitle: _emojiStyleLabel(
                      (appearance['emoji_style'] as String? ?? 'custom'),
                    ),
                    onTap: () => _showEmojiStyleDialog(context, appearance),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.flag_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'شتاب‌دهنده پرفورمنس چت (V1)',
                    subtitle: 'استفاده از الگوریتم جدید عملکرد',
                    trailing: Switch(
                      value: featureFlags['chat_perf_v1'] as bool? ?? true,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'feature_flags': {
                            ...featureFlags,
                            'chat_perf_v1': value,
                          }
                        });
                        ref.invalidate(performanceSettingsProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.flag_circle_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'افکت‌های تطبیقی (V1)',
                    subtitle: 'فعال‌سازی هوشمند تاری و تحرک با افت فریم',
                    trailing: Switch(
                      value:
                          featureFlags['adaptive_effects_v1'] as bool? ?? true,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'feature_flags': {
                            ...featureFlags,
                            'adaptive_effects_v1': value,
                          }
                        });
                        ref.invalidate(performanceSettingsProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.flag_outlined,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'توکن‌های حرکتی (V1)',
                    subtitle: 'فعال‌سازی بسته انیمیشن‌های روان و فشرده',
                    trailing: Switch(
                      value: featureFlags['motion_tokens_v1'] as bool? ?? true,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'feature_flags': {
                            ...featureFlags,
                            'motion_tokens_v1': value,
                          }
                        });
                        ref.invalidate(performanceSettingsProvider);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('خطا: $error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilitySettingsCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final appSettingsAsync = ref.watch(advancedAppSettingsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.accessibility_new_rounded,
                      color: isDark ? Colors.white : Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'دسترسی‌پذیری',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          appSettingsAsync.when(
            data: (settings) {
              final accessibility =
                  settings['accessibility'] as Map<String, dynamic>? ?? {};

              return Column(
                children: [
                  SettingsListItem(
                    icon: Icons.text_fields_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'متن بزرگ',
                    subtitle: 'افزایش اندازه متن',
                    trailing: Switch(
                      value: accessibility['large_text'] as bool? ?? false,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {
                            ...accessibility,
                            'large_text': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        ref.invalidate(dynamicThemeProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.format_bold_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'متن پررنگ',
                    subtitle: 'افزایش ضخامت متن',
                    trailing: Switch(
                      value: accessibility['bold_text'] as bool? ?? false,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {
                            ...accessibility,
                            'bold_text': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        ref.invalidate(dynamicThemeProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.contrast_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'کنتراست بالا',
                    subtitle: 'افزایش کنتراست رنگ‌ها',
                    trailing: Switch(
                      value: accessibility['high_contrast'] as bool? ?? false,
                      activeThumbColor: isDark ? Colors.white : Colors.black,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {
                            ...accessibility,
                            'high_contrast': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        ref.invalidate(dynamicThemeProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.color_lens_rounded,
                    iconColor: isDark ? Colors.white : Colors.black,
                    title: 'حالت رنگ‌کوری',
                    subtitle: _getColorBlindModeText(
                        accessibility['color_blind_mode'] as String? ?? 'none'),
                    onTap: () =>
                        _showColorBlindModeDialog(context, accessibility),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('خطا: $error'),
            ),
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

  void _showAnimationSpeedDialog(
      BuildContext context, Map<String, dynamic> animations) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سرعت انیمیشن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('کند'),
              value: 'slow',
              groupValue: animations['speed'] as String? ?? 'normal',
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'speed': value}
                });
                ref.invalidate(performanceSettingsProvider);
                await AnimationControllerService().loadSettings();
              },
            ),
            RadioListTile<String>(
              title: const Text('عادی'),
              value: 'normal',
              groupValue: animations['speed'] as String? ?? 'normal',
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'speed': value}
                });
                ref.invalidate(performanceSettingsProvider);
                await AnimationControllerService().loadSettings();
              },
            ),
            RadioListTile<String>(
              title: const Text('سریع'),
              value: 'fast',
              groupValue: animations['speed'] as String? ?? 'normal',
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'speed': value}
                });
                ref.invalidate(performanceSettingsProvider);
                await AnimationControllerService().loadSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChatEntryModeDialog(
      BuildContext context, Map<String, dynamic> animations) {
    final currentMode =
        (animations['chat_entry_mode'] as String?) ?? 'adaptive';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انیمیشن ورود به چت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('تطبیقی'),
              value: 'adaptive',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'chat_entry_mode': value}
                });
                ref.invalidate(performanceSettingsProvider);
              },
            ),
            RadioListTile<String>(
              title: const Text('کامل'),
              value: 'full',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'chat_entry_mode': value}
                });
                ref.invalidate(performanceSettingsProvider);
              },
            ),
            RadioListTile<String>(
              title: const Text('حداقل'),
              value: 'minimal',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'chat_entry_mode': value}
                });
                ref.invalidate(performanceSettingsProvider);
              },
            ),
            RadioListTile<String>(
              title: const Text('خاموش'),
              value: 'off',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'chat_entry_mode': value}
                });
                ref.invalidate(performanceSettingsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMaxBlurSigmaDialog(
      BuildContext context, Map<String, dynamic> rendering) {
    final initialSigma =
        ((rendering['max_blur_sigma'] as num?) ?? 10.0).toDouble();
    double selectedSigma = initialSigma.clamp(0.0, 16.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حداکثر شدت تاری'),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: selectedSigma,
                  min: 0,
                  max: 16,
                  divisions: 16,
                  label: selectedSigma.toStringAsFixed(1),
                  onChanged: (value) {
                    setLocalState(() => selectedSigma = value);
                  },
                ),
                Text(selectedSigma.toStringAsFixed(1)),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final service = AdvancedSettingsService();
              await service.updatePerformanceSettings({
                'rendering': {
                  ...rendering,
                  'max_blur_sigma': selectedSigma,
                }
              });
              ref.invalidate(performanceSettingsProvider);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  String _getColorBlindModeText(String mode) {
    switch (mode) {
      case 'protanopia':
        return 'پروتانوپیا (اختلال قرمز-سبز)';
      case 'deuteranopia':
        return 'دوتِرانوپیا (اختلال قرمز-سبز)';
      case 'tritanopia':
        return 'تریتانوپیا (اختلال آبی-زرد)';
      default:
        return 'غیرفعال';
    }
  }

  String _chatEntryModeLabel(String mode) {
    switch (mode.toLowerCase()) {
      case 'full':
        return 'کامل';
      case 'minimal':
        return 'حداقل';
      case 'off':
        return 'خاموش';
      case 'adaptive':
      default:
        return 'تطبیقی';
    }
  }

  String _emojiStyleLabel(String style) {
    switch (style.toLowerCase()) {
      case 'system':
        return 'سیستمی';
      case 'custom':
      default:
        return 'اختصاصی (آفلاین)';
    }
  }

  void _showColorBlindModeDialog(
      BuildContext context, Map<String, dynamic> accessibility) {
    final currentMode = accessibility['color_blind_mode'] as String? ?? 'none';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حالت رنگ‌کوری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('غیرفعال'),
              value: 'none',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                ref.invalidate(dynamicThemeProvider);
              },
            ),
            RadioListTile<String>(
              title: const Text('پروتانوپیا (اختلال قرمز-سبز)'),
              value: 'protanopia',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                ref.invalidate(dynamicThemeProvider);
              },
            ),
            RadioListTile<String>(
              title: const Text('دوتِرانوپیا (اختلال قرمز-سبز)'),
              value: 'deuteranopia',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                ref.invalidate(dynamicThemeProvider);
              },
            ),
            RadioListTile<String>(
              title: const Text('تریتانوپیا (اختلال آبی-زرد)'),
              value: 'tritanopia',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                ref.invalidate(dynamicThemeProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiStyleDialog(
      BuildContext context, Map<String, dynamic> appearance) {
    final currentStyle =
        (appearance['emoji_style'] as String? ?? 'custom').toLowerCase();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استایل ایموجی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('اختصاصی (آفلاین)'),
              value: 'custom',
              groupValue: currentStyle,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'appearance': {
                    ...appearance,
                    'emoji_style': value,
                  }
                });
                ref.invalidate(advancedAppSettingsProvider);
              },
            ),
            RadioListTile<String>(
              title: const Text('سیستمی'),
              value: 'system',
              groupValue: currentStyle,
              onChanged: (value) async {
                Navigator.pop(context);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'appearance': {
                    ...appearance,
                    'emoji_style': value,
                  }
                });
                ref.invalidate(advancedAppSettingsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
