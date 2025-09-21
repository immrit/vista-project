import 'package:flutter/material.dart';
import 'dart:async';

/// مجموعه بهبودهای performance برای ChatScreen
class ChatPerformanceImprovements {
  /// کش برای calculations گران
  static final Map<String, dynamic> _calculationCache = {};

  /// Timer برای debouncing
  static Timer? _debounceTimer;

  /// کلیدهای کش
  static const String _wallpaperUrlKey = 'wallpaper_url';
  static const String _overlayColorKey = 'overlay_color';
  static const String _borderRadiusKey = 'border_radius';
  static const String _formattedTimeKey = 'formatted_time';

  /// پاک کردن کش
  static void clearCache() {
    _calculationCache.clear();
  }

  /// گرفتن wallpaper URL با کش
  static String getCachedWallpaperUrl(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final key = '${_wallpaperUrlKey}_$isDarkMode';

    if (_calculationCache.containsKey(key)) {
      return _calculationCache[key] as String;
    }

    // محاسبه و کش کردن
    final url = isDarkMode
        ? 'https://storage.389346.ir.cdn.ir/vista/chat-wallpapers/dark_wallpaper.jpg'
        : 'https://storage.389346.ir.cdn.ir/vista/chat-wallpapers/light_wallpaper.jpg';

    _calculationCache[key] = url;
    return url;
  }

  /// گرفتن overlay color با کش
  static Color getCachedOverlayColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final key = '${_overlayColorKey}_$isDarkMode';

    if (_calculationCache.containsKey(key)) {
      return _calculationCache[key] as Color;
    }

    // محاسبه و کش کردن
    final color = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.white.withOpacity(0.4);

    _calculationCache[key] = color;
    return color;
  }

  /// گرفتن border radius با کش
  static BorderRadius getCachedBorderRadius(bool isMe, double fontSize) {
    final key = '${_borderRadiusKey}_${isMe}_$fontSize';

    if (_calculationCache.containsKey(key)) {
      return _calculationCache[key] as BorderRadius;
    }

    // محاسبه و کش کردن
    final baseRadius = (18.0 > fontSize * 1.3) ? 18.0 : fontSize * 1.3;
    final tailSmallRadius = (3.0 > fontSize * 0.22) ? 3.0 : fontSize * 0.22;
    final tailLargeRadius = (22.0 > fontSize * 1.6) ? 22.0 : fontSize * 1.6;

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(baseRadius),
      topRight: Radius.circular(baseRadius),
      bottomLeft: Radius.circular(isMe ? tailLargeRadius : tailSmallRadius),
      bottomRight: Radius.circular(isMe ? tailSmallRadius : tailLargeRadius),
    );

    _calculationCache[key] = borderRadius;
    return borderRadius;
  }

  /// فرمت کردن زمان با کش
  static String getCachedFormattedTime(DateTime dateTime) {
    final key = '${_formattedTimeKey}_${dateTime.millisecondsSinceEpoch}';

    if (_calculationCache.containsKey(key)) {
      return _calculationCache[key] as String;
    }

    // محاسبه و کش کردن
    final tehranOffset = const Duration(hours: 3, minutes: 30);
    final tehranTime = dateTime.toUtc().add(tehranOffset);
    final formatted =
        '${tehranTime.hour.toString().padLeft(2, '0')}:${tehranTime.minute.toString().padLeft(2, '0')}';

    _calculationCache[key] = formatted;
    return formatted;
  }

  /// Debounced function execution
  static void debouncedExecute(VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 100)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }

  /// Widget wrapper برای memoization
  static Widget memoizedWidget(String key, Widget Function() builder) {
    if (_calculationCache.containsKey(key)) {
      return _calculationCache[key] as Widget;
    }

    final widget = builder();
    _calculationCache[key] = widget;
    return widget;
  }
}

/// Mixin برای بهبود performance widgets
mixin PerformanceOptimizationMixin on State {
  /// کش محلی برای widget
  final Map<String, dynamic> _localCache = {};

  /// پاک کردن کش محلی
  void clearLocalCache() {
    _localCache.clear();
  }

  /// گرفتن مقدار از کش محلی
  T? getCached<T>(String key) {
    return _localCache[key] as T?;
  }

  /// تنظیم مقدار در کش محلی
  void setCached<T>(String key, T value) {
    _localCache[key] = value;
  }

  /// Debounced setState
  Timer? _setStateTimer;
  void debouncedSetState(VoidCallback fn,
      {Duration delay = const Duration(milliseconds: 50)}) {
    _setStateTimer?.cancel();
    _setStateTimer = Timer(delay, () {
      if (mounted) {
        setState(fn);
      }
    });
  }

  @override
  void dispose() {
    _setStateTimer?.cancel();
    clearLocalCache();
    super.dispose();
  }
}

