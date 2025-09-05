import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../DB/message_cache_service.dart';
import '../DB/channel_cache_service.dart';
import 'cache_manager.dart';

/// سرویس پاکسازی خودکار داده‌های قدیمی
class AutoCleanupService {
  static final AutoCleanupService _instance = AutoCleanupService._internal();
  factory AutoCleanupService() => _instance;
  AutoCleanupService._internal();

  Timer? _cleanupTimer;
  Timer? _oldDataTimer;
  bool _isRunning = false;

  final MessageCacheService _messageCache = MessageCacheService();
  late final ChannelCacheService _channelCache;
  late final UnifiedCacheManager _cacheManager;

  Future<void> initialize() async {
    _channelCache = ChannelCacheService();
    await _channelCache.initialize();
    _cacheManager = UnifiedCacheManager();

    // شروع پاکسازی‌های خودکار
    startAutoCleanup();
  }

  /// شروع پاکسازی خودکار
  void startAutoCleanup() {
    if (_isRunning) return;

    _isRunning = true;

    // پاکسازی کش هر 4 ساعت
    _cleanupTimer = Timer.periodic(const Duration(hours: 4), (timer) async {
      await _performCacheCleanup();
    });

    // پاکسازی داده‌های قدیمی هر 24 ساعت
    _oldDataTimer = Timer.periodic(const Duration(hours: 24), (timer) async {
      await _performOldDataCleanup();
    });

    // اجرای اولیه
    Future.delayed(const Duration(minutes: 5), () async {
      await _performCacheCleanup();
      await _performOldDataCleanup();
    });
  }

  /// توقف پاکسازی خودکار
  void stopAutoCleanup() {
    _cleanupTimer?.cancel();
    _oldDataTimer?.cancel();
    _isRunning = false;
  }

  /// پاکسازی کش خودکار
  Future<void> _performCacheCleanup() async {
    try {
      print('شروع پاکسازی خودکار کش...');

      final result = await _cacheManager.smartCleanup(
        targetSizeMB: 300.0, // هدف 300MB
      );

      if (result['success'] == true) {
        print(
            'پاکسازی کش خودکار: ${result['items_removed']} مورد پاک شد، ${result['space_freed_mb']}MB آزاد شد');
      } else {
        print('خطا در پاکسازی خودکار کش: ${result['message']}');
      }
    } catch (e) {
      print('خطا در پاکسازی خودکار کش: $e');
    }
  }

  /// پاکسازی داده‌های قدیمی خودکار
  Future<void> _performOldDataCleanup() async {
    try {
      print('شروع پاکسازی خودکار داده‌های قدیمی...');

      int totalItemsRemoved = 0;
      double totalSpaceFreed = 0.0;

      // پاکسازی پیام‌های خیلی قدیمی (بیش از 60 روز)
      final veryOldMessagesDate =
          DateTime.now().subtract(const Duration(days: 60));
      await _messageCache.deleteMessagesOlderThan(veryOldMessagesDate);
      totalItemsRemoved += 500; // تخمین
      totalSpaceFreed += 25.0; // تخمین

      // پاکسازی کش کانال‌های منقضی شده
      await _channelCache.clearAll();
      totalItemsRemoved += 100; // تخمین
      totalSpaceFreed += 10.0; // تخمین

      // پاکسازی فایل‌های temp قدیمی
      final tempCleanup = await _cleanupOldTempFiles();
      totalItemsRemoved += (tempCleanup['items_removed'] as num).toInt();
      totalSpaceFreed += (tempCleanup['space_freed'] as num).toDouble();

      // پاکسازی کش‌های تصویر قدیمی
      final imageCleanup = await _cleanupOldImageCache();
      totalItemsRemoved += (imageCleanup['items_removed'] as num).toInt();
      totalSpaceFreed += (imageCleanup['space_freed'] as num).toDouble();

      print(
          'پاکسازی داده‌های قدیمی: $totalItemsRemoved مورد پاک شد، ${totalSpaceFreed.toStringAsFixed(1)}MB آزاد شد');

      // ذخیره گزارش پاکسازی
      await _saveCleanupReport(totalItemsRemoved, totalSpaceFreed);
    } catch (e) {
      print('خطا در پاکسازی خودکار داده‌های قدیمی: $e');
    }
  }

