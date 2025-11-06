import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../provider/chat_provider.dart';

/// مدیریت مرکزی برای نمایش و کنترل Reaction Panel
class ReactionManager {
  static final ReactionManager _instance = ReactionManager._internal();
  factory ReactionManager() => _instance;
  ReactionManager._internal();

  OverlayEntry? _currentOverlay;
  String? _activeMessageId;

  bool get isShowing => _currentOverlay != null;
  String? get activeMessageId => _activeMessageId;

  /// نمایش Reaction Panel
  void showReactionPanel({
    required BuildContext context,
    required GlobalKey messageKey,
    required String messageId,
    required String conversationId,
    required bool isFromMe,
    required WidgetRef ref,
    VoidCallback? onDismiss,
    VoidCallback? onReactionSelected,
  }) {
    // بستن پنل قبلی اگر وجود داشته باشد
    hideReactionPanel();

    _activeMessageId = messageId;

    // محاسبه موقعیت پیام
    final RenderBox? renderBox =
        messageKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) return;

    final Offset messagePosition = renderBox.localToGlobal(Offset.zero);
    final Size messageSize = renderBox.size;
    final Size screenSize = MediaQuery.of(context).size;

    // محاسبه بهترین موقعیت برای پنل
    final panelPosition = _calculateOptimalPosition(
      messagePosition: messagePosition,
      messageSize: messageSize,
      screenSize: screenSize,
      isFromMe: isFromMe,
    );

    _currentOverlay = OverlayEntry(
      builder: (overlayContext) => _ReactionOverlayWidget(
        position: panelPosition,
        messageId: messageId,
        conversationId: conversationId,
        isFromMe: isFromMe,
        ref: ref,
        onDismiss: () {
          hideReactionPanel();
          onDismiss?.call();
        },
        onReactionSelected: (emoji) {
          _handleReactionSelection(
            messageId: messageId,
            conversationId: conversationId,
            emoji: emoji,
            ref: ref,
            onReactionSelected: () {
              onDismiss?.call();
              onReactionSelected?.call();
            },
          );
          hideReactionPanel();
        },
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// بستن Reaction Panel
  void hideReactionPanel() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _activeMessageId = null;
  }

  /// محاسبه موقعیت بهینه برای پنل
  _CalculatedPosition _calculateOptimalPosition({
    required Offset messagePosition,
    required Size messageSize,
    required Size screenSize,
    required bool isFromMe,
  }) {
    const double panelHeight = 56.0;
    const double panelWidth = 320.0;
    const double margin = 8.0;
    const double arrowSize = 8.0;

    double left, top;
    bool showAbove = true;

    // محاسبه موقعیت عمودی
    final spaceAbove = messagePosition.dy;
    final spaceBelow =
        screenSize.height - (messagePosition.dy + messageSize.height);

    if (spaceAbove >= panelHeight + margin + arrowSize) {
      // نمایش بالای پیام
      top = messagePosition.dy - panelHeight - arrowSize - margin;
      showAbove = true;
    } else if (spaceBelow >= panelHeight + margin + arrowSize) {
      // نمایش پایین پیام
      top = messagePosition.dy + messageSize.height + arrowSize + margin;
      showAbove = false;
    } else {
      // نمایش در وسط صفحه
      top = (screenSize.height - panelHeight) / 2;
      showAbove = true;
    }

    // محاسبه موقعیت افقی
    if (isFromMe) {
      // پیام‌های من: سمت راست
      left = messagePosition.dx + messageSize.width - panelWidth;
      left = left.clamp(margin, screenSize.width - panelWidth - margin);
    } else {
      // پیام‌های دیگران: سمت چپ
      left = messagePosition.dx;
      left = left.clamp(margin, screenSize.width - panelWidth - margin);
    }

    // محاسبه موقعیت arrow
    final arrowLeft = isFromMe
        ? messagePosition.dx + messageSize.width - 20
        : messagePosition.dx + 20;

    return _CalculatedPosition(
      left: left,
      top: top,
      showAbove: showAbove,
      arrowLeft: arrowLeft.clamp(left + 20, left + panelWidth - 20),
    );
  }

  /// مدیریت انتخاب reaction
  void _handleReactionSelection({
    required String messageId,
    required String conversationId,
    required String emoji,
    required WidgetRef ref,
    VoidCallback? onReactionSelected,
  }) {
    // فراخوانی provider برای toggle reaction
    ref.read(messageNotifierProvider.notifier).toggleReaction(
          messageId: messageId,
          conversationId: conversationId,
          emoji: emoji,
        );
    
    // فراخوانی callback برای خاموش کردن selection mode
    onReactionSelected?.call();
  }
}

/// کلاس داده برای موقعیت محاسبه شده
class _CalculatedPosition {
  final double left;
  final double top;
  final bool showAbove;
  final double arrowLeft;

