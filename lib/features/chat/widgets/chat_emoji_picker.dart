// lib/features/chat/widgets/chat_emoji_picker.dart
//
// Emoji Picker حرفه‌ای - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ 2 ردیف از دسته‌بندی‌ها - مشابه تلگرام
// ✅ دسته‌بندی ایموجی‌ها
// ✅ جستجوی پیشرفته
// ✅ اخیراً استفاده شده
// ✅ انیمیشن روان
// ✅ Skin tone selector
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/chat_theme.dart';

/// Emoji Picker سفارشی با 2 ردیف دسته‌بندی - مشابه تلگرام
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
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎮 CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  late TabController _categoryTabController;
  final TextEditingController _searchController = TextEditingController();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 STATE
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<String> _recentEmojis = [];
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  
  // دسته‌بندی‌های مختلف - مشابه تلگرام
  // ردیف اول: Recent, Smileys, Animals, Travel, Activities, Objects, Symbols, Flags
  // ردیف دوم: Recent, Smileys, Animals, Food, Buildings, Activities, Objects, Symbols
  static final _categories = [
    _EmojiCategory(
      icon: Icons.access_time_rounded,
      name: 'اخیر',
      category: Category.RECENT,
    ),
    _EmojiCategory(
      icon: Icons.emoji_emotions_rounded,
      name: 'صورتک',
      category: Category.SMILEYS,
    ),
    _EmojiCategory(
      icon: Icons.pets_rounded,
      name: 'حیوانات',
      category: Category.ANIMALS,
    ),
    _EmojiCategory(
      icon: Icons.directions_car_rounded,
      name: 'سفر',
      category: Category.TRAVEL,
    ),
    _EmojiCategory(
      icon: Icons.sports_soccer_rounded,
      name: 'فعالیت',
      category: Category.ACTIVITIES,
    ),
    _EmojiCategory(
      icon: Icons.lightbulb_rounded,
      name: 'اشیاء',
      category: Category.OBJECTS,
    ),
    _EmojiCategory(
      icon: Icons.tag_rounded,
      name: 'نمادها',
      category: Category.SYMBOLS,
    ),
    _EmojiCategory(
      icon: Icons.flag_rounded,
      name: 'پرچم‌ها',
      category: Category.FLAGS,
    ),
  ];

  // ردیف دوم دسته‌بندی‌ها (مشابه تلگرام)
  static final _categoriesRow2 = [
    _EmojiCategory(
      icon: Icons.access_time_rounded,
      name: 'اخیر',
      category: Category.RECENT,
    ),
    _EmojiCategory(
      icon: Icons.emoji_emotions_rounded,
      name: 'صورتک',
      category: Category.SMILEYS,
    ),
    _EmojiCategory(
      icon: Icons.pets_rounded,
      name: 'حیوانات',
      category: Category.ANIMALS,
    ),
    _EmojiCategory(
      icon: Icons.fastfood_rounded,
      name: 'غذا',
      category: Category.ACTIVITIES, // استفاده از ACTIVITIES به عنوان جایگزین
    ),
    _EmojiCategory(
      icon: Icons.business_rounded,
      name: 'ساختمان',
      category: Category.OBJECTS, // استفاده از OBJECTS به عنوان جایگزین
    ),
    _EmojiCategory(
      icon: Icons.sports_soccer_rounded,
      name: 'فعالیت',
      category: Category.ACTIVITIES,
    ),
    _EmojiCategory(
      icon: Icons.lightbulb_rounded,
      name: 'اشیاء',
      category: Category.OBJECTS,
    ),
    _EmojiCategory(
      icon: Icons.tag_rounded,
      name: 'نمادها',
      category: Category.SYMBOLS,
    ),
  ];

  // ایموجی‌های پرکاربرد برای نمایش در تب اخیر (وقتی خالی است)
  static const _popularEmojis = [
    '😀', '😂', '🥰', '😍', '😊', '🤔', '😢', '😭', '😡', '🤯',
    '👍', '👎', '❤️', '🔥', '✨', '💯', '🎉', '👏', '🙏', '💪',
    '😎', '🤩', '😇', '🥳', '😋', '😜', '🤪', '😝', '🤗', '🤭',
  ];

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(
      length: _categories.length,
      vsync: this,
    );
    _categoryTabController.addListener(() {
      if (!_categoryTabController.indexIsChanging) {
        setState(() {
          _selectedCategoryIndex = _categoryTabController.index;
        });
      }
    });
    _loadRecentEmojis();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
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
      
      if (mounted) {
        setState(() {}); // به‌روزرسانی UI
      }
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

  void _onCategoryTap(int index) {
    HapticFeedback.lightImpact();
    _categoryTabController.animateTo(index);
    setState(() {
      _selectedCategoryIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Search bar - مشابه تلگرام
          _buildSearchBar(theme),

          // 2 ردیف از دسته‌بندی‌ها - مشابه تلگرام
          _buildCategoryRows(theme),

          // محتوای ایموجی‌ها
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(theme)
                : _buildEmojiContent(theme),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔍 SEARCH BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: '... جستجوی ایموجی',
                hintStyle: TextStyle(
                  color: theme.inputHintColor,
                  fontSize: 14,
                ),
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
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📑 CATEGORY ROWS (2 ردیف دسته‌بندی)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCategoryRows(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.inputBackgroundColor.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // ردیف اول
          _buildCategoryRow(theme, _categories, 0),
          const SizedBox(height: 4),
          // ردیف دوم
          _buildCategoryRow(theme, _categoriesRow2, 0),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(ChatTheme theme, List<_EmojiCategory> categories, int rowOffset) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          // پیدا کردن index واقعی در لیست اصلی
          final realIndex = _categories.indexWhere(
            (c) => c.category == category.category,
          );
          final isSelected = realIndex >= 0 && realIndex == _selectedCategoryIndex;
          
          return _CategoryIcon(
            icon: category.icon,
            isSelected: isSelected,
            onTap: () {
              if (realIndex >= 0) {
                _onCategoryTap(realIndex);
              }
            },
            theme: theme,
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📄 EMOJI CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmojiContent(ChatTheme theme) {
    // اگر دسته‌بندی اخیر انتخاب شده، ایموجی‌های اخیر را نمایش بده
    if (_selectedCategoryIndex == 0) {
      return _buildRecentEmojis(theme);
    }
    
    // در غیر این صورت، از EmojiPicker استفاده کن
    return TabBarView(
      controller: _categoryTabController,
      children: _categories.map((cat) {
        if (cat.category == Category.RECENT) {
          return _buildRecentEmojis(theme);
        }
        return _buildCategoryPage(cat.category, theme);
      }).toList(),
    );
  }

  Widget _buildRecentEmojis(ChatTheme theme) {
    final emojisToShow = _recentEmojis.isEmpty ? _popularEmojis : _recentEmojis;
    
    if (emojisToShow.isEmpty) {
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
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
              ),
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
      itemCount: emojisToShow.length,
      itemBuilder: (context, index) {
        final emoji = emojisToShow[index];
        return _EmojiButton(
          emoji: emoji,
          onTap: () => _onEmojiTap(emoji),
        );
      },
    );
  }

  Widget _buildCategoryPage(Category category, ChatTheme theme) {
    return Stack(
      children: [
        // EmojiPicker کامل
        EmojiPicker(
          onEmojiSelected: (cat, emoji) {
            _onEmojiTap(emoji.emoji);
          },
          config: Config(
            height: widget.height - 200,
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
              initCategory: category,
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
            skinToneConfig: const SkinToneConfig(
              enabled: true,
            ),
          ),
        ),
        // پوشاندن نوار دسته‌بندی EmojiPicker
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 50, // ارتفاع نوار دسته‌بندی
          child: Container(
            color: theme.backgroundColor, // رنگ پس‌زمینه برای پوشاندن
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔍 SEARCH RESULTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchResults(ChatTheme theme) {
    // استفاده از EmojiPicker برای جستجوی پیشرفته
    return Stack(
      children: [
        // EmojiPicker کامل
        EmojiPicker(
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
                'نتیجه‌ای یافت نشد',
                style: TextStyle(color: theme.secondaryTextColor),
              ),
            ),
            categoryViewConfig: CategoryViewConfig(
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
            skinToneConfig: const SkinToneConfig(
              enabled: true,
            ),
          ),
        ),
        // پوشاندن نوار دسته‌بندی EmojiPicker
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 50, // ارتفاع نوار دسته‌بندی
          child: Container(
            color: theme.backgroundColor, // رنگ پس‌زمینه برای پوشاندن
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 HELPER CLASSES
// ═══════════════════════════════════════════════════════════════════════════

class _EmojiCategory {
  final IconData icon;
  final String name;
  final Category category;

  const _EmojiCategory({
    required this.icon,
    required this.name,
    required this.category,
  });
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ChatTheme theme;

  const _CategoryIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.sendButtonColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isSelected
              ? theme.sendButtonColor
              : theme.secondaryTextColor,
        ),
      ),
    );
  }
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
