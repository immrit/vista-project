// lib/features/chat/widgets/message_search_bar.dart
//
// نوار جستجو در پیام‌ها - با الهام از ویستا
//
// ویژگی‌ها:
// ✅ انیمیشن ظاهر شدن/محو شدن
// ✅ نمایش تعداد نتایج
// ✅ دکمه‌های بالا/پایین
// ✅ کلید میانبر Enter
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_search_service.dart';
import '../theme/chat_theme.dart';

class MessageSearchBar extends ConsumerStatefulWidget {
  final String conversationId;
  final VoidCallback onClose;
  final Function(String messageId)? onResultSelected;

  const MessageSearchBar({
    super.key,
    required this.conversationId,
    required this.onClose,
    this.onResultSelected,
  });

  @override
  ConsumerState<MessageSearchBar> createState() => _MessageSearchBarState();
}

class _MessageSearchBarState extends ConsumerState<MessageSearchBar>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animController.reverse();
    ref.read(searchStateProvider(widget.conversationId).notifier).clear();
    widget.onClose();
  }

  void _onSearch(String query) {
    ref
        .read(searchStateProvider(widget.conversationId).notifier)
        .search(query);
  }

  void _goToPrevious() {
    HapticFeedback.selectionClick();
    ref.read(searchStateProvider(widget.conversationId).notifier).previousResult();
    _notifyResultSelected();
  }

  void _goToNext() {
    HapticFeedback.selectionClick();
    ref.read(searchStateProvider(widget.conversationId).notifier).nextResult();
    _notifyResultSelected();
  }

  void _notifyResultSelected() {
    final state = ref.read(searchStateProvider(widget.conversationId));
    if (state.currentResult != null && widget.onResultSelected != null) {
      widget.onResultSelected!(state.currentResult!.message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final searchState = ref.watch(searchStateProvider(widget.conversationId));

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 60),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.appBarColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // دکمه بستن
            IconButton(
              onPressed: _close,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.iconColor,
              ),
            ),

            // فیلد جستجو
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearch,
                onSubmitted: (_) => _goToNext(),
                style: TextStyle(color: theme.textColor),
                decoration: InputDecoration(
                  hintText: 'جستجو در پیام‌ها...',
                  hintStyle: TextStyle(color: theme.secondaryTextColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),

            // نتایج و دکمه‌های navigation
            if (searchState.query.isNotEmpty) ...[
              // تعداد نتایج
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: searchState.isSearching
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.sendButtonColor,
                        ),
                      )
                    : Text(
                        searchState.hasResults
                            ? '${searchState.currentIndex + 1}/${searchState.results.length}'
                            : 'نتیجه‌ای یافت نشد',
                        style: TextStyle(
                          color: searchState.hasResults
                              ? theme.secondaryTextColor
                              : theme.errorColor,
                          fontSize: 13,
                        ),
                      ),
              ),

              const SizedBox(width: 8),

              // دکمه بالا
              IconButton(
                onPressed: searchState.canGoPrevious ? _goToPrevious : null,
                icon: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: searchState.canGoPrevious
                      ? theme.iconColor
                      : theme.iconColor.withOpacity(0.3),
                ),
              ),

              // دکمه پایین
              IconButton(
                onPressed: searchState.canGoNext ? _goToNext : null,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: searchState.canGoNext
                      ? theme.iconColor
                      : theme.iconColor.withOpacity(0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 HIGHLIGHT TEXT WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// ویجت نمایش متن با هایلایت
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int maxLines;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // اضافه کردن متن باقی‌مانده
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      // متن قبل از match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // متن match شده
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle ??
            const TextStyle(
              backgroundColor: Color(0xFFFFEB3B),
              fontWeight: FontWeight.w600,
            ),
      ));

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