/// OptimizedAnimatedContainer - جایگزین AnimatedContainer
class OptimizedAnimatedContainer extends StatefulWidget {
  final Duration duration;
  final Curve curve;
  final Widget child;
  final Color? color;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;

  const OptimizedAnimatedContainer({
    super.key,
    required this.duration,
    this.curve = Curves.linear,
    required this.child,
    this.color,
    this.decoration,
    this.padding,
    this.margin,
    this.transform,
  });

  @override
  State<OptimizedAnimatedContainer> createState() =>
      _OptimizedAnimatedContainerState();
}

class _OptimizedAnimatedContainerState extends State<OptimizedAnimatedContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.decoration,
      padding: widget.padding,
      margin: widget.margin,
      transform: widget.transform,
      child: widget.child,
    );
  }
}

/// OptimizedMessageBubble - bubble بهینه‌شده
class OptimizedMessageBubble extends StatelessWidget {
  final Widget child;
  final bool isMe;
  final Color bubbleColor;
  final BorderRadius borderRadius;
  final bool showBorder;

  const OptimizedMessageBubble({
    super.key,
    required this.child,
    required this.isMe,
    required this.bubbleColor,
    required this.borderRadius,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: Colors.grey[200]!,
                width: 1,
              )
            : null,
      ),
      child: child,
    );
  }
}

/// Controller برای مدیریت performance
class ChatPerformanceController {
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiration = Duration(minutes: 5);

  final Map<String, _CacheEntry> _cache = {};
  Timer? _cleanupTimer;

  ChatPerformanceController() {
    _startCleanupTimer();
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupExpiredEntries();
    });
  }

  void _cleanupExpiredEntries() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) {
      return now.difference(entry.timestamp) > _cacheExpiration;
    });

    // حداکثر اندازه کش
    if (_cache.length > _maxCacheSize) {
      final sortedEntries = _cache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      final toRemove = sortedEntries.take(_cache.length - _maxCacheSize);
      for (final entry in toRemove) {
        _cache.remove(entry.key);
      }
    }
  }

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry != null) {
      final now = DateTime.now();
      if (now.difference(entry.timestamp) < _cacheExpiration) {
        return entry.value as T;
      } else {
        _cache.remove(key);
      }
    }
    return null;
  }

  void set<T>(String key, T value) {
    _cache[key] = _CacheEntry(value, DateTime.now());
  }

  void clear() {
    _cache.clear();
  }

  void dispose() {
    _cleanupTimer?.cancel();
    clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime timestamp;

  _CacheEntry(this.value, this.timestamp);
}

/// Extension methods برای performance
extension PerformanceExtensions on Widget {
  /// Wrapper برای پیشگیری از rebuilds غیرضروری
  Widget preventRebuild() {
    return RepaintBoundary(child: this);
  }

  /// Cache کردن widget
  Widget cached(String key) {
    return ChatPerformanceImprovements.memoizedWidget(key, () => this);
  }
}

/// Utils برای optimization
class ChatOptimizationUtils {
  /// محاسبه تعداد پیام‌های قابل مشاهده
  static int calculateVisibleItemCount(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    const averageMessageHeight = 80.0;
    return (screenHeight / averageMessageHeight).ceil() + 2; // +2 برای buffer
  }

  /// بررسی اینکه آیا widget در viewport است یا نه
  static bool isWidgetInViewport(BuildContext context, GlobalKey key) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    return position.dy < screenSize.height &&
        position.dy + size.height > 0 &&
        position.dx < screenSize.width &&
        position.dx + size.width > 0;
  }

  /// تنظیمات بهینه‌سازی تصاویر
  static const int optimizedImageCacheWidth = 800;
  static const int optimizedImageCacheHeight = 600;
  static const Duration imageLoadTimeout = Duration(seconds: 30);

  /// محاسبه اندازه بهینه thumbnail
  static Size calculateOptimalThumbnailSize(Size originalSize, Size maxSize) {
    final aspectRatio = originalSize.width / originalSize.height;

    if (originalSize.width <= maxSize.width &&
        originalSize.height <= maxSize.height) {
      return originalSize;
    }

    double width, height;

    if (aspectRatio > 1) {
      // Landscape
      width = maxSize.width;
      height = width / aspectRatio;
      if (height > maxSize.height) {
        height = maxSize.height;
        width = height * aspectRatio;
      }
    } else {
      // Portrait
      height = maxSize.height;
      width = height * aspectRatio;
      if (width > maxSize.width) {
        width = maxSize.width;
        height = width / aspectRatio;
      }
    }

    return Size(width, height);
  }
}
