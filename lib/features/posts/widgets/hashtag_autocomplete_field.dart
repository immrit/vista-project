import 'dart:async';
import 'package:flutter/material.dart';
import '../data/go_posts_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../../model/UserModel.dart';
import '../../../widgets/verification_badge_icon.dart';

/// Combined autocomplete field for `#hashtags` **and** `@mentions`
/// (Instagram / X / Threads style).
///
/// While typing, [SocialTextEditingController] highlights the tokens live; this
/// widget pops an overlay with suggestions for whichever trigger the caret is
/// currently inside:
/// - `#` → trending / matching hashtags (Go backend, with trending cache fallback)
/// - `@` → matching users (profiles search, with a warm "suggested" cache)
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

  /// Enable `@mention` autocomplete. Hashtags are always enabled.
  final bool enableMentions;

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
    this.enableMentions = true,
  });

  @override
  State<HashtagAutocompleteField> createState() =>
      _HashtagAutocompleteFieldState();
}

enum _SuggestMode { none, hashtag, mention }

class _HashtagAutocompleteFieldState extends State<HashtagAutocompleteField> {
  final GoPostsRepository _postsRepository = GoPostsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Hashtag state
  List<Map<String, dynamic>> _hashtagSuggestions = [];
  List<Map<String, dynamic>> _trending = [];

  // Mention state
  List<UserModel> _userSuggestions = [];
  List<UserModel> _suggestedUsers = [];

  bool _isLoading = false;
  _SuggestMode _mode = _SuggestMode.none;

  Timer? _debounceTimer;
  String? _currentQuery;
  int _tokenStartIndex = 0;
  int _requestSeq = 0;
  final FocusNode _focusNode = FocusNode();

