import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../security/logging_utility.dart';
import '../../../services/user_friendly_error_handler.dart';
import '../models/group_user_item.dart';
import '../providers/chat_providers.dart';
import '../services/group_service.dart';
import 'modern_chat_screen.dart';

/// صفحه ساخت گروه جدید - UI مینیمال و مدرن
class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _groupService = GroupService();
  final _selectedUserIds = <String>{};
  final Map<String, GroupUserItem> _selectedUsers = {};
  final _nameFocusNode = FocusNode();

  List<GroupUserItem> _interactionUsers = [];
  List<GroupUserItem> _searchResults = [];
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadInteractions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInteractions() async {
    setState(() => _isLoading = true);
    try {
      final users = await _groupService.getInteractionUsers();
      if (mounted) {
        setState(() {
          _interactionUsers = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
        return;
      }
      setState(() => _isSearching = true);
      final results = await _groupService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty && _selectedUserIds.isNotEmpty;

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('نام گروه الزامی است');
      return;
    }
    if (_selectedUserIds.isEmpty) {
      _showSnack('حداقل یک عضو انتخاب کنید');
      return;
    }
    if (_selectedUserIds.length > 19) {
      _showSnack('حداکثر ۲۰ عضو مجاز است');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isCreating = true);

    try {
      final conversationId = await _groupService.createGroup(
        name: name,
        memberIds: _selectedUserIds.toList(),
      );
      await ref.read(chatRepositoryProvider).refreshConversations();
      final info = await _groupService.fetchGroupInfo(conversationId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ModernChatScreen(
            args: ChatScreenArgs(
              conversationId: conversationId,
              otherUserId: '',
              otherUserName: info?['name'] as String? ?? name,
              otherUserAvatar: info?['image'] as String?,
              isGroup: true,
            ),
          ),
        ),
      );
    } catch (e) {
      logError('Group create failed', error: e);
      if (mounted) {
        _showSnack(_mapCreateError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  String _mapCreateError(Object error) {
    final msg = _extractErrorMessage(error);
    if (msg.contains('group_name_required')) {
      return 'نام گروه الزامی است';
    }
    if (msg.contains('at_least_one_member_required')) {
      return 'حداقل یک عضو انتخاب کنید';
    }
    if (msg.contains('max_members_exceeded')) {
      return 'حداکثر ۲۰ عضو مجاز است';
    }
    if (msg.contains('user_add_not_allowed')) {
      return 'یکی از کاربران اجازه اضافه شدن به گروه را نداده';
    }
    if (msg.contains('unauthorized')) {
      return 'ابتدا وارد حساب شوید';
    }
    if (msg.contains('create_group_conversation') ||
        msg.contains('PGRST202') ||
        msg.contains('function') && msg.contains('does not exist')) {
      return 'توابع گروه روی سوپابیس اعمال نشده‌اند';
    }
    if (error is PostgrestException) {
      return UserFriendlyErrorHandler.getFriendlyMessage(error,
          context: 'group_create');
    }
    return 'خطا در ساخت گروه';
  }

  String _extractErrorMessage(Object error) {
    if (error is PostgrestException) {
      final buffer = StringBuffer();
      buffer.write(error.message);
      if (error.details != null) buffer.write(' ${error.details}');
      if (error.hint != null) buffer.write(' ${error.hint}');
      if (error.code != null) buffer.write(' ${error.code}');
      return buffer.toString();
    }
    return error.toString();
  }

  void _toggleSelect(GroupUserItem user) {
    HapticFeedback.selectionClick();
    if (_selectedUserIds.contains(user.id)) {
      setState(() {
        _selectedUserIds.remove(user.id);
        _selectedUsers.remove(user.id);
      });
      return;
    }
    if (_selectedUserIds.length >= 19) {
      _showSnack('حداکثر ۲۰ عضو مجاز است');
      return;
    }
    setState(() {
      _selectedUserIds.add(user.id);
      _selectedUsers[user.id] = user;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final query = _searchController.text.trim();
    final list = query.isEmpty ? _interactionUsers : _searchResults;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.iconTheme.color,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'گروه جدید',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        actions: [
          // دکمه ایجاد در AppBar
          TextButton(
            onPressed: _isCreating || !_canCreate ? null : _createGroup,
            child: _isCreating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Text(
                    'ایجاد',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _canCreate
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // بخش نام گروه و اعضای انتخاب شده
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // فیلد نام گروه با آیکون
                Row(
                  children: [
                    // آیکون گروه
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.group_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // فیلد نام
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: 'نام گروه',
                          hintStyle: TextStyle(
                            fontSize: 17,
                            color: theme.hintColor,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                // اعضای انتخاب شده (chips افقی)
                if (_selectedUsers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final user = _selectedUsers.values.elementAt(index);
                        return _buildSelectedChip(theme, user);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // جستجو
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSearchField(theme, isDark),
          ),

          const SizedBox(height: 16),

          // هدر لیست
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  query.isEmpty ? 'پیشنهادی' : 'نتایج جستجو',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.hintColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedUserIds.length}/20',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // لیست کاربران
          Expanded(
            child: _isLoading || _isSearching
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 48,
                              color: theme.hintColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              query.isEmpty
                                  ? 'کاربری یافت نشد'
                                  : 'نتیجه‌ای یافت نشد',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final user = list[index];
                          final isSelected = _selectedUserIds.contains(user.id);
                          return _buildUserTile(theme, user, isSelected,
                              index == list.length - 1);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChip(ThemeData theme, GroupUserItem user) {
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // آواتار کوچک
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            backgroundImage:
                user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          // نام
          Text(
            user.displayName.length > 10
                ? '${user.displayName.substring(0, 10)}...'
                : user.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          // دکمه حذف
          GestureDetector(
            onTap: () => _toggleSelect(user),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme, bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
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

  Widget _buildUserTile(
      ThemeData theme, GroupUserItem user, bool isSelected, bool isLast) {
    return InkWell(
      onTap: () => _toggleSelect(user),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // آواتار
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
                            fontSize: 16,
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
                // چک‌باکس دایره‌ای
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.hintColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
              ],
            ),
          ),
          // Divider
          if (!isLast)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 70,
              endIndent: 16,
              color: theme.dividerColor.withOpacity(0.3),
            ),
        ],
      ),
    );
  }
}
