import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/directional_navigation.dart';
import '../models/group_user_item.dart';
import '../services/group_service.dart';
import 'group_create_screen.dart';
import 'modern_chat_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';

/// صفحه پیام جدید - UI ساده و مینیمال مشابه ویستا
class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  final _service = GroupService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _isLoading = true;
  bool _isSecretMode = false;
  List<GroupUserItem> _users = [];
  List<GroupUserItem>? _globalSearchResults;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _service.getInteractionUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        if (!mounted) return;
        setState(() {
          _globalSearchResults = null;
        });
        return;
      }

      _service.searchUsers(query).then((results) {
        if (!mounted) return;
        setState(() {
          _globalSearchResults = results;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _globalSearchResults = [];
        });
      });
    });
  }

  List<GroupUserItem> _filteredUsers() {
    if (_globalSearchResults != null) {
      return _globalSearchResults!;
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((user) {
      final name = user.displayName.toLowerCase();
      final username = user.username.toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  void _openConversation(GroupUserItem user, {bool isSecret = false}) async {
    String? conversationId = user.conversationId;

    if (isSecret || conversationId == null || conversationId.isEmpty) {
      try {
        final repo = ref.read(chatRepositoryProvider);
        final result =
            await repo.createConversation(user.id, isSecret: isSecret);
        if (result.isSuccess && result.data != null) {
          conversationId = result.data!.id;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.error ?? 'خطا در ایجاد گفتگو')),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در ارتباط با سرور')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModernChatScreen(
          args: ChatScreenArgs(
            conversationId: conversationId!,
            otherUserName: user.displayName,
            otherUserAvatar: user.avatarUrl,
            otherUserId: user.id,
            isSecret: isSecret,
          ),
        ),
      ),
    );
  }

  void _openCreateGroup() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GroupCreateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredUsers();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            directionalBackIcon(context, ios: true),
            color: theme.iconTheme.color,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSecretMode ? 'گفتگوی محرمانه' : 'پیام جدید',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _isSecretMode
                ? Colors.green
                : theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // جستجو
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _buildSearchField(theme),
          ),

          // لیست
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // دکمه ساخت گروه
                      if (!_isSecretMode)
                        SliverToBoxAdapter(
                          child: _buildCreateGroupTile(theme),
                        ),

                      // دکمه ساخت سکرت چت
                      if (!_isSecretMode)
                        SliverToBoxAdapter(
                          child: _buildCreateSecretChatTile(theme),
                        ),

                      // هدر لیست کاربران
                      if (filtered.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'پیشنهادی',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.hintColor,
                              ),
                            ),
                          ),
                        ),

                      // لیست کاربران
                      filtered.isEmpty
                          ? SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_search_rounded,
                                      size: 48,
                                      color: theme.hintColor
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchController.text.isEmpty
                                          ? 'هنوز گفتگویی نداشتید'
                                          : 'نتیجه‌ای یافت نشد',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final user = filtered[index];
                                  return _buildUserTile(
                                    theme,
                                    user,
                                    isLast: index == filtered.length - 1,
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),

                      // فضای خالی پایین
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 24),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 15,
          color: theme.textTheme.bodyLarge?.color,
        ),
        decoration: InputDecoration(
          hintText: 'جستجو',
          hintStyle: TextStyle(
            fontSize: 15,
            color: theme.hintColor,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.hintColor,
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.hintColor,
                    size: 20,
                  ),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCreateGroupTile(ThemeData theme) {
    return InkWell(
      onTap: _openCreateGroup,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // آیکون گروه
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_add_rounded,
                color: theme.colorScheme.onPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // متن
            Expanded(
              child: Text(
                'ساخت گروه جدید',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            // فلش
            Icon(
              directionalForwardChevronIcon(context),
              size: 16,
              color: theme.hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateSecretChatTile(ThemeData theme) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isSecretMode = true;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // آیکون سکرت چت
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // متن
            const Expanded(
              child: Text(
                'گفتگوی محرمانه جدید',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(ThemeData theme, GroupUserItem user,
      {bool isLast = false}) {
    return InkWell(
      onTap: () => _openConversation(user, isSecret: _isSecretMode),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // آواتار ساده
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // نام و یوزرنیم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.username.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '@${user.username}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.hintColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          if (!isLast)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 72,
              endIndent: 16,
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }
}
