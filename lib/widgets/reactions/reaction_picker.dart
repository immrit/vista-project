import 'package:flutter/material.dart';

class ReactionPicker extends StatefulWidget {
  final Function(String emoji) onReactionSelected;
  final VoidCallback onClose;

  const ReactionPicker({
    required this.onReactionSelected,
    required this.onClose,
    super.key,
  });

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker>
    with TickerProviderStateMixin {
  // ✅ لیست emojis محبوب (مثل Telegram)
  final List<String> _reactions = [
    '👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '🎉'
  ];

  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();

    // ✅ ساخت AnimationController برای هر emoji
    _controllers = List.generate(
      _reactions.length,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 150 + (index * 30)),
      ),
    );

    // ✅ انیمیشن Scale (بزرگ شدن)
    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ),
      );
    }).toList();

    // ✅ انیمیشن Slide (سر خوردن از پایین)
    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOut,
        ),
      );
    }).toList();

    // ✅ شروع انیمیشن‌ها به صورت cascade
    _startAnimations();
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose, // بستن با کلیک خارج
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // جلوگیری از بسته شدن با کلیک روی picker
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_reactions.length, (index) {
                  return SlideTransition(
                    position: _slideAnimations[index],
                    child: ScaleTransition(
                      scale: _scaleAnimations[index],
                      child: _ReactionButton(
                        emoji: _reactions[index],
                        onTap: () {
                          // ✅ انیمیشن Bounce قبل از ارسال
                          _controllers[index].reverse().then((_) {
                            if (mounted) {
                              _controllers[index].forward().then((_) {
                                widget.onReactionSelected(_reactions[index]);
                                widget.onClose();
                              });
                            }
                          });
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

// ✅ دکمه هر Reaction
class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 1.3 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}





