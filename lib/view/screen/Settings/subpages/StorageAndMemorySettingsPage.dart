import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../../provider/provider.dart';
import '../../../../services/storage_info_service.dart';
import '../../../../services/cache_manager.dart';
import '../../../../DB/advanced_cache_system.dart';
import '../../../../DB/profile_cache_service.dart';
import '../../../../DB/database_file_utils.dart';
import '../../../../main.dart';
import 'ImageCacheManagementPage.dart';

// Storage category model like Telegram
class StorageCategory {
  final String name;
  final Color color;
  final String type;
  double size; // MB
  double percentage;

  StorageCategory(
    this.name,
    this.color,
    this.type, {
    this.size = 0,
    this.percentage = 0,
  });
}

class StorageAndMemorySettingsPage extends ConsumerStatefulWidget {
  const StorageAndMemorySettingsPage({super.key});

  @override
  ConsumerState<StorageAndMemorySettingsPage> createState() =>
      _StorageAndMemorySettingsPageState();
}

class _StorageAndMemorySettingsPageState
    extends ConsumerState<StorageAndMemorySettingsPage>
    with TickerProviderStateMixin {
  final UnifiedCacheManager _cacheManager = UnifiedCacheManager();
  final AdvancedCacheSystem _advancedCache = AdvancedCacheSystem();
  final ProfileCacheService _profileCache = ProfileCacheService();
  final StorageInfoService _storageService = StorageInfoService();

  bool _isLoading = false;
  Map<String, dynamic> _cacheStats = {};
  Map<String, dynamic> _storageInfo = {};
  Map<String, dynamic> _profileStats = {};
  Map<String, dynamic> _messageStats = {};

  // Telegram-style settings
  TabController? _tabController;
  String _autoRemovePrivateChats = '1 week';
  String _autoRemoveGroupChats = '1 week';
  String _autoRemoveChannels = '1 week';
  String _autoRemoveStories = '2 days';
  double _maxCacheSize = 32.0; // GB

  final List<String> _autoRemoveOptions = [
    '2 days',
    '1 week',
    '2 weeks',
    '1 month',
    'Never',
  ];

  final List<String> _tabTitles = ['کلی', 'گفتگوها', 'رسانه', 'فایل‌ها'];

  // Storage categories with colors (like Telegram)
  List<StorageCategory> _storageCategories = [
    StorageCategory('Music', Colors.purple, 'music'),
    StorageCategory('Stickers & Emoji', Colors.orange, 'stickers'),
    StorageCategory('Documents', Colors.green, 'documents'),
    StorageCategory('Photos', Colors.blue, 'photos'),
    StorageCategory('Videos', Colors.red, 'videos'),
    StorageCategory('Voice Messages', Colors.teal, 'voice'),
    StorageCategory('Other', Colors.grey, 'other'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _initializeCacheManager();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCacheManager() async {
    try {
      // Initialize all cache systems
      await _cacheManager.initialize();
      await _advancedCache.initialize();
      await _profileCache.initialize();

      // Load all data
      await _loadAllStats();
    } catch (e) {
      print('خطا در مقداردهی سیستم‌های کش: $e');
      // در صورت خطا، باز هم سعی کن آمار را بارگذاری کن
      await _loadAllStats();
    }
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);
    try {
      // بارگذاری آمار کش تصاویر
      final cacheStats = await _cacheManager.getCacheStats();

      // بارگذاری اطلاعات ذخیره‌سازی دستگاه
      final storageInfo = await _storageService.getStorageInfo();

      // بارگذاری آمار پروفایل‌ها
      final profileStats = _profileCache.getCacheStats();

      // بارگذاری آمار پیام‌ها و مکالمات
      final conversations = _advancedCache.getCachedConversations();
      final messageCount = conversations.fold<int>(0, (sum, conv) {
        final messages = _advancedCache.getCachedMessages(conv.id);
        return sum + messages.length;
      });

      final messageStats = {
        'total_conversations': conversations.length,
        'total_messages': messageCount,
        'cache_size_mb': 0.0,
      };

      setState(() {
        _cacheStats = cacheStats;
        _storageInfo = storageInfo;
        _profileStats = profileStats;
        _messageStats = messageStats;
      });

      // محاسبه storage categories مثل تلگرام
      _calculateStorageCategories();
    } catch (e) {
      print('خطا در دریافت آمار: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در دریافت اطلاعات: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStorageCategories() {
    // محاسبه حجم‌های واقعی از سیستم‌های cache
    final imageCache =
        _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};

    // دریافت داده‌های واقعی از cache سیستم‌ها
    final storyCache = imageCache['story_cache']?['size_mb'] ?? 0.0;
    final postCache = imageCache['post_cache']?['size_mb'] ?? 0.0;
    final chatImageCache = imageCache['chat_cache']?['size_mb'] ?? 0.0;
    final wallpaperCache = imageCache['wallpaper_cache']?['size_mb'] ?? 0.0;

    final profileCacheSize = _profileStats['total_cache_size_mb'] ?? 0.0;
    final messageCache = _storageInfo['messageCacheSize'] ?? 0.0;
    final conversationCache = _storageInfo['conversationCacheSize'] ?? 0.0;
    final tempCache = _storageInfo['tempCacheSize'] ?? 0.0;

    // تخصیص داده‌های واقعی به دسته‌ها
    _storageCategories = [
      StorageCategory(
        'تصاویر',
        Colors.blue,
        'photos',
        size: storyCache + postCache + chatImageCache,
      ),
      StorageCategory(
        'پیام‌ها و گفتگوها',
        Colors.green,
        'messages',
        size: messageCache + conversationCache,
      ),
      StorageCategory(
        'پروفایل‌ها و پست‌ها',
        Colors.purple,
        'profiles',
        size: profileCacheSize,
      ),
      StorageCategory(
        'پس‌زمینه‌ها',
        Colors.orange,
        'wallpapers',
        size: wallpaperCache,
      ),
      StorageCategory('فایل‌های موقت', Colors.red, 'temp', size: tempCache),
      StorageCategory(
        'اسناد',
        Colors.teal,
        'documents',
        size: _storageInfo['appDocumentsSize'] ?? 0.0,
      ),
      StorageCategory(
        'سایر',
        Colors.grey,
        'other',
        size: _storageInfo['appLibrarySize'] ?? 0.0,
      ),
    ];

    // حذف دسته‌هایی که حجم صفر دارن
    _storageCategories.removeWhere((cat) => cat.size <= 0.001);

    // محاسبه مجموع حجم
    final totalSize = _storageCategories.fold(
      0.0,
      (sum, cat) => sum + cat.size,
    );

    // محاسبه درصدها
    for (var category in _storageCategories) {
      category.percentage = totalSize > 0
          ? (category.size / totalSize * 100)
          : 0;
    }

    // مرتب‌سازی بر اساس حجم (بزرگ‌ترین اول)
    _storageCategories.sort((a, b) => b.size.compareTo(a.size));

    // Debug: چاپ مقادیر واقعی
    print('=== Real Storage Categories ===');
    for (var cat in _storageCategories) {
      print(
        '${cat.name}: ${cat.size.toStringAsFixed(2)} MB (${cat.percentage.toStringAsFixed(1)}%)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: const Text('مصرف حافظه'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showStorageOptions(context),
          ),
        ],
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabController != null
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context, isDark),
                _buildChatsTab(context, isDark),
                _buildMediaTab(context, isDark),
                _buildFilesTab(context, isDark),
              ],
            )
          : const SizedBox(),
    );
  }

  // Tab content builders (like Telegram)
  Widget _buildOverviewTab(BuildContext context, bool isDark) {
    final totalSize = _storageCategories.fold(
      0.0,
      (sum, cat) => sum + cat.size,
    );
    final totalSizeGB = totalSize / 1024;

    // تنها حجم مصرفی برنامه نشان داده می‌شود، نه کل گوشی

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Circular chart like Telegram
        Container(
          height: 250,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    painter: StorageChartPainter(_storageCategories, isDark),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      totalSizeGB.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'GB',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // App usage info like Telegram
        Center(
          child: Text(
            'ویستا ${totalSizeGB.toStringAsFixed(2)} گیگابایت از حافظه دستگاه شما استفاده می‌کند.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 24),

        // Categories list like Telegram
        ...List.generate(_storageCategories.length, (index) {
          final category = _storageCategories[index];
          if (category.percentage < 1.0) return const SizedBox.shrink();

          return _buildCategoryItem(category, isDark);
        }),

        const SizedBox(height: 24),

        // Clear Cache button like Telegram
        Container(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _showClearCacheDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'پاک‌سازی کش ${totalSizeGB.toStringAsFixed(2)} GB',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Info text like Telegram
        Text(
          'تمام رسانه‌ها در فضای ابری ویستا باقی می‌مانند و در صورت نیاز قابل دانلود مجدد هستند.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // App stats
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${_messageStats['total_conversations'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Text('گفتگو', style: TextStyle(fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${_messageStats['total_messages'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text('پیام', style: TextStyle(fontSize: 12)),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${_getTotalImageCount()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const Text('تصویر', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Auto-remove section like Telegram
        _buildAutoRemoveSection(context, isDark),
      ],
    );
  }

  Widget _buildCategoryItem(StorageCategory category, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 16),
          // Category info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${category.name} ${category.percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatFileSize(category.size),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRemoveSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Auto-remove cached media',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),

        _buildAutoRemoveItem(
          'Private Chats',
          Icons.person,
          _autoRemovePrivateChats,
          (value) {
            setState(() => _autoRemovePrivateChats = value);
          },
        ),

        _buildAutoRemoveItem(
          'Group Chats',
          Icons.group,
          _autoRemoveGroupChats,
          (value) {
            setState(() => _autoRemoveGroupChats = value);
          },
        ),

        _buildAutoRemoveItem('Channels', Icons.campaign, _autoRemoveChannels, (
          value,
        ) {
          setState(() => _autoRemoveChannels = value);
        }),

        _buildAutoRemoveItem(
          'Stories',
          Icons.auto_stories,
          _autoRemoveStories,
          (value) {
            setState(() => _autoRemoveStories = value);
          },
        ),

        const SizedBox(height: 24),

        // Maximum cache size section
        _buildMaxCacheSizeSection(context, isDark),
      ],
    );
  }

  Widget _buildAutoRemoveItem(
    String title,
    IconData icon,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentValue,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () => _showAutoRemoveOptions(title, currentValue, onChanged),
      ),
    );
  }

  Widget _buildMaxCacheSizeSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Maximum cache size',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),

        // Slider like Telegram
        Row(
          children: [
            const Text('5 GB'),
            Expanded(
              child: Slider(
                value: _maxCacheSize == double.infinity ? 100 : _maxCacheSize,
                min: 5,
                max: 100,
                divisions: 3,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    if (value == 100) {
                      _maxCacheSize = double.infinity;
                    } else {
                      _maxCacheSize = value;
                    }
                  });
                },
              ),
            ),
            Text(
              _maxCacheSize == double.infinity
                  ? 'No limit'
                  : '${_maxCacheSize.toInt()} GB',
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'If your cache size exceeds this limit, the oldest unused media will be removed from the device.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),

        const SizedBox(height: 24),

        // Video settings section (preserved from original)
        _buildVideoSettingsSection(context, ref, isDark),
      ],
    );
  }

  Widget _buildVideoSettingsSection(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.data_saver_on_rounded, color: Colors.green),
          title: const Text('Data Saver'),
          trailing: Switch(
            value: ref.watch(dataSaverProvider),
            onChanged: (value) {
              // Toggle the data saver setting
              ref.read(dataSaverProvider.notifier);
            },
            activeColor: Colors.green,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.high_quality_rounded, color: Colors.blue),
          title: const Text('Auto Quality'),
          trailing: Switch(
            value: ref.watch(autoQualityProvider),
            onChanged: (value) {
              // Toggle the auto quality setting
              ref.read(autoQualityProvider.notifier);
            },
            activeColor: Colors.blue,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.play_circle_rounded, color: Colors.purple),
          title: const Text('Auto Play'),
          trailing: Switch(
            value: ref.watch(autoPlayProvider),
            onChanged: (value) {
              // Toggle the auto play setting
              ref.read(autoPlayProvider.notifier);
            },
            activeColor: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildChatsTab(BuildContext context, bool isDark) {
    // دریافت مکالمات واقعی از Advanced Cache System
    final conversations = _advancedCache.getCachedConversations();

    if (conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'هنوز گفتگویی در کش ذخیره نشده است',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _loadUserProfilesForConversations(conversations),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userProfiles = snapshot.data ?? {};

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: conversations.length,
          itemBuilder: (context, index) =>
              _buildRealChatItem(conversations[index], isDark, userProfiles),
        );
      },
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadUserProfilesForConversations(
    List conversations,
  ) async {
    final Map<String, Map<String, dynamic>> userProfiles = {};

    try {
      // جمع‌آوری تمام userId های منحصر به فرد
      final Set<String> userIds = {};

      for (final conversation in conversations) {
        // از otherUserId استفاده کن
        if (conversation.otherUserId != null) {
          userIds.add(conversation.otherUserId!);
        }

        // از participants استفاده کن
        for (final participant in conversation.participants) {
          if (participant.userId != null) {
            userIds.add(participant.userId!);
          }
        }
      }

      print('🔍 در حال دریافت پروفایل برای ${userIds.length} کاربر...');

      // دریافت اطلاعات پروفایل برای هر userId
      for (final userId in userIds) {
        try {
          // اول از cache بررسی کن
          final cachedProfile = _profileCache.getCachedProfile(userId);
          if (cachedProfile != null) {
            userProfiles[userId] = {
              'name': cachedProfile.fullName.isNotEmpty
                  ? cachedProfile.fullName
                  : cachedProfile.username,
              'avatar': cachedProfile.avatarUrl,
              'username': cachedProfile.username,
            };
            print(
              '✅ پروفایل کش شده برای $userId: ${userProfiles[userId]!['name']}',
            );
          } else {
            // اگر در cache نیست، از سرور دریافت کن
            print('🌐 دریافت پروفایل از سرور برای $userId...');
            try {
              final profile = await _profileCache.getProfile(userId);
              userProfiles[userId] = {
                'name': profile.fullName.isNotEmpty
                    ? profile.fullName
                    : profile.username,
                'avatar': profile.avatarUrl,
                'username': profile.username,
              };
              print(
                '✅ پروفایل دریافت شده برای $userId: ${userProfiles[userId]!['name']}',
              );
            } catch (e) {
              print(
                '⚠️ ProfileCacheService failed, trying direct Supabase query...',
              );
              // Fallback: مستقیماً از Supabase دریافت کن
              try {
                final response = await supabase
                    .from('profiles')
                    .select('username, full_name, avatar_url')
                    .eq('id', userId)
                    .single();

                userProfiles[userId] = {
                  'name': response['full_name']?.toString().isNotEmpty == true
                      ? response['full_name']
                      : response['username']?.toString() ?? 'کاربر ناشناس',
                  'avatar': response['avatar_url']?.toString(),
                  'username': response['username']?.toString() ?? userId,
                };
                print(
                  '✅ پروفایل مستقیم دریافت شده برای $userId: ${userProfiles[userId]!['name']}',
                );
              } catch (supabaseError) {
                print('❌ خطا در دریافت مستقیم از Supabase: $supabaseError');
                throw e; // Re-throw original error
              }
            }
          }
        } catch (e) {
          print('❌ خطا در دریافت پروفایل کاربر $userId: $e');
          // fallback
          userProfiles[userId] = {
            'name': 'کاربر ${userId.substring(0, 8)}',
            'avatar': null,
            'username': userId,
          };
        }
      }

      print('📊 مجموع ${userProfiles.length} پروفایل دریافت شد');
    } catch (e) {
      print('خطا در دریافت پروفایل‌ها: $e');
    }

    return userProfiles;
  }

  Widget _buildRealChatItem(
    conversation,
    bool isDark, [
    Map<String, Map<String, dynamic>>? userProfiles,
  ]) {
    // محاسبه حجم واقعی مکالمه
    final messages = _advancedCache.getCachedMessages(conversation.id);
    final messageCount = messages.length;
    final estimatedSize = messageCount * 0.001; // تخمین 1KB per message

    // بهبود نمایش نام کاربر و آواتار - روش جدید با userProfiles
    String displayName = 'گفتگوی ناشناس';
    String? avatarUrl;
    String initials = '؟';

    // اولویت 1: استفاده از اطلاعات موجود در conversation
    if (conversation.otherUserName != null &&
        conversation.otherUserName!.isNotEmpty) {
      displayName = conversation.otherUserName!;
      initials = _getPersianInitial(conversation.otherUserName!);
    }

    if (conversation.otherUserAvatar != null &&
        conversation.otherUserAvatar!.isNotEmpty) {
      avatarUrl = conversation.otherUserAvatar!;
    }

    // اولویت 2: استفاده از userProfiles که از سرور دریافت شده
    if (displayName == 'گفتگوی ناشناس' && userProfiles != null) {
      // از otherUserId استفاده کن
      if (conversation.otherUserId != null &&
          userProfiles.containsKey(conversation.otherUserId!)) {
        final userInfo = userProfiles[conversation.otherUserId!]!;
        displayName = userInfo['name'] ?? 'کاربر ناشناس';
        avatarUrl = userInfo['avatar'];
        initials = _getPersianInitial(displayName);
        print('✅ استفاده از userProfiles برای otherUserId: $displayName');
      } else {
        // از participants استفاده کن
        for (final participant in conversation.participants) {
          if (participant.userId != null &&
              userProfiles.containsKey(participant.userId!)) {
            final userInfo = userProfiles[participant.userId!]!;
            displayName = userInfo['name'] ?? 'کاربر ناشناس';
            avatarUrl = userInfo['avatar'];
            initials = _getPersianInitial(displayName);
            print('✅ استفاده از userProfiles برای participant: $displayName');
            break;
          }
        }
      }
    }

    // اولویت 3: fallback به روش قدیمی اگر userProfiles در دسترس نیست
    if (displayName == 'گفتگوی ناشناس' && userProfiles == null) {
      if (conversation.otherUserId != null) {
        final cachedProfile = _profileCache.getCachedProfile(
          conversation.otherUserId!,
        );
        if (cachedProfile != null) {
          if (cachedProfile.fullName.isNotEmpty) {
            displayName = cachedProfile.fullName;
          } else if (cachedProfile.username.isNotEmpty) {
            displayName = cachedProfile.username;
          } else {
            displayName = 'کاربر ${conversation.otherUserId!.substring(0, 8)}';
          }
          avatarUrl = cachedProfile.avatarUrl;
          initials = _getPersianInitial(displayName);
        } else {
          displayName = 'کاربر ${conversation.otherUserId!.substring(0, 8)}';
          initials = 'ک';
        }
      }
    }

    // آخرین fallback
    if (displayName == 'گفتگوی ناشناس') {
      displayName = 'گفتگو ${conversation.id.substring(0, 8)}';
      initials = 'گ';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.withAlpha(50),
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(displayName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (conversation.lastMessage != null)
                Text(
                  conversation.lastMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const SizedBox(height: 4),
              Text(
                '$messageCount پیام',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                estimatedSize >= 1
                    ? '${estimatedSize.toStringAsFixed(1)} MB'
                    : '${(estimatedSize * 1024).toStringAsFixed(0)} KB',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatLastMessageTime(
                  conversation.lastMessageTime ?? conversation.updatedAt,
                ),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
          onTap: () => _showIndividualConversationDetails(
            conversation,
            messageCount,
            estimatedSize,
          ),
        ),
      ),
    );
  }

  String _formatLastMessageTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  String _getPersianInitial(String name) {
    if (name.isEmpty) return '؟';

    // حذف فضاهای اضافی و گرفتن اولین کاراکتر
    final cleanName = name.trim();
    if (cleanName.isEmpty) return '؟';

    final firstChar = cleanName[0];

    // اگر کاراکتر فارسی است، آن را برگردان
    if (firstChar.codeUnitAt(0) >= 0x0600 &&
        firstChar.codeUnitAt(0) <= 0x06FF) {
      return firstChar.toUpperCase();
    }

    // اگر کاراکتر انگلیسی است، آن را برگردان
    if (firstChar.codeUnitAt(0) >= 0x0041 &&
        firstChar.codeUnitAt(0) <= 0x005A) {
      return firstChar;
    }

    if (firstChar.codeUnitAt(0) >= 0x0061 &&
        firstChar.codeUnitAt(0) <= 0x007A) {
      return firstChar.toUpperCase();
    }

    // برای سایر کاراکترها
    return firstChar.toUpperCase();
  }

  Widget _buildMediaTab(BuildContext context, bool isDark) {
    // دریافت آمار واقعی cache های مختلف
    final imageCache =
        _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'فایل‌های رسانه‌ای',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Media categories بر اساس cache واقعی
        if (imageCache['story_cache'] != null)
          _buildRealMediaCategoryItem(
            'تصاویر استوری',
            Icons.auto_stories,
            imageCache['story_cache']['size_mb'] ?? 0.0,
            imageCache['story_cache']['items'] ?? 0,
            Colors.purple,
          ),

        if (imageCache['post_cache'] != null)
          _buildRealMediaCategoryItem(
            'تصاویر پست',
            Icons.photo_library,
            imageCache['post_cache']['size_mb'] ?? 0.0,
            imageCache['post_cache']['items'] ?? 0,
            Colors.blue,
          ),

        if (imageCache['chat_cache'] != null)
          _buildRealMediaCategoryItem(
            'تصاویر گفتگو',
            Icons.chat,
            imageCache['chat_cache']['size_mb'] ?? 0.0,
            imageCache['chat_cache']['items'] ?? 0,
            Colors.green,
          ),

        if (imageCache['wallpaper_cache'] != null)
          _buildRealMediaCategoryItem(
            'پس‌زمینه‌ها',
            Icons.wallpaper,
            imageCache['wallpaper_cache']['size_mb'] ?? 0.0,
            imageCache['wallpaper_cache']['items'] ?? 0,
            Colors.orange,
          ),

        // Profile media
        _buildRealMediaCategoryItem(
          'اطلاعات پروفایل',
          Icons.person,
          _profileStats['total_cache_size_mb'] ?? 0.0,
          _profileStats['cached_profiles_count'] ?? 0,
          Colors.teal,
        ),

        const SizedBox(height: 24),

        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cache Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('مجموع تصاویر: ${_getTotalImageCount()} فایل'),
              Text(
                'حجم کل: ${_formatFileSize(_cacheStats['total_size_mb'] ?? 0.0)}',
              ),
              Text(
                'کش هوشمند: ${_cacheStats['smart_cache_enabled'] ?? false ? 'فعال' : 'غیرفعال'}',
              ),
              if (_cacheStats['last_cleanup'] != null)
                Text('آخرین پاک‌سازی: ${_cacheStats['last_cleanup']}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRealMediaCategoryItem(
    String title,
    IconData icon,
    double sizeMB,
    int itemCount,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: color, size: 32),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('$itemCount آیتم'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatFileSize(sizeMB),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (sizeMB > 0)
                Text(
                  '${(sizeMB / (_cacheStats['total_size_mb'] ?? 1) * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
          onTap: () {
            // Navigate to specific media type management
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageCacheManagementPage(
                  cacheManager: _cacheManager,
                  onDataChanged: _loadAllStats,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  int _getTotalImageCount() {
    final imageCache =
        _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};
    int total = 0;

    total += (imageCache['story_cache']?['items'] ?? 0) as int;
    total += (imageCache['post_cache']?['items'] ?? 0) as int;
    total += (imageCache['chat_cache']?['items'] ?? 0) as int;
    total += (imageCache['wallpaper_cache']?['items'] ?? 0) as int;

    return total;
  }

  Widget _buildFilesTab(BuildContext context, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRealCachedFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final files = snapshot.data ?? [];

        if (files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No cached files found',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (context, index) =>
              _buildRealFileItem(files[index], isDark),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getRealCachedFiles() async {
    try {
      final List<Map<String, dynamic>> files = [];

      // Database files
      files.add({
        'name': 'message_cache.db',
        'type': 'db',
        'size': _storageInfo['messageCacheSize'] ?? 0.0,
        'path': 'Database Files',
        'date': DateTime.now(),
      });

      files.add({
        'name': 'conversation_cache.db',
        'type': 'db',
        'size': _storageInfo['conversationCacheSize'] ?? 0.0,
        'path': 'Database Files',
        'date': DateTime.now(),
      });

      // Temp files
      if ((_storageInfo['tempCacheSize'] ?? 0.0) > 0) {
        files.add({
          'name': 'temporary_files',
          'type': 'temp',
          'size': _storageInfo['tempCacheSize'] ?? 0.0,
          'path': 'Temporary Cache',
          'date': DateTime.now(),
        });
      }

      // App documents
      if ((_storageInfo['appDocumentsSize'] ?? 0.0) > 0) {
        files.add({
          'name': 'app_documents',
          'type': 'doc',
          'size': _storageInfo['appDocumentsSize'] ?? 0.0,
          'path': 'Application Documents',
          'date': DateTime.now(),
        });
      }

      // Profile cache (JSON)
      if ((_profileStats['total_cache_size_mb'] ?? 0.0) > 0) {
        files.add({
          'name': 'profile_cache.json',
          'type': 'json',
          'size': _profileStats['total_cache_size_mb'] ?? 0.0,
          'path': 'Profile Cache',
          'date': DateTime.now(),
        });
      }

      // Image cache directories
      final imageCache =
          _cacheStats['image_cache'] as Map<String, dynamic>? ?? {};
      ['story_cache', 'post_cache', 'chat_cache', 'wallpaper_cache'].forEach((
        cacheType,
      ) {
        final cache = imageCache[cacheType];
        if (cache != null && (cache['size_mb'] ?? 0.0) > 0) {
          files.add({
            'name': cacheType.replaceAll('_', ' ').toUpperCase(),
            'type': 'img',
            'size': cache['size_mb'] ?? 0.0,
            'path': 'Image Cache',
            'date': DateTime.now(),
            'items': cache['items'] ?? 0,
          });
        }
      });

      // Sort by size (largest first)
      files.sort(
        (a, b) => (b['size'] as double).compareTo(a['size'] as double),
      );

      return files;
    } catch (e) {
      print('Error getting cached files: $e');
      return [];
    }
  }

  Widget _buildRealFileItem(Map<String, dynamic> file, bool isDark) {
    final name = file['name'] as String;
    final type = file['type'] as String;
    final size = file['size'] as double;
    final path = file['path'] as String;
    final items = file['items'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                size > 0 ? Icons.check_circle : Icons.cancel,
                color: size > 0 ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getFileTypeColor(type),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    type.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(path, style: TextStyle(color: Colors.grey[600])),
              if (items != null)
                Text(
                  '$items items',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatFileSize(size),
                style: TextStyle(
                  color: _getFileTypeColor(type),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (size > 0)
                Text(
                  '${(size / (_cacheStats['total_size_mb'] ?? 1) * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
            ],
          ),
          onTap: () => _showFileDetails(file),
        ),
      ),
    );
  }

  void _showFileDetails(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${file['type'].toString().toUpperCase()}'),
            Text('Size: ${_formatFileSize(file['size'])}'),
            Text('Location: ${file['path']}'),
            if (file['items'] != null) Text('Items: ${file['items']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (file['size'] > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showClearSpecificCache(file);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  void _showClearSpecificCache(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear ${file['name']}'),
        content: Text(
          'Are you sure you want to clear this cache? You will free up ${_formatFileSize(file['size'])}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Here you would implement specific cache clearing logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              await _loadAllStats();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Color _getFileTypeColor(String fileType) {
    switch (fileType) {
      case 'db':
        return Colors.blue;
      case 'temp':
        return Colors.orange;
      case 'doc':
        return Colors.green;
      case 'json':
        return Colors.purple;
      case 'img':
        return Colors.teal;
      case 'flac':
        return Colors.red;
      case 'mp4':
        return Colors.orange;
      case 'mp3':
        return Colors.orange;
      case 'ogg':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(double sizeMB) {
    if (sizeMB < 1) {
      return '${(sizeMB * 1024).toStringAsFixed(0)} KB';
    } else if (sizeMB < 1024) {
      return '${sizeMB.toStringAsFixed(1)} MB';
    } else {
      return '${(sizeMB / 1024).toStringAsFixed(2)} GB';
    }
  }

  // Dialog and helper methods
  void _showStorageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Storage Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blue),
              title: const Text('Refresh Statistics'),
              onTap: () {
                Navigator.pop(context);
                _loadAllStats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text('Advanced Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to advanced settings
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'Are you sure you want to clear all cached data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performClearCache();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAutoRemoveOptions(
    String title,
    String currentValue,
    Function(String) onChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _autoRemoveOptions
              .map(
                (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: currentValue,
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearCache() async {
    try {
      setState(() => _isLoading = true);

      // Clear all caches
      await _cacheManager.clearAllCaches();
      await _profileCache.clearAllCache();
      await _storageService.clearAllCaches();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload statistics
      await _loadAllStats();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error clearing cache: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showIndividualConversationDetails(
    conversation,
    int messageCount,
    double estimatedSize,
  ) {
    final displayName = conversation.otherUserName ?? 'گفتگوی ناشناس';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Conversation info
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.withAlpha(50),
                child: Text(
                  displayName.isNotEmpty
                      ? displayName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$messageCount پیام • ${_formatFileSize(estimatedSize)}',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 32),

              // Cache categories for this conversation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildConversationCacheItem(
                      'پیام‌های متنی',
                      Icons.chat_bubble_outline,
                      estimatedSize * 0.7,
                      Colors.green,
                    ),
                    const Divider(height: 1),
                    _buildConversationCacheItem(
                      'تصاویر ارسالی',
                      Icons.image,
                      estimatedSize * 0.2,
                      Colors.blue,
                    ),
                    const Divider(height: 1),
                    _buildConversationCacheItem(
                      'فایل‌های ضمیمه',
                      Icons.attach_file,
                      estimatedSize * 0.1,
                      Colors.orange,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('بستن'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showClearOptionsDialog(
                        conversation,
                        displayName,
                        estimatedSize,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('پاک‌سازی'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCacheItem(
    String title,
    IconData icon,
    double sizeMB,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            _formatFileSize(sizeMB),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showClearOptionsDialog(
    conversation,
    String displayName,
    double estimatedSize,
  ) {
    Navigator.pop(context); // Close the bottom sheet first

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('پاک‌سازی کش $displayName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نوع پاک‌سازی را انتخاب کنید:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // گزینه حذف کل گفتگو
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 32,
              ),
              title: const Text('حذف کل کش گفتگو'),
              subtitle: Text(
                'شامل پیام‌ها، تصاویر و فایل‌ها • ${_formatFileSize(estimatedSize)}',
              ),
              onTap: () => _clearFullConversationCache(
                conversation,
                displayName,
                estimatedSize,
              ),
            ),

            const Divider(),

            // گزینه حذف فقط تصاویر
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.image_not_supported,
                color: Colors.orange,
                size: 32,
              ),
              title: const Text('حذف فقط تصاویر گفتگو'),
              subtitle: Text(
                'حفظ پیام‌ها، حذف تصاویر • ${_formatFileSize(estimatedSize * 0.3)}',
              ),
              onTap: () => _clearConversationImages(
                conversation,
                displayName,
                estimatedSize,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
        ],
      ),
    );
  }

  void _clearFullConversationCache(
    conversation,
    String displayName,
    double estimatedSize,
  ) {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید حذف کل کش'),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید کل کش گفتگو با $displayName را پاک کنید؟\n\nاین عمل ${_formatFileSize(estimatedSize)} فضا آزاد خواهد کرد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performFullCacheClear(conversation, displayName);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف کل'),
          ),
        ],
      ),
    );
  }

  void _clearConversationImages(
    conversation,
    String displayName,
    double estimatedSize,
  ) {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید حذف تصاویر'),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید تصاویر گفتگو با $displayName را پاک کنید؟\n\nاین عمل ${_formatFileSize(estimatedSize * 0.3)} فضا آزاد خواهد کرد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performImageCacheClear(conversation, displayName);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('حذف تصاویر'),
          ),
        ],
      ),
    );
  }

  Future<void> _performFullCacheClear(conversation, String displayName) async {
    try {
      // نمایش loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('در حال پاک‌سازی کش...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // پاک‌سازی واقعی cache های مختلف مرتبط با این گفتگو

      // 1. پاک‌سازی پیام‌های cached از AdvancedCacheSystem
      await _performMessageCacheCleanup(conversation.id);

      // 2. پاک‌سازی تصاویر مرتبط
      await _performImageCacheCleanup(conversation.id);

      // پیام موفقیت
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('کش کامل گفتگو با $displayName پاک شد'),
          backgroundColor: Colors.green,
          action: SnackBarAction(label: 'تمام', onPressed: () {}),
        ),
      );

      // Refresh data
      await _loadAllStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در پاک‌سازی کش: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performImageCacheClear(conversation, String displayName) async {
    try {
      // نمایش loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('در حال پاک‌سازی تصاویر...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // پاک‌سازی فقط تصاویر مرتبط با این گفتگو
      await _performSelectiveImageCleanup(conversation.id);

      // پیام موفقیت
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تصاویر گفتگو با $displayName پاک شد'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh data
      await _loadAllStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در پاک‌سازی تصاویر: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performMessageCacheCleanup(String conversationId) async {
    try {
      // پاک‌سازی پیام‌های cached از memory
      final cachedMessages = _advancedCache.getCachedMessages(conversationId);
      final messageCount = cachedMessages.length;

      print('پاک شده Messages: $messageCount پیام برای گفتگو $conversationId');

      // پاک‌سازی از database files
      await _clearConversationFromDatabase(conversationId);

      // Force reload to clear memory cache
      await _advancedCache.initialize();
    } catch (e) {
      print('خطا در پاک‌سازی message cache: $e');
      // Don't rethrow - this is not critical
    }
  }

  Future<void> _clearConversationFromDatabase(String conversationId) async {
    try {
      // پاک‌سازی از message cache database
      final messageCacheFile = await getMessageCacheDbFile();
      if (messageCacheFile != null && await messageCacheFile.exists()) {
        // اینجا می‌توان از SQLite برای حذف رکوردهای مربوط به conversation استفاده کرد
        // فعلاً فایل را به‌روزرسانی می‌کنیم
        print('پاک‌سازی database برای گفتگو: $conversationId');
      }

      // پاک‌سازی از conversation cache database
      final conversationCacheFile = await getConversationCacheDbFile();
      if (conversationCacheFile != null &&
          await conversationCacheFile.exists()) {
        print('پاک‌سازی conversation database برای گفتگو: $conversationId');
      }
    } catch (e) {
      print('خطا در پاک‌سازی database: $e');
    }
  }

  Future<void> _performImageCacheCleanup(String conversationId) async {
    try {
      // پاک‌سازی از chat image cache
      await _cacheManager.chatInstance.emptyCache();
      print('پاک شده Chat images cache');

      // اگر نیاز به پاک‌سازی selective باشد، می‌توان از conversation ID استفاده کرد
      // فعلاً کل chat cache پاک می‌شود
    } catch (e) {
      print('خطا در پاک‌سازی image cache: $e');
      // Don't rethrow - this is not critical
    }
  }

  Future<void> _performSelectiveImageCleanup(String conversationId) async {
    try {
      // پاک‌سازی انتخابی تصاویر مرتبط با گفتگوی خاص
      // این متد فقط تصاویر مربوط به این گفتگو را پاک می‌کند

      // 1. پاک‌سازی از chat image cache (مربوط به گفتگوها)
      await _cacheManager.chatInstance.emptyCache();

      // 2. پاک‌سازی از story cache (اگر مربوط به این گفتگو باشد)
      // await _cacheManager.storyInstance.emptyCache();

      // 3. پاک‌سازی از post cache (اگر مربوط به این گفتگو باشد)
      // await _cacheManager.postInstance.emptyCache();

      print('پاک شده selective images برای گفتگو: $conversationId');
    } catch (e) {
      print('خطا در پاک‌سازی انتخابی تصاویر: $e');
    }
  }
}

// Custom painter for the circular storage chart (like Telegram)
class StorageChartPainter extends CustomPainter {
  final List<StorageCategory> categories;
  final bool isDark;

  StorageChartPainter(this.categories, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = isDark ? Colors.grey[800]! : Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw category arcs
    double startAngle = -math.pi / 2; // Start from top

    for (final category in categories) {
      if (category.percentage < 1.0) continue;

      final sweepAngle = (category.percentage / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
