import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';
import 'modern_reaction_picker.dart';

class ModernContextMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDivider;

  const ModernContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDivider = false,
  });

  const ModernContextMenuItem.divider()
      : icon = Icons.remove,
        label = '',
        onTap = _emptyCallback,
        color = null,
        isDivider = true;

  static void _emptyCallback() {}
}

class ModernContextMenu extends StatefulWidget {
  final Widget messageWidget;
  final Rect messageRect;
  final List<ModernContextMenuItem> items;
  final List<String>? quickReactions;
  final ValueChanged<String>? onReactionSelected;
  final VoidCallback onClose;
  final bool isMyMessage;
  final bool showReactions;
  final bool showAnchorPreview;
  final bool openAboveAnchor;

  const ModernContextMenu({
    super.key,
    required this.messageWidget,
    required this.messageRect,
    required this.items,
    this.quickReactions,
    this.onReactionSelected,
    required this.onClose,
    required this.isMyMessage,
    this.showReactions = true,
    this.showAnchorPreview = true,
    this.openAboveAnchor = false,
  });

  static void show({
    required BuildContext context,
    required Widget messageWidget,
    required Rect messageRect,
    required List<ModernContextMenuItem> items,
    List<String>? quickReactions,
    ValueChanged<String>? onReactionSelected,
    required bool isMyMessage,
    required VoidCallback onDismiss,
    bool showReactions = true,
    bool showAnchorPreview = true,
    bool openAboveAnchor = false,
  }) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ModernContextMenu(
          messageWidget: messageWidget,
          messageRect: messageRect,
          items: items,
          quickReactions: quickReactions,
          onReactionSelected: onReactionSelected,
          isMyMessage: isMyMessage,
          showReactions: showReactions,
          showAnchorPreview: showAnchorPreview,
          openAboveAnchor: openAboveAnchor,
          onClose: () {
            Navigator.of(context).pop();
            Future.delayed(const Duration(milliseconds: 120), onDismiss);
          },
        );
      },
    ));
  }

  @override
  State<ModernContextMenu> createState() => _ModernContextMenuState();
}

class _ModernContextMenuState extends State<ModernContextMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // متغیرهای محاسبه شده برای انیمیشن جابجایی
  late double _targetMessageTop;
  late double _targetMessageHeight;
  late bool _isScrollable;
  late double _menuTop;
  late double _menuLeft;

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
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
    const menuWidth = 250.0;

    if (!widget.showAnchorPreview) {
      _targetMessageTop = widget.messageRect.top;
      _targetMessageHeight = widget.messageRect.height;
      _isScrollable = false;

      final menuHeight = _estimateMenuHeight();
      final centeredLeft = widget.messageRect.center.dx - (menuWidth / 2);
      _menuLeft = centeredLeft.clamp(16.0, screenSize.width - menuWidth - 16);

      if (widget.openAboveAnchor) {
        _menuTop = widget.messageRect.top - menuHeight - 12;
        if (_menuTop < padding.top + 8) {
          _menuTop = widget.messageRect.bottom + 12;
        }
      } else {
        _menuTop = widget.messageRect.bottom + 12;
      }
      return;
    }

    // ارتفاع حدودی منو و ری‌اکشن‌ها
    const menuHeight = 280.0;
    final reactionHeight = widget.showReactions ? 60.0 : 0.0;
    final totalMenuSpace = menuHeight + reactionHeight + 20;

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

    _menuLeft = 16.0;
    _menuTop = _targetMessageTop + _targetMessageHeight + 16;
  }

  double _estimateMenuHeight() {
    var height = 0.0;
    for (final item in widget.items) {
      height += item.isDivider ? 1 : 44;
    }
    return height;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const menuWidth = 250.0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onClose,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (!widget.showAnchorPreview) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.34),
                      ),
                    ),
                  ),
                  Positioned(
                    top: _menuTop,
                    left: _menuLeft,
                    width: menuWidth,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      alignment: widget.openAboveAnchor
                          ? Alignment.bottomCenter
                          : Alignment.topCenter,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: _cachedMenu,
                      ),
                    ),
                  ),
                ],
              );
            }

            // محاسبه انیمیشن پوزیشن پیام (Tween بین جای اولیه و جای نهایی)
            final currentTop = lerpDouble(
                widget.messageRect.top, _targetMessageTop, _controller.value)!;

            final currentHeight = lerpDouble(widget.messageRect.height,
                _targetMessageHeight, _controller.value)!;

            // موقعیت منو بر اساس موقعیت فعلی پیام
            final menuTop = currentTop + currentHeight + 16;

            return Stack(
              children: [
                // 1. Simple dim background.
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.34,
                      ),
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
                  left: _menuLeft,
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
                if (widget.showReactions)
                  Positioned(
                    top: currentTop - 60,
                    left: 16,
                    right: 16,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      alignment: Alignment.bottomCenter,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Center(
                          child: _cachedReactions,
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.items.map((item) {
            if (item.isDivider) {
              return Divider(
                height: 1,
                thickness: 0.5,
                color: isDark
                    ? Colors.white12
                    : Colors.grey.withValues(alpha: 0.15),
              );
            }
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onClose();
                  Future.delayed(const Duration(milliseconds: 90), item.onTap);
                },
                overlayColor: WidgetStateProperty.all(isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: item.color ??
                              (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      Icon(
                        item.icon,
                        size: 19,
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
      height: 46,
      constraints: const BoxConstraints(maxWidth: 316),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
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
        scale: _isPressed ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: 42,
          height: 46,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Text(
            widget.emoji,
            style: const TextStyle(
              fontSize: 24,
              fontFamily: 'Apple Color Emoji',
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
