import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Vista/utils/themes.dart';
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
    final selectedColor = ref.watch(selectedColorProvider);
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
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      brightness == Brightness.dark ? 'شب' : 'روز',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: brightness == Brightness.dark
                            ? Colors.amber[700]
                            : Colors.blue[700],
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
                        ? [Colors.amber[400]!, Colors.orange[400]!]
                        : [Colors.blue[400]!, Colors.lightBlue[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (brightness == Brightness.dark
                              ? Colors.amber
                              : Colors.blue)
                          .withValues(alpha: 0.4),
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
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              activeThumbColor:
                  brightness == Brightness.dark ? Colors.amber : Colors.blue,
            ),
          ),

          const SizedBox(height: 20),

          // انتخاب رنگ تم
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "انتخاب رنگ تم",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "رنگ مورد نظر خود را انتخاب کنید",
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 20),

                  // پیش‌نمایش تم‌ها به صورت افقی قابل اسکرول
                  SizedBox(
                    height: 240, // ارتفاع ثابت برای پیش‌نمایش‌ها
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      children: [
                        _buildThemePreview(
                          context,
                          color: ThemeColor.white,
                          label: 'سفید',
                          isSelected: selectedColor == ThemeColor.white,
                          brightness: brightness,
                          onTap: () {
                            ref
                                .read(selectedColorProvider.notifier)
                                .updateColor(ThemeColor.white);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildThemePreview(
                          context,
                          color: ThemeColor.blue,
                          label: 'آبی',
                          isSelected: selectedColor == ThemeColor.blue,
                          brightness: brightness,
                          onTap: () {
                            ref
                                .read(selectedColorProvider.notifier)
                                .updateColor(ThemeColor.blue);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildThemePreview(
                          context,
                          color: ThemeColor.red,
                          label: 'قرمز',
                          isSelected: selectedColor == ThemeColor.red,
                          brightness: brightness,
                          onTap: () {
                            ref
                                .read(selectedColorProvider.notifier)
                                .updateColor(ThemeColor.red);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildThemePreview(
                          context,
                          color: ThemeColor.yellow,
                          label: 'زرد',
                          isSelected: selectedColor == ThemeColor.yellow,
                          brightness: brightness,
                          onTap: () {
                            ref
                                .read(selectedColorProvider.notifier)
                                .updateColor(ThemeColor.yellow);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildThemePreview(
                          context,
                          color: ThemeColor.teal,
                          label: 'سبزآبی',
                          isSelected: selectedColor == ThemeColor.teal,
                          brightness: brightness,
                          onTap: () {
                            ref
                                .read(selectedColorProvider.notifier)
                                .updateColor(ThemeColor.teal);
                          },
                        ),
                        const SizedBox(width: 4), // فاصله انتهایی
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // راهنمای تم‌ها
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        "راهنمای تم‌ها",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "ابتدا حالت تاریک یا روشن را انتخاب کنید، سپس رنگ مورد نظر خود را از بین رنگ‌های موجود انتخاب کنید. تنظیمات انتخاب شده در تمام بخش‌های برنامه اعمال خواهد شد.",
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

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
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.speed_rounded,
                      color: Colors.purple, size: 20),
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
                    iconColor: Colors.blue,
                    title: 'انیمیشن‌ها',
                    subtitle: 'فعال/غیرفعال کردن انیمیشن‌ها',
                    trailing: Switch(
                      value: animations['enabled'] as bool? ?? true,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'animations': {...animations, 'enabled': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        // به‌روزرسانی AnimationControllerService
                        await AnimationControllerService().loadSettings();
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.speed_rounded,
                    iconColor: Colors.orange,
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
                    iconColor: Colors.green,
                    title: 'کاهش حرکت',
                    subtitle: 'برای کاربران حساس به حرکت',
                    trailing: Switch(
                      value: animations['reduce_motion'] as bool? ?? false,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'animations': {...animations, 'reduce_motion': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        // به‌روزرسانی AnimationControllerService
                        await AnimationControllerService().loadSettings();
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.memory_rounded,
                    iconColor: Colors.teal,
                    title: 'GPU Acceleration',
                    subtitle: 'افزایش سرعت رندرینگ',
                    trailing: Switch(
                      value:
                          rendering['enable_gpu_acceleration'] as bool? ?? true,
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
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.accessibility_new_rounded,
                      color: Colors.indigo, size: 20),
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
                    iconColor: Colors.blue,
                    title: 'متن بزرگ',
                    subtitle: 'افزایش اندازه متن',
                    trailing: Switch(
                      value: accessibility['large_text'] as bool? ?? false,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {
                            ...accessibility,
                            'large_text': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        // Force rebuild theme
                        ref.invalidate(dynamicThemeProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.format_bold_rounded,
                    iconColor: Colors.purple,
                    title: 'متن پررنگ',
                    subtitle: 'افزایش ضخامت متن',
                    trailing: Switch(
                      value: accessibility['bold_text'] as bool? ?? false,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {
                            ...accessibility,
                            'bold_text': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        // Force rebuild theme
                        ref.invalidate(dynamicThemeProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.contrast_rounded,
                    iconColor: Colors.orange,
                    title: 'کنتراست بالا',
                    subtitle: 'افزایش کنتراست رنگ‌ها',
                    trailing: Switch(
                      value: accessibility['high_contrast'] as bool? ?? false,
                      onChanged: (value) async {
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {
                            ...accessibility,
                            'high_contrast': value
                          }
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        // Force rebuild theme
                        ref.invalidate(dynamicThemeProvider);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.color_lens_rounded,
                    iconColor: Colors.teal,
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
                // به‌روزرسانی AnimationControllerService
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
                // به‌روزرسانی AnimationControllerService
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
                // به‌روزرسانی AnimationControllerService
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
                // Force rebuild theme
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
                // Force rebuild theme
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
                // Force rebuild theme
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
                // Force rebuild theme
                ref.invalidate(dynamicThemeProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  // متد پیش‌نمایش تم با شبیه‌سازی publicPosts
  Widget _buildThemePreview(
    BuildContext context, {
    required ThemeColor color,
    required String label,
    required bool isSelected,
    required Brightness brightness,
    required VoidCallback onTap,
  }) {
    final themeData = createTheme(color, brightness);
    final previewIsDark = themeData.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? themeData.primaryColor
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? themeData.primaryColor.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: isSelected ? 12 : 8,
              offset: Offset(0, isSelected ? 6 : 4),
            ),
          ],
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeData.primaryColor.withValues(alpha: 0.1),
                    themeData.primaryColor.withValues(alpha: 0.05),
                  ],
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 160, // عرض ثابت برای هر پیش‌نمایش
            height: 200, // ارتفاع کمی بیشتر برای تناسب بهتر
            color: previewIsDark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF5F5F5),
            child: Column(
              children: [
                // هدر با نام تم و gradient
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeData.primaryColor,
                        themeData.primaryColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.palette,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        AnimatedScale(
                          scale: isSelected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.check,
                              color: themeData.primaryColor,
                              size: 14,
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),

                // محتوای شبیه‌سازی شده
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // شبیه‌سازی AppBar
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: themeData.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Icon(Icons.public, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              const Text(
                                'Vista',
                                style: TextStyle(
                                  fontFamily: 'Bauhaus',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.favorite_border,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // شبیه‌سازی TabBar
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: previewIsDark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 20,
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: themeData.primaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'همه پست‌ها',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 20,
                                  margin: const EdgeInsets.all(2),
                                  child: Center(
                                    child: Text(
                                      'دنبال‌شده‌ها',
                                      style: TextStyle(
                                        color: previewIsDark
                                            ? Colors.white70
                                            : Colors.black54,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // شبیه‌سازی Story Bar
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                previewIsDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              ...List.generate(
                                  4,
                                  (index) => Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                themeData.primaryColor,
                                                themeData.primaryColor
                                                    .withValues(alpha: 0.7),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 1),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 8,
                                          ),
                                        ),
                                      )),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // شبیه‌سازی پست
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: previewIsDark
                                  ? Colors.grey[800]
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: previewIsDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[100]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // هدر پست
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: themeData.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person,
                                          color: Colors.white, size: 6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'کاربر نمونه',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: previewIsDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 8,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.more_vert,
                                      color: previewIsDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 8,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                // متن پست
                                Text(
                                  'این یک پست نمونه است',
                                  style: TextStyle(
                                    color: previewIsDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 7,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // تصویر نمونه
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: themeData.primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.image,
                                        color: themeData.primaryColor,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // دکمه‌های تعامل
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite_border,
                                      color: previewIsDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 8,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '12',
                                      style: TextStyle(
                                        fontSize: 6,
                                        color: previewIsDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.comment_outlined,
                                      color: previewIsDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 8,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '3',
                                      style: TextStyle(
                                        fontSize: 6,
                                        color: previewIsDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
