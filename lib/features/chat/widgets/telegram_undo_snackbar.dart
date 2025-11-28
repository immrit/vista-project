// lib/features/chat/widgets/telegram_undo_snackbar.dart
//
// Undo Snackbar به سبک تلگرام
//
// ویژگی‌ها:
// ✅ Timer countdown با انیمیشن
// ✅ Swipe to dismiss
// ✅ Haptic feedback
// ✅ Auto-dismiss
// ✅ Glass effect background
//

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// نوع عملیات Undo
enum UndoAction {
  deleteMessage,
  deleteMessages,
  clearChat,
  blockUser,
  muteChat,
}

/// Telegram-style Undo Snackbar
class TelegramUndoSnackbar {
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  /// نمایش Undo Snackbar
  static void show({
    required BuildContext context,
    required UndoAction action,
    required VoidCallback onUndo,
    VoidCallback? onDismiss,
    int count = 1,
    Duration duration = const Duration(seconds: 5),
  }) {
    // حذف snackbar قبلی اگر وجود داره
    dismiss();

    HapticFeedback.mediumImpact();

    _currentOverlay = OverlayEntry(
      builder: (context) => _UndoSnackbarWidget(
        action: action,
        count: count,
        duration: duration,
        onUndo: () {
          HapticFeedback.heavyImpact();
          dismiss();
          onUndo();
        },
        onDismiss: () {
          dismiss();
          onDismiss?.call();
        },
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);

    // Auto dismiss
    _dismissTimer = Timer(duration, () {
      dismiss();
      onDismiss?.call();
    });
  }

  /// بستن Snackbar
  static void dismiss() {
    _dismissTimer?.cancel();
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

/// Widget Snackbar
class _UndoSnackbarWidget extends StatefulWidget {
  final UndoAction action;
  final int count;
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  const _UndoSnackbarWidget({
    required this.action,
    required this.count,
    required this.duration,
    required this.onUndo,
    required this.onDismiss,
  });

  @override
  State<_UndoSnackbarWidget> createState() => _UndoSnackbarWidgetState();
}

class _UndoSnackbarWidgetState extends State<_UndoSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  double _dragExtent = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Progress animation (countdown)
    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    // شروع انیمیشن ورود
    _controller.forward();

    // شروع countdown
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _controller.duration = widget.duration;
        _controller.reset();
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta ?? 0;
      _dragExtent = _dragExtent.clamp(-200.0, 200.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() > 100) {
      // اگر بیشتر از 100 پیکسل کشیده شد، dismiss کن
      widget.onDismiss();
    } else {
      // برگشت به حالت اولیه
      setState(() {
        _dragExtent = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Center(
            child: GestureDetector(
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_dragExtent, 0, 0),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth - 32,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFF3A3A3A))
                              .withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Progress indicator (خط بالا)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return LinearProgressIndicator(
                                    value: _progressAnimation.value,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation(
                                      theme.primaryColor.withOpacity(0.5),
                                    ),
                                    minHeight: 3,
                                  );
                                },
                              ),
                            ),

                            // محتوا
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // آیکون
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getActionColor(widget.action)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getActionIcon(widget.action),
                                      color: _getActionColor(widget.action),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // متن
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _getActionTitle(
                                              widget.action, widget.count),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        AnimatedBuilder(
                                          animation: _progressAnimation,
                                          builder: (context, child) {
                                            final remaining = (widget.duration
                                                        .inSeconds *
                                                    _progressAnimation.value)
                                                .ceil();
                                            return Text(
                                              '$remaining ثانیه',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.6),
                                                fontSize: 12,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // دکمه Undo
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.onUndo,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.primaryColor
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.undo_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'لغو',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getActionIcon(UndoAction action) {
    switch (action) {
      case UndoAction.deleteMessage:
      case UndoAction.deleteMessages:
        return Icons.delete_outline_rounded;
      case UndoAction.clearChat:
        return Icons.clear_all_rounded;
      case UndoAction.blockUser:
        return Icons.block_rounded;
      case UndoAction.muteChat:
        return Icons.notifications_off_rounded;
    }
  }

  Color _getActionColor(UndoAction action) {
    switch (action) {
      case UndoAction.deleteMessage:
      case UndoAction.deleteMessages:
      case UndoAction.clearChat:
        return Colors.red;
      case UndoAction.blockUser:
        return Colors.orange;
      case UndoAction.muteChat:
        return Colors.blue;
    }
  }

  String _getActionTitle(UndoAction action, int count) {
    switch (action) {
      case UndoAction.deleteMessage:
        return 'پیام حذف شد';
      case UndoAction.deleteMessages:
        return '$count پیام حذف شد';
      case UndoAction.clearChat:
        return 'چت پاک شد';
      case UndoAction.blockUser:
        return 'کاربر مسدود شد';
      case UndoAction.muteChat:
        return 'چت بی‌صدا شد';
    }
  }
}

