import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';
import 'telegram_reaction_picker.dart';

class TelegramContextMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDivider;

  const TelegramContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDivider = false,
  });

  const TelegramContextMenuItem.divider()
      : icon = Icons.remove,
        label = '',
        onTap = _emptyCallback,
        color = null,
        isDivider = true;

  static void _emptyCallback() {}
}

class TelegramContextMenu extends StatefulWidget {
  final Widget messageWidget;
  final Rect messageRect;
  final List<TelegramContextMenuItem> items;
  final List<String>? quickReactions;
  final ValueChanged<String>? onReactionSelected;
  final VoidCallback onClose;
  final bool isMyMessage;

  const TelegramContextMenu({
    super.key,
    required this.messageWidget,
    required this.messageRect,
    required this.items,
    this.quickReactions,
    this.onReactionSelected,
    required this.onClose,
    required this.isMyMessage,
  });

  static void show({
    required BuildContext context,
    required Widget messageWidget,
    required Rect messageRect,
    required List<TelegramContextMenuItem> items,
    List<String>? quickReactions,
    ValueChanged<String>? onReactionSelected,
    required bool isMyMessage,
    required VoidCallback onDismiss,
  }) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration:
          const Duration(milliseconds: 300), // کمی کندتر برای نرمی انیمیشن
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TelegramContextMenu(
          messageWidget: messageWidget,
          messageRect: messageRect,
          items: items,
          quickReactions: quickReactions,
          onReactionSelected: onReactionSelected,
          isMyMessage: isMyMessage,
          onClose: () {
            Navigator.of(context).pop();
            Future.delayed(const Duration(milliseconds: 200), onDismiss);
          },
        );
      },
    ));
  }

  @override
  State<TelegramContextMenu> createState() => _TelegramContextMenuState();
}