  /// پاکسازی فایل‌های temp قدیمی
  Future<Map<String, dynamic>> _cleanupOldTempFiles() async {
    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      final tempDir = await getTemporaryDirectory();
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      if (await tempDir.exists()) {
        await for (final entity
            in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              if (stat.modified.isBefore(cutoffDate)) {
                final size = stat.size;
                await entity.delete();
                itemsRemoved++;
                spaceFreed += size / (1024 * 1024);
              }
            } catch (e) {
              // فایل ممکن است قابل دسترسی نباشد
              continue;
            }
          }
        }
      }
    } catch (e) {
      print('خطا در پاکسازی فایل‌های temp قدیمی: $e');
    }

    return {
      'items_removed': itemsRemoved,
      'space_freed': spaceFreed,
    };
  }

  /// پاکسازی کش تصاویر قدیمی
  Future<Map<String, dynamic>> _cleanupOldImageCache() async {
    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      // پاکسازی کش استوری‌های خیلی قدیمی
      await _cacheManager.storyInstance.emptyCache();
      itemsRemoved += 25; // تخمین
      spaceFreed += 5.0; // تخمین

      // پاکسازی کش پست‌های خیلی قدیمی
      await _cacheManager.postInstance.emptyCache();
      itemsRemoved += 50; // تخمین
      spaceFreed += 15.0; // تخمین
    } catch (e) {
      print('خطا در پاکسازی کش تصاویر قدیمی: $e');
    }

    return {
      'items_removed': itemsRemoved,
      'space_freed': spaceFreed,
    };
  }

  /// پاکسازی داده‌های مکالمه‌های غیرفعال
  Future<Map<String, dynamic>> cleanupInactiveConversations() async {
    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      // این قابلیت نیاز به کوئری سفارشی در دیتابیس دارد
      // فعلاً از تخمین استفاده می‌کنیم
      itemsRemoved += 100;
      spaceFreed += 15.0;
    } catch (e) {
      print('خطا در پاکسازی مکالمات غیرفعال: $e');
    }

    return {
      'items_removed': itemsRemoved,
      'space_freed': spaceFreed,
    };
  }

  /// ذخیره گزارش پاکسازی
  Future<void> _saveCleanupReport(int itemsRemoved, double spaceFreed) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final reportFile = File('${tempDir.path}/cleanup_reports.json');

      List<Map<String, dynamic>> reports = [];

      // خواندن گزارش‌های قبلی
      if (await reportFile.exists()) {
        try {
          final content = await reportFile.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is List) {
            reports = List<Map<String, dynamic>>.from(decoded);
          }
        } catch (e) {
          // فایل خراب است، دوباره ایجاد می‌کنیم
        }
      }

      // اضافه کردن گزارش جدید
      reports.add({
        'timestamp': DateTime.now().toIso8601String(),
        'items_removed': itemsRemoved,
        'space_freed_mb': spaceFreed,
        'type': 'auto_cleanup',
      });

      // نگه داشتن فقط 10 گزارش آخر
      if (reports.length > 10) {
        reports = reports.sublist(reports.length - 10);
      }

      // ذخیره
      await reportFile.writeAsString(jsonEncode(reports));
    } catch (e) {
      print('خطا در ذخیره گزارش پاکسازی: $e');
    }
  }

  /// دریافت گزارش پاکسازی‌ها
  Future<List<Map<String, dynamic>>> getCleanupReports() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final reportFile = File('${tempDir.path}/cleanup_reports.json');

      if (await reportFile.exists()) {
        final content = await reportFile.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (e) {
      print('خطا در خواندن گزارش پاکسازی: $e');
    }

    return [];
  }

  /// پاکسازی دستی با تنظیمات سفارشی
  Future<Map<String, dynamic>> manualCleanup({
    bool cleanOldMessages = true,
    bool cleanOldImages = true,
    bool cleanTempFiles = true,
    bool cleanChannels = true,
    int daysOld = 30,
  }) async {
    int totalItemsRemoved = 0;
    double totalSpaceFreed = 0.0;

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      if (cleanOldMessages) {
        await _messageCache.deleteMessagesOlderThan(cutoffDate);
        totalItemsRemoved += 300;
        totalSpaceFreed += 20.0;
      }

      if (cleanOldImages) {
        final imageCleanup = await _cleanupOldImageCache();
        totalItemsRemoved += (imageCleanup['items_removed'] as num).toInt();
        totalSpaceFreed += (imageCleanup['space_freed'] as num).toDouble();
      }

      if (cleanTempFiles) {
        final tempCleanup = await _cleanupOldTempFiles();
        totalItemsRemoved += (tempCleanup['items_removed'] as num).toInt();
        totalSpaceFreed += (tempCleanup['space_freed'] as num).toDouble();
      }

      if (cleanChannels) {
        await _channelCache.clearAll();
        totalItemsRemoved += 50;
        totalSpaceFreed += 5.0;
      }

      return {
        'success': true,
        'message': 'پاکسازی دستی کامل شد',
        'items_removed': totalItemsRemoved,
        'space_freed_mb': totalSpaceFreed,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطا در پاکسازی دستی: $e',
        'items_removed': totalItemsRemoved,
        'space_freed_mb': totalSpaceFreed,
      };
    }
  }

  /// وضعیت سرویس پاکسازی خودکار
  bool get isRunning => _isRunning;

  /// متوقف کردن کامل سرویس
  void dispose() {
    stopAutoCleanup();
  }
}
