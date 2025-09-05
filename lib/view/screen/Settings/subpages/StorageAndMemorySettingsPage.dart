import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../provider/provider.dart';
import '../../../../services/storage_info_service.dart';
import '../../../../services/cache_manager.dart';
import '../widgets/SettingsListItem.dart';

class StorageAndMemorySettingsPage extends ConsumerStatefulWidget {
  const StorageAndMemorySettingsPage({super.key});

  static final StorageInfoService _storageService = StorageInfoService();

  @override
  ConsumerState<StorageAndMemorySettingsPage> createState() =>
      _StorageAndMemorySettingsPageState();
}

class _StorageAndMemorySettingsPageState
    extends ConsumerState<StorageAndMemorySettingsPage> {
  final UnifiedCacheManager _cacheManager = UnifiedCacheManager();
  bool _isLoading = false;
  Map<String, dynamic> _cacheStats = {};

  @override
  void initState() {
    super.initState();
    _initializeCacheManager();
  }

  Future<void> _initializeCacheManager() async {
    try {
      await _cacheManager.initialize();
      await _loadCacheStats();
    } catch (e) {
      print('خطا در مقداردهی کش منیجر: $e');
      // در صورت خطا، باز هم سعی کن آمار را بارگذاری کن
      await _loadCacheStats();
    }
  }

  Future<void> _loadCacheStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _cacheManager.getCacheStats();
      setState(() => _cacheStats = stats);

      // تست داده‌ها برای بررسی صحت
      _testCacheData(stats);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت آمار کش: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMaxCacheSizeDialog() {
    final currentSize = _cacheStats['max_cache_size_mb'] ?? 200;
    double sliderValue = currentSize.toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تنظیم حداکثر حجم کش'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${sliderValue.round()} مگابایت',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.orange,
                  inactiveTrackColor: Colors.grey[300],
                  thumbColor: Colors.orange,
                  overlayColor: Colors.orange.withValues(alpha: 0.2),
                  valueIndicatorColor: Colors.orange,
                  valueIndicatorTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Slider(
                  value: sliderValue,
                  min: 50.0,
                  max: 1000.0,
                  divisions: 19,
                  label: '${sliderValue.round()} MB',
                  onChanged: (double value) {
                    setState(() {
                      sliderValue = value;
                    });
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '50MB',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '1000MB',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'مقادیر پیشنهادی: 100MB (کم), 200MB (متوسط), 500MB (زیاد)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () {
                final newSize = sliderValue.round();
                _cacheManager.setMaxCacheSize(newSize);
                this.setState(() => _cacheStats['max_cache_size_mb'] = newSize);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('حداکثر حجم کش به $newSize مگابایت تغییر کرد'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('تأیید'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedCleanupButton(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        children: [
          // دکمه اصلی پاکسازی
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[400]!,
                  Colors.blue[600]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showCleanupOptionsDialog(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_fix_high_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          Text(
                            'پاکسازی کش',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'هوشمند یا کامل',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // دکمه‌های سریع
          Row(
            children: [
              Expanded(
                child: _buildQuickCleanupButton(
                  'پاکسازی هوشمند',
                  Icons.auto_fix_high_rounded,
                  Colors.green,
                  () => _performSmartCleanup(),
                  isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickCleanupButton(
                  'پاکسازی کامل',
                  Icons.delete_sweep_rounded,
                  Colors.red,
                  () => _clearAllCaches(),
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCleanupButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCleanupOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتخاب نوع پاکسازی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('نوع پاکسازی مورد نظر خود را انتخاب کنید:'),
            const SizedBox(height: 20),
            _buildCleanupOption(
              context,
              'پاکسازی هوشمند',
              'حذف داده‌های قدیمی و حفظ داده‌های مهم',
              Icons.auto_fix_high_rounded,
              Colors.green,
              () {
                Navigator.pop(context);
                _performSmartCleanup();
              },
            ),
            const SizedBox(height: 12),
            _buildCleanupOption(
              context,
              'پاکسازی کامل',
              'حذف تمام کش‌ها و آزادسازی حداکثر فضا',
              Icons.delete_sweep_rounded,
              Colors.red,
              () {
                Navigator.pop(context);
                _clearAllCaches();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _testCacheData(Map<String, dynamic> stats) {
    print('=== تست داده‌های کش ===');
    print('مجموع کش: ${stats['total_size_mb']} MB');
    print('حداکثر حجم کش: ${stats['max_cache_size_mb']} MB');
    print('کش هوشمند فعال: ${stats['smart_cache_enabled']}');
    print('حالت ذخیره باتری: ${stats['battery_saver_mode']}');

    final imageCache = stats['image_cache'] as Map<String, dynamic>? ?? {};
    print('\n--- کش تصاویر ---');
    print(
        'کش استوری: ${imageCache['story_cache']?['size_mb']} MB (${imageCache['story_cache']?['items']} فایل)');
    print(
        'کش پست: ${imageCache['post_cache']?['size_mb']} MB (${imageCache['post_cache']?['items']} فایل)');
    print(
        'کش چت: ${imageCache['chat_cache']?['size_mb']} MB (${imageCache['chat_cache']?['items']} فایل)');
    print(
        'کش والپیپر: ${imageCache['wallpaper_cache']?['size_mb']} MB (${imageCache['wallpaper_cache']?['items']} فایل)');

    // بررسی اینکه آیا مقادیر متفاوت هستند
    final imageValues = [
      imageCache['story_cache']?['size_mb'] ?? 0.0,
      imageCache['post_cache']?['size_mb'] ?? 0.0,
      imageCache['chat_cache']?['size_mb'] ?? 0.0,
      imageCache['wallpaper_cache']?['size_mb'] ?? 0.0,
    ];

    final uniqueValues = imageValues.toSet();
    if (uniqueValues.length > 1) {
      print('\n✅ مقادیر کش متفاوت هستند - داده‌ها درست مقداردهی شده‌اند');
    } else {
      print('\n❌ مقادیر کش یکسان هستند - مشکل در مقداردهی');
    }

    // بررسی مقادیر صفر
    final zeroValues = imageValues.where((value) => value == 0.0).length;
    if (zeroValues == imageValues.length) {
      print('⚠️ همه مقادیر کش صفر هستند - ممکن است کش خالی باشد');
    }

    print('=== پایان تست ===');
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
    return Consumer(
      builder: (context, ref, child) {
        final autoPlay = ref.watch(autoPlayProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('داده‌ها و ذخیره‌سازی'),
            centerTitle: true,
            elevation: 0,
            backgroundColor:
                isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
            foregroundColor: isDark ? Colors.white : Colors.black,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            children: [
              // بخش مدیریت کش پیشرفته
              _buildCacheManagementSection(context, ref, isDark, colorScheme),

              const SizedBox(height: 20),

              // بخش تنظیمات ویدیو
              _buildVideoSettingsSection(
                  context, ref, autoPlay, isDark, colorScheme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoSettingsSection(BuildContext context, WidgetRef ref,
      bool autoPlay, bool isDark, ColorScheme colorScheme) {
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
                Icon(
                  Icons.video_settings_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'تنظیمات ویدیو',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          SettingsListItem(
            icon: Icons.save_alt,
            iconColor: Colors.orange,
            title: 'حالت ذخیره داده',
            subtitle: 'پخش ویدیو با کیفیت پایین برای صرفه‌جویی در داده',
            trailing: Switch(
              value: ref.watch(dataSaverProvider),
              onChanged: (value) {
                ref.read(dataSaverProvider.notifier).set(value);
              },
            ),
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.auto_awesome,
            iconColor: Colors.blue,
            title: 'تنظیم خودکار کیفیت',
            subtitle: 'تنظیم خودکار کیفیت بر اساس سرعت اینترنت',
            trailing: Switch(
              value: ref.watch(autoQualityProvider),
              onChanged: (value) {
                ref.read(autoQualityProvider.notifier).set(value);
              },
            ),
          ),
          _buildDivider(),
          SettingsListItem(
            icon: Icons.play_circle_filled,
            iconColor: Colors.green,
            title: 'پخش خودکار ویدیو',
            subtitle: 'ویدیوها به محض باز شدن پخش شوند',
            trailing: Switch(
              value: autoPlay,
              onChanged: (val) {
                ref.read(autoPlayProvider.notifier).set(val);
              },
            ),
          ),
          const SizedBox(height: 16),
          // Cache management buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showClearCacheDialog(context, ref),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('پاک‌سازی کش'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(storageInfoProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('به‌روزرسانی'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          color: isDark ? Colors.grey[300] : Colors.grey[200],
        );
      },
    );
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(1)} بایت';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} کیلوبایت';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} مگابایت';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} گیگابایت';
    }
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'همین الان';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else {
      return '${difference.inDays} روز پیش';
    }
  }

  Future<Map<String, dynamic>> _getStorageInfo() async {
    return await StorageAndMemorySettingsPage._storageService.getStorageInfo();
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک‌سازی کش'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید تمام کش‌ها را پاک کنید؟ این عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllCaches();
            },
            child: const Text('پاک‌سازی'),
          ),
        ],
      ),
    );
  }

  // نمایش جزئیات حافظه دستگاه
  void _showDeviceStorageDetails(
      BuildContext context, Map<String, dynamic> storageInfo, bool isDark) {
    final totalSpace = storageInfo['totalDeviceSpace'] ?? 0.0;
    final usedSpace = storageInfo['usedDeviceSpace'] ?? 0.0;
    final freeSpace = storageInfo['freeDeviceSpace'] ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  child: const Icon(Icons.phone_android_rounded,
                      color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Text(
                  'جزئیات حافظه دستگاه',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailItem(
                'فضای کل', _formatBytes(totalSpace), Colors.green, isDark),
            const SizedBox(height: 12),
            _buildDetailItem('فضای استفاده شده', _formatBytes(usedSpace),
                Colors.red, isDark),
            const SizedBox(height: 12),
            _buildDetailItem(
                'فضای آزاد', _formatBytes(freeSpace), Colors.blue, isDark),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // نمایش جزئیات حافظه اپلیکیشن
  void _showAppStorageDetails(
      BuildContext context, Map<String, dynamic> storageInfo, bool isDark) {
    final totalApp = storageInfo['appOccupiedSpace'] ?? 0.0;
    final documents = storageInfo['appDocumentsSize'] ?? 0.0;
    final library = storageInfo['appLibrarySize'] ?? 0.0;
    final support = storageInfo['appSupportSize'] ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.apps_rounded, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Text(
                  'جزئیات حافظه اپلیکیشن',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailItem(
                'مجموع فضای اپ', _formatBytes(totalApp), Colors.orange, isDark),
            if (documents > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem('اسناد و داده‌ها', _formatBytes(documents),
                  Colors.orange[300]!, isDark),
            ],
            if (library > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem('کتابخانه', _formatBytes(library),
                  Colors.orange[400]!, isDark),
            ],
            if (support > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem('پشتیبانی سیستم', _formatBytes(support),
                  Colors.orange[600]!, isDark),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // نمایش جزئیات کش
  void _showCacheStorageDetails(
      BuildContext context, Map<String, dynamic> storageInfo, bool isDark) {
    final totalCache = storageInfo['totalCacheSize'] ?? 0.0;
    final messages = storageInfo['messageCacheSize'] ?? 0.0;
    final conversations = storageInfo['conversationCacheSize'] ?? 0.0;
    final channels = storageInfo['channelCacheSize'] ?? 0.0;
    final temp = storageInfo['tempCacheSize'] ?? 0.0;
    final images = storageInfo['imageCacheSize'] ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  child: const Icon(Icons.cached_rounded, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  'جزئیات کش و حافظه موقت',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailItem(
                'مجموع کش', _formatBytes(totalCache), Colors.purple, isDark),
            if (messages > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem('کش پیام‌ها', _formatBytes(messages),
                  Colors.purple[300]!, isDark),
            ],
            if (conversations > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem('کش مکالمات', _formatBytes(conversations),
                  Colors.purple[400]!, isDark),
            ],
            if (channels > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem('کش کانال‌ها', _formatBytes(channels),
                  Colors.purple[500]!, isDark),
            ],
            if (temp > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem(
                  'کش موقت', _formatBytes(temp), Colors.purple[600]!, isDark),
            ],
            if (images > 0) ...[
              const SizedBox(height: 12),
              _buildDetailItem('کش تصاویر', _formatBytes(images),
                  Colors.purple[700]!, isDark),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('لغو'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // پاک‌سازی کش بدون نیاز به ref
                      _clearCacheWithoutRef(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('پاک‌سازی'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
      String title, String value, Color color, bool isDark) {
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
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // پاک‌سازی کش بدون نیاز به ref
  void _clearCacheWithoutRef(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک‌سازی کش'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید تمام کش‌ها را پاک کنید؟ این عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Clear caches using service
                final result = await StorageAndMemorySettingsPage
                    ._storageService
                    .clearAllCaches();

                if (context.mounted) {
                  Navigator.pop(context); // Close loading

                  final clearedItems = result['clearedItems'] ?? 0;
                  final freedSpace = result['freedSpace'] ?? 0.0;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'کش پاک‌سازی شد: $clearedItems مورد، ${_formatBytes(freedSpace)} آزاد شد',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطا در پاک‌سازی کش: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('پاک‌سازی'),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheManagementSection(BuildContext context, WidgetRef ref,
      bool isDark, ColorScheme colorScheme) {
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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cached_rounded,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'مدیریت کش پیشرفته',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // آمار کلی کش
          _buildCacheOverviewCard(context, isDark, colorScheme),
          _buildDivider(),
          // دکمه پاکسازی واحد
          _buildUnifiedCleanupButton(context, isDark, colorScheme),
          _buildDivider(),
          // تنظیمات هوشمند
          _buildSmartSettingsCard(context, isDark, colorScheme),
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
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نمای کلی کش',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_rounded,
                  size: 18,
                  color: Colors.orange,
                ),
                onPressed: () => _showMaxCacheSizeDialog(),
                tooltip: 'تنظیم حداکثر حجم کش',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'این فقط حداکثر حجم کش اپلیکیشن است، نه حافظه کل گوشی',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          Text(
            '${totalSize.toStringAsFixed(1)} MB از ${maxSize.toStringAsFixed(0)} MB',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 4),
          Text(
            '${(usagePercentage * 100).toStringAsFixed(1)}% استفاده شده',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          // کش چت
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue[900]?.withValues(alpha: 0.3)
                  : Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildChatCacheDetails(isDark),
          ),
          const SizedBox(height: 8),
          // جزئیات کش تصاویر
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'جزئیات کش تصاویر',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                _buildImageCacheDetails(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSettingsCard(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    final smartCacheEnabled = _cacheStats['smart_cache_enabled'] ?? true;
    final batterySaverMode = _cacheStats['battery_saver_mode'] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تنظیمات هوشمند',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _loadCacheStats,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'بروزرسانی',
              ),
              IconButton(
                onPressed: () => _testCacheData(_cacheStats),
                icon: const Icon(Icons.bug_report_rounded),
                tooltip: 'تست داده‌ها',
              ),
              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatCacheDetails(bool isDark) {
    final imageCache =
        _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};
    final chatCache = imageCache['chat_cache'] as Map<String, dynamic>? ?? {};

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'کش چت',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.blue[300] : Colors.blue[700],
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
        ),
        Text(
          '${chatCache['items'] ?? 0} مورد - ${(chatCache['size_mb'] ?? 0.0).toStringAsFixed(1)} MB',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.blue[200] : Colors.blue[600],
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.left,
        ),
      ],
    );
  }

  Widget _buildImageCacheDetails(bool isDark) {
    final imageCache =
        _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        _buildCacheDetailItem('استوری‌ها', imageCache['story_cache'], isDark),
        const SizedBox(height: 6),
        _buildCacheDetailItem('پست‌ها', imageCache['post_cache'], isDark),
        const SizedBox(height: 6),
        _buildCacheDetailItem('والپیپر', imageCache['wallpaper_cache'], isDark),
      ],
    );
  }

  Widget _buildCacheDetailItem(String title, dynamic cacheData, bool isDark) {
    if (cacheData == null) {
      return Text(
        '$title: اطلاعات موجود نیست',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
      );
    }

    final data = cacheData as Map<String, dynamic>;
    final items = data['items'] ?? 0;
    final size = data['size_mb'] ?? 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$items مورد - ${size.toStringAsFixed(1)} MB',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.left,
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}

// Provider for storage info
final storageInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await StorageAndMemorySettingsPage._storageService.getStorageInfo();
});
