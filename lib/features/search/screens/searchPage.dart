import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:isar/isar.dart';
import 'package:Vista/DB/isar_database_manager.dart';
import 'package:Vista/DB/entities/recent_search_entity.dart';
import 'package:Vista/model/ProfileModel.dart';
import 'package:Vista/model/SearchResut.dart';
// import 'package:Vista/model/publicPostModel.dart'; // Removed unused import
import 'package:Vista/provider/provider.dart';
import 'package:Vista/features/posts/screens/profileScreen.dart';
import 'package:Vista/features/search/screens/VistaQRScanner.dart';
import 'dart:async';

/// صفحه جستجو مدرن - الهام گرفته از اینستاگرام
class SearchPage extends ConsumerStatefulWidget {
  final String? initialHashtag;

  const SearchPage({super.key, this.initialHashtag});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  Isar? _isar;
  bool _isInitialized = false;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeApp();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeApp() async {
    try {
      _isar = await IsarDatabaseManager().instance;
    } catch (e) {
      debugPrint('خطا در باز کردن Isar: $e');
    }
    if (mounted) {
      setState(() => _isInitialized = true);
      _handleInitialHashtag();
    }
  }

  void _handleInitialHashtag() {
    if (widget.initialHashtag != null && widget.initialHashtag!.isNotEmpty) {
      final hashtag = widget.initialHashtag!.startsWith('#')
          ? widget.initialHashtag!
          : '#${widget.initialHashtag!}';
      _searchController.text = hashtag;
      _tabController.animateTo(2); // تگ‌ها
      _performSearch(hashtag);
    }
  }

