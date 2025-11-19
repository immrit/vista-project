import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/cache_manager.dart';
import '../../../../provider/settings_providers.dart';
import '../../../../DB/advanced_settings_service.dart';
import '../widgets/SettingsListItem.dart';

class CacheManagementSettingsPage extends ConsumerStatefulWidget {
  const CacheManagementSettingsPage({super.key});

  @override
  ConsumerState<CacheManagementSettingsPage> createState() =>
      _CacheManagementSettingsPageState();
}

class _CacheManagementSettingsPageState
    extends ConsumerState<CacheManagementSettingsPage> {
  final UnifiedCacheManager _cacheManager = UnifiedCacheManager();
  bool _isLoading = false;
  Map<String, dynamic> _cacheStats = {};

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _cacheManager.getCacheStats();
      setState(() => _cacheStats = stats);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت آمار کش: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performSmartCleanup() async {
    setState(() => _isLoading = true);
    try {
      final result = await _cacheManager.smartCleanup();
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${result['message']}\n${result['items_removed']} مورد حذف شد - ${result['space_freed_mb'].toStringAsFixed(1)}MB آزاد شد'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      await _loadCacheStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در پاکسازی هوشمند: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performAutoOptimization() async {
    setState(() => _isLoading = true);
    try {
      final result = await _cacheManager.autoOptimizeCache();
      if (result['success'] == true) {
        final optimizations = result['optimizations'] as List<String>? ?? [];
        final optimizationsText = optimizations.isNotEmpty
            ? '\nبهینه‌سازی‌ها: ${optimizations.join(', ')}'
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${result['message']}\n${result['optimizations_applied']} بهینه‌سازی اعمال شد - ${result['space_saved_mb'].toStringAsFixed(1)}MB صرفه‌جویی شد$optimizationsText'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      await _loadCacheStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بهینه‌سازی خودکار: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAllCaches() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک‌سازی کامل کش'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید تمام کش‌ها را پاک کنید؟\nاین عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('پاک‌سازی'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await _cacheManager.clearAllCaches();
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${result['message']}\n${result['space_freed_mb'].toStringAsFixed(1)}MB آزاد شد'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      await _loadCacheStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در پاکسازی: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('مدیریت کش و حافظه'),
        centerTitle: true,
        elevation: 0,
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            onPressed: _loadCacheStats,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              children: [
                // آمار کلی کش
                _buildCacheOverviewCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // آمار کش تصاویر
                _buildImageCacheCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // آمار کش دیتابیس
                _buildDatabaseCacheCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // تنظیمات هوشمند
                _buildSmartSettingsCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // تنظیمات ذخیره‌سازی
                _buildStorageSettingsCard(context, isDark, colorScheme),

                const SizedBox(height: 20),

                // عملیات پاکسازی
                _buildCleanupActionsCard(context, isDark, colorScheme),
              ],
            ),
    );
  }

  Widget _buildCacheOverviewCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final totalSize = _cacheStats['total_size_mb'] ?? 0.0;
    final maxSize = _cacheStats['max_cache_size_mb'] ?? 500.0;
    final usagePercentage = (totalSize / maxSize).clamp(0.0, 1.0);

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
      child: Padding(
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
                  child: const Icon(Icons.storage_rounded,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'نمای کلی کش',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${totalSize.toStringAsFixed(1)} MB از ${maxSize.toStringAsFixed(0)} MB',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: usagePercentage,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercentage > 0.8
                    ? Colors.red
                    : usagePercentage > 0.6
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(usagePercentage * 100).toStringAsFixed(1)}% استفاده شده',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCacheCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final imageCache =
        _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};

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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_rounded,
                      color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'کش تصاویر',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCacheItem('استوری‌ها', imageCache['story_cache'], isDark),
            const SizedBox(height: 12),
            _buildCacheItem('پست‌ها', imageCache['post_cache'], isDark),
            const SizedBox(height: 12),
            _buildCacheItem('چت', imageCache['chat_cache'], isDark),
            const SizedBox(height: 12),
            _buildCacheItem('والپیپر', imageCache['wallpaper_cache'], isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseCacheCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final dbCache =
        _cacheStats['database_cache'] as Map<String, dynamic>? ?? {};

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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.storage_rounded,
                      color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'کش دیتابیس',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDatabaseCacheItem('کانال‌ها', dbCache['channels'] ?? 0,
                dbCache['channel_cache_size_mb'] ?? 0.0, isDark),
            const SizedBox(height: 12),
            _buildDatabaseCacheItem('پیام‌های کانال',
                dbCache['channel_messages'] ?? 0, null, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartSettingsCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final smartCacheEnabled = _cacheStats['smart_cache_enabled'] ?? true;
    final batterySaverMode = _cacheStats['battery_saver_mode'] ?? false;

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
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'تنظیمات هوشمند',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SettingsListItem(
            icon: Icons.smart_toy_rounded,
            iconColor: Colors.blue,
            title: 'کش هوشمند',
            subtitle: 'پاکسازی خودکار کش‌های قدیمی',
            trailing: Switch(
              value: smartCacheEnabled,
              onChanged: (value) {
                _cacheManager.setSmartCacheEnabled(value);
                setState(() => _cacheStats['smart_cache_enabled'] = value);
              },
            ),
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.battery_saver_rounded,
            iconColor: Colors.green,
            title: 'حالت ذخیره باتری',
            subtitle: 'کاهش مصرف باتری با محدود کردن کش',
            trailing: Switch(
              value: batterySaverMode,
              onChanged: (value) {
                _cacheManager.setBatterySaverMode(value);
                setState(() => _cacheStats['battery_saver_mode'] = value);
              },
            ),
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.image_rounded,
            iconColor: Colors.blue,
            title: 'کش تصاویر',
            subtitle: 'ذخیره تصاویر برای دسترسی سریع‌تر',
            trailing: Switch(
              value: _cacheStats['image_cache_enabled'] ?? true,
              onChanged: (value) {
                _cacheManager.setImageCacheEnabled(value);
                setState(() => _cacheStats['image_cache_enabled'] = value);
              },
            ),
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.music_note_rounded,
            iconColor: Colors.purple,
            title: 'کش موزیک',
            subtitle: 'ذخیره فایل‌های صوتی برای پخش آفلاین',
            trailing: Switch(
              value: _cacheStats['music_cache_enabled'] ?? true,
              onChanged: (value) {
                _cacheManager.setMusicCacheEnabled(value);
                setState(() => _cacheStats['music_cache_enabled'] = value);
              },
            ),
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.video_library_rounded,
            iconColor: Colors.red,
            title: 'کش کلیپ‌ها',
            subtitle: 'ذخیره ویدیوها برای پخش آفلاین',
            trailing: Switch(
              value: _cacheStats['video_cache_enabled'] ?? true,
              onChanged: (value) {
                _cacheManager.setVideoCacheEnabled(value);
                setState(() => _cacheStats['video_cache_enabled'] = value);
              },
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

  Widget _buildCleanupActionsCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cleaning_services_rounded,
                      color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'عملیات پاکسازی',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SettingsListItem(
            icon: Icons.auto_fix_high_rounded,
            iconColor: Colors.blue,
            title: 'پاکسازی هوشمند',
            subtitle: 'پاکسازی خودکار کش‌های قدیمی و غیرضروری',
            onTap: _performSmartCleanup,
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.tune_rounded,
            iconColor: Colors.purple,
            title: 'بهینه‌سازی خودکار',
            subtitle: 'بهینه‌سازی کامل کش بر اساس الگوی استفاده',
            onTap: _performAutoOptimization,
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.delete_sweep_rounded,
            iconColor: Colors.red,
            title: 'پاک‌سازی کامل',
            subtitle: 'پاک‌سازی تمام کش‌ها (غیرقابل بازگشت)',
            onTap: _clearAllCaches,
          ),
        ],
      ),
    );
  }

  Widget _buildCacheItem(String title, dynamic cacheData, bool isDark) {
    if (cacheData == null) {
      return Text(
        '$title: اطلاعات موجود نیست',
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      );
    }

    final data = cacheData as Map<String, dynamic>;
    final items = data['items'] ?? 0;
    final size = data['size_mb'] ?? 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Text(
          '$items مورد - ${size.toStringAsFixed(1)} MB',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseCacheItem(
      String title, int count, double? size, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Text(
          size != null
              ? '$count مورد - ${size.toStringAsFixed(1)} MB'
              : '$count مورد',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(left: 68.0),
          height: 0.5,
          color: isDark ? Colors.grey[300] : Colors.grey[200],
        );
      },
    );
  }
}