  const _CalculatedPosition({
    required this.left,
    required this.top,
    required this.showAbove,
    required this.arrowLeft,
  });
}

/// Widget اصلی Overlay برای نمایش Reaction Panel
class _ReactionOverlayWidget extends StatefulWidget {
  final _CalculatedPosition position;
  final String messageId;
  final String conversationId;
  final bool isFromMe;
  final WidgetRef ref;
  final VoidCallback onDismiss;
  final Function(String emoji) onReactionSelected;

  const _ReactionOverlayWidget({
    required this.position,
    required this.messageId,
    required this.conversationId,
    required this.isFromMe,
    required this.ref,
    required this.onDismiss,
    required this.onReactionSelected,
  });

  @override
  State<_ReactionOverlayWidget> createState() => _ReactionOverlayWidgetState();
}

class _ReactionOverlayWidgetState extends State<_ReactionOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // ✅ Emojis محبوب (مشابه واتساپ)
  final List<String> _quickEmojis = [
    '😂',
    '❤️',
    '😮',
    '😢',
    '🙏',
    '👏',
    '🔥'
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ✅ پس‌زمینه شفاف برای dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: _handleDismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.black.withOpacity(0.01), // شفاف ولی قابل کلیک
            ),
          ),
        ),

        // ✅ Arrow (فلش اشاره‌گر)
        _buildArrow(),

        // ✅ Reaction Panel
        _buildReactionPanel(),
      ],
    );
  }

  Widget _buildArrow() {
    return Positioned(
      left: widget.position.arrowLeft - 6,
      top: widget.position.showAbove
          ? widget.position.top + 56 - 2 // بالای پیام
          : widget.position.top - 8, // پایین پیام
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomPaint(
          size: const Size(12, 8),
          painter: _ArrowPainter(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1A1A)
                : Colors.white,
            pointDown: !widget.position.showAbove,
          ),
        ),
      ),
    );
  }

  Widget _buildReactionPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      left: widget.position.left,
      top: widget.position.top,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: widget.isFromMe ? Alignment.topRight : Alignment.topLeft,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(30),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._quickEmojis.map((emoji) => _buildEmojiButton(emoji)),
                  const SizedBox(width: 4),
                  _buildMoreButton(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return GestureDetector(
      onTap: () => _handleEmojiTap(emoji),
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 36,
          height: 40,
          alignment: Alignment.center,
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton(bool isDark) {
    return GestureDetector(
      onTap: _showFullEmojiPicker,
      child: Container(
        width: 36,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          color: isDark ? Colors.white70 : Colors.grey[700],
          size: 20,
        ),
      ),
    );
  }

  void _handleEmojiTap(String emoji) {
    // ✅ Haptic Feedback
    HapticFeedback.lightImpact();

    widget.onReactionSelected(emoji);
  }

  void _showFullEmojiPicker() {
    widget.onDismiss();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FullEmojiPickerSheet(
        onEmojiSelected: (emoji) {
          Navigator.pop(context);
          widget.onReactionSelected(emoji);
        },
      ),
    );
  }

  void _handleDismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }
}

/// Painter برای رسم فلش اشاره‌گر
class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool pointDown;

  _ArrowPainter({
    required this.color,
    required this.pointDown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (pointDown) {
      // فلش رو به پایین
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    } else {
      // فلش رو به بالا
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointDown != pointDown;
  }
}

/// Bottom Sheet کامل برای انتخاب emoji
class _FullEmojiPickerSheet extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;

  const _FullEmojiPickerSheet({
    required this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // ✅ Handle (دسته کشیدن)
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ✅ Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'انتخاب Emoji',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ✅ Emoji Picker
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                onEmojiSelected(emoji.emoji);
              },
              config: Config(
                height: double.infinity,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: EdgeInsets.zero,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: const CategoryViewConfig(),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: const SearchViewConfig(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

