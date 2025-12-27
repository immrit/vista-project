import '../../../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    _testSupabaseConnection();
    _loadBlockedUsers();
  }

  Future<void> _testSupabaseConnection() async {
    try {
      final client = Supabase.instance.client;

      final auth = client.auth;

      final currentUser = auth.currentUser;

      // تست اتصال به دیتابیس
      try {
        await client.from('blocked_users').select('id').limit(1);

        // بررسی ساختار جدول
        try {
          final structureResponse =
              await client.from('blocked_users').select('*').limit(1);
          if (structureResponse.isNotEmpty) {
            final sample = structureResponse.first;
            logInfo('🏗️ ساختار جدول blocked_users:');
            sample.forEach((key, value) {
              logInfo('   $key: ${value.runtimeType} = $value');
            });
          }
        } catch (structureError) {
          logInfo('⚠️ خطا در بررسی ساختار جدول: $structureError');
        }
      } catch (dbError) {
        logInfo('❌ خطا در اتصال به جدول blocked_users: $dbError');

        // بررسی وجود جدول
        try {
          final tablesResponse = await client.rpc('get_tables');
          logInfo('📋 جداول موجود: $tablesResponse');
        } catch (tablesError) {
          logInfo('⚠️ خطا در دریافت لیست جداول: $tablesError');
        }

        // بررسی جدول profiles
        try {
          final profilesResponse = await client
              .from('profiles')
              .select('id, username, full_name')
              .limit(1);
          logInfo('✅ اتصال به جدول profiles موفق');
          logInfo('👥 تعداد پروفایل‌ها: ${profilesResponse.length}');
        } catch (profilesError) {
          logInfo('❌ خطا در اتصال به جدول profiles: $profilesError');
        }

        // تست کوئری اصلی
        if (currentUser != null) {
          try {
            logInfo('🧪 تست کوئری اصلی...');

            // تست کوئری جدید (بدون join)
            final blockedResponse = await client
                .from('blocked_users')
                .select('blocked_user_id, created_at')
                .eq('user_id', currentUser.id)
                .limit(1);
            print(
                '✅ کوئری blocked_users موفق: ${blockedResponse.length} نتیجه');

            if (blockedResponse.isNotEmpty) {
              final blockedUserId =
                  blockedResponse.first['blocked_user_id'] as String;
              logInfo('🆔 شناسه کاربر مسدود شده: $blockedUserId');

              // تست کوئری profiles
              final profileResponse = await client
                  .from('profiles')
                  .select('id, username, full_name')
                  .eq('id', blockedUserId)
                  .maybeSingle();

              if (profileResponse != null) {
                logInfo(
                    '✅ کوئری profiles موفق: ${profileResponse['username']}');
              } else {
                logInfo('⚠️ پروفایل برای کاربر $blockedUserId یافت نشد');
              }
            }
          } catch (mainQueryError) {
            logInfo('❌ خطا در کوئری اصلی: $mainQueryError');
          }
        }
      }
    } catch (e) {
      // Error testing Supabase connection
    }
  }

  Future<void> _loadBlockedUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception('کاربر وارد نشده است');
      }

      // ابتدا لیست کاربران مسدود شده را دریافت می‌کنیم
      final blockedResponse = await Supabase.instance.client
          .from('blocked_users')
          .select('blocked_user_id, created_at')
          .eq('user_id', currentUserId)
          .order('created_at', ascending: false);

      print(
          '📊 پاسخ دریافتی از جدول blocked_users: ${blockedResponse.length} رکورد');

      if (blockedResponse.isEmpty) {
        logInfo('✅ هیچ کاربر مسدود شده‌ای یافت نشد');
        setState(() {
          _blockedUsers = [];
          _filteredUsers = [];
          _isLoading = false;
        });
        return;
      }

      // استخراج شناسه‌های کاربران مسدود شده
      final blockedUserIds = blockedResponse
          .map((item) => item['blocked_user_id'] as String)
          .toList();

      logInfo('🆔 شناسه‌های کاربران مسدود شده: $blockedUserIds');

      // سپس اطلاعات پروفایل این کاربران را دریافت می‌کنیم
      final profilesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, username, full_name, avatar_url, is_verified')
          .inFilter('id', blockedUserIds);

      logInfo('👥 اطلاعات پروفایل‌ها: ${profilesResponse.length} رکورد');

      // ایجاد map برای دسترسی سریع به اطلاعات پروفایل
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesResponse) {
        profilesMap[profile['id'] as String] = profile;
      }

      final blockedUsers = <BlockedUserModel>[];
      for (final blockedItem in blockedResponse) {
        try {
          final blockedUserId = blockedItem['blocked_user_id'] as String;
          final profile = profilesMap[blockedUserId];

          if (profile == null) {
            logInfo('⚠️ پروفایل برای کاربر $blockedUserId یافت نشد');
            continue;
          }

          logInfo('🔍 پردازش کاربر: ${profile['username']}');

          final blockedUser = BlockedUserModel(
            id: profile['id'] as String,
            username: profile['username'] as String,
            fullName: profile['full_name'] as String? ?? 'کاربر ناشناس',
            avatarUrl: profile['avatar_url'] as String?,
            isVerified: profile['is_verified'] as bool? ?? false,
            blockedAt: DateTime.parse(blockedItem['created_at'] as String),
          );

          print(
              '✅ کاربر ایجاد شد: ${blockedUser.fullName} (@${blockedUser.username})');
          blockedUsers.add(blockedUser);
        } catch (parseError) {
          logInfo('⚠️ خطا در پردازش آیتم: $parseError');
          logInfo('⚠️ آیتم مشکل‌دار: $blockedItem');
          continue; // ادامه پردازش آیتم‌های بعدی
        }
      }

      logInfo('✅ تعداد کل کاربران پردازش شده: ${blockedUsers.length}');

      setState(() {
        _blockedUsers = blockedUsers;
        _filteredUsers = blockedUsers;
        _isLoading = false;
      });

      logInfo('🎉 بارگذاری با موفقیت تکمیل شد');
    } catch (e, stackTrace) {
      logInfo('💥 خطای کلی در بارگذاری: $e');
      logInfo('📚 Stack Trace: $stackTrace');

      // لاگ کردن جزئیات بیشتر خطا
      if (e.toString().contains('relation')) {
        logInfo('🔍 احتمالاً مشکل در ساختار جدول دیتابیس است');
      } else if (e.toString().contains('auth')) {
        logInfo('🔍 احتمالاً مشکل در احراز هویت است');
      } else if (e.toString().contains('network')) {
        logInfo('🔍 احتمالاً مشکل در اتصال شبکه است');
      }

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
                        child: Icon(
                          Icons.verified,
                          color: Colors.blue,
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
  final DateTime blockedAt;

  BlockedUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.isVerified,
    required this.blockedAt,
  });
}
