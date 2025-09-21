import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'chat_performance_improvements.dart';
import '../../../provider/chat_provider.dart';
import '../../../provider/provider.dart';

/// پچ‌های عملکردی برای ChatScreen اصلی
/// این فایل بهبودهای performance رو بدون تغییر کامل ChatScreen اعمال می‌کنه
class ChatScreenPerformancePatches {
  /// نسخه بهینه‌شده _buildMessageItem که rebuilds رو کم می‌کنه
  static Widget buildOptimizedMessageItem({
    required BuildContext context,
    required Widget Function(BuildContext, dynamic, bool, double)
        originalBuilder,
    required dynamic message,
    required bool isMe,
    required WidgetRef ref,
    required ChatPerformanceController performanceController,
  }) {
    // Cache fontSize to prevent unnecessary Consumer rebuilds
    final fontSize = performanceController.get<double>('fontSize') ?? 16.0;

    return RepaintBoundary(
      key: ValueKey(message.id), // Prevent unnecessary rebuilds
      child: originalBuilder(context, message, isMe, fontSize),
    );
  }

  /// Handler بهینه‌شده برای scroll events
  static void optimizedScrollHandler({
    required Function originalHandler,
    required Timer? debounceTimer,
    required Function(Timer?) setDebounceTimer,
  }) {
    debounceTimer?.cancel();
    final newTimer = Timer(const Duration(milliseconds: 100), () {
      originalHandler();
    });
    setDebounceTimer(newTimer);
  }

  /// Message list builder بهینه‌شده
  static Widget buildOptimizedMessagesList({
    required BuildContext context,
    required WidgetRef ref,
    required String conversationId,
    required Widget Function(BuildContext, dynamic, bool) messageBuilder,
    required ScrollController? scrollController,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final lazyState = ref.watch(lazyMessagesProvider(conversationId));

        if (lazyState.messages.isEmpty && !lazyState.isLoading) {
          return const Center(
            child: Text(
              'پیامی وجود ندارد. اولین پیام را ارسال کنید!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // بهینه‌سازی فیلتر پیام‌ها
        final filteredMessages = _optimizedMessageFilter(lazyState.messages);

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          itemCount: filteredMessages.length + (lazyState.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == filteredMessages.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final message = filteredMessages[index];
            final currentUser = ref.read(currentUserProvider);
            final isMe = currentUser.hasValue && currentUser.value != null
                ? message.senderId == currentUser.value!['id']
                : false;

            return RepaintBoundary(
              key: ValueKey('msg_${message.id}'),
              child: messageBuilder(context, message, isMe),
            );
          },
        );
      },
    );
  }

  /// فیلتر بهینه‌شده پیام‌ها
  static List<dynamic> _optimizedMessageFilter(List<dynamic> messages) {
    // Cache the filtering result to avoid recalculation
    final realLocalIds = <String>{};
    for (final m in messages) {
      if (!m.id.startsWith('temp_') && m.localId != null) {
        realLocalIds.add(m.localId);
      }
    }

    return messages.where((m) {
      if (m.id.startsWith('temp_') && realLocalIds.contains(m.id)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Wallpaper widget بهینه‌شده
  static Widget buildOptimizedWallpaper({
    required BuildContext context,
    required String? cachedWallpaperUrl,
    required Color? cachedOverlayColor,
  }) {
    final wallpaperUrl = cachedWallpaperUrl ??
        ChatPerformanceImprovements.getCachedWallpaperUrl(context);
    final overlayColor = cachedOverlayColor ??
        ChatPerformanceImprovements.getCachedOverlayColor(context);

    return RepaintBoundary(
      child: Stack(
        children: [
          // Wallpaper
          Positioned.fill(
            child: Image.network(
              wallpaperUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [Colors.grey[900]!, Colors.grey[800]!]
                          : [Colors.grey[100]!, Colors.grey[200]!],
                    ),
                  ),
                );
              },
            ),
          ),
          // Overlay
          Positioned.fill(
            child: Container(color: overlayColor),
          ),
        ],
      ),
    );
  }

  /// Debounced setState helper
  static void debouncedSetState({
    required Function() setState,
    required Timer? debounceTimer,
    required Function(Timer?) setDebounceTimer,
    Duration delay = const Duration(milliseconds: 50),
  }) {
    debounceTimer?.cancel();
    final newTimer = Timer(delay, setState);
    setDebounceTimer(newTimer);
  }
}

/// Mixin برای اضافه کردن performance optimizations
mixin ChatScreenOptimizationMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final ChatPerformanceController _perfController;
  Timer? _scrollDebounceTimer;
  Timer? _setStateDebounceTimer;
  String? _cachedWallpaperUrl;
  Color? _cachedOverlayColor;

