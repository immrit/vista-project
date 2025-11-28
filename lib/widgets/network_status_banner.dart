// lib/widgets/network_status_banner.dart
//
// بنر وضعیت شبکه که در بالای صفحه نمایش داده میشه
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/network_state.dart';
import '../provider/network_provider.dart';

/// بنر وضعیت شبکه
/// 
/// فقط زمانی نمایش داده میشه که:
/// - آفلاین باشیم
/// - کیفیت شبکه ضعیف باشه
/// 
/// استفاده:
/// ```dart
/// Column(
///   children: [
///     const NetworkStatusBanner(),
///     Expanded(child: ...),
///   ],
/// )
/// ```
class NetworkStatusBanner extends ConsumerWidget {
  /// آیا انیمیشن داشته باشه؟
  final bool animated;
  
  /// آیا دکمه retry نشون بده؟
  final bool showRetryButton;
  
  /// Callback برای retry
  final VoidCallback? onRetry;

  const NetworkStatusBanner({
    super.key,
    this.animated = true,
    this.showRetryButton = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStateAsync = ref.watch(networkStateStreamProvider);

    return networkStateAsync.when(
      data: (state) {
        // فقط زمانی که آفلاین هستیم یا کیفیت پایین است نمایش بده
        if (state.isConnected && state.quality != NetworkQuality.poor) {
          return const SizedBox.shrink();
        }

        return _buildBanner(context, ref, state);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context, WidgetRef ref, NetworkState state) {
    final Color backgroundColor;
    final IconData icon;
    final String message;
    final String subMessage;
    const Color textColor = Colors.white;

    if (!state.isConnected) {
      backgroundColor = Colors.red.shade700;
      icon = Icons.cloud_off_rounded;
      message = 'اتصال به اینترنت برقرار نیست';
      subMessage = 'پیام‌ها پس از اتصال ارسال می‌شوند';
    } else if (state.quality == NetworkQuality.poor) {
      backgroundColor = Colors.orange.shade700;
      icon = Icons.signal_cellular_alt_1_bar_rounded;
      message = 'کیفیت اتصال ضعیف است';
      subMessage = 'ممکن است ارسال پیام کندتر باشد';
    } else {
      return const SizedBox.shrink();
    }

    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // آیکون با انیمیشن pulse
            _AnimatedIcon(
              icon: icon,
              color: textColor,
              animated: animated && !state.isConnected,
            ),
            const SizedBox(width: 12),
            
            // متن‌ها
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subMessage,
                    style: TextStyle(
                      color: textColor.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            // Latency (اگه موجوده)
            if (state.latencyMs != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.latencyMs}ms',
                  style: TextStyle(
                    color: textColor.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // دکمه Retry
            if (showRetryButton)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: textColor, size: 20),
                onPressed: () {
                  if (onRetry != null) {
                    onRetry!();
                  } else {
                    ref.read(networkActionsProvider).refresh();
                  }
                },
                tooltip: 'تلاش مجدد',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      ),
    );

    if (animated) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: banner,
      );
    }

    return banner;
  }
}

/// آیکون با انیمیشن pulse
class _AnimatedIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool animated;

  const _AnimatedIcon({
    required this.icon,
    required this.color,
    required this.animated,
  });

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.animated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animated && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animated) {
      return Icon(widget.icon, color: widget.color, size: 20);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(widget.icon, color: widget.color, size: 20),
        );
      },
    );
  }
}

/// بنر کوچک‌تر برای نمایش در bottom sheet ها
class CompactNetworkBanner extends ConsumerWidget {
  const CompactNetworkBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentNetworkStateProvider);

    if (state.isConnected && state.quality != NetworkQuality.poor) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: state.isConnected 
            ? Colors.orange.shade100 
            : Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            state.isConnected 
                ? Icons.signal_cellular_alt_1_bar_rounded 
                : Icons.cloud_off_rounded,
            size: 14,
            color: state.isConnected 
                ? Colors.orange.shade700 
                : Colors.red.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            state.isConnected 
                ? 'اتصال ضعیف' 
                : 'آفلاین',
            style: TextStyle(
              fontSize: 11,
              color: state.isConnected 
                  ? Colors.orange.shade700 
                  : Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

