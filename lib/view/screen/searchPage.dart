import '../../security/logging_utility.dart';
import 'package:Vista/view/util/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:isar/isar.dart';
import '../../DB/isar_database_manager.dart';
import '../../DB/entities/recent_search_entity.dart';
import '../../model/ProfileModel.dart';
import '../../model/SearchResut.dart';
import '../../model/publicPostModel.dart';
import '../../provider/provider.dart';
import 'PublicPosts/profileScreen.dart';
import 'dart:async';

class SearchPage extends ConsumerStatefulWidget {
  final String? initialHashtag;

  const SearchPage({super.key, this.initialHashtag});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

// Local RecentSearch and SearchType removed in favor of Isar entities

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  Isar? _isar;
  // final StoreRef<String, Map<String, dynamic>> _store =
  //     StoreRef<String, Map<String, dynamic>>.main();
  bool _showRecentSearches = true;
  bool _isInitialized = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _setupTabController();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initIsar();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      _handleInitialHashtag();
    }
  }

  void _setupTabController() {
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _showRecentSearches = false;
        });
      }
      ref.read(searchProvider.notifier).setTab(_tabController.index);
    });
  }

  void _handleInitialHashtag() {
    if (widget.initialHashtag != null && widget.initialHashtag!.isNotEmpty) {
      final hashtag = widget.initialHashtag!.startsWith('#')
          ? widget.initialHashtag!
          : '#${widget.initialHashtag!}';
      _searchController.text = hashtag;
      setState(() {
        _showRecentSearches = false;
        _isSearching = true;
      });
      _tabController.animateTo(0); // هشتگ‌ها
      _performSearch(hashtag);
    }
  }

  Future<void> _initIsar() async {
    try {
      _isar = await IsarDatabaseManager().instance;
    } catch (e) {
      logDebug('خطا در باز کردن دیتابیس Isar: $e');
    }
  }

  Future<void> _addToRecentSearches(String query) async {
    if (query.isEmpty || _isar == null) return;

    final searchType =
        query.startsWith('#') ? SearchType.hashtag : SearchType.user;

    try {
      await _isar!.writeTxn(() async {
        // حذف جستجوی تکراری قبلی
        await _isar!.recentSearchEntitys
            .filter()
            .queryEqualTo(query)
            .deleteAll();

        // اضافه کردن جستجوی جدید
        final recentSearch = RecentSearchEntity()
          ..query = query
          ..timestamp = DateTime.now()
          ..searchType = searchType;

        await _isar!.recentSearchEntitys.put(recentSearch);

        // محدود کردن تعداد جستجوها به 20 مورد
        final count = await _isar!.recentSearchEntitys.count();
        if (count > 20) {
          final oldSearches = await _isar!.recentSearchEntitys
              .where()
              .sortByTimestamp() // قدیمی‌ترین‌ها اول
              .limit(count - 20)
              .findAll();

          await _isar!.recentSearchEntitys
              .deleteAll(oldSearches.map((e) => e.id).toList());
        }
      });
    } catch (e) {
      logDebug('خطا در ذخیره جستجوی اخیر: $e');
    }
  }

  void _performSearch(String query) {
    setState(() {
      _showRecentSearches = query.isEmpty;
      _isSearching = query.isNotEmpty;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (mounted && query.isNotEmpty) {
        await _addToRecentSearches(query);

        // تنظیم تب مناسب برای نوع جستجو
        if (query.startsWith('#') && _tabController.index != 0) {
          _tabController.animateTo(0); // هشتگ‌ها
        } else if (!query.startsWith('#') && _tabController.index != 1) {
          _tabController.animateTo(1); // کاربران
        }

        ref.read(searchProvider.notifier).search(query);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showRecentSearches = true;
      _isSearching = false;
    });
    ref.read(searchProvider.notifier).clearHashtagResults();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    // _database?.close(); Isar manager handles closing usually, or keep open
    super.dispose();
  }

  Widget _buildRecentSearches() {
    if (!_isInitialized || _isar == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<RecentSearchEntity>>(
      future: _getRecentSearches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('خطا در بارگذاری جستجوهای اخیر: ${snapshot.error}'),
          );
        }

        final searches = snapshot.data ?? [];

        if (searches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color:
                      Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'جستجوی اخیری وجود ندارد',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: searches.length,
          itemBuilder: (context, index) {
            final search = searches[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Icon(
                  search.searchType == SearchType.hashtag
                      ? Icons.tag
                      : Icons.person,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              title: Text(
                search.query,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              subtitle: Text(
                search.searchType == SearchType.hashtag ? 'هشتگ' : 'کاربر',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTimeAgo(search.timestamp),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: Theme.of(context)
                          .iconTheme
                          .color
                          ?.withValues(alpha: 0.6),
                    ),
                    onPressed: () => _deleteRecentSearch(search.query),
                  ),
                ],
              ),
              onTap: () {
                _searchController.text = search.query;
                if (search.searchType == SearchType.hashtag) {
                  _tabController.animateTo(0);
                } else {
                  _tabController.animateTo(1);
                }
                _performSearch(search.query);
              },
            );
          },
        );
      },
    );
  }

  Future<List<RecentSearchEntity>> _getRecentSearches() async {
    if (_isar == null) return [];

    try {
      final searches = await _isar!.recentSearchEntitys
          .where()
          .sortByTimestampDesc()
          .findAll();
      return searches;
    } catch (e) {
      logDebug('خطا در دریافت جستجوهای اخیر: $e');
      return [];
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
      setState(() {}); // Refresh the UI
    } catch (e) {
      logDebug('خطا در حذف جستجوی اخیر: $e');
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} روز پیش';
    } else {
      return '${(difference.inDays / 30).floor()} ماه پیش';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(searchState),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: _buildSearchBar(),
      actions: [
        if (_showRecentSearches)
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showClearHistoryDialog,
          ),
      ],
      bottom: !_showRecentSearches
          ? TabBar(
              controller: _tabController,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'هشتگ‌ها'),
                Tab(text: 'کاربران'),
              ],
            )
          : null,
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پاک کردن تاریخچه'),
        content: const Text(
            'آیا مطمئن هستید که می‌خواهید تمام تاریخچه جستجو را پاک کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              await _clearAllRecentSearches();
              Navigator.pop(context);
            },
            child: const Text('پاک کردن'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllRecentSearches() async {
    if (_isar == null) return;

    try {
      await _isar!.writeTxn(() async {
        await _isar!.recentSearchEntitys.clear();
      });
      setState(() {}); // Refresh the UI
    } catch (e) {
      logDebug('خطا در پاک کردن تمام جستجوهای اخیر: $e');
    }
  }

  Widget _buildBody(SearchState searchState) {
    if (_showRecentSearches) {
      return _buildRecentSearches();
    }

    if (searchState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildHashtagResults(searchState),
        _buildUserResults(searchState),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Directionality(
        textDirection: getDirectionality(_searchController.text),
        child: TextField(
          controller: _searchController,
          decoration: _buildSearchDecoration(),
          onChanged: _performSearch,
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
        ),
      ),
    );
  }

  InputDecoration _buildSearchDecoration() {
    return InputDecoration(
      hintText: 'جستجوی کاربران یا هشتگ‌ها...',
      prefixIcon: Icon(
        Icons.search,
        color: Theme.of(context).iconTheme.color,
      ),
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: Icon(
                Icons.clear,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: _clearSearch,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Theme.of(context).cardColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
    );
  }

  Widget _buildHashtagResults(SearchState state) {
    if (state.error != null) {
      return _buildErrorWidget(state.error!);
    }

    if (_shouldShowEmptyState(state.hashtagResults, state.currentQuery)) {
      return _buildEmptyResultWidget("هشتگی با این عنوان یافت نشد");
    }

    return RefreshIndicator(
      onRefresh: () async => _performSearch(state.currentQuery),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemCount: state.hashtagResults.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) =>
            PostCard(post: state.hashtagResults[index]),
      ),
    );
  }

  Widget _buildUserResults(SearchState state) {
    if (state.error != null) {
      return _buildErrorWidget(state.error!);
    }

    if (_shouldShowEmptyState(state.userResults, state.currentQuery)) {
      return _buildEmptyResultWidget("کاربری با این مشخصات یافت نشد");
    }

    return RefreshIndicator(
      onRefresh: () async => _performSearch(state.currentQuery),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        padding: const EdgeInsets.all(8),
        itemCount: state.userResults.length,
        itemBuilder: (context, index) =>
            UserCard(user: state.userResults[index]),
      ),
    );
  }

  Widget _buildEmptyResultWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          if (_isSearching)
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('جستجوی جدید'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('خطا: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _performSearch(_searchController.text),
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  bool _shouldShowEmptyState(List items, String query) {
    return items.isEmpty && query.isNotEmpty;
  }
}

// کامپوننت کارت پست - بهبود یافته
class PostCard extends StatelessWidget {
  final PublicPostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // باز کردن صفحه جزئیات پست
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر پست با اطلاعات کاربر
            _buildPostHeader(context),

            // تصویر پست
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: post.imageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                ),
              ),

            // متن پست
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),

                  // فوتر پست با آمار لایک و کامنت
                  _buildPostFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // آواتار کاربر
          CircleAvatar(
            radius: 16,
            backgroundImage: post.avatarUrl.isNotEmpty
                ? NetworkImage(post.avatarUrl)
                : const AssetImage('lib/view/util/images/default-avatar.jpg')
                    as ImageProvider,
          ),
          const SizedBox(width: 8),

          // نام کاربری و آیکون تیک
          Expanded(
            child: Row(
              children: [
                Text(
                  post.username ?? 'کاربر',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                if (post.isVerified) _buildVerificationBadge(post),
              ],
            ),
          ),

          // زمان انتشار پست
          Text(
            _getTimeAgo(post.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // تعداد لایک
        Row(
          children: [
            const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              post.likeCount.toString() ?? '0',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),

        // تعداد کامنت
        Row(
          children: [
            Image.asset(
              'lib/view/util/images/component/comment.png',
              width: 16,
              height: 16,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              post.commentCount.toString() ?? '0',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),

        // دکمه اشتراک‌گذاری
        const Icon(Icons.share_outlined, size: 16, color: Colors.grey),
      ],
    );
  }

  // نمایش تیک تأیید متناسب با نوع آن
  Widget _buildVerificationBadge(PublicPostModel post) {
    if (post.verificationType == 'blueTick') {
      return const Icon(Icons.verified, color: Colors.blue, size: 16);
    } else if (post.verificationType == 'goldTick') {
      return const Icon(Icons.verified, color: Colors.amber, size: 16);
    } else if (post.verificationType == 'blackTick') {
      return const Icon(Icons.verified, color: Colors.black, size: 16);
    } else {
      return const Icon(Icons.verified, color: Colors.blue, size: 16);
    }
  }

  // تبدیل تاریخ به فرمت «... پیش»
  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} روز پیش';
    } else {
      return '${(difference.inDays / 30).floor()} ماه پیش';
    }
  }
}

