// lib/features/chat/widgets/modern_online_status.dart
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
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/user_presence_service.dart';
import '../../../provider/presence_provider.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// رنگ‌های وضعیت
class OnlineStatusColors {
  static const Color online = AppColors.success; // سبز ویستا
  static const Color typing = AppColors.info; // آبی
  static const Color recording = AppColors.accent; // صورتی
  static const Color offline = Color(0xFF9E9E9E); // خاکستری
  static const Color away = Color(0xFFFFC107); // زرد
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
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
    // No repeating pulse. An always-on animation forces a frame every vsync, and
    // on the Impeller GLES backend each forced frame recomposited the whole chat
    // scene (~24ms raster) → continuous idle jank even when nothing moved. The
    // static glowing dot conveys "online" without driving frames (Telegram-style).
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
    final borderColor =
        widget.borderColor ?? Theme.of(context).scaffoldBackgroundColor;

    final isOnline = widget.status == UserPresenceStatus.online;

    // Main dot ثابت است — بیرون از AnimatedBuilder تا هر فریم rebuild نشود.
    final mainDot = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border:
            widget.showBorder ? Border.all(color: borderColor, width: 2) : null,
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );

    // Static dot only — no animated pulse ring (see _updateAnimation).
    return RepaintBoundary(child: mainDot);
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
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: TypingDotsAnimation(
                color: _getTextColor(context),
              ),
            ),
          Flexible(
            child: Text(
              presence.displayText,
              style: (style ?? const TextStyle(fontSize: 12)).copyWith(
                color: _getTextColor(context),
                fontWeight:
                    presence.isOnline ? FontWeight.w500 : FontWeight.normal,
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
class ModernOnlineStatus extends ConsumerWidget {
  final String userId;
  final bool showDot;
  final double dotSize;
  final TextStyle? textStyle;
  final bool isTyping;
  final bool isRecording;

  const ModernOnlineStatus({
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
    final cachedPresence = ref.watch(cachedPresenceProvider(userId));

    return presenceAsync.when(
      data: (presence) => _buildContent(context, presence),
      loading: () => cachedPresence != null
          ? _buildContent(context, cachedPresence)
          : _buildLoading(context),
      error: (_, __) => cachedPresence != null
          ? _buildContent(context, cachedPresence)
          : _buildError(context),
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
      'آفلاین',
      style: textStyle ??
          TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color,
          ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'نامشخص',
      style: textStyle ??
          TextStyle(
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
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                    theme.colorScheme.primary,
                  ],
                ),
              ),
              child: avatarUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            _buildFallback(theme),
                      ),
                    )
                  : _buildFallback(theme),
            ),
            // نقطه آنلاین
            presenceAsync.maybeWhen(
              data: (presence) {
                if (!presence.isOnline) return const SizedBox.shrink();
                return PositionedDirectional(
                  end: 0,
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
