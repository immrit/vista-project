import '../../../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../widgets/verification_badge_icon.dart';
import '../../../../features/chat/services/user_moderation_service.dart';

import '../../../../provider/provider.dart';
import '../../../../features/chat/providers/chat_providers.dart';

class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  List<BlockedUserModel> _blockedUsers = [];
  List<BlockedUserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    logInfo('🚀 صفحه کاربران مسدود شده راه‌اندازی شد');
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final moderationService = UserModerationService();
      final rows = await moderationService.getBlockedUsers();
      final blockedUsers = rows
          .map((profile) {
            final id = (profile['id'] ?? profile['user_id'] ?? '').toString();
            final username = (profile['username'] ?? '').toString();
            final fullName = (profile['full_name'] ?? '').toString();
            return BlockedUserModel(
              id: id,
              username: username.isEmpty ? 'user' : username,
              fullName: fullName.isEmpty ? 'کاربر ناشناس' : fullName,
              avatarUrl: profile['avatar_url']?.toString(),
              isVerified: profile['is_verified'] == true,
              verificationType: profile['verification_type'],
              role: profile['role']?.toString(),
              blockedAt: DateTime.tryParse(
                    profile['blocked_at']?.toString() ?? '',
                  ) ??
                  DateTime.now(),
            );
          })
          .where((user) => user.id.isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _blockedUsers = blockedUsers;
        _filteredUsers = blockedUsers;
        _isLoading = false;
      });

      logInfo('Blocked users loaded from Go backend: ${blockedUsers.length}');
    } catch (e, stackTrace) {
      logError('Failed to load blocked users',
          error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = 'خطا در بارگذاری: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      logInfo('🔄 شروع رفع مسدودیت کاربر: $userId');

      final repo = ref.read(chatRepositoryProvider);
      logInfo('🔧 سرویس چت دریافت شد');

      await repo.unblockUser(userId);
      logInfo('✅ رفع مسدودیت در دیتابیس انجام شد');

      // حذف کاربر از لیست
      setState(() {
        _blockedUsers.removeWhere((user) => user.id == userId);
        _filteredUsers.removeWhere((user) => user.id == userId);
      });
      logInfo('🗑️ کاربر از لیست‌های محلی حذف شد');

      // بروزرسانی تعداد کاربران مسدود شده در تنظیمات
      ref.invalidate(blockedUsersCountProvider);
      logInfo('🔄 پروایدر تعداد کاربران مسدود شده بروزرسانی شد');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کاربر با موفقیت از مسدودیت خارج شد'),
            backgroundColor: Colors.green,
          ),
        );
        logInfo('✅ پیام موفقیت نمایش داده شد');
      }
    } catch (e, stackTrace) {
      logInfo('💥 خطا در رفع مسدودیت: $e');
      logInfo('📚 Stack Trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در رفع مسدودیت: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUnblockDialog(BlockedUserModel user) {
    print(
        '💬 نمایش دیالوگ رفع مسدودیت برای: ${user.fullName} (@${user.username})');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفع مسدودیت'),
        content: Text(
          'آیا می‌خواهید ${user.fullName} (@${user.username}) را از حالت مسدود خارج کنید؟',
        ),
        actions: [
          TextButton(
            onPressed: () {
              logInfo('❌ کاربر از رفع مسدودیت انصراف داد');
              Navigator.pop(context);
            },
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              logInfo('✅ کاربر رفع مسدودیت را تایید کرد');
              Navigator.pop(context);
              _unblockUser(user.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('رفع مسدودیت'),
          ),
        ],
      ),
    );
  }

  void _filterUsers(String query) {
    logInfo('🔍 جستجو با عبارت: "$query"');

    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _blockedUsers;
      });
      logInfo('✅ نمایش تمام کاربران (${_blockedUsers.length} کاربر)');
    } else {
      setState(() {
        _filteredUsers = _blockedUsers.where((user) {
          return user.fullName.toLowerCase().contains(query.toLowerCase()) ||
              user.username.toLowerCase().contains(query.toLowerCase());
        }).toList();
      });
      logInfo('🔍 نتایج جستجو: ${_filteredUsers.length} کاربر یافت شد');
    }
  }

  @override
  void dispose() {
    logInfo('🧹 صفحه کاربران مسدود شده در حال پاکسازی...');
    _searchController.dispose();
    super.dispose();
    logInfo('✅ صفحه کاربران مسدود شده پاکسازی شد');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('کاربران مسدود شده'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _buildBody(),
      floatingActionButton: _blockedUsers.isNotEmpty
          ? FloatingActionButton(
              onPressed: _loadBlockedUsers,
              backgroundColor: Colors.brown,
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    print(
        '🎨 ساخت UI - وضعیت: isLoading=$_isLoading, error=$_error, blockedUsers=${_blockedUsers.length}, filteredUsers=${_filteredUsers.length}');

    if (_isLoading) {
      logInfo('⏳ نمایش صفحه بارگذاری');
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      logInfo('❌ نمایش صفحه خطا: $_error');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'خطا در بارگذاری',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                logInfo('🔄 تلاش مجدد برای بارگذاری');
                _loadBlockedUsers();
              },
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    if (_blockedUsers.isEmpty) {
      logInfo('📭 نمایش صفحه خالی - هیچ کاربری مسدود نشده است');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ کاربری مسدود نشده است',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'کاربران مسدود شده در اینجا نمایش داده می‌شوند',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredUsers.isEmpty && _searchController.text.isNotEmpty) {
      print(
          '🔍 نمایش صفحه جستجوی بدون نتیجه برای: "${_searchController.text}"');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'نتیجه‌ای یافت نشد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'هیچ کاربری با عبارت "${_searchController.text}" یافت نشد',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    logInfo('📱 نمایش صفحه اصلی با ${_filteredUsers.length} کاربر');
    return Column(
      children: [
        // Header section with count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF404040) : const Color(0xFFE9ECEF),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.brown.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.block_outlined,
                  color: Colors.brown,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'کاربران مسدود شده',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${_blockedUsers.length} کاربر',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF404040) : const Color(0xFFE9ECEF),
                width: 1,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A3A3A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF505050) : const Color(0xFFE9ECEF),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'جستجو در کاربران مسدود شده...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        // Users list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBlockedUsers,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filteredUsers.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color:
                    isDark ? const Color(0xFF404040) : const Color(0xFFE9ECEF),
                indent: 20,
                endIndent: 20,
              ),
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return _buildBlockedUserItem(user);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockedUserItem(BlockedUserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    logInfo('🎴 ساخت آیتم کاربر: ${user.fullName} (@${user.username})');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: user.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 24,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: VerificationBadgeIcon(
                          isVerified: user.isVerified,
                          verificationType: user.verificationType,
                          role: user.role,
                          size: 18,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'مسدود شده در ${_formatDate(user.blockedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Action button
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => _showUnblockDialog(user),
              icon: Icon(
                Icons.lock_open,
                color: Colors.red,
                size: 20,
              ),
              tooltip: 'رفع مسدودیت',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    String result;
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        result = '${difference.inMinutes} دقیقه پیش';
      } else {
        result = '${difference.inHours} ساعت پیش';
      }
    } else if (difference.inDays == 1) {
      result = 'دیروز';
    } else if (difference.inDays < 7) {
      result = '${difference.inDays} روز پیش';
    } else {
      result = '${date.day}/${date.month}/${date.year}';
    }

    logInfo('📅 تاریخ مسدودیت: $date -> $result');
    return result;
  }
}

class BlockedUserModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final bool isVerified;
  final dynamic verificationType;
  final String? role;
  final DateTime blockedAt;

  BlockedUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.isVerified,
    this.verificationType,
    this.role,
    required this.blockedAt,
  });
}