  @override
  void initState() {
    super.initState();
    _perfController = ChatPerformanceController();

    // Pre-cache wallpaper and overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheWallpaperAndOverlay();
    });
  }

  void _cacheWallpaperAndOverlay() {
    _cachedWallpaperUrl =
        ChatPerformanceImprovements.getCachedWallpaperUrl(context);
    _cachedOverlayColor =
        ChatPerformanceImprovements.getCachedOverlayColor(context);
  }

  @override
  void dispose() {
    _perfController.dispose();
    _scrollDebounceTimer?.cancel();
    _setStateDebounceTimer?.cancel();
    super.dispose();
  }

  /// Optimized scroll handler
  void optimizedScrollHandler(VoidCallback originalHandler) {
    ChatScreenPerformancePatches.optimizedScrollHandler(
      originalHandler: originalHandler,
      debounceTimer: _scrollDebounceTimer,
      setDebounceTimer: (timer) => _scrollDebounceTimer = timer,
    );
  }

  /// Debounced setState
  void debouncedSetState(VoidCallback fn) {
    ChatScreenPerformancePatches.debouncedSetState(
      setState: () => setState(fn),
      debounceTimer: _setStateDebounceTimer,
      setDebounceTimer: (timer) => _setStateDebounceTimer = timer,
    );
  }

  /// Get cached performance controller
  ChatPerformanceController get performanceController => _perfController;

  /// Get cached wallpaper URL
  String? get cachedWallpaperUrl => _cachedWallpaperUrl;

  /// Get cached overlay color
  Color? get cachedOverlayColor => _cachedOverlayColor;
}

/// Widget wrapper برای بهینه‌سازی automatic
class OptimizedWidget extends StatelessWidget {
  final Widget child;
  final String? cacheKey;
  final bool preventRepaint;

  const OptimizedWidget({
    super.key,
    required this.child,
    this.cacheKey,
    this.preventRepaint = true,
  });

  @override
  Widget build(BuildContext context) {
    if (preventRepaint) {
      return RepaintBoundary(
        key: cacheKey != null ? ValueKey(cacheKey) : null,
        child: child,
      );
    }
    return child;
  }
}

/// Performance monitoring برای debugging
class ChatPerformanceMonitor {
  static final Stopwatch _buildStopwatch = Stopwatch();
  static final Stopwatch _scrollStopwatch = Stopwatch();
  static final Map<String, int> _buildCounts = {};
  static final Map<String, Duration> _buildTimes = {};

  static void startBuildTimer(String widgetName) {
    _buildStopwatch.reset();
    _buildStopwatch.start();
    _buildCounts[widgetName] = (_buildCounts[widgetName] ?? 0) + 1;
  }

  static void endBuildTimer(String widgetName) {
    _buildStopwatch.stop();
    _buildTimes[widgetName] = _buildStopwatch.elapsed;

    // Log if build takes too long
    if (_buildStopwatch.elapsedMilliseconds > 16) {
      // More than one frame
      print(
          '⚠️ Slow build detected: $widgetName took ${_buildStopwatch.elapsedMilliseconds}ms');
    }
  }

  static void logPerformanceReport() {
    print('\n📊 Chat Performance Report:');
    print('Build Counts: $_buildCounts');
    print('Build Times: $_buildTimes');

    final slowWidgets = _buildTimes.entries
        .where((entry) => entry.value.inMilliseconds > 16)
        .toList();

    if (slowWidgets.isNotEmpty) {
      print('🐌 Slow widgets:');
      for (final entry in slowWidgets) {
        print('  ${entry.key}: ${entry.value.inMilliseconds}ms');
      }
    }
  }

  static void reset() {
    _buildCounts.clear();
    _buildTimes.clear();
  }
}
