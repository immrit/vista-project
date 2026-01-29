// lib/features/chat/widgets/vista_emoji_panel.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'gif_picker_widget.dart';

enum PanelView { emoji, gif }

class VistaEmojiPanel extends StatefulWidget {
  final TextEditingController controller;
  final double height;
  final Function(String gifUrl)? onGifSelected; // تابع اصلی اتصال به چت

  const VistaEmojiPanel({
    super.key,
    required this.controller,
    this.height = 300,
    this.onGifSelected,
  });

  @override
  State<VistaEmojiPanel> createState() => _VistaEmojiPanelState();
}

class _VistaEmojiPanelState extends State<VistaEmojiPanel> {
  PanelView _currentView = PanelView.emoji;
  int _selectedCategoryIndex = 0;
  late final PageController _pageController;

  final List<_EmojiCategory> _categories = const [
    _EmojiCategory(icon: Icons.access_time_rounded, category: Category.RECENT),
    _EmojiCategory(
        icon: Icons.emoji_emotions_rounded, category: Category.SMILEYS),
    _EmojiCategory(icon: Icons.pets_rounded, category: Category.ANIMALS),
    _EmojiCategory(
        icon: Icons.directions_car_rounded, category: Category.TRAVEL),
    _EmojiCategory(
        icon: Icons.sports_soccer_rounded, category: Category.ACTIVITIES),
    _EmojiCategory(icon: Icons.lightbulb_rounded, category: Category.OBJECTS),
    _EmojiCategory(icon: Icons.tag_rounded, category: Category.SYMBOLS),
    _EmojiCategory(icon: Icons.flag_rounded, category: Category.FLAGS),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onCategoryTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedCategoryIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _onEmojiSelected(Category category, Emoji emoji) {
    HapticFeedback.lightImpact();
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji.emoji);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.emoji.length),
    );
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final newText = text.replaceRange(selection.start, selection.end, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
      return;
    }
    if (text.isNotEmpty) {
      final cursorPosition = selection.isValid ? selection.start : text.length;
      if (cursorPosition > 0) {
        final newText = text.substring(0, cursorPosition - 1) +
            (cursorPosition < text.length
                ? text.substring(cursorPosition)
                : '');
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorPosition - 1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final bottomBarColor = isDark
        ? const Color(0xFF1C1C1E).withOpacity(0.9)
        : const Color(0xFFF9F9F9).withOpacity(0.9);
    final activeIconColor = const Color(0xFF3390EC);

    return Container(
      height: widget.height,
      color: backgroundColor,
      child: Stack(
        children: [
          // 1. محتوای اصلی (ایموجی یا گیف)
          Padding(
            padding: const EdgeInsets.only(bottom: 45),
            child: IndexedStack(
              index: _currentView == PanelView.emoji ? 0 : 1,
              children: [
                _buildEmojiPage(backgroundColor),
                // ✅ بخش گیف: اتصال مستقیم به تابع پدر
                GifPickerWidget(
                  // حذف کلید ثابت برای جلوگیری از مشکل کش شدن ویجت
                  // key: const ValueKey('gif_picker'),
                  onGifSelected: (url) {
                    print("🚀 VistaPanel: GIF Selected -> $url");
                    if (widget.onGifSelected != null) {
                      widget.onGifSelected!(url);
                    } else {
                      print(
                          "❌ Error: onGifSelected callback is NULL in VistaPanel");
                    }
                  },
                ),
              ],
            ),
          ),

          // 2. نوار ابزار پایین (تب‌ها)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: bottomBarColor,
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabBtn(Icons.gif_box_outlined, PanelView.gif,
                          activeIconColor, isDark),
                      _buildTabBtn(Icons.emoji_emotions_outlined,
                          PanelView.emoji, activeIconColor, isDark),
                      Container(
                          width: 1,
                          height: 16,
                          color: theme.dividerColor.withOpacity(0.3)),
                      if (_currentView == PanelView.emoji)
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final isSelected =
                                  index == _selectedCategoryIndex;
                              return GestureDetector(
                                onTap: () => _onCategoryTap(index),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? activeIconColor.withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: isSelected
                                        ? activeIconColor
                                        : (isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600]),
                                    size: isSelected ? 24 : 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const Spacer(),
                      if (_currentView == PanelView.emoji)
                        GestureDetector(
                          onTap: _onBackspace,
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _onBackspace();
                          },
                          child: Container(
                            width: 60,
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            child: Icon(Icons.backspace_outlined,
                                color: isDark ? Colors.white70 : Colors.black54,
                                size: 22),
                          ),
                        )
                      else
                        const SizedBox(width: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPage(Color bgColor) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) => setState(() => _selectedCategoryIndex = index),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        return EmojiPicker(
          onEmojiSelected: (cat, emoji) =>
              _onEmojiSelected(cat ?? _categories[index].category, emoji),
          config: Config(
            height: widget.height - 45,
            checkPlatformCompatibility:
                false, // ❌ جلوگیری از استایل iOS که باعث هدر شناور می‌شود
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 28,
              backgroundColor: bgColor,
              verticalSpacing: 0,
              horizontalSpacing: 0,
              gridPadding: EdgeInsets.zero,
              recentsLimit: 28,
              buttonMode: ButtonMode.MATERIAL, // ✅ استایل متریال ساده‌تر
            ),
            categoryViewConfig: CategoryViewConfig(
              initCategory: _categories[index].category,
              backgroundColor: bgColor,
              tabBarHeight: 0, // مخفی کردن تب‌بار
              dividerColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              iconColor: Colors.transparent,
              iconColorSelected: Colors.transparent,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig:
                const SearchViewConfig(backgroundColor: Colors.transparent),
            skinToneConfig: const SkinToneConfig(enabled: false),
          ),
        );
      },
    );
  }

  Widget _buildTabBtn(
      IconData icon, PanelView view, Color activeColor, bool isDark) {
    final isSelected = _currentView == view;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentView = view);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: Colors.transparent,
        child: Icon(
          icon,
          color: isSelected
              ? activeColor
              : (isDark ? Colors.grey[500] : Colors.grey[600]),
          size: 26,
        ),
      ),
    );
  }
}

class _EmojiCategory {
  final IconData icon;
  final Category category;
  const _EmojiCategory({required this.icon, required this.category});
}