class _TelegramContextMenuState extends State<TelegramContextMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // متغیرهای محاسبه شده برای انیمیشن جابجایی
  late double _targetMessageTop;
  late double _targetMessageHeight;
  late bool _isScrollable;

  // ✅ Cache heavy widgets
  Widget? _cachedMenu;
  Widget? _cachedReactions;

  List<String> get _currentReactions =>
      (widget.quickReactions != null && widget.quickReactions!.isNotEmpty)
          ? widget.quickReactions!
          : kDefaultReactions;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateLayout();

    // ✅ Cache widgets here to avoid rebuilding in animation loop
    final theme = context.chatTheme;
    final isDark = theme.isDark;
    _cachedMenu = _buildMenu(theme, isDark);
    _cachedReactions = _buildQuickReactionsBar(theme, isDark);

    _controller.forward();
  }

  /// 📐 محاسبات دقیق ریاضی برای جایگذاری المان‌ها
  void _calculateLayout() {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // ارتفاع حدودی منو و ری‌اکشن‌ها
    const menuHeight = 280.0;
    const reactionHeight = 60.0;
    const totalMenuSpace = menuHeight + reactionHeight + 20;

    // حداکثر ارتفاعی که پیام می‌تواند داشته باشد (تا روی منو نیفتد)
    final maxAvailableHeight =
        screenSize.height - totalMenuSpace - padding.top - padding.bottom;

    // 1. آیا پیام بلندتر از فضای موجود است؟
    if (widget.messageRect.height > maxAvailableHeight) {
      _targetMessageHeight = maxAvailableHeight;
      _isScrollable = true;
    } else {
      _targetMessageHeight = widget.messageRect.height;
      _isScrollable = false;
    }

    // 2. محاسبه موقعیت عمودی (Y) پیام
    // اگر پیام پایین صفحه باشد، باید بیاید بالا تا منو زیرش جا شود
    // اگر پیام بالا باشد، سرجایش می‌ماند

    double bottomSpace = screenSize.height - widget.messageRect.bottom;

    if (bottomSpace < totalMenuSpace) {
      // جا کم است! پیام باید برود بالا
      // مقصد: طوری که پایینِ پیام، دقیقاً بالای منو باشد
      // اما نه آنقدر بالا که از Header خارج شود
      _targetMessageTop =
          screenSize.height - totalMenuSpace - _targetMessageHeight - 20;
      if (_targetMessageTop < padding.top + 50) {
        _targetMessageTop = padding.top + 50;
      }
    } else {
      // جا هست، پیام سر جایش بماند
      _targetMessageTop = widget.messageRect.top;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // تنظیمات منو (گوشه سمت چپ/راست)
    const menuWidth = 250.0;

    // منو همیشه سعی می‌کند در سمت مخالف پیام باز شود یا فیکس در یک سمت
    // طبق درخواست شما: گوشه سمت چپ (برای فارسی که RTL است شاید سمت راست بهتر باشد، اما اینجا چپ می‌گذاریم)
    final menuLeft = 16.0;

    // موقعیت عمودی منو: همیشه زیر پیام (چون پیام را می‌بریم بالا اگر جا نباشد)
    // ما از انیمیشن استفاده می‌کنیم تا موقعیت نهایی منو را تعیین کنیم

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onClose,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // محاسبه انیمیشن پوزیشن پیام (Tween بین جای اولیه و جای نهایی)
            final currentTop = lerpDouble(
                widget.messageRect.top, _targetMessageTop, _controller.value)!;

            final currentHeight = lerpDouble(widget.messageRect.height,
                _targetMessageHeight, _controller.value)!;

            // موقعیت منو بر اساس موقعیت فعلی پیام
            final menuTop = currentTop + currentHeight + 16;

            return Stack(
              children: [
                // 1. پس‌زمینه بلور
                // 1. پس‌زمینه (بدون افکت بلور - ساده و سریع مثل ویستا اندروید)
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      color: Colors.black
                          .withOpacity(0.6), // تاریکی بیشتر برای تمرکز روی پیام
                    ),
                  ),
                ),

                // 2. پیام اصلی (متحرک و اسکرول‌دار)
                Positioned(
                  top: currentTop,
                  left: widget.messageRect.left,
                  width: widget.messageRect.width,
                  height: currentHeight,
                  child: Material(
                    // اضافه کردن Material برای جلوگیری از Overflow داخلی
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      physics: _isScrollable
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: IgnorePointer(
                        ignoring: true, // محتوای پیام کلیک نشود (فقط اسکرول)
                        child: widget.messageWidget,
                      ),
                    ),
                  ),
                ),

                // 3. منوی گزینه‌ها
                Positioned(
                  top: menuTop,
                  left: menuLeft, // منو سمت چپ فیکس شده
                  width: menuWidth,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    alignment: Alignment.topLeft, // انیمیشن باز شدن از بالا چپ
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: _cachedMenu, // ✅ استفاده از نسخه کش شده
                    ),
                  ),
                ),

                // 4. نوار ری‌اکشن‌ها (بالای پیام یا بالای منو)
                Positioned(
                  top: currentTop - 60, // همیشه بالای پیام حرکت می‌کند
                  left: 16,
                  right: 16,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Center(
                        child: _cachedReactions, // ✅ استفاده از نسخه کش شده
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ); // Correct closing for RepaintBoundary
  }

  Widget _buildMenu(ChatTheme theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.items.map((item) {
            if (item.isDivider) {
              return Divider(
                height: 1,
                thickness: 0.5,
                color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.15),
              );
            }
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onClose();
                  Future.delayed(const Duration(milliseconds: 200), item.onTap);
                },
                overlayColor: WidgetStateProperty.all(isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: item.color ??
                              (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      Icon(
                        item.icon,
                        size: 20,
                        color: item.color ??
                            (isDark ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQuickReactionsBar(ChatTheme theme, bool isDark) {
    return Container(
      height: 52,
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          itemCount: _currentReactions.length,
          itemBuilder: (context, index) {
            final emoji = _currentReactions[index];
            return _ReactionItem(
              emoji: emoji,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onReactionSelected?.call(emoji);
                widget.onClose();
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReactionItem extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionItem({required this.emoji, required this.onTap});

  @override
  State<_ReactionItem> createState() => _ReactionItemState();
}

class _ReactionItemState extends State<_ReactionItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 42,
          height: 52,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Text(
            widget.emoji,
            style: const TextStyle(
              fontSize: 26,
              fontFamily: 'Apple Color Emoji',
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
