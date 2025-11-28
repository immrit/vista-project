// lib/features/chat/widgets/chat_emoji_picker.dart
//
// Emoji Picker حرفه‌ای - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ دسته‌بندی ایموجی‌ها
// ✅ جستجو
// ✅ اخیراً استفاده شده
// ✅ انیمیشن روان
// ✅ Skin tone selector
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/chat_theme.dart';

/// Emoji Picker سفارشی
class ChatEmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback? onBackspace;
  final double height;

  const ChatEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.onBackspace,
    this.height = 280,
  });

  @override
  State<ChatEmojiPicker> createState() => _ChatEmojiPickerState();
}

class _ChatEmojiPickerState extends State<ChatEmojiPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _recentEmojis = [];
  String _searchQuery = '';
  
  // دسته‌بندی‌ها
  static const _categories = [
    _EmojiCategory(icon: Icons.access_time_rounded, name: 'اخیر'),
    _EmojiCategory(icon: Icons.emoji_emotions_rounded, name: 'صورتک'),
    _EmojiCategory(icon: Icons.pets_rounded, name: 'حیوانات'),
    _EmojiCategory(icon: Icons.fastfood_rounded, name: 'غذا'),
    _EmojiCategory(icon: Icons.directions_car_rounded, name: 'سفر'),
    _EmojiCategory(icon: Icons.sports_soccer_rounded, name: 'فعالیت'),
    _EmojiCategory(icon: Icons.lightbulb_rounded, name: 'اشیاء'),
    _EmojiCategory(icon: Icons.tag_rounded, name: 'نمادها'),
    _EmojiCategory(icon: Icons.flag_rounded, name: 'پرچم‌ها'),
  ];

  // ایموجی‌های پرکاربرد
  static const _popularEmojis = [
    '😀', '😂', '🥰', '😍', '😊', '🤔', '😢', '😭', '😡', '🤯',
    '👍', '👎', '❤️', '🔥', '✨', '💯', '🎉', '👏', '🙏', '💪',
    '😎', '🤩', '😇', '🥳', '😋', '😜', '🤪', '😝', '🤗', '🤭',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadRecentEmojis();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentEmojis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recent_emojis') ?? [];
      setState(() => _recentEmojis = recent);
    } catch (_) {}
  }

  Future<void> _saveRecentEmoji(String emoji) async {
    try {
      _recentEmojis.remove(emoji);
      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > 30) {
        _recentEmojis = _recentEmojis.sublist(0, 30);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_emojis', _recentEmojis);
    } catch (_) {}
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  void _onEmojiTap(String emoji) {
    HapticFeedback.lightImpact();
    widget.onEmojiSelected(emoji);
    _saveRecentEmoji(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          _buildSearchBar(theme),

          // Category tabs
          _buildCategoryTabs(theme),

          // Emoji grid
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(theme)
                : _buildEmojiGrid(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: theme.textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'جستجوی ایموجی...',
                hintStyle: TextStyle(color: theme.inputHintColor),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.secondaryTextColor,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.secondaryTextColor,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.inputBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),

          // Backspace button
          if (widget.onBackspace != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onBackspace!();
              },
              icon: Icon(
                Icons.backspace_rounded,
                color: theme.iconColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(ChatTheme theme) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: theme.sendButtonColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: theme.sendButtonColor,
        unselectedLabelColor: theme.secondaryTextColor,
        tabs: _categories.map((cat) => Tab(
          icon: Icon(cat.icon, size: 22),
        )).toList(),
      ),
    );
  }

  Widget _buildEmojiGrid(ChatTheme theme) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Recent
        _buildEmojiPage(
          _recentEmojis.isEmpty ? _popularEmojis : _recentEmojis,
          theme,
        ),
        // باقی دسته‌بندی‌ها - استفاده از emoji_picker_flutter
        ...List.generate(8, (index) => _buildCategoryPage(index, theme)),
      ],
    );
  }

  Widget _buildCategoryPage(int categoryIndex, ChatTheme theme) {
    // استفاده از پکیج emoji_picker_flutter برای داده‌های واقعی
    return EmojiPicker(
      onEmojiSelected: (category, emoji) {
        _onEmojiTap(emoji.emoji);
      },
      config: Config(
        height: widget.height - 100,
        checkPlatformCompatibility: true,
        emojiViewConfig: EmojiViewConfig(
          columns: 8,
          emojiSizeMax: 28,
          backgroundColor: theme.backgroundColor,
          noRecents: Text(
            'ایموجی اخیری نیست',
            style: TextStyle(color: theme.secondaryTextColor),
          ),
        ),
        categoryViewConfig: CategoryViewConfig(
          initCategory: Category.values[categoryIndex.clamp(0, Category.values.length - 1)],
          backgroundColor: theme.backgroundColor,
          indicatorColor: theme.sendButtonColor,
          iconColorSelected: theme.sendButtonColor,
          iconColor: theme.secondaryTextColor,
        ),
        bottomActionBarConfig: const BottomActionBarConfig(
          enabled: false,
        ),
        searchViewConfig: SearchViewConfig(
          backgroundColor: theme.backgroundColor,
          buttonIconColor: theme.iconColor,
        ),
      ),
    );
  }

  Widget _buildEmojiPage(List<String> emojis, ChatTheme theme) {
    if (emojis.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              size: 48,
              color: theme.secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'ایموجی اخیری نیست',
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return _EmojiButton(
          emoji: emoji,
          onTap: () => _onEmojiTap(emoji),
        );
      },
    );
  }

  Widget _buildSearchResults(ChatTheme theme) {
    // جستجوی ساده در ایموجی‌های پرکاربرد
    // در نسخه واقعی باید از دیتابیس ایموجی استفاده شه
    final results = _popularEmojis.where((e) => e.contains(_searchQuery)).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'نتیجه‌ای یافت نشد',
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return _buildEmojiPage(results, theme);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _EmojiCategory {
  final IconData icon;
  final String name;

  const _EmojiCategory({required this.icon, required this.name});
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton> {
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
        scale: _isPressed ? 1.3 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.grey.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 QUICK EMOJI BAR - نوار ایموجی سریع بالای کیبورد
// ═══════════════════════════════════════════════════════════════════════════

class QuickEmojiBar extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback onExpandTap;

  const QuickEmojiBar({
    super.key,
    required this.onEmojiSelected,
    required this.onExpandTap,
  });

  static const _quickEmojis = ['😀', '😂', '❤️', '👍', '🔥', '✨', '🎉', '😊'];

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.inputBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Quick emojis
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickEmojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onEmojiSelected(_quickEmojis[index]);
                  },
                  child: Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      _quickEmojis[index],
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                );
              },
            ),
          ),

          // Expand button
          IconButton(
            onPressed: onExpandTap,
            icon: Icon(
              Icons.emoji_emotions_outlined,
              color: theme.iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

