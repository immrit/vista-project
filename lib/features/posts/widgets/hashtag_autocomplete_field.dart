import 'dart:async';
import 'package:flutter/material.dart';
import '../data/go_posts_repository.dart';

/// فیلد متنی با قابلیت Autocomplete هشتگ (مشابه ویستا)
class HashtagAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final int maxLines;
  final int minLines;
  final String hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final Color? cardColor;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final TextDirection textDirection;

  const HashtagAutocompleteField({
    super.key,
    required this.controller,
    this.maxLines = 7,
    this.minLines = 3,
    this.hintText = 'چیزی بنویسید...',
    this.style,
    this.hintStyle,
    this.cardColor,
    this.decoration,
    this.onChanged,
    this.textDirection = TextDirection.rtl,
  });

  @override
  State<HashtagAutocompleteField> createState() =>
      _HashtagAutocompleteFieldState();
}

class _HashtagAutocompleteFieldState extends State<HashtagAutocompleteField> {
  final GoPostsRepository _postsRepository = GoPostsRepository();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _trending = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  String? _currentHashtagQuery;
  int _hashtagStartIndex = 0;
  final FocusNode _focusNode = FocusNode();

  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    // Warm cache for fast "just typed #" suggestions (Social-like).
    unawaited(_loadTrendingTags());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    widget.onChanged?.call(widget.controller.text);
    _detectHashtag();
  }

  /// تشخیص هشتگ در موقعیت مکان‌نما
  void _detectHashtag() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _removeOverlay();
      return;
    }

    final cursorPosition = selection.baseOffset;
    if (cursorPosition <= 0) {
      _removeOverlay();
      return;
    }

    // پیدا کردن کلمه فعلی که کرسر درونش است
    final textBeforeCursor = text.substring(0, cursorPosition);

    // استفاده از Regex برای یافتن هشتگ در انتهای متن قبل از کرسر
    // این الگو هشتگ‌هایی که با # شروع می‌شوند و شامل حروف فارسی/انگلیسی/اعداد هستند را پیدا می‌کند
    final RegExp hashtagRegex = RegExp(r'#([\u0600-\u06FF\w]*)$');
    final match = hashtagRegex.firstMatch(textBeforeCursor);

    if (match != null) {
      final query = match.group(1) ?? '';
      _hashtagStartIndex = match.start;
      _currentHashtagQuery = query;

      // Debounce API call
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceDuration, () {
        _searchHashtags(query);
      });
    } else {
      _currentHashtagQuery = null;
      _removeOverlay();
    }
  }

  Future<void> _loadTrendingTags() async {
    try {
      final suggestions = await _postsRepository.getTrendingHashtags(
        limit: 20,
        days: 30,
      );
      final list = suggestions.map((item) => item.toMap()).toList();
      if (mounted) {
        setState(() => _trending = list);
      } else {
        _trending = list;
      }
    } catch (_) {
      // ignore – trending is best-effort for UX only
    }
  }

  /// جستجوی هشتگ از Go backend
  Future<void> _searchHashtags(String keyword) async {
    // If user just typed '#', show trending tags instead of an empty dropdown.
    if (keyword.isEmpty) {
      if (_trending.isEmpty) {
        await _loadTrendingTags();
      }
      if (!mounted) return;
      setState(() => _suggestions = _trending);
      if (_suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _postsRepository.searchHashtags(
        keyword: keyword,
        limit: 20,
      );
      final suggestions = response.map((item) => item.toMap()).toList();

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      } else {
        _suggestions = suggestions;
      }

      if (_suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        // fallback: filter trending cache if search returns nothing
        if (_trending.isEmpty) {
          await _loadTrendingTags();
        }
        final k = keyword.toLowerCase();
        final filtered = _trending
            .where(
                (m) => (m['tag']?.toString().toLowerCase() ?? '').startsWith(k))
            .toList();
        if (mounted) {
          setState(() => _suggestions = filtered);
        } else {
          _suggestions = filtered;
        }
        if (_suggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      // If the RPC doesn't exist or network is flaky, fall back to trending cache.
      if (_trending.isEmpty) {
        await _loadTrendingTags();
      }
      final k = keyword.toLowerCase();
      final filtered = _trending
          .where(
              (m) => (m['tag']?.toString().toLowerCase() ?? '').startsWith(k))
          .toList();
      if (!mounted) return;
      setState(() => _suggestions = filtered);
      if (_suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// نمایش Overlay پیشنهادات
  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56), // زیر فیلد متنی
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white12
                      : Colors.black12,
                ),
              ),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// حذف Overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// ساخت لیست پیشنهادات
  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final tag = suggestion['tag'] as String? ?? '';
        final usageCount = suggestion['usage_count'] as int? ?? 0;

        return InkWell(
          onTap: () => _selectHashtag(tag),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // آیکون هشتگ
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF58529), Color(0xFFDD2A7B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '#',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // اطلاعات هشتگ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$tag',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$usageCount پست',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white60
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // آیکون افزودن
                Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white38
                      : Colors.black38,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// انتخاب هشتگ از لیست
  void _selectHashtag(String tag) {
    if (_currentHashtagQuery == null) return;

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // جایگزینی هشتگ تایپ شده با هشتگ انتخاب شده
    final newText = text.replaceRange(
      _hashtagStartIndex,
      cursorPosition,
      '#$tag ', // اضافه کردن فاصله بعد از هشتگ
    );

    widget.controller.text = newText;

    // قرار دادن کرسر بعد از هشتگ جدید
    final newCursorPosition =
        _hashtagStartIndex + tag.length + 2; // +2 for # and space
    widget.controller.selection = TextSelection.collapsed(
      offset: newCursorPosition.clamp(0, newText.length),
    );

    _removeOverlay();
    _currentHashtagQuery = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Card(
        color: widget.cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            keyboardType: TextInputType.multiline,
            textDirection: widget.textDirection,
            style: widget.style,
            decoration: widget.decoration ??
                InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: widget.hintStyle,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
          ),
        ),
      ),
    );
  }
}
