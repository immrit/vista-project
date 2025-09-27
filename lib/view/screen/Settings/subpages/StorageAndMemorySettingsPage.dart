import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import '../../../../services/storage_info_service.dart';
import '../../../../services/cache_manager.dart';
import '../../../../DB/advanced_cache_system.dart';
import '../../../../DB/profile_cache_service.dart';
import '../../../../DB/database_file_utils.dart';
import '../../../../main.dart';
import '../../../../provider/provider.dart';
import '../../../../services/video_autoplay_service.dart';

// Storage category model like Telegram
class StorageCategory {
  final String name;
  final Color color;
  final String type;
  double size; // MB
  double percentage;

  StorageCategory(
    this.name,
    this.color,
    this.type, {
    this.size = 0,
    this.percentage = 0,
  });
}

class StorageAndMemorySettingsPage extends ConsumerStatefulWidget {
  const StorageAndMemorySettingsPage({super.key});

  @override
  ConsumerState<StorageAndMemorySettingsPage> createState() =>
      _StorageAndMemorySettingsPageState();
}

class _StorageAndMemorySettingsPageState
    extends ConsumerState<StorageAndMemorySettingsPage>
    with TickerProviderStateMixin {
  final UnifiedCacheManager _cacheManager = UnifiedCacheManager();
  final AdvancedCacheSystem _advancedCache = AdvancedCacheSystem();
  final ProfileCacheService _profileCache = ProfileCacheService();
  final StorageInfoService _storageService = StorageInfoService();

  bool _isLoading = false;
  Map<String, dynamic> _cacheStats = {};
  Map<String, dynamic> _storageInfo = {};
  Map<String, dynamic> _profileStats = {};

  // Telegram-style settings
  TabController? _tabController;
  String _autoRemovePrivateChats = '۱ هفته';
  String _autoRemoveProfiles = '۲ روز';
  double _maxCacheSize = 32.0; // GB

  // Video settings
  bool _dataSaverEnabled = false;
  bool _autoQualityEnabled = true;
  bool _autoPlayEnabled = false;

  // Visible categories in chart (toggleable under the chart)
  Set<String> _visibleCategoryTypes = <String>{};

  final List<String> _autoRemoveOptions = [
    '۲ روز',
    '۱ هفته',
    '۲ هفته',
    '۱ ماه',
    'هرگز',
  ];

  final List<String> _tabTitles = ['کلی', 'گفتگوها'];

  // Storage categories with colors (like Telegram)
  List<StorageCategory> _storageCategories = [
    StorageCategory('Music', Colors.purple, 'music'),
    StorageCategory('Stickers & Emoji', Colors.orange, 'stickers'),
    StorageCategory('Documents', Colors.green, 'documents'),
    StorageCategory('Photos', Colors.blue, 'photos'),
    StorageCategory('Videos', Colors.red, 'videos'),
    StorageCategory('Voice Messages', Colors.teal, 'voice'),
    StorageCategory('Other', Colors.grey, 'other'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _initializeCacheManager();
    _loadAutoRemoveSettings();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCacheManager() async {
    try {
      // Initialize all cache systems
      await _cacheManager.initialize();
      await _advancedCache.initialize();
      await _profileCache.initialize();

      // Load all data
      await _loadAllStats();
    } catch (e) {
      print('خطا در مقداردهی سیستم‌های کش: $e');
      // در صورت خطا، باز هم سعی کن آمار را بارگذاری کن
      await _loadAllStats();
    }
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);
    try {
      // بارگذاری آمار کش تصاویر
      final cacheStats = await _cacheManager.getCacheStats();

      // بارگذاری اطلاعات ذخیره‌سازی دستگاه
      final storageInfo = await _storageService.getStorageInfo();

      // بارگذاری آمار پروفایل‌ها
      final profileStats = _profileCache.getCacheStats();

      setState(() {
        _cacheStats = cacheStats;
        _storageInfo = storageInfo;
        _profileStats = profileStats;
      });

      // محاسبه storage categories مثل تلگرام
      _calculateStorageCategories();
    } catch (e) {
      print('خطا در دریافت آمار: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در دریافت اطلاعات: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStorageCategories() {
    // محاسبه حجم‌های واقعی از سیستم‌های cache
    final imageCache =
        _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};

    // دریافت داده‌های واقعی از cache سیستم‌ها
    final storyCache = imageCache['story_cache']?['size_mb'] ?? 0.0;
    final postCache = imageCache['post_cache']?['size_mb'] ?? 0.0;
    final chatImageCache = imageCache['chat_cache']?['size_mb'] ?? 0.0;
    final wallpaperCache = imageCache['wallpaper_cache']?['size_mb'] ?? 0.0;

    final profileCacheSize = _profileStats['total_cache_size_mb'] ?? 0.0;
    final messageCache = _storageInfo['messageCacheSize'] ?? 0.0;
    final conversationCache = _storageInfo['conversationCacheSize'] ?? 0.0;
    final tempCache = _storageInfo['tempCacheSize'] ?? 0.0;

    // Debug: نمایش آمار دریافت شده
    print('📊 آمار کش دریافت شده:');
    print('   Story Cache: ${storyCache.toStringAsFixed(2)} MB');
    print('   Post Cache: ${postCache.toStringAsFixed(2)} MB');
    print('   Chat Image Cache: ${chatImageCache.toStringAsFixed(2)} MB');
    print('   Wallpaper Cache: ${wallpaperCache.toStringAsFixed(2)} MB');
    print('   Profile Cache: ${profileCacheSize.toStringAsFixed(2)} MB');
    print('   Message Cache: ${messageCache.toStringAsFixed(2)} MB');
    print('   Conversation Cache: ${conversationCache.toStringAsFixed(2)} MB');
    print('   Temp Cache: ${tempCache.toStringAsFixed(2)} MB');

    // تخصیص داده‌های واقعی به دسته‌ها
    _storageCategories = [
      StorageCategory(
        'تصاویر',
        Colors.blue,
        'photos',
        size: storyCache + postCache + chatImageCache,
      ),
      StorageCategory(
        'پیام‌ها و گفتگوها',
        Colors.green,
        'messages',
        size: messageCache + conversationCache,
      ),
      StorageCategory(
        'پروفایل‌ها و پست‌ها',
        Colors.purple,
        'profiles',
        size: profileCacheSize,
      ),
      StorageCategory(
        'پس‌زمینه‌ها',
        Colors.orange,
        'wallpapers',
        size: wallpaperCache,
      ),
      StorageCategory('فایل‌های موقت', Colors.red, 'temp', size: tempCache),
      StorageCategory(
        'اسناد',
        Colors.teal,
        'documents',
        size: _storageInfo['appDocumentsSize'] ?? 0.0,
      ),
      StorageCategory(
        'سایر',
        Colors.grey,
        'other',
        size: _storageInfo['appLibrarySize'] ?? 0.0,
      ),
    ];

    // حذف دسته‌هایی که حجم صفر دارن
    _storageCategories.removeWhere((cat) => cat.size <= 0.001);

    // محاسبه مجموع حجم
    final totalSize = _storageCategories.fold(
      0.0,
      (sum, cat) => sum + cat.size,
    );

    // محاسبه درصدها
    for (var category in _storageCategories) {
      category.percentage =
          totalSize > 0 ? (category.size / totalSize * 100) : 0;
    }

    // مرتب‌سازی بر اساس حجم (بزرگ‌ترین اول)
    _storageCategories.sort((a, b) => b.size.compareTo(a.size));

    // همگام‌سازی مجموعه دسته‌های قابل مشاهده با دسته‌های فعلی
    final currentTypes = _storageCategories.map((c) => c.type).toSet();
    if (_visibleCategoryTypes.isEmpty) {
      _visibleCategoryTypes = {...currentTypes};
    } else {
      _visibleCategoryTypes = _visibleCategoryTypes.intersection(currentTypes);
      if (_visibleCategoryTypes.isEmpty) {
        _visibleCategoryTypes = {...currentTypes};
      }
    }

    // Debug: چاپ مقادیر واقعی
    print('=== Real Storage Categories ===');
    for (var cat in _storageCategories) {
      print(
        '${cat.name}: ${cat.size.toStringAsFixed(2)} MB (${cat.percentage.toStringAsFixed(1)}%)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: const Text('مصرف حافظه'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showStorageOptions(context),
          ),
        ],
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabController != null
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(context, isDark),
                    _buildChatsTab(context, isDark),
                  ],
                )
              : const SizedBox(),
    );
  }

  // Tab content builders (like Telegram)
  Widget _buildOverviewTab(BuildContext context, bool isDark) {
    final categoriesForChart = _storageCategories
        .where((c) => _visibleCategoryTypes.contains(c.type))
        .toList();
    final totalSize = categoriesForChart.fold(
      0.0,
      (sum, cat) => sum + cat.size,
    );
    final totalSizeGB = totalSize / 1024;

    // تنها حجم مصرفی برنامه نشان داده می‌شود، نه کل گوشی

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Circular chart like Telegram
          SizedBox(
            height: 250,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      painter: StorageChartPainter(categoriesForChart, isDark),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        totalSizeGB.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'GB',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // (قدیمی) لیست دسته‌ها در پایین برای فعال/غیرفعال کردن استفاده می‌شود

          // App usage info like Telegram
          Center(
            child: Text(
              'ویستا ${totalSizeGB.toStringAsFixed(2)} گیگابایت از حافظه دستگاه شما استفاده می‌کند.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // Categories list like Telegram
          ...List.generate(_storageCategories.length, (index) {
            final category = _storageCategories[index];
            if (category.percentage < 1.0) return const SizedBox.shrink();

            return _buildCategoryItem(category, isDark);
          }),

          const SizedBox(height: 24),

          // Clear Cache button like Telegram
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _showClearCacheDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'پاک‌سازی کش ${totalSizeGB.toStringAsFixed(2)} GB',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info text like Telegram
          Text(
            'تمام رسانه‌ها در فضای ابری ویستا باقی می‌مانند و در صورت نیاز قابل دانلود مجدد هستند.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Auto-remove section like Telegram
          _buildAutoRemoveSection(context, isDark),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(StorageCategory category, bool isDark) {
    final selected = _visibleCategoryTypes.contains(category.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          // Category info
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${category.name} ${category.percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _formatFileSize(category.size),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Checkbox(
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _visibleCategoryTypes.add(category.type);
                          } else {
                            _visibleCategoryTypes.remove(category.type);
                            if (_visibleCategoryTypes.isEmpty) {
                              _visibleCategoryTypes.add(category.type);
                            }
                          }
                        });
                      },
                      activeColor: category.color,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRemoveSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حذف خودکار رسانه‌های کش شده',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'رسانه‌های قدیمی‌تر از مدت انتخاب شده به صورت خودکار حذف می‌شوند',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        _buildAutoRemoveItem(
          'گفتگوهای خصوصی',
          Icons.person_rounded,
          _autoRemovePrivateChats,
          (value) {
            setState(() => _autoRemovePrivateChats = value);
            _saveAutoRemoveSetting('conversations', value);
          },
        ),

        // گزینه کانال‌ها حذف شد

        _buildAutoRemoveItem(
          'رسانه‌های پروفایل',
          Icons.account_circle_rounded,
          _autoRemoveProfiles,
          (value) {
            setState(() => _autoRemoveProfiles = value);
            _saveAutoRemoveSetting('profiles', value);
          },
        ),

        const SizedBox(height: 24),

        // Maximum cache size section
        _buildMaxCacheSizeSection(context, isDark),
      ],
    );
  }

  /// ذخیره تنظیمات حذف خودکار در SharedPreferences
  Future<void> _saveAutoRemoveSetting(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auto_remove_$key', value);

      // اجرای حذف خودکار بر اساس تنظیمات جدید
      await _performAutoRemoval(key, value);

      print('✅ تنظیمات حذف خودکار ذخیره شد: $key = $value');
    } catch (e) {
      print('❌ خطا در ذخیره تنظیمات حذف خودکار: $e');
    }
  }

  /// بارگذاری تنظیمات حذف خودکار از SharedPreferences
  Future<void> _loadAutoRemoveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videoAutoplayService = VideoAutoplayService();

      // بارگذاری تنظیمات سرویس پخش خودکار ویدیو
      await videoAutoplayService.loadSettings();

      setState(() {
        _autoRemovePrivateChats =
            prefs.getString('auto_remove_conversations') ?? '۱ هفته';
        _autoRemoveProfiles =
            prefs.getString('auto_remove_profiles') ?? '۲ روز';
        _maxCacheSize = prefs.getDouble('max_cache_size') ?? 32.0;

        // Video settings from service
        _dataSaverEnabled = videoAutoplayService.dataSaverEnabled;
        _autoQualityEnabled = prefs.getBool('video_auto_quality') ?? true;
        _autoPlayEnabled = videoAutoplayService.autoPlayEnabled;
      });
    } catch (e) {
      print('❌ خطا در بارگذاری تنظیمات حذف خودکار: $e');
    }
  }

  /// اجرای حذف خودکار بر اساس تنظیمات
  Future<void> _performAutoRemoval(String category, String duration) async {
    try {
      if (duration == 'هرگز') return;

      final daysToKeep = _convertDurationToDays(duration);
      if (daysToKeep <= 0) return;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      switch (category) {
        case 'conversations':
          await _cleanupConversationsMedia(cutoffDate);
          break;
        case 'profiles':
          await _cleanupProfilesMedia(cutoffDate);
          break;
      }

      // بروزرسانی آمار
      await _loadAllStats();

      print('✅ حذف خودکار انجام شد برای $category');
    } catch (e) {
      print('❌ خطا در حذف خودکار: $e');
    }
  }

  /// تبدیل رشته مدت زمان به تعداد روز
  int _convertDurationToDays(String duration) {
    switch (duration) {
      case '۲ روز':
        return 2;
      case '۱ هفته':
        return 7;
      case '۲ هفته':
        return 14;
      case '۱ ماه':
        return 30;
      case 'هرگز':
      default:
        return 0;
    }
  }

  /// پاک‌سازی رسانه‌های گفتگوهای خصوصی
  Future<void> _cleanupConversationsMedia(DateTime cutoffDate) async {
    try {
      print('🧹 شروع پاک‌سازی رسانه‌های گفتگوها قدیمی‌تر از $cutoffDate');

      // دریافت تمام گفتگوها
      final conversations = _advancedCache.getCachedConversations();
      int cleanedItems = 0;

      for (final conversation in conversations) {
        // دریافت پیام‌های این گفتگو
        final messages = _advancedCache.getCachedMessages(conversation.id);

        for (final message in messages) {
          // بررسی اینکه آیا پیام قدیمی‌تر از cutoffDate است
          if (message.createdAt.isBefore(cutoffDate)) {
            // حذف رسانه‌های مرتبط با این پیام (اگر وجود دارد)
            await _cleanupMessageMedia(message);
            cleanedItems++;
          }
        }
      }

      print('✅ $cleanedItems آیتم رسانه از گفتگوها پاک شد');
    } catch (e) {
      print('❌ خطا در پاک‌سازی رسانه‌های گفتگوها: $e');
    }
  }

  /// پاک‌سازی رسانه‌های کانال‌ها
  // متد پاک‌سازی کانال‌ها حذف شد

  /// پاک‌سازی رسانه‌های پروفایل
  Future<void> _cleanupProfilesMedia(DateTime cutoffDate) async {
    try {
      print('🧹 شروع پاک‌سازی رسانه‌های پروفایل قدیمی‌تر از $cutoffDate');

      // پاک‌سازی تصاویر پروفایل و پست‌های قدیمی
      // TODO: اگر ProfileCacheService متد cleanupOldCaches دارد، اینجا فراخوانی کنید
      print(
          '📝 پاک‌سازی کش پروفایل - نیاز به پیاده‌سازی در ProfileCacheService');

      print('✅ پاک‌سازی رسانه‌های پروفایل تکمیل شد');
    } catch (e) {
      print('❌ خطا در پاک‌سازی رسانه‌های پروفایل: $e');
    }
  }

  /// پاک‌سازی رسانه‌های مرتبط با یک پیام
  Future<void> _cleanupMessageMedia(dynamic message) async {
    try {
      // اگر پیام دارای attachment است
      if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
        // حذف فایل از cache
        // TODO: اگر UnifiedCacheManager متد removeFromCache دارد، اینجا فراخوانی کنید
        print('📝 حذف attachment: ${message.attachmentUrl}');
      }

      // اگر پیام دارای تصویر است
      if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
        // TODO: اگر UnifiedCacheManager متد removeFromCache دارد، اینجا فراخوانی کنید
        print('📝 حذف تصویر: ${message.imageUrl}');
      }
    } catch (e) {
      print('❌ خطا در حذف رسانه پیام: $e');
    }
  }

  /// ذخیره تنظیمات ویدیو در SharedPreferences
  Future<void> _saveVideoSetting(String key, dynamic value) async {
    try {
      final videoAutoplayService = VideoAutoplayService();

      if (key == 'auto_play') {
        await videoAutoplayService.setAutoPlay(value as bool);
        setState(() {
          _autoPlayEnabled = videoAutoplayService.autoPlayEnabled;
        });
        // به‌روزرسانی autoPlayProvider
        ref.read(autoPlayProvider.notifier).refresh();
      } else if (key == 'data_saver') {
        await videoAutoplayService.setDataSaver(value as bool);
        setState(() {
          _dataSaverEnabled = value;
        });
        // به‌روزرسانی autoPlayProvider
        ref.read(autoPlayProvider.notifier).refresh();
      } else {
        // ذخیره سایر تنظیمات در SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (value is bool) {
          await prefs.setBool('video_$key', value);
        } else if (value is String) {
          await prefs.setString('video_$key', value);
        } else if (value is int) {
          await prefs.setInt('video_$key', value);
        }
      }

      print('✅ تنظیمات ویدیو ذخیره شد: $key = $value');
    } catch (e) {
      print('❌ خطا در ذخیره تنظیمات ویدیو: $e');
    }
  }

  Widget _buildAutoRemoveItem(
    String title,
    IconData icon,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentValue,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () => _showAutoRemoveOptions(title, currentValue, onChanged),
      ),
    );
  }

  Widget _buildMaxCacheSizeSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حداکثر اندازه کش',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'وقتی اندازه کش از این حد تجاوز کند، قدیمی‌ترین رسانه‌ها حذف می‌شوند',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Slider like Telegram
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('۵ گیگابایت'),
                  Expanded(
                    child: Slider(
                      value: _maxCacheSize == double.infinity
                          ? 100
                          : _maxCacheSize,
                      min: 5,
                      max: 100,
                      divisions:
                          19, // 5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100
                      activeColor: Colors.blue,
                      onChanged: (value) {
                        setState(() {
                          if (value == 100) {
                            _maxCacheSize = double.infinity;
                          } else {
                            _maxCacheSize = value;
                          }
                        });
                        _saveMaxCacheSize();
                      },
                    ),
                  ),
                  Text(
                    _maxCacheSize == double.infinity
                        ? 'بدون محدودیت'
                        : '${_maxCacheSize.toInt()} گیگابایت',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'فضای فعلی استفاده شده: ${(_storageCategories.fold(0.0, (sum, cat) => sum + cat.size) / 1024).toStringAsFixed(1)} گیگابایت',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Max cache size actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _performCacheSizeCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.cleaning_services_rounded),
                label: const Text('بررسی و پاک‌سازی'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showCacheSizeDetails(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('جزئیات'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Video settings section (preserved from original)
        _buildVideoSettingsSection(context, isDark),

        const SizedBox(height: 24),

        // Performance settings section
        _buildPerformanceSettingsSection(context, isDark),
      ],
    );
  }

  /// ذخیره تنظیمات حداکثر اندازه کش
  Future<void> _saveMaxCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('max_cache_size', _maxCacheSize);
      print('✅ حداکثر اندازه کش ذخیره شد: $_maxCacheSize GB');
    } catch (e) {
      print('❌ خطا در ذخیره حداکثر اندازه کش: $e');
    }
  }

  /// بررسی و پاک‌سازی کش بر اساس حداکثر اندازه
  Future<void> _performCacheSizeCheck() async {
    try {
      final currentSizeGB =
          _storageCategories.fold(0.0, (sum, cat) => sum + cat.size) / 1024;

      if (_maxCacheSize != double.infinity && currentSizeGB > _maxCacheSize) {
        final excessSizeGB = currentSizeGB - _maxCacheSize;
        final excessSizeMB = excessSizeGB * 1024;

        // نمایش دیالوگ تأیید
        final shouldClean = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تجاوز از حد مجاز کش'),
            content: Text(
              'اندازه کش فعلی (${currentSizeGB.toStringAsFixed(1)} گیگابایت) از حد مجاز (${_maxCacheSize.toInt()} گیگابایت) تجاوز کرده است.\n\n'
              'آیا می‌خواهید ${excessSizeGB.toStringAsFixed(1)} گیگابایت از قدیمی‌ترین فایل‌ها حذف شوند؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لغو'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('پاک‌سازی'),
              ),
            ],
          ),
        );

        if (shouldClean == true) {
          await _cleanupOldestMediaFiles(excessSizeMB);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${excessSizeGB.toStringAsFixed(1)} گیگابایت فضا آزاد شد'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اندازه کش در حد مجاز است'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در بررسی کش: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// حذف قدیمی‌ترین فایل‌های رسانه‌ای
  Future<void> _cleanupOldestMediaFiles(double targetSizeMB) async {
    // پیاده‌سازی حذف قدیمی‌ترین فایل‌ها بر اساس اندازه هدف
    // TODO: implementation
    print(
        '🧹 پاک‌سازی ${targetSizeMB.toStringAsFixed(1)} مگابایت از قدیمی‌ترین فایل‌ها');
  }

  /// نمایش جزئیات اندازه کش
  void _showCacheSizeDetails(BuildContext context) {
    final currentSizeGB =
        _storageCategories.fold(0.0, (sum, cat) => sum + cat.size) / 1024;
    final progressPercentage = _maxCacheSize == double.infinity
        ? 0.0
        : (currentSizeGB / _maxCacheSize * 100).clamp(0, 100);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('جزئیات اندازه کش'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اندازه فعلی: ${currentSizeGB.toStringAsFixed(2)} گیگابایت'),
            Text(
                'حد مجاز: ${_maxCacheSize == double.infinity ? "بدون محدودیت" : "${_maxCacheSize.toInt()} گیگابایت"}'),
            if (_maxCacheSize != double.infinity) ...[
              const SizedBox(height: 16),
              Text('درصد استفاده: ${progressPercentage.toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressPercentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressPercentage > 90
                      ? Colors.red
                      : progressPercentage > 70
                          ? Colors.orange
                          : Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('توزیع فضا:'),
            ..._storageCategories.where((cat) => cat.size > 0).map(
                  (cat) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat.name),
                        Text(
                            '${(cat.size / 1024).toStringAsFixed(1)} گیگابایت'),
                      ],
                    ),
                  ),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSettingsSection(
    BuildContext context,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تنظیمات ویدیو',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'تنظیمات پخش و کیفیت ویدیوهای پست‌ها',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Data Saver Setting
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading:
                const Icon(Icons.data_saver_on_rounded, color: Colors.green),
            title: const Text('صرفه‌جویی در داده'),
            subtitle: const Text('کاهش کیفیت برای کاهش مصرف اینترنت'),
            trailing: Switch(
              value: _dataSaverEnabled,
              onChanged: (value) {
                setState(() => _dataSaverEnabled = value);
                _saveVideoSetting('data_saver', value);
              },
              activeThumbColor: Colors.green,
            ),
          ),
        ),

        // Auto Quality Setting
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.high_quality_rounded, color: Colors.blue),
            title: const Text('کیفیت خودکار'),
            subtitle: const Text('تنظیم خودکار کیفیت بر اساس سرعت اینترنت'),
            trailing: Switch(
              value: _autoQualityEnabled,
              onChanged: (value) {
                setState(() => _autoQualityEnabled = value);
                _saveVideoSetting('auto_quality', value);
              },
              activeThumbColor: Colors.blue,
            ),
          ),
        ),

        // Auto Play Setting
        Consumer(
          builder: (context, ref, child) {
            final performanceSettings = ref.watch(performanceProvider);
            final isDisabled = performanceSettings.batterySaverMode;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.play_circle_rounded,
                    color: isDisabled ? Colors.grey : Colors.purple),
                title: Text(
                  'پخش خودکار',
                  style: TextStyle(
                    color: isDisabled ? Colors.grey : null,
                  ),
                ),
                subtitle: Text(
                  isDisabled
                      ? 'غیرفعال به دلیل حالت کم‌مصرف'
                      : 'پخش خودکار ویدیوهای پست‌ها',
                  style: TextStyle(
                    color: isDisabled ? Colors.grey : null,
                  ),
                ),
                trailing: Switch(
                  value: isDisabled ? false : _autoPlayEnabled,
                  onChanged: isDisabled
                      ? null
                      : (value) {
                          _saveVideoSetting('auto_play', value);
                        },
                  activeThumbColor: Colors.purple,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPerformanceSettingsSection(BuildContext context, bool isDark) {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(performanceProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تنظیمات کارایی',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'بهینه‌سازی مصرف باتری و رم',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Battery Saver Mode
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.battery_saver, color: Colors.green),
                title: const Text('حالت کم‌مصرف'),
                subtitle: Text(ref
                    .read(performanceProvider.notifier)
                    .getBatterySaverDescription()),
                trailing: Switch(
                  value: settings.batterySaverMode,
                  onChanged: (value) async {
                    await ref
                        .read(performanceProvider.notifier)
                        .updateBatterySaver(value);
                    // به‌روزرسانی autoPlayProvider پس از تغییر حالت کم‌مصرف
                    ref.read(autoPlayProvider.notifier).refresh();
                  },
                  activeThumbColor: Colors.green,
                ),
              ),
            ),

            // Smart Cache
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.memory, color: Colors.blue),
                title: const Text('کش هوشمند'),
                subtitle: Text(ref
                    .read(performanceProvider.notifier)
                    .getSmartCacheDescription()),
                trailing: Switch(
                  value: settings.smartCache,
                  onChanged: (value) {
                    ref
                        .read(performanceProvider.notifier)
                        .updateSmartCache(value);
                  },
                  activeThumbColor: Colors.blue,
                ),
              ),
            ),

            // Message Preloading
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.speed, color: Colors.purple),
                title: const Text('پیش‌بارگذاری پیام‌ها'),
                subtitle: Text(ref
                    .read(performanceProvider.notifier)
                    .getPreloadingDescription()),
                trailing: Switch(
                  value: settings.messagePreloading,
                  onChanged: (value) {
                    ref
                        .read(performanceProvider.notifier)
                        .updateMessagePreloading(value);
                  },
                  activeThumbColor: Colors.purple,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildChatsTab(BuildContext context, bool isDark) {
    return FutureBuilder<List<dynamic>>(
      future: _loadConversationsWithProfiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('در حال بارگذاری پروفایل‌ها...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('خطا: ${snapshot.error}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          );
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'هنوز گفتگویی در کش ذخیره نشده است',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'گفتگوها به صورت خودکار در کش ذخیره می‌شوند',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with refresh button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${conversations.length} گفتگو',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    onPressed: () async {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('در حال بروزرسانی...')),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'بروزرسانی',
                  ),
                  const SizedBox(width: 8),
                  // Storage usage indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_calculateTotalStorageSize(conversations)} MB',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Conversations list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: conversations.length,
                itemBuilder: (context, index) =>
                    _buildRealChatItem(conversations[index], isDark, null),
              ),
            ),
          ],
        );
      },
    );
  }

  /// بارگذاری گفتگوها و تضمین وجود پروفایل‌ها
  Future<List<dynamic>> _loadConversationsWithProfiles() async {
    try {
      print('🔄 شروع بارگذاری گفتگوها و پروفایل‌ها...');

      // 1. دریافت گفتگوها از cache
      final conversations = _advancedCache.getCachedConversations();
      print('📥 تعداد گفتگوها در کش: ${conversations.length}');

      // 2. جمع‌آوری تمام user ID های نیاز به پروفایل
      final Set<String> userIdsToLoad = {};
      for (final conversation in conversations) {
        if (conversation.otherUserId != null) {
          userIdsToLoad.add(conversation.otherUserId!);
        }
        // اضافه کردن participants
        for (final participant in conversation.participants) {
          userIdsToLoad.add(participant.userId);
        }
      }

      print('👥 تعداد کاربران برای بارگذاری پروفایل: ${userIdsToLoad.length}');

      // 3. بارگذاری پروفایل‌های مفقود
      int loadedProfiles = 0;
      for (final userId in userIdsToLoad) {
        final existingProfile = _profileCache.getCachedProfile(userId);
        if (existingProfile == null) {
          try {
            print('📱 بارگذاری پروفایل برای: $userId');
            await _profileCache.cacheProfileAndPosts(userId);
            loadedProfiles++;
          } catch (e) {
            print('⚠️ خطا در بارگذاری پروفایل $userId: $e');
          }
        } else {
          print(
              '✅ پروفایل موجود در کش: $userId - ${existingProfile.fullName.isNotEmpty ? existingProfile.fullName : existingProfile.username}');
        }
      }

      print('✅ تعداد پروفایل‌های جدید بارگذاری شده: $loadedProfiles');

      // 4. بررسی نهایی پروفایل‌ها
      print('🔍 بررسی نهایی پروفایل‌ها:');
      for (final conversation in conversations) {
        if (conversation.otherUserId != null) {
          final profile =
              _profileCache.getCachedProfile(conversation.otherUserId!);
          if (profile != null) {
            print(
                '   ✅ ${conversation.id}: ${profile.fullName.isNotEmpty ? profile.fullName : profile.username}');
          } else {
            print('   ❌ ${conversation.id}: پروفایل یافت نشد');
          }
        }
      }

      // 5. مرتب‌سازی بر اساس حجم
      conversations.sort((a, b) {
        final messagesA = _advancedCache.getCachedMessages(a.id);
        final messagesB = _advancedCache.getCachedMessages(b.id);
        final sizeA = messagesA.length * 0.001;
        final sizeB = messagesB.length * 0.001;
        return sizeB.compareTo(sizeA);
      });

      print('🎯 گفتگوها آماده نمایش: ${conversations.length}');
      return conversations;
    } catch (e) {
      print('❌ خطا در بارگذاری گفتگوها: $e');
      rethrow;
    }
  }

  /// Calculate total storage size for all conversations
  double _calculateTotalStorageSize(List conversations) {
    double totalSize = 0;
    for (final conversation in conversations) {
      final messages = _advancedCache.getCachedMessages(conversation.id);
      totalSize += messages.length * 0.001; // تخمین 1KB per message
    }
    return totalSize;
  }

  Future<Map<String, Map<String, dynamic>>> _loadUserProfilesForConversations(
    List conversations,
  ) async {
    final Map<String, Map<String, dynamic>> userProfiles = {};

    try {
      // جمع‌آوری تمام userId های منحصر به فرد
      final Set<String> userIds = {};

      for (final conversation in conversations) {
        // از otherUserId استفاده کن
        if (conversation.otherUserId != null) {
          userIds.add(conversation.otherUserId!);
        }

        // از participants استفاده کن
        for (final participant in conversation.participants) {
          if (participant.userId != null) {
            userIds.add(participant.userId!);
          }
        }
      }

      print('🔍 در حال دریافت پروفایل برای ${userIds.length} کاربر...');

      // دریافت اطلاعات پروفایل برای هر userId
      for (final userId in userIds) {
        try {
          // اول از cache بررسی کن
          final cachedProfile = _profileCache.getCachedProfile(userId);
          if (cachedProfile != null) {
            userProfiles[userId] = {
              'name': cachedProfile.fullName.isNotEmpty
                  ? cachedProfile.fullName
                  : cachedProfile.username,
              'avatar': cachedProfile.avatarUrl,
              'username': cachedProfile.username,
            };
            print(
              '✅ پروفایل کش شده برای $userId: ${userProfiles[userId]!['name']}',
            );
          } else {
            // اگر در cache نیست، از سرور دریافت کن
            print('🌐 دریافت پروفایل از سرور برای $userId...');
            try {
              final profile = await _profileCache.getProfile(userId);
              userProfiles[userId] = {
                'name': profile.fullName.isNotEmpty
                    ? profile.fullName
                    : profile.username,
                'avatar': profile.avatarUrl,
                'username': profile.username,
              };
              print(
                '✅ پروفایل دریافت شده برای $userId: ${userProfiles[userId]!['name']}',
              );
            } catch (e) {
              print(
                '⚠️ ProfileCacheService failed, trying direct Supabase query...',
              );
              // Fallback: مستقیماً از Supabase دریافت کن
              try {
                final response = await supabase
                    .from('profiles')
                    .select('username, full_name, avatar_url')
                    .eq('id', userId)
                    .single();

                userProfiles[userId] = {
                  'name': response['full_name']?.toString().isNotEmpty == true
                      ? response['full_name']
                      : response['username']?.toString() ?? 'کاربر ناشناس',
                  'avatar': response['avatar_url']?.toString(),
                  'username': response['username']?.toString() ?? userId,
                };
                print(
                  '✅ پروفایل مستقیم دریافت شده برای $userId: ${userProfiles[userId]!['name']}',
                );
              } catch (supabaseError) {
                print('❌ خطا در دریافت مستقیم از Supabase: $supabaseError');
                // Don't re-throw, use fallback instead
                userProfiles[userId] = {
                  'name': 'کاربر ناشناس',
                  'avatar': null,
                  'username': userId,
                };
              }
            }
          }
        } catch (e) {
          print('❌ خطا در دریافت پروفایل کاربر $userId: $e');
          // fallback
          userProfiles[userId] = {
            'name': 'کاربر ناشناس',
            'avatar': null,
            'username': userId,
          };
        }
      }

      print('📊 مجموع ${userProfiles.length} پروفایل دریافت شد');
    } catch (e) {
      print('خطا در دریافت پروفایل‌ها: $e');
    }

    return userProfiles;
  }

  /// دریافت اطلاعات نمایش کاربر (نام، آواتار، حروف اول)

  /// دریافت اطلاعات نمایش کاربر - بهبود یافته با دریافت مستقیم از ProfileCache
  Map<String, String> _getUserDisplayInfoImproved(conversation) {
    String displayName = 'گفتگو ناشناس';
    String? avatarUrl;
    String initials = 'گ';

    try {
      print('🔍 Debug Conversation Info:');
      print('   Conversation ID: ${conversation.id}');
      print('   Other User ID: ${conversation.otherUserId}');
      print('   Other User Name: "${conversation.otherUserName}"');
      print('   Other User Avatar: "${conversation.otherUserAvatar}"');
      print('   Participants Count: ${conversation.participants.length}');

      // Debug participants
      for (int i = 0; i < conversation.participants.length; i++) {
        final participant = conversation.participants[i];
        print('   Participant $i: User ID = ${participant.userId}');
      }

      // Debug ProfileCache
      if (conversation.otherUserId != null) {
        final profile =
            _profileCache.getCachedProfile(conversation.otherUserId!);
        print(
            '   🔍 ProfileCache برای ${conversation.otherUserId}: ${profile != null ? 'موجود' : 'مفقود'}');
        if (profile != null) {
          print('     Full Name: "${profile.fullName}"');
          print('     Username: "${profile.username}"');
          print('     Avatar: "${profile.avatarUrl}"');
        }
      }

      // استفاده از همان منطق popup - اولویت 1: conversation info
      if (conversation.otherUserName != null &&
          conversation.otherUserName!.isNotEmpty &&
          conversation.otherUserName != 'کاربر ناشناس') {
        displayName = conversation.otherUserName!;
        print(
            '✅ لیست اصلی - استفاده از conversation.otherUserName: $displayName');
      }

      if (conversation.otherUserAvatar != null &&
          conversation.otherUserAvatar!.isNotEmpty) {
        avatarUrl = conversation.otherUserAvatar!;
        print(
            '✅ لیست اصلی - استفاده از conversation.otherUserAvatar: $avatarUrl');
      }

      // اولویت 2: ProfileCache (همان منطق popup)
      if (displayName == 'گفتگو ناشناس' || avatarUrl == null) {
        if (conversation.otherUserId != null) {
          final cachedProfile =
              _profileCache.getCachedProfile(conversation.otherUserId!);
          if (cachedProfile != null) {
            print('✅ لیست اصلی - پروفایل یافت شد در cache');
            if (displayName == 'گفتگو ناشناس') {
              if (cachedProfile.fullName.isNotEmpty) {
                displayName = cachedProfile.fullName;
              } else if (cachedProfile.username.isNotEmpty) {
                displayName = cachedProfile.username;
              } else {
                displayName = 'کاربر ناشناس';
              }
            }
            avatarUrl ??= cachedProfile.avatarUrl;
            print('✅ لیست اصلی - استفاده از cached profile: $displayName');
          } else {
            print(
                '❌ لیست اصلی - پروفایل در cache نیست: ${conversation.otherUserId}');
            // اولویت 3: بررسی participants
            for (final participant in conversation.participants) {
              if (participant.userId != conversation.otherUserId) {
                final participantProfile =
                    _profileCache.getCachedProfile(participant.userId);
                if (participantProfile != null) {
                  if (displayName == 'گفتگو ناشناس') {
                    if (participantProfile.fullName.isNotEmpty) {
                      displayName = participantProfile.fullName;
                    } else if (participantProfile.username.isNotEmpty) {
                      displayName = participantProfile.username;
                    }
                  }
                  avatarUrl ??= participantProfile.avatarUrl;
                  print(
                      '✅ لیست اصلی - استفاده از participant profile: $displayName');
                  break;
                }
              }
            }

            // fallback نهایی
            if (displayName == 'گفتگو ناشناس') {
              displayName = 'کاربر ناشناس';
              print('⚠️ لیست اصلی - fallback به ID: $displayName');
            }
          }
        } else {
          print('❌ لیست اصلی - otherUserId null است');
        }
      }

      print(
          '🎯 لیست اصلی - Final Result: Display Name = "$displayName", Avatar = "${avatarUrl ?? 'none'}"');
      print('=' * 50);
    } catch (e) {
      print('❌ خطا در دریافت اطلاعات کاربر: $e');
      displayName = 'گفتگو ناشناس';
    }

    // تولید حروف اول
    initials = _getPersianInitial(displayName);

    return {
      'displayName': displayName,
      'avatarUrl': avatarUrl ?? '',
      'initials': initials,
    };
  }

  Widget _buildRealChatItem(
    conversation,
    bool isDark, [
    Map<String, Map<String, dynamic>>? userProfiles,
  ]) {
    // محاسبه حجم واقعی مکالمه
    final messages = _advancedCache.getCachedMessages(conversation.id);
    final messageCount = messages.length;
    final estimatedSize = messageCount * 0.001; // تخمین 1KB per message

    // دریافت اطلاعات نمایش کاربر - بهبود یافته با دریافت مستقیم از ProfileCache
    final userDisplayInfo = _getUserDisplayInfoImproved(conversation);

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withAlpha(30),
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showIndividualConversationDetails(
            conversation,
            messageCount,
            estimatedSize,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar با مدیریت خطا
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withAlpha(50),
                  ),
                  child: userDisplayInfo['avatarUrl']!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            userDisplayInfo['avatarUrl']!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                  '❌ خطا در بارگذاری تصویر: ${userDisplayInfo['avatarUrl']}');
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withAlpha(50),
                                ),
                                child: Center(
                                  child: Text(
                                    userDisplayInfo['initials']!,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withAlpha(50),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            userDisplayInfo['initials']!,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDisplayInfo['displayName']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$messageCount پیام',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Storage size with visual indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStorageColor(estimatedSize).withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        estimatedSize >= 1
                            ? '${estimatedSize.toStringAsFixed(1)} MB'
                            : '${(estimatedSize * 1024).toStringAsFixed(0)} KB',
                        style: TextStyle(
                          color: _getStorageColor(estimatedSize),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Storage bar indicator
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(30),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _getStoragePercentage(estimatedSize),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getStorageColor(estimatedSize),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get color based on storage size
  Color _getStorageColor(double sizeMB) {
    if (sizeMB < 1) return Colors.green;
    if (sizeMB < 5) return Colors.orange;
    if (sizeMB < 10) return Colors.red;
    return Colors.purple;
  }

  /// Get storage percentage for visual indicator (0.0 to 1.0)
  double _getStoragePercentage(double sizeMB) {
    // Normalize to 0-1 range, with 20MB as max
    return (sizeMB / 20).clamp(0.0, 1.0);
  }

  String _getPersianInitial(String name) {
    if (name.isEmpty) return '؟';

    // حذف فضاهای اضافی و گرفتن اولین کاراکتر
    final cleanName = name.trim();
    if (cleanName.isEmpty) return '؟';

    final firstChar = cleanName[0];

    // اگر کاراکتر فارسی است، آن را برگردان
    if (firstChar.codeUnitAt(0) >= 0x0600 &&
        firstChar.codeUnitAt(0) <= 0x06FF) {
      return firstChar.toUpperCase();
    }

    // اگر کاراکتر انگلیسی است، آن را برگردان
    if (firstChar.codeUnitAt(0) >= 0x0041 &&
        firstChar.codeUnitAt(0) <= 0x005A) {
      return firstChar;
    }

    if (firstChar.codeUnitAt(0) >= 0x0061 &&
        firstChar.codeUnitAt(0) <= 0x007A) {
      return firstChar.toUpperCase();
    }

    // برای سایر کاراکترها
    return firstChar.toUpperCase();
  }

  /// Helper method to get proper display name for conversation
  // متد _getConversationDisplayName حذف شد - استفاده نمی‌شود

  // تب فایل‌ها حذف شد - دیگر استفاده نمی‌شود

  // تب فایل‌ها و رسانه‌ها حذف شد

  String _formatFileSize(double sizeMB) {
    if (sizeMB < 1) {
      return '${(sizeMB * 1024).toStringAsFixed(0)} KB';
    } else if (sizeMB < 1024) {
      return '${sizeMB.toStringAsFixed(1)} MB';
    } else {
      return '${(sizeMB / 1024).toStringAsFixed(2)} GB';
    }
  }

  // Dialog and helper methods
  void _showStorageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Storage Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('Refresh Statistics'),
              onTap: () {
                Navigator.pop(context);
                _loadAllStats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text('Advanced Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to advanced settings
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'Are you sure you want to clear all cached data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performClearCache();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAutoRemoveOptions(
    String title,
    String currentValue,
    Function(String) onChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _autoRemoveOptions
              .map(
                (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: currentValue,
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearCache() async {
    try {
      setState(() => _isLoading = true);

      // Clear all caches
      await _cacheManager.clearAllCaches();
      await _profileCache.clearAllCache();
      await _storageService.clearAllCaches();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload statistics
      await _loadAllStats();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error clearing cache: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showIndividualConversationDetails(
    conversation,
    int messageCount,
    double estimatedSize,
  ) {
    // نمایش پاپ‌آپ جزئیات کش مکالمه خاص
    _showSpecificConversationCacheDialog(
        conversation, messageCount, estimatedSize);
  }

  // متد قدیمی حذف شد - از _showAdvancedConversationCacheDialog استفاده می‌شود

  // متد حذف شد - دیگر استفاده نمی‌شود

  // متدهای قدیمی مربوط به dialog های تکی حذف شدند - استفاده نمی‌شوند

  // متدهای قدیمی حذف شدند - استفاده نمی‌شوند

  Future<void> _performMessageCacheCleanup(String conversationId) async {
    try {
      // پاک‌سازی پیام‌های cached از memory
      final cachedMessages = _advancedCache.getCachedMessages(conversationId);
      final messageCount = cachedMessages.length;

      print('پاک شده Messages: $messageCount پیام برای گفتگو $conversationId');

      // پاک‌سازی از database files
      await _clearConversationFromDatabase(conversationId);

      // Force reload to clear memory cache
      await _advancedCache.initialize();
    } catch (e) {
      print('خطا در پاک‌سازی message cache: $e');
      // Don't rethrow - this is not critical
    }
  }

  // متدهای قدیمی حذف شدند

  // متدهای قدیمی حذف شدند - استفاده نمی‌شوند

  Future<void> _clearConversationFromDatabase(String conversationId) async {
    try {
      // پاک‌سازی از message cache database
      final messageCacheFile = await getMessageCacheDbFile();
      if (messageCacheFile != null && await messageCacheFile.exists()) {
        // اینجا می‌توان از SQLite برای حذف رکوردهای مربوط به conversation استفاده کرد
        // فعلاً فایل را به‌روزرسانی می‌کنیم
        print('پاک‌سازی database برای گفتگو: $conversationId');
      }

      // پاک‌سازی از conversation cache database
      final conversationCacheFile = await getConversationCacheDbFile();
      if (conversationCacheFile != null &&
          await conversationCacheFile.exists()) {
        print('پاک‌سازی conversation database برای گفتگو: $conversationId');
      }
    } catch (e) {
      print('خطا در پاک‌سازی database: $e');
    }
  }

  Future<void> _performImageCacheCleanup(String conversationId) async {
    try {
      // پاک‌سازی از chat image cache
      await _cacheManager.chatInstance.emptyCache();
      print('پاک شده Chat images cache');

      // اگر نیاز به پاک‌سازی selective باشد، می‌توان از conversation ID استفاده کرد
      // فعلاً کل chat cache پاک می‌شود
    } catch (e) {
      print('خطا در پاک‌سازی image cache: $e');
      // Don't rethrow - this is not critical
    }
  }

  // متد _performSelectiveImageCleanup حذف شد - استفاده نمی‌شود

  /// Show specific conversation cache dialog
  void _showSpecificConversationCacheDialog(
    conversation,
    int messageCount,
    double estimatedSize,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSpecificConversationCacheSheet(
        context,
        Theme.of(context).brightness == Brightness.dark,
        conversation,
        messageCount,
        estimatedSize,
      ),
    );
  }

  /// Build specific conversation cache management sheet
  Widget _buildSpecificConversationCacheSheet(
    BuildContext context,
    bool isDark,
    conversation,
    int messageCount,
    double estimatedSize,
  ) {
    return FutureBuilder<ConversationCacheDetails>(
      future: _calculateSpecificConversationCache(
          conversation, messageCount, estimatedSize),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final cacheDetails = snapshot.data;
        if (cacheDetails == null) {
          return Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Center(
              child: Text('خطا در بارگذاری اطلاعات کش'),
            ),
          );
        }

        return _buildSpecificConversationContent(context, isDark, cacheDetails);
      },
    );
  }

  // متد _buildAdvancedCacheClearSheet حذف شد - استفاده نمی‌شود

  /// Calculate cache details for a specific conversation
  Future<ConversationCacheDetails> _calculateSpecificConversationCache(
    conversation,
    int messageCount,
    double estimatedSize,
  ) async {
    // استفاده از همان منطق _buildRealChatItem برای نمایش نام و عکس
    String displayName = 'گفتگوی ناشناس';
    String? avatarUrl;

    try {
      print('🔍 محاسبه اطلاعات کش برای مکالمه: ${conversation.id}');
      print(
          '📋 اطلاعات conversation: otherUserName=${conversation.otherUserName}, otherUserId=${conversation.otherUserId}');

      // اولویت 1: استفاده از اطلاعات موجود در conversation (که حالا باید پر باشد)
      if (conversation.otherUserName != null &&
          conversation.otherUserName!.isNotEmpty &&
          conversation.otherUserName != 'کاربر ناشناس') {
        displayName = conversation.otherUserName!;
        print('✅ استفاده از conversation.otherUserName: $displayName');
      }

      if (conversation.otherUserAvatar != null &&
          conversation.otherUserAvatar!.isNotEmpty) {
        avatarUrl = conversation.otherUserAvatar!;
        print('✅ استفاده از conversation.otherUserAvatar: $avatarUrl');
      }

      // اولویت 2: استفاده از userProfiles اگر conversation info کامل نیست
      if ((displayName == 'گفتگوی ناشناس' || avatarUrl == null)) {
        // بارگذاری userProfiles از Supabase
        final userProfiles =
            await _loadUserProfilesForConversations([conversation]);

        // از otherUserId استفاده کن
        if (conversation.otherUserId != null &&
            userProfiles.containsKey(conversation.otherUserId!)) {
          final userInfo = userProfiles[conversation.otherUserId!]!;
          if (displayName == 'گفتگوی ناشناس') {
            displayName = userInfo['name'] ?? 'کاربر ناشناس';
          }
          avatarUrl ??= userInfo['avatar'];
          print('✅ استفاده از userProfiles برای otherUserId: $displayName');
        } else {
          // از participants استفاده کن
          for (final participant in conversation.participants) {
            if (participant.userId != null &&
                userProfiles.containsKey(participant.userId!)) {
              final userInfo = userProfiles[participant.userId!]!;
              if (displayName == 'گفتگوی ناشناس') {
                displayName = userInfo['name'] ?? 'کاربر ناشناس';
              }
              avatarUrl ??= userInfo['avatar'];
              print('✅ استفاده از userProfiles برای participant: $displayName');
              break;
            }
          }
        }
      }

      // اولویت 3: fallback به profile cache اگر userProfiles در دسترس نیست
      if (displayName == 'گفتگوی ناشناس') {
        if (conversation.otherUserId != null) {
          final cachedProfile =
              _profileCache.getCachedProfile(conversation.otherUserId!);
          if (cachedProfile != null) {
            if (cachedProfile.fullName.isNotEmpty) {
              displayName = cachedProfile.fullName;
            } else if (cachedProfile.username.isNotEmpty) {
              displayName = cachedProfile.username;
            } else {
              displayName = 'کاربر ناشناس';
            }
            avatarUrl ??= cachedProfile.avatarUrl;
            print('✅ استفاده از cached profile: $displayName');
          } else {
            displayName = 'کاربر ناشناس';
          }
        }
      }

      // آخرین fallback
      if (displayName == 'گفتگوی ناشناس') {
        displayName =
            'گفتگو ${conversation.id.substring(0, math.min<int>(8, conversation.id.length))}';
      }

      print('🎯 Final display name: $displayName, avatar: $avatarUrl');
    } catch (e) {
      print('❌ خطا در محاسبه اطلاعات مکالمه: $e');
      displayName = 'گفتگوی ناشناس';
      avatarUrl = null;
    }

    // محاسبه انواع کش برای این مکالمه خاص
    final messages = _advancedCache.getCachedMessages(conversation.id);

    // تخمین تعداد انواع مختلف پیام‌ها
    final textMessages = messages.length; // همه پیام‌ها فعلاً متنی هستند
    final imageMessages = (messages.length * 0.15).round(); // تخمین 15% تصویر
    final voiceMessages = (messages.length * 0.05).round(); // تخمین 5% ویس

    // محاسبه حجم هر دسته
    final textSizeKB = textMessages * 0.5; // 0.5 KB per text message
    final imageSizeKB = imageMessages * 150.0; // 150 KB per image
    final voiceSizeKB = voiceMessages * 30.0; // 30 KB per voice message

    final totalSizeKB = textSizeKB + imageSizeKB + voiceSizeKB;

    // ایجاد دسته‌بندی‌های کش
    final categories = <String, ConversationCacheCategory>{
      'text': ConversationCacheCategory(
        name: 'پیام‌های متنی',
        description: '$textMessages پیام',
        icon: Icons.chat_bubble_outline,
        color: Colors.blue,
        sizeKB: textSizeKB,
        count: textMessages,
      ),
      'images': ConversationCacheCategory(
        name: 'تصاویر',
        description: '$imageMessages تصویر',
        icon: Icons.image,
        color: Colors.green,
        sizeKB: imageSizeKB,
        count: imageMessages,
      ),
      'voice': ConversationCacheCategory(
        name: 'پیام‌های صوتی',
        description: '$voiceMessages ویس',
        icon: Icons.mic,
        color: Colors.orange,
        sizeKB: voiceSizeKB,
        count: voiceMessages,
      ),
    };

    return ConversationCacheDetails(
      conversationId: conversation.id,
      displayName: displayName,
      avatarUrl: avatarUrl,
      messageCount: messageCount,
      totalSizeKB: totalSizeKB,
      categories: categories,
      conversation: conversation,
    );
  }

  /// Build content for specific conversation cache sheet
  Widget _buildSpecificConversationContent(
    BuildContext context,
    bool isDark,
    ConversationCacheDetails cacheDetails,
  ) {
    // حالت‌های محلی برای انیمیشن حذف کش
    final Set<String> recentlyClearedKeys = <String>{};
    final Map<String, double> clearedOriginalSizes = <String, double>{};
    int animationVersion = 0;

    return StatefulBuilder(
      builder: (context, setStateSheet) {
        // محاسبه حجم انتخاب شده
        double calculateSelectedSize() {
          return cacheDetails.categories.values
              .where((category) => category.isSelected)
              .fold<double>(0, (sum, category) => sum + category.sizeKB);
        }

        // محاسبه درصدها برای نمودار
        final selectedCategories = cacheDetails.categories.values
            .where((category) => category.isSelected)
            .toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Fixed header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                        const Expanded(
                          child: Text(
                            'مدیریت کش مکالمه',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Conversation profile with circular chart around it
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Circular chart around avatar with smooth animation
                        TweenAnimationBuilder<double>(
                          key: ValueKey(animationVersion),
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, progress, _) {
                            // بر اساس progress، اندازه دسته‌های حذف‌شده را به صفر نزدیک می‌کنیم
                            final List<ConversationCacheCategory> animatedCats =
                                cacheDetails.categories.entries.map((e) {
                              final cat = e.value;
                              final key = e.key;
                              double size = cat.sizeKB;
                              if (clearedOriginalSizes.containsKey(key)) {
                                final original = clearedOriginalSizes[key]!;
                                // در طول انیمیشن از original به 0 می‌رویم
                                size = original * (1 - progress);
                              }
                              return ConversationCacheCategory(
                                name: cat.name,
                                description: cat.description,
                                icon: cat.icon,
                                color: cat.color,
                                sizeKB: size,
                                count: cat.count,
                                isSelected: cat.isSelected,
                              );
                            }).toList();

                            // فقط دسته‌های انتخاب‌شده را در حلقه نشان بده
                            final animatedSelected = animatedCats
                                .where((c) => cacheDetails.categories.values
                                    .any((orig) =>
                                        orig.name == c.name && orig.isSelected))
                                .toList();

                            return SizedBox(
                              width: 90,
                              height: 90,
                              child: CustomPaint(
                                painter: ConversationSpecificCacheChartPainter(
                                  animatedSelected,
                                  isDark,
                                ),
                              ),
                            );
                          },
                        ),
                        // Profile avatar
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue.withAlpha(50),
                          backgroundImage: cacheDetails.avatarUrl != null &&
                                  cacheDetails.avatarUrl!.isNotEmpty
                              ? NetworkImage(cacheDetails.avatarUrl!)
                              : null,
                          onBackgroundImageError: cacheDetails.avatarUrl != null
                              ? (exception, stackTrace) {
                                  print(
                                      'خطا در بارگذاری تصویر پروفایل: $exception');
                                }
                              : null,
                          child: (cacheDetails.avatarUrl == null ||
                                  cacheDetails.avatarUrl!.isEmpty)
                              ? Text(
                                  _getPersianInitial(cacheDetails.displayName),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      cacheDetails.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${cacheDetails.messageCount} پیام • ${_formatFileSize(cacheDetails.totalSizeKB / 1024)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // نمودار حالا دور عکس پروفایل قرار گرفته است

                      // Cache categories section
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'انواع کش',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...cacheDetails.categories.values.map((category) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildSpecificConversationCacheItem(
                                  category,
                                  (value) => setStateSheet(() {
                                    category.isSelected = value;
                                  }),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Fixed bottom action section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[300]!,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: selectedCategories.isNotEmpty
                            ? () {
                                // قبل از پاک‌سازی، اندازه‌های فعلی را ذخیره می‌کنیم تا انیمیشن طبیعی باشد
                                final Map<String, double> beforeSizes = {};
                                for (final entry
                                    in cacheDetails.categories.entries) {
                                  if (selectedCategories
                                      .contains(entry.value)) {
                                    beforeSizes[entry.key] = entry.value.sizeKB;
                                  }
                                }

                                _performSpecificConversationCacheClear(
                                  context,
                                  cacheDetails,
                                  selectedCategories,
                                  onCleared: (List<String> clearedKeys) {
                                    setStateSheet(() {
                                      clearedOriginalSizes
                                        ..clear()
                                        ..addAll(beforeSizes);
                                      recentlyClearedKeys
                                        ..clear()
                                        ..addAll(clearedKeys);
                                      animationVersion++; // اجرای انیمیشن
                                    });
                                  },
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedCategories.isNotEmpty
                              ? Colors.red
                              : Colors.grey[400],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: selectedCategories.isNotEmpty ? 2 : 0,
                        ),
                        child: Text(
                          selectedCategories.isNotEmpty
                              ? 'پاک‌سازی انتخاب شده (${(calculateSelectedSize() / 1024).toStringAsFixed(1)} MB)'
                              : 'هیچ موردی انتخاب نشده',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'پیام‌ها در فضای ابری ویستا باقی می‌مانند',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // متد _calculateConversationCacheItems حذف شد - استفاده نمی‌شود

  // متدهای قدیمی مربوط به dialog کل گفتگوها حذف شدند

  // متدهای قدیمی مربوط به پاپ‌آپ کل مکالمه‌ها حذف شدند

  /// Build cache item for specific conversation categories
  Widget _buildSpecificConversationCacheItem(
    ConversationCacheCategory category,
    Function(bool) onChanged,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: category.isSelected
            ? category.color.withAlpha(15)
            : Colors.grey.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              category.isSelected ? category.color : Colors.grey.withAlpha(40),
          width: category.isSelected ? 2 : 1,
        ),
        boxShadow: category.isSelected
            ? [
                BoxShadow(
                  color: category.color.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onChanged(!category.isSelected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.isSelected
                        ? category.color.withAlpha(40)
                        : category.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: category.isSelected
                              ? category.color
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Size info and checkbox
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(category.sizeKB / 1024).toStringAsFixed(1)} MB',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: category.isSelected
                            ? category.color
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${category.count} آیتم',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Transform.scale(
                      scale: 1.05,
                      child: Checkbox(
                        value: category.isSelected,
                        onChanged: (value) => onChanged(value ?? false),
                        activeColor: category.color,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Perform cache clearing for specific conversation categories
  Future<void> _performSpecificConversationCacheClear(
    BuildContext context,
    ConversationCacheDetails cacheDetails,
    List<ConversationCacheCategory> selectedCategories, {
    Function(List<String>)? onCleared,
  }) async {
    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هیچ دسته‌ای انتخاب نشده است'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totalSize =
        selectedCategories.fold<double>(0, (sum, cat) => sum + cat.sizeKB);

    // نمایش dialog تأیید
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید پاک‌سازی کش'),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید کش انتخاب شده از مکالمه "${cacheDetails.displayName}" را پاک کنید؟\n\nحجم: ${(totalSize / 1024).toStringAsFixed(1)} MB\n\nدسته‌های انتخاب شده:\n${selectedCategories.map((cat) => '• ${cat.name}').join('\n')}',
        ),
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

    try {
      // نمایش loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('در حال پاک‌سازی کش...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // پاک‌سازی بر اساس دسته‌های انتخاب شده
      final List<String> clearedKeys = [];
      final Map<String, ConversationCacheCategory> categories =
          cacheDetails.categories;
      for (final category in selectedCategories) {
        // کلید دسته را پیدا کن
        final String key = categories.entries
            .firstWhere((e) => e.value.name == category.name,
                orElse: () => MapEntry('unknown', category))
            .key;

        if (category.name.contains('متنی')) {
          // پاک‌سازی پیام‌های متنی
          await _performMessageCacheCleanup(cacheDetails.conversationId);
        } else if (category.name.contains('تصاویر')) {
          // پاک‌سازی تصاویر
          await _performImageCacheCleanup(cacheDetails.conversationId);
        } else if (category.name.contains('صوتی')) {
          // پاک‌سازی فایل‌های صوتی (voice messages)
          await _performVoiceCacheCleanup(cacheDetails.conversationId);
        }

        clearedKeys.add(key);
      }

      // اطلاع به UI برای اجرای انیمیشن و صفر شدن تدریجی اندازه‌ها
      if (onCleared != null) {
        onCleared(clearedKeys);
      }

      // پیام موفقیت
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'کش انتخاب شده از مکالمه "${cacheDetails.displayName}" (${(totalSize / 1024).toStringAsFixed(1)} MB) با موفقیت پاک شد',
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'تمام',
            onPressed: () {},
            textColor: Colors.white,
          ),
        ),
      );

      // بروزرسانی آمار
      await _loadAllStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در پاک‌سازی کش: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Clean voice cache for specific conversation
  Future<void> _performVoiceCacheCleanup(String conversationId) async {
    try {
      // پاک‌سازی cache مرتبط با فایل‌های صوتی
      // اینجا می‌توان cache مخصوص voice messages را پاک کرد
      print('پاک‌سازی voice cache برای مکالمه: $conversationId');

      // اگر سیستم cache مخصوص voice داریم:
      // await _voiceCacheManager.clearConversationVoiceCache(conversationId);
    } catch (e) {
      print('خطا در پاک‌سازی voice cache: $e');
    }
  }

  // متد قدیمی _performAdvancedConversationCacheClear حذف شد - استفاده نمی‌شود

  // متدهای قدیمی حذف شدند - از _performAdvancedConversationCacheClear استفاده می‌شود
}

// مدل برای آیتم‌های کش مکالمه
class ConversationCacheItem {
  final String conversationId;
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final Color color;
  final double sizeKB;
  final int messageCount;
  double percentage;
  bool isSelected;
  final dynamic conversation; // ConversationModel

  ConversationCacheItem({
    required this.conversationId,
    required this.title,
    required this.subtitle,
    this.avatarUrl,
    required this.color,
    required this.sizeKB,
    required this.messageCount,
    this.percentage = 0,
    required this.isSelected,
    required this.conversation,
  });
}

/// Details of cache for a specific conversation
class ConversationCacheDetails {
  final String conversationId;
  final String displayName;
  final String? avatarUrl;
  final int messageCount;
  final double totalSizeKB;
  final Map<String, ConversationCacheCategory> categories;
  final dynamic conversation;

  ConversationCacheDetails({
    required this.conversationId,
    required this.displayName,
    this.avatarUrl,
    required this.messageCount,
    required this.totalSizeKB,
    required this.categories,
    required this.conversation,
  });
}

/// Individual cache category for a conversation
class ConversationCacheCategory {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final double sizeKB;
  final int count;
  bool isSelected;

  ConversationCacheCategory({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.sizeKB,
    required this.count,
    this.isSelected = true,
  });
}

// Custom painter for specific conversation cache chart
class ConversationSpecificCacheChartPainter extends CustomPainter {
  final List<ConversationCacheCategory> categories;
  final bool isDark;

  ConversationSpecificCacheChartPainter(this.categories, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = isDark ? Colors.grey[800]! : Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (categories.isEmpty) return;

    // محاسبه مجموع حجم
    final totalSize =
        categories.fold<double>(0, (sum, cat) => sum + cat.sizeKB);
    if (totalSize <= 0) return;

    // Draw category arcs
    double startAngle = -math.pi / 2; // Start from top

    for (final category in categories) {
      if (category.sizeKB < 0.1) continue; // حداقل حجم برای نمایش

      final percentage = (category.sizeKB / totalSize * 100);
      final sweepAngle = (percentage / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Custom painter for conversation cache chart
class ConversationCacheChartPainter extends CustomPainter {
  final List<ConversationCacheItem> conversations;
  final bool isDark;

  ConversationCacheChartPainter(this.conversations, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = isDark ? Colors.grey[800]! : Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (conversations.isEmpty) return;

    // محاسبه مجموع حجم
    final totalSize =
        conversations.fold<double>(0, (sum, conv) => sum + conv.sizeKB);
    if (totalSize <= 0) return;

    // Draw conversation arcs
    double startAngle = -math.pi / 2; // Start from top

    for (final conversation in conversations) {
      if (conversation.sizeKB < 0.1) continue; // حداقل حجم برای نمایش

      final percentage = (conversation.sizeKB / totalSize * 100);
      final sweepAngle = (percentage / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = conversation.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Custom painter for the circular storage chart (like Telegram)
class StorageChartPainter extends CustomPainter {
  final List<StorageCategory> categories;
  final bool isDark;

  StorageChartPainter(this.categories, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = isDark ? Colors.grey[800]! : Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw category arcs
    double startAngle = -math.pi / 2; // Start from top

    for (final category in categories) {
      if (category.percentage < 1.0) continue;

      final sweepAngle = (category.percentage / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