  static const Duration _debounceDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    // Warm caches so the first '#'/'@' feels instant.
    unawaited(_loadTrendingTags());
    if (widget.enableMentions) unawaited(_loadSuggestedUsers());
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
    if (!_focusNode.hasFocus) _removeOverlay();
  }

  void _onTextChanged() {
    widget.onChanged?.call(widget.controller.text);
    _detectTrigger();
  }

  /// Detect whether the caret sits inside a `#`/`@` token and, if so, kick off
  /// a debounced search for that token.
  void _detectTrigger() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _reset();
      return;
    }

    final cursor = selection.baseOffset;
    if (cursor <= 0) {
      _reset();
      return;
    }

    final before = text.substring(0, cursor);

    // The trigger char must start the token: either at string start or after a
    // whitespace/newline — this prevents emails (`a@b`) from triggering mentions.
    final RegExp tokenRegex =
        RegExp(r'(^|[\s\n])([#@])([؀-ۿ\w_]*)$', unicode: true);
    final match = tokenRegex.firstMatch(before);

    if (match == null) {
      _reset();
      return;
    }

    final trigger = match.group(2)!;
    final query = match.group(3) ?? '';
    // start index of the trigger char itself (group 1 may be a leading space).
    _tokenStartIndex = match.start + match.group(1)!.length;
    _currentQuery = query;

    final mode = trigger == '#'
        ? _SuggestMode.hashtag
        : (widget.enableMentions ? _SuggestMode.mention : _SuggestMode.none);

    if (mode == _SuggestMode.none) {
      _reset();
      return;
    }
    _mode = mode;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (mode == _SuggestMode.hashtag) {
        _searchHashtags(query);
      } else {
        _searchUsers(query);
      }
    });
  }

  void _reset() {
    _currentQuery = null;
    _mode = _SuggestMode.none;
    _removeOverlay();
  }

  // ---------------------------------------------------------------------------
  // Hashtags
  // ---------------------------------------------------------------------------

  Future<void> _loadTrendingTags() async {
    try {
      final suggestions =
          await _postsRepository.getTrendingHashtags(limit: 20, days: 30);
      final list = suggestions.map((item) => item.toMap()).toList();
      if (mounted) {
        setState(() => _trending = list);
      } else {
        _trending = list;
      }
    } catch (_) {
      // trending is best-effort UX only
    }
  }

  Future<void> _searchHashtags(String keyword) async {
    final seq = ++_requestSeq;

    if (keyword.isEmpty) {
      if (_trending.isEmpty) await _loadTrendingTags();
      if (!mounted || seq != _requestSeq) return;
      setState(() => _hashtagSuggestions = _trending);
      _refreshOverlay(_hashtagSuggestions.isNotEmpty);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response =
          await _postsRepository.searchHashtags(keyword: keyword, limit: 20);
      var suggestions = response.map((item) => item.toMap()).toList();

      if (suggestions.isEmpty) {
        // Fallback: prefix-filter the trending cache.
        if (_trending.isEmpty) await _loadTrendingTags();
        final k = keyword.toLowerCase();
        suggestions = _trending
            .where(
                (m) => (m['tag']?.toString().toLowerCase() ?? '').startsWith(k))
            .toList();
      }

      if (!mounted || seq != _requestSeq) return;
      setState(() => _hashtagSuggestions = suggestions);
      _refreshOverlay(suggestions.isNotEmpty);
    } catch (_) {
      if (_trending.isEmpty) await _loadTrendingTags();
      final k = keyword.toLowerCase();
      final filtered = _trending
          .where(
              (m) => (m['tag']?.toString().toLowerCase() ?? '').startsWith(k))
          .toList();
      if (!mounted || seq != _requestSeq) return;
      setState(() => _hashtagSuggestions = filtered);
      _refreshOverlay(filtered.isNotEmpty);
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Mentions
  // ---------------------------------------------------------------------------

  Future<void> _loadSuggestedUsers() async {
    try {
      final profiles =
          await _profileRepository.searchProfiles(query: '', limit: 8);
      final users = profiles.map((p) => UserModel.fromMap(p.toMap())).toList();
      if (mounted) {
        setState(() => _suggestedUsers = users);
      } else {
        _suggestedUsers = users;
      }
    } catch (_) {
      // best-effort only
    }
  }

  Future<void> _searchUsers(String keyword) async {
    final seq = ++_requestSeq;

    if (keyword.isEmpty) {
      if (_suggestedUsers.isEmpty) await _loadSuggestedUsers();
      if (!mounted || seq != _requestSeq) return;
      setState(() => _userSuggestions = _suggestedUsers);
      _refreshOverlay(_userSuggestions.isNotEmpty);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profiles =
          await _profileRepository.searchProfiles(query: keyword, limit: 12);
      final users = profiles.map((p) => UserModel.fromMap(p.toMap())).toList();
      if (!mounted || seq != _requestSeq) return;
      setState(() => _userSuggestions = users);
      _refreshOverlay(users.isNotEmpty);
    } catch (_) {
      // Fallback: prefix-filter warm suggested cache.
      final k = keyword.toLowerCase();
      final filtered = _suggestedUsers
          .where((u) => u.username.toLowerCase().startsWith(k))
          .toList();
      if (!mounted || seq != _requestSeq) return;
      setState(() => _userSuggestions = filtered);
      _refreshOverlay(filtered.isNotEmpty);
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Overlay
  // ---------------------------------------------------------------------------

  void _refreshOverlay(bool hasItems) {
    if (hasItems || _isLoading) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white12
                      : Colors.black12,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading &&
        ((_mode == _SuggestMode.hashtag && _hashtagSuggestions.isEmpty) ||
            (_mode == _SuggestMode.mention && _userSuggestions.isEmpty))) {
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

    if (_mode == _SuggestMode.mention) {
      return _buildMentionList(isDark);
    }
    return _buildHashtagList(isDark);
  }

  Widget _buildHashtagList(bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hashtagSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _hashtagSuggestions[index];
        final tag = suggestion['tag'] as String? ?? '';
        final usageCount = suggestion['usage_count'] as int? ?? 0;

        return InkWell(
          onTap: () => _commitToken('#$tag '),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$tag',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$usageCount پست',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_outline,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMentionList(bool isDark) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _userSuggestions.length,
      itemBuilder: (context, index) {
        final user = _userSuggestions[index];
        final avatar = user.avatarUrl;
        return InkWell(
          onTap: () => _commitToken('@${user.username} '),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (avatar != null && avatar.isNotEmpty)
                      ? NetworkImage(avatar)
                      : const AssetImage('lib/utils/images/default-avatar.jpg')
                          as ImageProvider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.username.isEmpty ? 'کاربر' : user.username,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      VerificationBadgeIcon(
                        isVerified: user.isVerified,
                        verificationType: user.verificationType.name,
                        role: user.role,
                        size: 15,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.alternate_email,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Replace the in-progress token (`#partial` / `@partial`) with [replacement]
  /// and place the caret right after it.
  void _commitToken(String replacement) {
    if (_currentQuery == null) return;
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < _tokenStartIndex) {
      _reset();
      return;
    }

    final newText = text.replaceRange(_tokenStartIndex, cursor, replacement);
    final newCursor = _tokenStartIndex + replacement.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: newCursor.clamp(0, newText.length),
      ),
    );

    _reset();
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
