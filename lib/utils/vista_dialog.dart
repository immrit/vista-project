import 'package:flutter/material.dart';

/// VistaDialog - یک دیالوگ یکپارچه و زیبا برای کل اپلیکیشن
/// با انیمیشن iOS-style و طراحی مدرن
class VistaDialog {
  VistaDialog._();

  /// نمایش دیالوگ استاندارد
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String content,
    List<VistaDialogAction>? actions,
    bool barrierDismissible = true,
    Widget? icon,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _VistaDialogWidget(
          title: title,
          content: content,
          actions: actions ?? [],
          icon: icon,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// دیالوگ تأیید با دو دکمه (لغو + تأیید)
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String content,
    String cancelText = 'انصراف',
    String confirmText = 'تأیید',
    Color? confirmColor,
    bool isDestructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      content: content,
      actions: [
        VistaDialogAction(
          text: cancelText,
          isCancel: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        VistaDialogAction(
          text: confirmText,
          color: isDestructive ? Colors.red : confirmColor,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  /// دیالوگ خروج از حساب
  static Future<bool?> showLogoutDialog(BuildContext context) {
    return confirm(
      context: context,
      title: 'خروج از حساب',
      content: 'آیا مطمئن هستید که می‌خواهید از حساب کاربری خود خارج شوید؟',
      cancelText: 'انصراف',
      confirmText: 'خروج',
      isDestructive: true,
    );
  }

  /// دیالوگ حذف
  static Future<bool?> showDeleteDialog(
    BuildContext context, {
    required String itemName,
  }) {
    return confirm(
      context: context,
      title: 'حذف',
      content: 'آیا از حذف "$itemName" مطمئن هستید؟ این عمل قابل بازگشت نیست.',
      cancelText: 'انصراف',
      confirmText: 'حذف',
      isDestructive: true,
    );
  }

  /// دیالوگ اطلاع‌رسانی ساده
  static Future<void> alert({
    required BuildContext context,
    required String title,
    required String content,
    String buttonText = 'متوجه شدم',
  }) {
    return show(
      context: context,
      title: title,
      content: content,
      actions: [
        VistaDialogAction(
          text: buttonText,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// اکشن دیالوگ
class VistaDialogAction {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final bool isCancel;

  const VistaDialogAction({
    required this.text,
    required this.onPressed,
    this.color,
    this.isCancel = false,
  });
}

/// ویجت داخلی دیالوگ
class _VistaDialogWidget extends StatelessWidget {
  final String title;
  final String content;
  final List<VistaDialogAction> actions;
  final Widget? icon;

  const _VistaDialogWidget({
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(height: 16),
                    ],
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),

              // Actions
              if (actions.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: _buildActions(context, isDark, primaryColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool isDark, Color primaryColor) {
    if (actions.length == 1) {
      // یک دکمه - تمام عرض
      return _buildActionButton(actions.first, isDark, primaryColor);
    }

    if (actions.length == 2) {
      // دو دکمه - کنار هم
      return IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildActionButton(actions[0], isDark, primaryColor,
                  showRightBorder: true),
            ),
            Expanded(
              child: _buildActionButton(actions[1], isDark, primaryColor),
            ),
          ],
        ),
      );
    }

    // بیش از دو دکمه - عمودی
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .map((a) => _buildActionButton(a, isDark, primaryColor))
          .toList(),
    );
  }

  Widget _buildActionButton(
    VistaDialogAction action,
    bool isDark,
    Color primaryColor, {
    bool showRightBorder = false,
  }) {
    final buttonColor = action.isCancel
        ? (isDark ? Colors.grey[400] : Colors.grey[600])
        : (action.color ?? primaryColor);

    return Container(
      decoration: showRightBorder
          ? BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
            )
          : null,
      child: TextButton(
        onPressed: action.onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        child: Text(
          action.text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: action.isCancel ? FontWeight.w400 : FontWeight.w600,
            color: buttonColor,
          ),
        ),
      ),
    );
  }
}
