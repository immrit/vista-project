import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../provider/settings_providers.dart';
import '../../../../DB/advanced_settings_service.dart';
import '../widgets/SettingsListItem.dart';

class AdvancedSettingsPage extends ConsumerStatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  ConsumerState<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends ConsumerState<AdvancedSettingsPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('تنظیمات پیشرفته'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              children: [
                // آمار کلی
                _buildStatsCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // تنظیمات عملکرد
                _buildPerformanceSettingsCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // تنظیمات ذخیره‌سازی
                _buildStorageSettingsCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // تنظیمات اپلیکیشن پیشرفته
                _buildAdvancedAppSettingsCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // تنظیمات دسترسی‌پذیری
                _buildAccessibilitySettingsCard(context, isDark, colorScheme),

                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildStatsCard(BuildContext context, bool isDark, ColorScheme colorScheme) {
    final statsAsync = ref.watch(cacheStatsProvider);

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
      child: statsAsync.when(
        data: (stats) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'آمار کلی',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatRow('حجم Cache', '${stats['cache_size_mb']} MB', isDark),
              const SizedBox(height: 8),
              _buildStatRow('حداکثر Cache', '${stats['max_cache_size_mb']} MB', isDark),
              const SizedBox(height: 8),
              _buildStatRow('درصد استفاده', '${stats['usage_percent']}%', isDark),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (stats['cache_size_mb'] as int) / (stats['max_cache_size_mb'] as int),
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  (stats['usage_percent'] as String).replaceAll('%', '').isEmpty
                      ? Colors.green
                      : double.parse((stats['usage_percent'] as String).replaceAll('%', '')) > 80
                          ? Colors.red
                          : double.parse((stats['usage_percent'] as String).replaceAll('%', '')) > 60
                              ? Colors.orange
                              : Colors.green,
                ),
              ),
            ],
          ),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text('خطا در دریافت آمار: $error'),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSettingsCard(BuildContext context, bool isDark, ColorScheme colorScheme) {
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
                  child: const Icon(Icons.speed_rounded, color: Colors.purple, size: 20),
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
              final animations = settings['animations'] as Map<String, dynamic>? ?? {};
              final rendering = settings['rendering'] as Map<String, dynamic>? ?? {};
              final battery = settings['battery'] as Map<String, dynamic>? ?? {};

              return Column(
                children: [
                  // انیمیشن‌ها
                  SettingsListItem(
                    icon: Icons.animation_rounded,
                    iconColor: Colors.blue,
                    title: 'انیمیشن‌ها',
                    subtitle: 'فعال/غیرفعال کردن انیمیشن‌ها',
                    trailing: Switch(
                      value: animations['enabled'] as bool? ?? true,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'animations': {...animations, 'enabled': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.speed_rounded,
                    iconColor: Colors.orange,
                    title: 'سرعت انیمیشن',
                    subtitle: animations['speed'] == 'slow' ? 'کند' : animations['speed'] == 'fast' ? 'سریع' : 'عادی',
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
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'animations': {...animations, 'reduce_motion': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  _buildDivider(),
                  // GPU Acceleration
                  SettingsListItem(
                    icon: Icons.memory_rounded,
                    iconColor: Colors.teal,
                    title: 'GPU Acceleration',
                    subtitle: 'افزایش سرعت رندرینگ',
                    trailing: Switch(
                      value: rendering['enable_gpu_acceleration'] as bool? ?? true,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'rendering': {...rendering, 'enable_gpu_acceleration': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  _buildDivider(),
                  // Battery Saver
                  SettingsListItem(
                    icon: Icons.battery_saver_rounded,
                    iconColor: Colors.green,
                    title: 'حالت ذخیره باتری',
                    subtitle: 'کاهش مصرف باتری',
                    trailing: Switch(
                      value: battery['power_save_mode'] as bool? ?? false,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updatePerformanceSettings({
                          'battery': {...battery, 'power_save_mode': value}
                        });
                        ref.invalidate(performanceSettingsProvider);
                        setState(() => _isLoading = false);
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

  Widget _buildStorageSettingsCard(BuildContext context, bool isDark, ColorScheme colorScheme) {
    final storageAsync = ref.watch(storageSettingsProvider);

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
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storage_rounded, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'تنظیمات ذخیره‌سازی',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          storageAsync.when(
            data: (settings) {
              final cache = settings['cache'] as Map<String, dynamic>? ?? {};

              return Column(
                children: [
                  SettingsListItem(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: Colors.blue,
                    title: 'پاکسازی خودکار Cache',
                    subtitle: 'پاکسازی خودکار فایل‌های قدیمی',
                    trailing: Switch(
                      value: cache['auto_clear_cache'] as bool? ?? true,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updateStorageSettings({
                          'cache': {...cache, 'auto_clear_cache': value}
                        });
                        ref.invalidate(storageSettingsProvider);
                        ref.invalidate(cacheStatsProvider);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.storage_rounded,
                    iconColor: Colors.purple,
                    title: 'حداکثر حجم Cache',
                    subtitle: '${cache['max_cache_size_mb'] ?? 500} MB',
                    onTap: () => _showMaxCacheSizeDialog(context, cache),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.delete_sweep_rounded,
                    iconColor: Colors.red,
                    title: 'پاکسازی دستی Cache',
                    subtitle: 'پاکسازی فوری تمام Cache',
                    onTap: () => _performManualCacheCleanup(context),
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

  Widget _buildAdvancedAppSettingsCard(BuildContext context, bool isDark, ColorScheme colorScheme) {
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
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.teal, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'تنظیمات اپلیکیشن',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          appSettingsAsync.when(
            data: (settings) {
              final feedback = settings['feedback'] as Map<String, dynamic>? ?? {};
              final security = settings['security'] as Map<String, dynamic>? ?? {};

              return Column(
                children: [
                  SettingsListItem(
                    icon: Icons.volume_up_rounded,
                    iconColor: Colors.blue,
                    title: 'صداهای سیستم',
                    subtitle: 'فعال/غیرفعال کردن صداها',
                    trailing: Switch(
                      value: feedback['enable_sound_effects'] as bool? ?? true,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'feedback': {...feedback, 'enable_sound_effects': value}
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.vibration_rounded,
                    iconColor: Colors.orange,
                    title: 'بازخورد لمسی',
                    subtitle: 'لرزش هنگام لمس',
                    trailing: Switch(
                      value: feedback['enable_haptic_feedback'] as bool? ?? true,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'feedback': {...feedback, 'enable_haptic_feedback': value}
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.lock_rounded,
                    iconColor: Colors.red,
                    title: 'قفل خودکار',
                    subtitle: security['auto_lock_enabled'] == true ? '${security['auto_lock_timeout_minutes']} دقیقه' : 'غیرفعال',
                    trailing: Switch(
                      value: security['auto_lock_enabled'] as bool? ?? true,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'security': {...security, 'auto_lock_enabled': value}
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        setState(() => _isLoading = false);
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

  Widget _buildAccessibilitySettingsCard(BuildContext context, bool isDark, ColorScheme colorScheme) {
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
                  child: const Icon(Icons.accessibility_new_rounded, color: Colors.indigo, size: 20),
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
              final accessibility = settings['accessibility'] as Map<String, dynamic>? ?? {};

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
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {...accessibility, 'large_text': value}
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        setState(() => _isLoading = false);
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
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {...accessibility, 'bold_text': value}
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        setState(() => _isLoading = false);
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
                        setState(() => _isLoading = true);
                        final service = AdvancedSettingsService();
                        await service.updateAdvancedAppSettings({
                          'accessibility': {...accessibility, 'high_contrast': value}
                        });
                        ref.invalidate(advancedAppSettingsProvider);
                        setState(() => _isLoading = false);
                      },
                    ),
                  ),
                  _buildDivider(),
                  SettingsListItem(
                    icon: Icons.color_lens_rounded,
                    iconColor: Colors.teal,
                    title: 'حالت رنگ‌کوری',
                    subtitle: _getColorBlindModeText(accessibility['color_blind_mode'] as String? ?? 'none'),
                    onTap: () => _showColorBlindModeDialog(context, accessibility),
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

  void _showAnimationSpeedDialog(BuildContext context, Map<String, dynamic> animations) {
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
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'speed': value}
                });
                ref.invalidate(performanceSettingsProvider);
                setState(() => _isLoading = false);
              },
            ),
            RadioListTile<String>(
              title: const Text('عادی'),
              value: 'normal',
              groupValue: animations['speed'] as String? ?? 'normal',
              onChanged: (value) async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'speed': value}
                });
                ref.invalidate(performanceSettingsProvider);
                setState(() => _isLoading = false);
              },
            ),
            RadioListTile<String>(
              title: const Text('سریع'),
              value: 'fast',
              groupValue: animations['speed'] as String? ?? 'normal',
              onChanged: (value) async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updatePerformanceSettings({
                  'animations': {...animations, 'speed': value}
                });
                ref.invalidate(performanceSettingsProvider);
                setState(() => _isLoading = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMaxCacheSizeDialog(BuildContext context, Map<String, dynamic> cache) {
    final controller = TextEditingController(
      text: (cache['max_cache_size_mb'] as int? ?? 500).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حداکثر حجم Cache (MB)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'حجم به مگابایت',
            hintText: '500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updateStorageSettings({
                  'cache': {...cache, 'max_cache_size_mb': value}
                });
                ref.invalidate(storageSettingsProvider);
                ref.invalidate(cacheStatsProvider);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showColorBlindModeDialog(BuildContext context, Map<String, dynamic> accessibility) {
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
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                setState(() => _isLoading = false);
              },
            ),
            RadioListTile<String>(
              title: const Text('Protanopia (قرمز-سبز)'),
              value: 'protanopia',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                setState(() => _isLoading = false);
              },
            ),
            RadioListTile<String>(
              title: const Text('Deuteranopia (قرمز-سبز)'),
              value: 'deuteranopia',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                setState(() => _isLoading = false);
              },
            ),
            RadioListTile<String>(
              title: const Text('Tritanopia (آبی-زرد)'),
              value: 'tritanopia',
              groupValue: currentMode,
              onChanged: (value) async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final service = AdvancedSettingsService();
                await service.updateAdvancedAppSettings({
                  'accessibility': {...accessibility, 'color_blind_mode': value}
                });
                ref.invalidate(advancedAppSettingsProvider);
                setState(() => _isLoading = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performManualCacheCleanup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاکسازی Cache'),
        content: const Text('آیا مطمئن هستید که می‌خواهید تمام Cache را پاک کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('پاکسازی'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final service = AdvancedSettingsService();
      final result = await service.manualCacheCleanup();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'پاکسازی انجام شد. ${result['cleaned_mb']} MB آزاد شد.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      ref.invalidate(cacheStatsProvider);
      ref.invalidate(storageSettingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در پاکسازی: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

