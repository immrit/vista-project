// lib/features/chat/widgets/telegram_online_status.dart
//
// ویجت وضعیت آنلاین به سبک ویستا
//
// ویژگی‌ها:
// ✅ انیمیشن‌های روان و حرفه‌ای
// ✅ انتقال نرم بین وضعیت‌ها
// ✅ نقطه سبز با pulse effect
// ✅ نمایش تایپ با انیمیشن نقطه‌ها
// ✅ به‌روزرسانی Real-time با Riverpod
// ✅ بدون Memory Leak
//

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/user_presence_service.dart';
import '../../../provider/presence_provider.dart';

/// رنگ‌های وضعیت
class OnlineStatusColors {
  static const Color online = Color(0xFF4CAF50);      // سبز ویستا
  static const Color typing = Color(0xFF2196F3);      // آبی
  static const Color recording = Color(0xFFE91E63);   // صورتی
  static const Color offline = Color(0xFF9E9E9E);     // خاکستری
  static const Color away = Color(0xFFFFC107);        // زرد
}

/// نقطه وضعیت آنلاین با انیمیشن
class OnlineStatusDot extends StatefulWidget {
  final UserPresenceStatus status;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const OnlineStatusDot({
    super.key,
    required this.status,
    this.size = 12,
    this.showBorder = true,
    this.borderColor,
  });

  @override
  State<OnlineStatusDot> createState() => _OnlineStatusDotState();
}

class _OnlineStatusDotState extends State<OnlineStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(OnlineStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status == UserPresenceStatus.online) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case UserPresenceStatus.online:
        return OnlineStatusColors.online;
      case UserPresenceStatus.typing:
        return OnlineStatusColors.typing;
      case UserPresenceStatus.recording:
        return OnlineStatusColors.recording;
      case UserPresenceStatus.away:
        return OnlineStatusColors.away;
      case UserPresenceStatus.offline:
        return OnlineStatusColors.offline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final borderColor = widget.borderColor ?? 
        Theme.of(context).scaffoldBackgroundColor;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring (فقط برای آنلاین)
            if (widget.status == UserPresenceStatus.online)
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(_opacityAnimation.value),
                  ),
                ),
              ),
            // Main dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: widget.showBorder
                    ? Border.all(color: borderColor, width: 2)
                    : null,
                boxShadow: widget.status == UserPresenceStatus.online
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// متن وضعیت با انیمیشن - بدون وابستگی به سرویس
class OnlineStatusText extends StatelessWidget {
  final UserPresenceState presence;
  final TextStyle? style;
  final bool showTypingDots;

  const OnlineStatusText({
    super.key,
    required this.presence,
    this.style,
    this.showTypingDots = false,
  });

  Color _getTextColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (presence.status) {
      case UserPresenceStatus.online:
        return OnlineStatusColors.online;
      case UserPresenceStatus.typing:
      case UserPresenceStatus.recording:
        return OnlineStatusColors.typing;
      default:
        return theme.textTheme.bodySmall?.color ?? Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey('${presence.status}_${presence.lastOnline}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTypingDots && presence.isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TypingDotsAnimation(
                color: _getTextColor(context),
              ),
            ),
          Flexible(
            child: Text(
              presence.displayText,
              style: (style ?? const TextStyle(fontSize: 12)).copyWith(
                color: _getTextColor(context),
                fontWeight: presence.isOnline ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// انیمیشن نقطه‌های تایپ - Public برای استفاده خارجی
class TypingDotsAnimation extends StatefulWidget {
  final Color color;
  final double dotSize;

  const TypingDotsAnimation({
    super.key,
    this.color = Colors.blue,
    this.dotSize = 4,
  });

  @override
  State<TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<TypingDotsAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -3).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    // شروع با تاخیر
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// ✅ ویجت کامل وضعیت آنلاین به سبک ویستا - بهینه با Riverpod
class TelegramOnlineStatus extends ConsumerWidget {
  final String userId;
  final bool showDot;
  final double dotSize;
  final TextStyle? textStyle;
  final bool isTyping;
  final bool isRecording;

  const TelegramOnlineStatus({
    super.key,
    required this.userId,
    this.showDot = false,
    this.dotSize = 10,
    this.textStyle,
    this.isTyping = false,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ استفاده مستقیم از Provider - بدون StreamSubscription اضافی
    final presenceAsync = ref.watch(userPresenceStreamProvider(userId));

    return presenceAsync.when(
      data: (presence) => _buildContent(context, presence),
      loading: () => _buildLoading(context),
      error: (_, __) => _buildError(context),
    );
  }

  Widget _buildContent(BuildContext context, UserPresenceState presence) {
    // Override با وضعیت تایپ/ضبط اگر فعال باشد
    final effectiveState = _getEffectiveState(presence);

    if (showDot) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnlineStatusDot(
            status: effectiveState.status,
            size: dotSize,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: OnlineStatusText(
              presence: effectiveState,
              style: textStyle,
            ),
          ),
        ],
      );
    }

    return OnlineStatusText(
      presence: effectiveState,
      style: textStyle,
      showTypingDots: effectiveState.isTyping,
    );
  }

  Widget _buildLoading(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'در حال بررسی...',
      style: textStyle ?? TextStyle(
        fontSize: 12,
        color: theme.textTheme.bodySmall?.color,
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'نامشخص',
      style: textStyle ?? TextStyle(
        fontSize: 12,
        color: theme.textTheme.bodySmall?.color,
      ),
    );
  }

  UserPresenceState _getEffectiveState(UserPresenceState presence) {
    if (isTyping) {
      return presence.copyWith(status: UserPresenceStatus.typing);
    }
    if (isRecording) {
      return presence.copyWith(status: UserPresenceStatus.recording);
    }
    return presence;
  }
}

/// ویجت آواتار با نقطه آنلاین - بهینه
class AvatarWithOnlineStatus extends ConsumerWidget {
  final String userId;
  final String? avatarUrl;
  final String fallbackText;
  final double size;
  final VoidCallback? onTap;

  const AvatarWithOnlineStatus({
    super.key,
    required this.userId,
    this.avatarUrl,
    required this.fallbackText,
    this.size = 48,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final presenceAsync = ref.watch(userPresenceStreamProvider(userId));

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // آواتار
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.8),
                    theme.colorScheme.primary,
                  ],
                ),
              ),
              child: avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallback(theme),
                      ),
                    )
                  : _buildFallback(theme),
            ),
            // نقطه آنلاین
            presenceAsync.maybeWhen(
              data: (presence) {
                if (!presence.isOnline) return const SizedBox.shrink();
                return Positioned(
                  right: 0,
                  bottom: 0,
                  child: OnlineStatusDot(
                    status: presence.status,
                    size: size * 0.28,
                    borderColor: theme.scaffoldBackgroundColor,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    return Center(
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
