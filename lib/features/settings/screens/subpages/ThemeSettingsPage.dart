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
      body: ListView(
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }

  Widget _buildPerformanceSettingsCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final performanceAsync = ref.watch(performanceSettingsProvider);

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
                    title: 'GPU Acceleration',
                    subtitle: 'افزایش سرعت رندرینگ',
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

  String _getColorBlindModeText(String mode) {
    switch (mode) {
      case 'protanopia':
        return 'Protanopia (قرمز-سبز)';
      case 'deuteranopia':
        return 'Deuteranopia (قرمز-سبز)';
      case 'tritanopia':
        return 'Tritanopia (آبی-زرد)';
      default:
        return 'غیرفعال';
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
              title: const Text('Protanopia (قرمز-سبز)'),
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
              title: const Text('Deuteranopia (قرمز-سبز)'),
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
              title: const Text('Tritanopia (آبی-زرد)'),
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
}