// کامپوننت کارت کاربر - بهبود یافته
class UserCard extends ConsumerStatefulWidget {
  final ProfileModel user;

  const UserCard({super.key, required this.user});

  @override
  ConsumerState<UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<UserCard> {
  bool _isLoading = false;

  Future<void> _toggleFollow() async {
    if (_isLoading) return; // جلوگیری از کلیک مجدد هنگام بارگذاری

    setState(() => _isLoading = true);
    try {
      await ref
          .read(userProfileProvider(widget.user.id).notifier)
          .toggleFollow(widget.user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در تغییر وضعیت فالو: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider(widget.user.id));

    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userId: widget.user.id,
                username: widget.user.username,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUserAvatar(),
              const SizedBox(height: 12),
              _buildUserInfo(),
              const SizedBox(height: 12),
              _buildFollowButton(userProfile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey[200],
          backgroundImage:
              widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty
                  ? NetworkImage(widget.user.avatarUrl!)
                  : const AssetImage('lib/view/util/images/default-avatar.jpg')
                      as ImageProvider,
        ),
        if (widget.user.isVerified)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: _buildVerificationBadge(),
          ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          widget.user.username,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (widget.user.fullName.isNotEmpty)
          Text(
            widget.user.fullName,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        // if (widget.user.bio != null && widget.user.bio!.isNotEmpty)
        //   Padding(
        //     padding: const EdgeInsets.only(top: 4),
        //     child: Text(
        //       widget.user.bio!,
        //       style: TextStyle(
        //         fontSize: 12,
        //         color: Colors.grey[600],
        //       ),
        //       textAlign: TextAlign.center,
        //       overflow: TextOverflow.ellipsis,
        //       maxLines: 2,
        //     ),
        //   ),
      ],
    );
  }

  Widget _buildFollowButton(ProfileModel? userProfile) {
    final isFollowed = userProfile?.isFollowed ?? false;

    return SizedBox(
      width: 120,
      height: 32,
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowed
                    ? Colors.grey[300]
                    : Theme.of(context).primaryColor,
                foregroundColor: isFollowed ? Colors.black87 : Colors.white,
                elevation: isFollowed ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                isFollowed ? 'دنبال شده' : 'دنبال کردن',
                style: const TextStyle(fontSize: 12),
              ),
            ),
    );
  }

  Widget _buildVerificationBadge() {
    if (widget.user.verificationType == VerificationType.blueTick) {
      return const Icon(Icons.verified, color: Colors.blue, size: 18);
    } else if (widget.user.verificationType == VerificationType.goldTick) {
      return const Icon(Icons.verified, color: Colors.amber, size: 18);
    } else if (widget.user.verificationType == VerificationType.blackTick) {
      return const Icon(Icons.verified, color: Colors.black, size: 18);
    } else {
      return const Icon(Icons.verified, color: Colors.blue, size: 18);
    }
  }
}
