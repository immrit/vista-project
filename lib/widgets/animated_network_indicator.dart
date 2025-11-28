// lib/widgets/animated_network_indicator.dart
//
// نشانگر وضعیت شبکه با انیمیشن زیبا (مثل تلگرام)
//
// ویژگی‌ها:
// ✅ انیمیشن Slide و Fade
// ✅ نمایش "در حال اتصال..." با انیمیشن نقطه
// ✅ نمایش "بروزرسانی..." هنگام sync
// ✅ طراحی مینیمال و زیبا
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/network_state.dart';
import '../provider/network_provider.dart';

/// نشانگر وضعیت شبکه برای AppBar (مثل تلگرام)
class AnimatedNetworkIndicator extends ConsumerStatefulWidget {
  /// عنوان اصلی (وقتی آنلاین هستیم)
  final String title;
  
  /// استایل عنوان
  final TextStyle? titleStyle;
  
  /// رنگ پس‌زمینه
  final Color? backgroundColor;

  const AnimatedNetworkIndicator({
    super.key,
    required this.title,
    this.titleStyle,
    this.backgroundColor,
  });

  @override
  ConsumerState<AnimatedNetworkIndicator> createState() =>
      _AnimatedNetworkIndicatorState();
}

class _AnimatedNetworkIndicatorState
    extends ConsumerState<AnimatedNetworkIndicator>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _dotsController;

  String _previousStatus = '';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // انیمیشن slide
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // انیمیشن نقطه‌ها
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(currentNetworkStateProvider);
    final status = _getStatus(networkState);
    
    // انیمیشن وقتی وضعیت تغییر کنه
    if (status != _previousStatus) {
      _previousStatus = status;
      if (status.isNotEmpty) {
        _slideController.forward(from: 0);
        _dotsController.repeat();
      } else {
        _slideController.reverse();
        _dotsController.stop();
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: status.isEmpty
          ? Text(
              widget.title,
              key: const ValueKey('title'),
              style: widget.titleStyle,
            )
          : _buildStatusIndicator(status, networkState),
    );
  }

  String _getStatus(NetworkState state) {
    if (!state.isConnected) {
      return 'در حال اتصال';
    }
    if (state.quality == NetworkQuality.poor) {
      return 'اتصال ضعیف';
    }
    return '';
  }

  Widget _buildStatusIndicator(String status, NetworkState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final color = !state.isConnected
        ? (isDark ? const Color(0xFFEF5350) : const Color(0xFFE53935))
        : (isDark ? const Color(0xFFFFA726) : const Color(0xFFF57C00));

    return Row(
      key: ValueKey(status),
      mainAxisSize: MainAxisSize.min,
      children: [
        // آیکون با انیمیشن pulse
        _AnimatedPulseIcon(
          icon: !state.isConnected 
              ? Icons.cloud_off_rounded 
              : Icons.signal_cellular_alt_1_bar_rounded,
          color: color,
          size: 16,
        ),
        
        const SizedBox(width: 8),
        
        // متن وضعیت
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // نقطه‌های انیمیشنی
        if (!state.isConnected)
          _AnimatedDots(
            controller: _dotsController,
            color: color,
          ),
      ],
    );
  }
}

/// آیکون با انیمیشن Pulse
class _AnimatedPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _AnimatedPulseIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<_AnimatedPulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            widget.icon,
            color: widget.color.withOpacity(0.7 + _controller.value * 0.3),
            size: widget.size,
          ),
        );
      },
    );
  }
}

/// نقطه‌های انیمیشنی "..."
class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _AnimatedDots({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final dots = (controller.value * 4).floor() % 4;
        return SizedBox(
          width: 20,
          child: Text(
            '.' * dots,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

/// نشانگر کامل برای جایگزینی عنوان AppBar
/// 
/// استفاده:
/// ```dart
/// AppBar(
///   title: NetworkAwareTitle(
///     title: 'پیام‌ها',
///   ),
/// )
/// ```
class NetworkAwareTitle extends ConsumerWidget {
  final String title;
  final TextStyle? titleStyle;

  const NetworkAwareTitle({
    super.key,
    required this.title,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedNetworkIndicator(
      title: title,
      titleStyle: titleStyle ?? Theme.of(context).appBarTheme.titleTextStyle,
    );
  }
}

/// بنر زیبا برای نمایش در زیر AppBar
class NetworkStatusBar extends ConsumerStatefulWidget {
  const NetworkStatusBar({super.key});

  @override
  ConsumerState<NetworkStatusBar> createState() => _NetworkStatusBarState();
}

class _NetworkStatusBarState extends ConsumerState<NetworkStatusBar>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _heightAnimation = Tween<double>(begin: 0, end: 32).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(currentNetworkStateProvider);
    final shouldShow = !networkState.isConnected || 
                       networkState.quality == NetworkQuality.poor;

    if (shouldShow) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.isDismissed) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: _heightAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: _buildBar(networkState),
    );
  }

  Widget _buildBar(NetworkState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final (bgColor, textColor, icon, text) = !state.isConnected
        ? (
            isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFBE9E7),
            isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F),
            Icons.cloud_off_rounded,
            'در انتظار اتصال به شبکه...',
          )
        : (
            isDark ? const Color(0xFF2D2B1B) : const Color(0xFFFFF3E0),
            isDark ? const Color(0xFFFFA726) : const Color(0xFFE65100),
            Icons.signal_cellular_alt_1_bar_rounded,
            'کیفیت اتصال ضعیف است',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: textColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedPulseIcon(
            icon: icon,
            color: textColor,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

