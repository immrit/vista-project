import 'package:Vista/util/widgets.dart';
import 'package:Vista/view/screen/PublicPosts/PostDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../model/Hive Model/RecentSearch.dart';
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

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  late Box<RecentSearch>? _recentSearchesBox; // تغییر به nullable
  bool _showRecentSearches = true;
  bool _isInitialized = false; // اضافه کردن فلگ برای کنترل وضعیت초기화

  @override
  void initState() {
    super.initState();
    _setupTabController();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initHive();
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
    if (widget.initialHashtag != null) {
      final hashtag = widget.initialHashtag!.startsWith('#')
          ? widget.initialHashtag!
          : '#${widget.initialHashtag!}';
      _searchController.text = hashtag;
      _showRecentSearches = false;
      _tabController.animateTo(0);
      _performSearch(hashtag);
    }
  }

  Future<void> _initHive() async {
    _recentSearchesBox = await Hive.openBox<RecentSearch>('recent_searches');
  }

  void _addToRecentSearches(String query) {
    if (query.isEmpty || _recentSearchesBox == null) return;

    final searchType =
        query.startsWith('#') ? SearchType.hashtag : SearchType.user;

    // حذف جستجوی تکراری قبلی
    _recentSearchesBox!.values
        .where((search) =>
            search.query == query && search.searchType == searchType)
        .forEach((search) => search.delete());

    // اضافه کردن جستجوی جدید
    _recentSearchesBox!.add(RecentSearch(
      query: query,
      timestamp: DateTime.now(),
      searchType: searchType,
    ));

    // محدود کردن تعداد جستجوها به 20 مورد
    if (_recentSearchesBox!.length > 20) {
      final searches = _recentSearchesBox!.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      for (var i = 20; i < searches.length; i++) {
        searches[i].delete();
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      _showRecentSearches = query.isEmpty;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (query.isNotEmpty) {
          _addToRecentSearches(query);
          ref.read(searchProvider.notifier).search(query);
        }
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showRecentSearches = true;
    });
    ref.read(searchProvider.notifier).clearHashtagResults();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _recentSearchesBox?.close();
    super.dispose();
  }

  Widget _buildRecentSearches() {
    if (!_isInitialized || _recentSearchesBox == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder(
      valueListenable: _recentSearchesBox!.listenable(),
      builder: (context, Box<RecentSearch> box, _) {
        final searches = box.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (searches.isEmpty) {
          return Center(
            child: Text(
              'جستجوی اخیری وجود ندارد',
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.color
                    ?.withOpacity(0.6),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: searches.length,
          itemBuilder: (context, index) {
            final search = searches[index];
            return ListTile(
              leading: Icon(
                search.searchType == SearchType.hashtag
                    ? Icons.tag
                    : Icons.person,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                search.query,
                style: TextStyle(
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () => search.delete(),
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
        if (_showRecentSearches && _recentSearchesBox?.isNotEmpty == true)
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
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
                      onPressed: () {
                        _recentSearchesBox?.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('پاک کردن'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
      // تب‌ها فقط زمانی نمایش داده می‌شوند که جستجو انجام شده باشد
      bottom: !_showRecentSearches
          ? TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'هشتگ‌ها'),
                Tab(text: 'کاربران'),
              ],
            )
          : null,
    );
  }

  Widget _buildBody(SearchState searchState) {
    if (_showRecentSearches) {
      return _buildRecentSearches();
    }

    return searchState.isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
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
        ),
      ),
    );
  }

  InputDecoration _buildSearchDecoration() {
    return InputDecoration(
      hintText: 'جستجو...',
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
    );
  }

  Widget _buildHashtagResults(SearchState state) {
    if (state.error != null) {
      return _buildErrorWidget(state.error!);
    }

    if (_shouldShowEmptyState(state.hashtagResults, state.currentQuery)) {
      return const Center(child: Text('نتیجه‌ای یافت نشد'));
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
      return const Center(child: Text('نتیجه‌ای یافت نشد'));
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

// کامپوننت کارت پست
class PostCard extends ConsumerWidget {
  final PublicPostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailsPage(postId: post.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: post.avatarUrl != null
                            ? NetworkImage(post.avatarUrl)
                            : const AssetImage(
                                    'lib/util/images/default-avatar.jpg')
                                as ImageProvider,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.username ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// کامپوننت کارت کاربر
class UserCard extends ConsumerStatefulWidget {
  final ProfileModel user;

  const UserCard({super.key, required this.user});

  @override
  ConsumerState<UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<UserCard> {
  bool _isLoading = false;

  Future<void> _toggleFollow() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(userProfileProvider(widget.user.id).notifier)
          .toggleFollow(widget.user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در تغییر وضعیت فالو: $e')),
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
    final currentColor = ref.watch(themeProvider);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: widget.user.avatarUrl != null
                  ? NetworkImage(widget.user.avatarUrl!)
                  : const AssetImage('lib/util/images/default-avatar.jpg')
                      as ImageProvider,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.user.username,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.user.isVerified)
                  const Icon(Icons.verified, color: Colors.blue, size: 16),
              ],
            ),
            Text(
              widget.user.fullName,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              height: 32,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: userProfile?.isFollowed ?? false
                            ? Colors.grey
                            : Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        userProfile?.isFollowed ?? false
                            ? 'دنبال شده'
                            : 'دنبال کردن',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