  void _onSearchChanged() {
    setState(() => _hasQuery = _searchController.text.trim().isNotEmpty);
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (mounted && query.isNotEmpty) {
        await _addToRecentSearches(query);
        ref.read(searchProvider.notifier).search(query);
      }
    });
  }

  Future<void> _addToRecentSearches(String query) async {
    if (query.isEmpty || _isar == null) return;
    final searchType =
        query.startsWith('#') ? SearchType.hashtag : SearchType.user;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.recentSearchEntitys
            .filter()
            .queryEqualTo(query)
            .deleteAll();

        final recentSearch = RecentSearchEntity()
          ..query = query
          ..timestamp = DateTime.now()
          ..searchType = searchType;

        await _isar!.recentSearchEntitys.put(recentSearch);

        final count = await _isar!.recentSearchEntitys.count();
        if (count > 20) {
          final oldSearches = await _isar!.recentSearchEntitys
              .where()
              .sortByTimestamp()
              .limit(count - 20)
              .findAll();
          await _isar!.recentSearchEntitys
              .deleteAll(oldSearches.map((e) => e.id).toList());
        }
      });
    } catch (e) {
      debugPrint('خطا در ذخیره جستجو: $e');
    }
  }

  Future<void> _deleteRecentSearch(String query) async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        await _isar!.recentSearchEntitys
            .filter()
            .queryEqualTo(query)
            .deleteAll();
      });
      setState(() {});
    } catch (e) {
      debugPrint('خطا در حذف جستجو: $e');
    }
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clearHashtagResults();
    setState(() => _hasQuery = false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // نوار جستجو
            _buildSearchBar(isDark),

            // تب‌بار (فقط وقتی متن وارد شده)
            if (_hasQuery) _buildTabBar(isDark),

            // محتوا
            Expanded(
              child: _hasQuery
                  ? _buildSearchResults()
                  : _buildRecentSearches(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: isDark ? Colors.black : Colors.white,
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'جستجو...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasQuery)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    onPressed: _clearSearch,
                  ),
                IconButton(
                  icon: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const VistaQRScanner()),
                    );
                  },
                ),
              ],
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: _performSearch,
          onSubmitted: _performSearch,
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: isDark ? Colors.white : Colors.black,
        unselectedLabelColor: isDark ? Colors.grey[600] : Colors.grey[500],
        indicatorColor: isDark ? Colors.white : Colors.black,
        indicatorWeight: 2,
        tabs: const [
          Tab(text: 'همه'),
          Tab(text: 'افراد'),
          Tab(text: 'تگ‌ها'),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchState = ref.watch(searchProvider);

    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // همه نتایج
        _buildAllResults(searchState),
        // افراد
        _buildUserResults(searchState),
        // تگ‌ها
        _buildHashtagResults(searchState),
      ],
    );
  }

  Widget _buildAllResults(SearchState state) {
    final users = state.userResults;
    final hashtags = state.hashtagResults;

    if (users.isEmpty && hashtags.isEmpty) {
      return _buildEmptyState('نتیجه‌ای یافت نشد');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (users.isNotEmpty) ...[
          _buildSectionHeader('افراد'),
          ...users.take(5).map((user) => _UserTile(user: user)),
          if (users.length > 5)
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('مشاهده همه افراد'),
            ),
        ],
        if (hashtags.isNotEmpty) ...[
          _buildSectionHeader('پست‌ها'),
          ...hashtags.take(5).map((post) => _PostTile(
                imageUrl: post.imageUrl,
                content: post.content,
                username: post.username ?? '',
              )),
        ],
      ],
    );
  }

  Widget _buildUserResults(SearchState state) {
    if (state.userResults.isEmpty) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _buildEmptyState('کاربری یافت نشد');
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (state.hasMoreUsers &&
            !state.isLoading &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(searchProvider.notifier).loadMoreUsers();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.userResults.length + (state.hasMoreUsers ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.userResults.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _UserTile(user: state.userResults[index]);
        },
      ),
    );
  }

  Widget _buildHashtagResults(SearchState state) {
    if (state.hashtagResults.isEmpty) {
      return _buildEmptyState('پستی یافت نشد');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.hashtagResults.length,
      itemBuilder: (context, index) {
        final post = state.hashtagResults[index];
        return _PostTile(
          imageUrl: post.imageUrl,
          content: post.content,
          username: post.username ?? '',
        );
      },
    );
  }

  Widget _buildRecentSearches(bool isDark) {
    return FutureBuilder<List<RecentSearchEntity>>(
      future: _getRecentSearches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final searches = snapshot.data ?? [];

        if (searches.isEmpty) {
          return _buildEmptyState('جستجوی اخیری ندارید');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'جستجوهای اخیر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: searches.length,
                itemBuilder: (context, index) {
                  final search = searches[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(
                        search.searchType == SearchType.hashtag
                            ? Icons.tag
                            : Icons.person_outline,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    title: Text(
                      search.query,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      onPressed: () => _deleteRecentSearch(search.query),
                    ),
                    onTap: () {
                      _searchController.text = search.query;
                      _performSearch(search.query);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<RecentSearchEntity>> _getRecentSearches() async {
    if (_isar == null) return [];
    try {
      return await _isar!.recentSearchEntitys
          .where()
          .sortByTimestampDesc()
          .findAll();
    } catch (e) {
      return [];
    }
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// ویجت تایل کاربر
class _UserTile extends StatelessWidget {
  final ProfileModel user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? CachedNetworkImageProvider(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
            ? Icon(
                Icons.person,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.fullName.isNotEmpty ? user.fullName : user.username,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user.hasGoldBadge || user.role == 'premium') ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: Color(0xFFFFD700), size: 16),
          ] else if (user.hasBlueBadge) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: Colors.blue, size: 16),
          ],
        ],
      ),
      subtitle: Text(
        '@${user.username}',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.chevron_left,
        color: isDark ? Colors.grey[700] : Colors.grey[400],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProfileScreen(userId: user.id, username: user.username),
          ),
        );
      },
    );
  }
}

/// ویجت تایل پست
class _PostTile extends StatelessWidget {
  final String? imageUrl;
  final String content;
  final String username;

  const _PostTile({
    this.imageUrl,
    required this.content,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.image_outlined,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              )
            : Icon(
                Icons.article_outlined,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
      ),
      title: Text(
        content.length > 50 ? '${content.substring(0, 50)}...' : content,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '@$username',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
    );
  }
}
