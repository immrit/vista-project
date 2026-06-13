import 'dart:async';
import 'dart:ui' as ui;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:emoji_picker_flutter/locales/default_emoji_set_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/domain/modern_emoji_lookup.dart';
import '../../emoji/widgets/modern_emoji_inline.dart';
import '../utils/grapheme_text_editing.dart';
import 'gif_picker_widget.dart';

enum PanelView { emoji, gif }

class VistaEmojiPanel extends StatefulWidget {
  final TextEditingController controller;
  final double height;
  final Function(String gifUrl)? onGifSelected;

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
  static const String _recentsStorageKey = 'vista_recent_emojis_v1';

  PanelView _currentView = PanelView.emoji;
  int _selectedCategoryIndex = 0;
  late final PageController _pageController;
  late final TextEditingController _searchController;

  bool _useModernPanel = false;
  String _searchQuery = '';
  List<String> _recentEmojis = <String>[];
  Map<Category, List<Emoji>> _emojiByCategory = <Category, List<Emoji>>{};

  final List<_EmojiCategory> _categories = const [
    _EmojiCategory(icon: Icons.access_time_rounded, category: Category.RECENT),
    _EmojiCategory(
      icon: Icons.emoji_emotions_rounded,
      category: Category.SMILEYS,
    ),
    _EmojiCategory(icon: Icons.pets_rounded, category: Category.ANIMALS),
    _EmojiCategory(
        icon: Icons.directions_car_rounded, category: Category.TRAVEL),
    _EmojiCategory(
      icon: Icons.sports_soccer_rounded,
      category: Category.ACTIVITIES,
    ),
    _EmojiCategory(icon: Icons.lightbulb_rounded, category: Category.OBJECTS),
    _EmojiCategory(icon: Icons.tag_rounded, category: Category.SYMBOLS),
    _EmojiCategory(icon: Icons.flag_rounded, category: Category.FLAGS),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    unawaited(_initializePanelMode());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _initializePanelMode() async {
    await ModernEmojiLookup.instance.load();
    final useModern = EmojiRenderPolicy.useModernEmojiPanel();
    final categories = _loadEmojiCatalog();
    final recents = await _loadRecentEmojis();
    if (!mounted) return;
    setState(() {
      _useModernPanel = useModern;
      _emojiByCategory = categories;
      _recentEmojis = recents;
    });
  }

  Map<Category, List<Emoji>> _loadEmojiCatalog() {
    final set = getDefaultEmojiLocale(const Locale('en'));
    final map = <Category, List<Emoji>>{};
    for (final item in set) {
      map[item.category] = item.emoji;
    }
    return map;
  }

  Future<List<String>> _loadRecentEmojis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentsStorageKey) ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _saveRecentEmoji(String emoji) async {
    if (emoji.trim().isEmpty) return;
    _recentEmojis.remove(emoji);
    _recentEmojis.insert(0, emoji);
    if (_recentEmojis.length > 48) {
      _recentEmojis = _recentEmojis.sublist(0, 48);
    }
    if (mounted) setState(() {});

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentsStorageKey, _recentEmojis);
    } catch (_) {}
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
    });
    if (query.isEmpty) {
      _syncPageControllerToSelectedCategory();
    }
  }

  void _onCategoryTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedCategoryIndex = index);
    if (_searchQuery.isEmpty && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _syncPageControllerToSelectedCategory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_selectedCategoryIndex);
    });
  }

  void _insertEmoji(String emojiText) {
    HapticFeedback.lightImpact();
    widget.controller.value = GraphemeTextEditing.insertText(
      widget.controller.value,
      emojiText,
    );
    unawaited(_saveRecentEmoji(emojiText));
  }

  void _onEmojiSelected(Category _, Emoji emoji) {
    _insertEmoji(emoji.emoji);
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    widget.controller.value =
        GraphemeTextEditing.backspace(widget.controller.value);
  }

  List<Emoji> _currentModernEmojis() {
    if (_searchQuery.isNotEmpty) {
      final all = _emojiByCategory.values.expand((e) => e);
      return all
          .where(
            (e) =>
                e.emoji.contains(_searchQuery) ||
                e.name.toLowerCase().contains(_searchQuery),
          )
          .toList(growable: false);
    }

    return _modernEmojisForCategory(_selectedCategoryIndex);
  }

  List<Emoji> _modernEmojisForCategory(int index) {
    final selectedCategory = _categories[index].category;

    if (selectedCategory == Category.RECENT) {
      if (_recentEmojis.isEmpty) {
        return (_emojiByCategory[Category.SMILEYS] ?? const <Emoji>[])
            .take(40)
            .toList(growable: false);
      }
      return _recentEmojis.map((e) => Emoji(e, e)).toList(growable: false);
    }

    return _emojiByCategory[selectedCategory] ?? const <Emoji>[];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final bottomBarColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.9)
        : const Color(0xFFF9F9F9).withValues(alpha: 0.9);
    final activeIconColor = const Color(0xFF3390EC);

    return Container(
      height: widget.height,
      color: backgroundColor,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 45),
            child: IndexedStack(
              index: _currentView == PanelView.emoji ? 0 : 1,
              children: [
                _useModernPanel
                    ? _buildModernEmojiView(backgroundColor, isDark)
                    : _buildSystemEmojiPage(backgroundColor),
                GifPickerWidget(
                  onGifSelected: (url) {
                    if (widget.onGifSelected != null) {
                      widget.onGifSelected!(url);
                    }
                  },
                ),
              ],
            ),
          ),
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
                        color: theme.dividerColor.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabBtn(
                        Icons.gif_box_outlined,
                        PanelView.gif,
                        activeIconColor,
                        isDark,
                      ),
                      _buildTabBtn(
                        Icons.emoji_emotions_outlined,
                        PanelView.emoji,
                        activeIconColor,
                        isDark,
                      ),
                      Container(
                        width: 1,
                        height: 16,
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
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
                                        ? activeIconColor.withValues(
                                            alpha: 0.15)
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
                            child: Icon(
                              Icons.backspace_outlined,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 22,
                            ),
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

  Widget _buildModernEmojiView(Color bgColor, bool isDark) {
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: TextField(
            controller: _searchController,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'جستجوی ایموجی',
              hintStyle: TextStyle(color: hintColor),
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF141416) : Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: hintColor,
                      ),
                    ),
            ),
          ),
        ),
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildModernEmojiGrid(
                  emojis: _currentModernEmojis(),
                  bgColor: bgColor,
                  hintColor: hintColor,
                )
              : PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategoryIndex = index);
                  },
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    return _buildModernEmojiGrid(
                      emojis: _modernEmojisForCategory(index),
                      bgColor: bgColor,
                      hintColor: hintColor,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModernEmojiGrid({
    required List<Emoji> emojis,
    required Color bgColor,
    required Color hintColor,
  }) {
    if (emojis.isEmpty) {
      return Center(
        child: Text(
          'ایموجی پیدا نشد',
          style: TextStyle(color: hintColor, fontSize: 13),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emojiText = emojis[index].emoji;
        return GestureDetector(
          onTap: () => _insertEmoji(emojiText),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ModernEmojiInline(
              emoji: emojiText,
              size: 29,
              fallbackStyle: const TextStyle(fontSize: 26),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemEmojiPage(Color bgColor) {
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
            checkPlatformCompatibility: false,
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 28,
              backgroundColor: bgColor,
              verticalSpacing: 0,
              horizontalSpacing: 0,
              gridPadding: EdgeInsets.zero,
              recentsLimit: 28,
              buttonMode: ButtonMode.MATERIAL,
            ),
            categoryViewConfig: CategoryViewConfig(
              initCategory: _categories[index].category,
              backgroundColor: bgColor,
              tabBarHeight: 0,
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
    IconData icon,
    PanelView view,
    Color activeColor,
    bool isDark,
  ) {
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

  const _EmojiCategory({
    required this.icon,
    required this.category,
  });
}
