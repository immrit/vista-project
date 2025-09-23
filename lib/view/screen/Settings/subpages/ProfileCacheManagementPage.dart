import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../DB/profile_cache_service.dart';

class ProfileCacheManagementPage extends ConsumerStatefulWidget {
  final ProfileCacheService profileCache;
  final VoidCallback? onDataChanged;

  const ProfileCacheManagementPage({
    super.key,
    required this.profileCache,
    this.onDataChanged,
  });

  @override
  ConsumerState<ProfileCacheManagementPage> createState() =>
      _ProfileCacheManagementPageState();
}

class _ProfileCacheManagementPageState
    extends ConsumerState<ProfileCacheManagementPage>
    with TickerProviderStateMixin {
  List<CachedProfile> cachedProfiles = [];
  Set<String> selectedProfiles = {};
  bool isSelectMode = false;
  bool isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCachedProfiles();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadCachedProfiles() async {
    setState(() => isLoading = true);
    try {
      final stats = widget.profileCache.getCacheStats();
      final List<CachedProfile> profiles = [];

      // شبیه‌سازی لیست پروفایل‌های کش شده
      // در واقع باید از ProfileCacheService متد مناسب برای دریافت لیست استفاده کنیم
      for (int i = 0; i < (stats['cached_profiles_count'] ?? 0); i++) {
        profiles.add(CachedProfile(
          userId: 'user_$i',
          username: 'user_$i',
          fullName: 'کاربر $i',
          avatarUrl: null,
          postsCount: (i * 3 + 2),
          cacheSize: (i * 0.5 + 1.2), // MB
          lastUpdated: DateTime.now().subtract(Duration(hours: i * 2)),
        ));
      }

      setState(() {
        cachedProfiles = profiles;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری پروفایل‌ها: $e')),
      );
    }
  }

  String _formatSize(double sizeMB) {
    if (sizeMB < 1) {
      return '${(sizeMB * 1024).toStringAsFixed(0)} KB';
    }
    return '${sizeMB.toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  void _toggleSelectMode() {
    setState(() {
      isSelectMode = !isSelectMode;
      if (!isSelectMode) {
        selectedProfiles.clear();
      }
    });
  }

  void _toggleProfileSelection(String userId) {
    setState(() {
      if (selectedProfiles.contains(userId)) {
        selectedProfiles.remove(userId);
      } else {
        selectedProfiles.add(userId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedProfiles = cachedProfiles.map((p) => p.userId).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      selectedProfiles.clear();
    });
  }

  Future<void> _deleteSelectedProfiles() async {
    if (selectedProfiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید حذف'),
        content: Text(
            'آیا مطمئن هستید که می‌خواهید ${selectedProfiles.length} پروفایل را از کش حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        double freedSpace = 0;

        for (final userId in selectedProfiles) {
          try {
            await widget.profileCache.clearUserCache(userId);
            final profile =
                cachedProfiles.firstWhere((p) => p.userId == userId);
            freedSpace += profile.cacheSize;
          } catch (e) {
            continue;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${selectedProfiles.length} پروفایل حذف شد • ${_formatSize(freedSpace)} آزاد شد'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onDataChanged?.call();
        await _loadCachedProfiles();
        setState(() {
          selectedProfiles.clear();
          isSelectMode = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف: $e')),
        );
      }
    }
  }

  Future<void> _refreshProfile(String userId) async {
    try {
      await widget.profileCache.refreshCacheInBackground(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پروفایل به‌روزرسانی شد'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadCachedProfiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در به‌روزرسانی: $e')),
      );
    }
  }

  void _showProfileDetails(CachedProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl == null
                  ? Text(profile.fullName.substring(0, 1))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: const TextStyle(fontSize: 16)),
                  Text('@${profile.username}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('تعداد پست‌ها:', '${profile.postsCount}'),
            _buildDetailRow('حجم کش:', _formatSize(profile.cacheSize)),
            _buildDetailRow(
                'آخرین به‌روزرسانی:', _formatDate(profile.lastUpdated)),
            const SizedBox(height: 16),
            const Text('عملیات:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _refreshProfile(profile.userId);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('به‌روزرسانی'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await widget.profileCache.clearUserCache(profile.userId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('پروفایل از کش حذف شد'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      widget.onDataChanged?.call();
                      await _loadCachedProfiles();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطا در حذف: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProfileList() {
    if (cachedProfiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('هیچ پروفایلی در کش یافت نشد',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // مرتب‌سازی بر اساس آخرین به‌روزرسانی
    final sortedProfiles = List<CachedProfile>.from(cachedProfiles);
    sortedProfiles.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedProfiles.length,
      itemBuilder: (context, index) {
        final profile = sortedProfiles[index];
        final isSelected = selectedProfiles.contains(profile.userId);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: isSelectMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleProfileSelection(profile.userId),
                  )
                : CircleAvatar(
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Text(profile.fullName.substring(0, 1))
                        : null,
                  ),
            title: Text(
              profile.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${profile.username}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.photo_library_rounded,
                        size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${profile.postsCount} پست',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.storage_rounded,
                        size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(_formatSize(profile.cacheSize),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ],
            ),
            trailing: isSelectMode
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatDate(profile.lastUpdated),
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 11)),
                      const SizedBox(height: 2),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey[400]),
                    ],
                  ),
            onTap: isSelectMode
                ? () => _toggleProfileSelection(profile.userId)
                : () => _showProfileDetails(profile),
            onLongPress: isSelectMode ? null : _toggleSelectMode,
          ),
        );
      },
    );
  }

  Widget _buildCacheStats() {
    final totalSize = cachedProfiles.fold(0.0, (sum, p) => sum + p.cacheSize);
    final totalPosts = cachedProfiles.fold(0, (sum, p) => sum + p.postsCount);

    return Column(
      children: [
        // آمار کلی
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('${cachedProfiles.length}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple)),
                  const Text('پروفایل', style: TextStyle(color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Text('$totalPosts',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue)),
                  const Text('پست', style: TextStyle(color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Text(_formatSize(totalSize),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                  const Text('حجم کل', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),

        // نمودار دایره‌ای ساده
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('توزیع حجم پروفایل‌ها',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...cachedProfiles.take(5).map((profile) {
                final percentage =
                    totalSize > 0 ? (profile.cacheSize / totalSize * 100) : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        child: Text(profile.fullName.substring(0, 1),
                            style: const TextStyle(fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.fullName,
                                style: const TextStyle(fontSize: 12)),
                            LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.purple),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              if (cachedProfiles.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('و ${cachedProfiles.length - 5} پروفایل دیگر...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // دکمه‌های عملیات
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await widget.profileCache.clearAllCache();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تمام کش پروفایل‌ها پاک‌سازی شد'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      widget.onDataChanged?.call();
                      await _loadCachedProfiles();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطا در پاکسازی: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('پاک‌سازی همه'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadCachedProfiles,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('بروزرسانی'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectMode
            ? '${selectedProfiles.length} انتخاب شده'
            : 'مدیریت پروفایل‌ها'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.person_rounded), text: 'پروفایل‌ها'),
                  Tab(icon: Icon(Icons.analytics_rounded), text: 'آمار'),
                ],
                indicatorColor: Colors.purple,
                labelColor: isDark ? Colors.white : Colors.black,
              )
            : null,
        actions: [
          if (!isSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: cachedProfiles.isNotEmpty ? _toggleSelectMode : null,
              tooltip: 'انتخاب چندگانه',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadCachedProfiles,
              tooltip: 'بروزرسانی',
            ),
          ] else ...[
            TextButton(
              onPressed: selectedProfiles.length == cachedProfiles.length
                  ? _deselectAll
                  : _selectAll,
              child: Text(selectedProfiles.length == cachedProfiles.length
                  ? 'لغو همه'
                  : 'انتخاب همه'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed:
                  selectedProfiles.isEmpty ? null : _deleteSelectedProfiles,
              color: Colors.red,
              tooltip: 'حذف انتخاب شده‌ها',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _toggleSelectMode,
              tooltip: 'لغو انتخاب',
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabController != null
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileList(),
                    _buildCacheStats(),
                  ],
                )
              : const Center(child: Text('خطا در بارگذاری')),
    );
  }
}

class CachedProfile {
  final String userId;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final int postsCount;
  final double cacheSize; // MB
  final DateTime lastUpdated;

  CachedProfile({
    required this.userId,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    required this.postsCount,
    required this.cacheSize,
    required this.lastUpdated,
  });
}
