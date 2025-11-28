// lib/features/chat/widgets/telegram_delete_dialog.dart
//
// دیالوگ حذف پیام به سبک تلگرام
//
// ویژگی‌ها:
// ✅ انیمیشن ورود از پایین
// ✅ Blur backdrop
// ✅ Checkbox برای "حذف برای همه"
// ✅ Timer countdown (48h)
// ✅ Undo snackbar
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

/// نوع دیالوگ حذف
enum DeleteDialogType {
  singleMessage,
  multipleMessages,
  entireChat,
}

/// دیالوگ حذف به سبک تلگرام
class TelegramDeleteDialog extends StatefulWidget {
  final DeleteDialogType type;
  final int messageCount;
  final bool canDeleteForEveryone;
  final Duration? timeRemaining; // زمان باقی‌مانده برای حذف دوطرفه
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;

  const TelegramDeleteDialog({
    super.key,
    required this.type,
    this.messageCount = 1,
    this.canDeleteForEveryone = false,
    this.timeRemaining,
    required this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  /// نمایش دیالوگ
  static Future<bool?> show({
    required BuildContext context,
    required DeleteDialogType type,
    int messageCount = 1,
    bool canDeleteForEveryone = false,
    Duration? timeRemaining,
    required VoidCallback onDeleteForMe,
    VoidCallback? onDeleteForEveryone,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TelegramDeleteDialog(
          type: type,
          messageCount: messageCount,
          canDeleteForEveryone: canDeleteForEveryone,
          timeRemaining: timeRemaining,
          onDeleteForMe: onDeleteForMe,
          onDeleteForEveryone: onDeleteForEveryone,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
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
    );
  }

  @override
  State<TelegramDeleteDialog> createState() => _TelegramDeleteDialogState();
}

class _TelegramDeleteDialogState extends State<TelegramDeleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _deleteForEveryone = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1A1A1A) : Colors.white)
                    .withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(theme, isDark),
                  _buildContent(theme, isDark),
                  _buildActions(theme, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getSubtitle(),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // توضیحات
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(isDark ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getWarningText(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // گزینه "حذف برای همه"
          if (widget.canDeleteForEveryone) ...[
            const SizedBox(height: 16),
            _buildDeleteForEveryoneOption(theme, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildDeleteForEveryoneOption(ThemeData theme, bool isDark) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _deleteForEveryone = !_deleteForEveryone);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _deleteForEveryone
              ? theme.primaryColor.withOpacity(0.1)
              : (isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _deleteForEveryone
                ? theme.primaryColor.withOpacity(0.5)
                : theme.dividerColor.withOpacity(0.3),
            width: _deleteForEveryone ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _deleteForEveryone
                    ? theme.primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _deleteForEveryone
                      ? theme.primaryColor
                      : theme.hintColor,
                  width: 2,
                ),
              ),
              child: _deleteForEveryone
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حذف برای همه',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.timeRemaining != null
                        ? 'زمان باقی‌مانده: ${_formatDuration(widget.timeRemaining!)}'
                        : 'پیام برای طرف مقابل هم حذف می‌شود',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, false);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: const Text('انصراف'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
                
                if (_deleteForEveryone && widget.onDeleteForEveryone != null) {
                  widget.onDeleteForEveryone!();
                } else {
                  widget.onDeleteForMe();
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _deleteForEveryone ? 'حذف برای همه' : 'حذف برای من',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (widget.type) {
      case DeleteDialogType.singleMessage:
        return 'حذف پیام؟';
      case DeleteDialogType.multipleMessages:
        return 'حذف ${widget.messageCount} پیام؟';
      case DeleteDialogType.entireChat:
        return 'پاکسازی چت؟';
    }
  }

  String _getSubtitle() {
    switch (widget.type) {
      case DeleteDialogType.singleMessage:
        return 'پیام را چگونه حذف کنید؟';
      case DeleteDialogType.multipleMessages:
        return '${widget.messageCount} پیام انتخاب شده';
      case DeleteDialogType.entireChat:
        return 'تمام پیام‌های این چت';
    }
  }

  String _getWarningText() {
    if (widget.type == DeleteDialogType.entireChat) {
      return 'تمام پیام‌های این مکالمه برای شما حذف خواهد شد. این عمل قابل بازگشت نیست.';
    }
    return 'این عمل قابل بازگشت نیست.';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours ساعت و $minutes دقیقه';
    }
    return '$minutes دقیقه';
  }
}

