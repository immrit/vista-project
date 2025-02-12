import 'package:Vista/view/screen/PublicPosts/PostDetailPage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../main.dart';
import '../Stories/story_system.dart';
import '../searchPage.dart';
import '/model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../util/widgets.dart';
import 'profileScreen.dart';
import 'dart:async';

class PublicPostsScreen extends ConsumerStatefulWidget {
  const PublicPostsScreen({super.key});

  @override
  ConsumerState<PublicPostsScreen> createState() => _PublicPostsScreenState();
}

class _PublicPostsScreenState extends ConsumerState<PublicPostsScreen>
    with AutomaticKeepAliveClientMixin {
  String _connectionStatus = '';
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isChecking = false;
  final _pageStorageKey = const PageStorageKey('public_posts');
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _tabControllerKey = GlobalKey();

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result);
    });

    // بررسی دوره‌ای وضعیت اتصال
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _initConnectivity();
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _initConnectivity() async {
    setState(() => _isChecking = true);
    try {
      final result = await _connectivity.checkConnectivity();
      if (mounted) {
        await _updateConnectionStatus(result);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      if (mounted) {
        setState(() {
          _connectionStatus = 'آفلاین';
          _isChecking = false;
        });
      }
      Future.delayed(const Duration(seconds: 3), _initConnectivity);
    }
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (!mounted) return;

    bool hasInternet = false;
    try {
      final response = await Future.any<dynamic>([
        Supabase.instance.client.from('posts').select().limit(1).single(),
        Future<dynamic>.delayed(
            const Duration(seconds: 3), () => throw 'timeout'),
      ]);
      hasInternet = response != null;
    } catch (_) {
      hasInternet = false;
    }

    setState(() {
      _isChecking = false;
      if (!hasInternet) {
        _connectionStatus = 'آفلاین';
        return;
      }

      switch (result) {
        case ConnectivityResult.wifi:
          _connectionStatus = 'متصل به وای‌فای';
          break;
        case ConnectivityResult.mobile:
          _connectionStatus = 'متصل به اینترنت همراه';
          break;
        default:
          _connectionStatus = 'آفلاین';
      }
    });
  }

  Widget _buildConnectionStatus() {
    return ConnectionStatusBar(
      status: _connectionStatus,
      isChecking: _isChecking,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentColor = ref.watch(themeProvider);
    final getProfile = ref.watch(profileProvider);

    return DefaultTabController(
      length: 2,
      initialIndex: 1, // اضافه کردن این خط
      key: _tabControllerKey,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              floating: true,
              snap: true,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _connectionStatus == 'متصل به وای‌فای' ||
                        _connectionStatus == 'متصل به اینترنت همراه'
                    ? const Text(
                        'Vista',
                        key: ValueKey('app-name'),
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Bauhaus',
                        ),
                      )
                    : _buildConnectionStatus(),
              ),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                labelColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                unselectedLabelColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                tabs: const [
                  Tab(text: 'همه پست‌ها'),
                  Tab(text: 'پست‌های دنبال‌شده‌ها'),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                height: 150, // Increased height for stories
                child: const StoryBar(),
              ),
            )
          ],
          body: const TabBarView(
            children: [
              _AllPostsTab(),
              _FollowingPostsTab(),
            ],
          ),
        ),
        endDrawer: CustomDrawer(getProfile, currentColor, context, ref),
      ),
    );
  }
}

class _AllPostsTab extends ConsumerWidget {
  const _AllPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsyncValue = ref.watch(fetchPublicPosts);

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh posts
        ref.refresh(fetchPublicPosts);
        ref.refresh(notificationsProvider);
        ref.refresh(hasNewNotificationProvider);

        // Get posts and refresh their comments
        final posts = await ref.read(fetchPublicPosts.future);
        for (final post in posts) {
          ref.refresh(commentsProvider(post.id));
        }
      },
      child: postsAsyncValue.when(
        data: (posts) => _buildPostList(context, ref, posts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                color: Colors.grey,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(fetchFollowingPostsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش مجدد'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowingPostsTab extends ConsumerWidget {
  const _FollowingPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingPostsAsyncValue = ref.watch(fetchFollowingPostsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(fetchFollowingPostsProvider);
        final posts = await ref.read(fetchFollowingPostsProvider.future);
        for (final post in posts) {
          ref.refresh(commentsProvider(post.id));
        }
      },
      child: followingPostsAsyncValue.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'شما هنوز کسی را دنبال نکرده‌اید',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // تغییر تب به "همه پست‌ها"
                      final tabController = DefaultTabController.of(context);
                      tabController.animateTo(0); // تب اول (همه پست‌ها)
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('یافتن افراد جدید'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildPostList(context, ref, posts);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.grey,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'مشکلی در دریافت پست‌ها پیش آمده',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.refresh(fetchFollowingPostsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش مجدد'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildPostList(
    BuildContext context, WidgetRef ref, List<PublicPostModel> posts) {
  if (posts.isEmpty) {
    return const Center(child: Text('هیچ پستی وجود ندارد.'));
  }

  return ListView.builder(
    padding: const EdgeInsets.only(top: 8.0), // کاهش فاصله از بالا
    itemCount: posts.length,
    itemBuilder: (context, index) {
      final post = posts[index];

      DateTime createdAt = post.createdAt.toLocal();
      Jalali jalaliDate = Jalali.fromDateTime(createdAt);
      String formattedDate =
          '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 18.0),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailsPage(
                  postId: post.id,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          userId: post.userId,
                          username: post.username,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: post.avatarUrl.isEmpty
                        ? const AssetImage('lib/util/images/default-avatar.jpg')
                            as ImageProvider
                        : CachedNetworkImageProvider(post.avatarUrl),
                  ),
                ),
                title: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          userId: post.userId,
                          username: post.username,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      if (post.isVerified)
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 16.0),
                    ],
                  ),
                ),
                subtitle: Text(
                  formattedDate,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: _buildPostActions(context, ref, post),
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: getDirectionality(post.content),
                child: _buildPostContent(post.content, context),
              ),
              // نمایش هشتگ‌ها
              if (post.hashtags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: post.hashtags
                      .map(
                        (tag) => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchPage(
                                  initialHashtag: tag,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              // اضافه کردن نمایش تصویر در صورت وجود
              if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PostImageViewer(imageUrl: post.imageUrl!),
                      ),
                    );
                  },
                  child: Hero(
                    tag: post.imageUrl!, // استفاده از Hero در اینجا
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl!,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : null,
                    ),
                    onPressed: () async {
                      post.isLiked = !post.isLiked;
                      post.likeCount += post.isLiked ? 1 : -1;
                      (context as Element).markNeedsBuild();
                      await ref.watch(supabaseServiceProvider).toggleLike(
                            postId: post.id,
                            ownerId: post.userId,
                            ref: ref,
                          );
                    },
                  ),
                  Text('${post.likeCount}'),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.comment),
                        onPressed: () {
                          showCommentsBottomSheet(context, post.id, ref);
                        },
                      ),
                      Text('${post.commentCount}')
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      String sharePost =
                          'کاربر ${post.username} به شما ارسال کرد:\n\n${post.content}';
                      Share.share(sharePost);
                    },
                  ),
                ],
              ),
              const Divider(),
            ],
          ),
        ),
      );
    },
  );
}

class LinkifyText extends StatelessWidget {
  const LinkifyText({
    super.key,
    required this.text,
    required this.onTap,
    this.linkStyle,
  });

  final TextStyle? linkStyle;
  final Function(String) onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Updated regex to catch domains without http/https
    final urlRegex = RegExp(
      r'(?:(?:https?:\/\/)?(?:www\.)?)?[a-zA-Z0-9][-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    var start = 0;

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle ??
              const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final formattedUrl =
                  url.startsWith('http') ? url : 'https://$url';
              onTap(formattedUrl);
            },
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

Widget _buildPostContent(String content, BuildContext context) {
  final pattern = RegExp(
    r'(#[\w\u0600-\u06FF]+)|((https?:\/\/)?([\w\-])+\.{1}([a-zA-Z]{2,63})([\/\w-]*)*\/?\??([^\s<>#]*))',
    multiLine: true,
    unicode: true,
  );

  List<TextSpan> spans = [];
  int start = 0;

  for (Match match in pattern.allMatches(content)) {
    if (match.start > start) {
      spans.add(TextSpan(text: content.substring(start, match.start)));
    }

    final matchedText = match.group(0)!;

    if (matchedText.startsWith('#')) {
      spans.add(
        TextSpan(
          text: matchedText,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // ارسال کل هشتگ با علامت # به صفحه جستجو
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(
                    initialHashtag: matchedText, // ارسال کل هشتگ با علامت #
                  ),
                ),
              );
            },
        ),
      );
    } else {
      // کد مربوط به URL بدون تغییر
      spans.add(
        TextSpan(
          text: matchedText,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final url = matchedText.startsWith('http')
                  ? matchedText
                  : 'https://$matchedText';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
        ),
      );
    }
    start = match.end;
  }

  if (start < content.length) {
    spans.add(TextSpan(text: content.substring(start)));
  }

  return RichText(
    text: TextSpan(
      style: DefaultTextStyle.of(context).style,
      children: spans,
    ),
  );
}

PopupMenuButton<String> _buildPostActions(
    BuildContext context, WidgetRef ref, PublicPostModel post) {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  return PopupMenuButton<String>(
    onSelected: (value) async {
      switch (value) {
        case 'report':
          if (post.userId != currentUserId) {
            return showDialog(
              context: context,
              builder: (context) => ReportDialog(post: post),
            );
          }

          break;
        case 'copy':
          Clipboard.setData(ClipboardData(text: post.content));
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('متن کپی شد!')));
          break;
        case 'delete':
          if (post.userId == currentUserId) {
            final confirmed = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('حذف پست'),
                content: const Text('آیا از حذف این پست اطمینان دارید؟'),
                actions: [
                  TextButton(
                    style: ButtonStyle(
                      overlayColor: WidgetStateProperty.all(
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white12 // افکت لمس در تم تاریک
                            : Colors.black12, // افکت لمس در تم روشن
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'انصراف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300] // رنگ روشن‌تر برای تم تاریک
                            : Colors.grey[800], // رنگ تیره‌تر برای تم روشن
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.red[700] // رنگ دکمه در تم تاریک
                              : Colors.red, // رنگ دکمه در تم روشن
                      shadowColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : Colors.grey[400], // سایه
                      elevation: 5,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'حذف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors
                            .white, // Text color remains white for both themes
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.watch(supabaseServiceProvider).deletePost(ref, post.id);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('پست حذف شد!')));
            }
          }
          break;
      }
    },
    itemBuilder: (context) => [
      if (post.userId != currentUserId)
        const PopupMenuItem(value: 'report', child: Text('گزارش')),
      const PopupMenuItem(value: 'copy', child: Text('کپی')),
      if (post.userId == currentUserId)
        const PopupMenuItem(value: 'delete', child: Text('حذف')),
    ],
  );
}

class _PublicPostsState extends ConsumerState<PublicPostsScreen> {
  String _connectionStatus = '';
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _hasMore = true;
  bool _isChecking = false;
  bool _isLoading = false;
  final int _limit = 10;
  int _offset = 0;
  List<Map<String, dynamic>> _posts = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _initConnectivity() async {
    setState(() => _isChecking = true);
    try {
      final result = await _connectivity.checkConnectivity();
      if (mounted) {
        await _updateConnectionStatus(result);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      if (mounted) {
        setState(() {
          _connectionStatus = 'آفلاین';
          _isChecking = false;
        });
      }
      Future.delayed(const Duration(seconds: 3), _initConnectivity);
    }
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (!mounted) return;

    bool hasInternet = false;
    try {
      final response = await Future.any<dynamic>([
        Supabase.instance.client.from('posts').select().limit(1).single(),
        Future<dynamic>.delayed(
            const Duration(seconds: 3), () => throw 'timeout'),
      ]);
      hasInternet = response != null;
    } catch (_) {
      hasInternet = false;
    }

    setState(() {
      _isChecking = false;
      if (!hasInternet) {
        _connectionStatus = 'آفلاین';
        return;
      }

      switch (result) {
        case ConnectivityResult.wifi:
          _connectionStatus = 'متصل به وای‌فای';
          break;
        case ConnectivityResult.mobile:
          _connectionStatus = 'متصل به اینترنت همراه';
          break;
        default:
          _connectionStatus = 'آفلاین';
      }
    });
  }

  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _posts = [];
      _offset = 0;
      _hasMore = true;
    });

    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    try {
      final response = await supabase
          .from('posts')
          .select()
          .range(_offset, _offset + _limit - 1)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }

      setState(() {
        _posts.addAll(List<Map<String, dynamic>>.from(response));
        _offset += response.length;
        _hasMore = response.length >= _limit;
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load posts: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 200.0;

    if (maxScroll - currentScroll <= threshold) {
      _loadMorePosts();
    }
  }

  Future<void> _handleRefresh() async {
    await _loadInitialPosts();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: _posts.isEmpty && _isLoading
          ? Center(
              child: LoadingAnimationWidget.progressiveDots(
                color: Theme.of(context).primaryColor,
                size: 50,
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _posts.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _posts.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: LoadingAnimationWidget.progressiveDots(
                        color: Theme.of(context).primaryColor,
                        size: 40,
                      ),
                    ),
                  );
                }
                return PostCard(post: PublicPostModel.fromMap(_posts[index]));
              },
            ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.grey[300],
    );
  }
}

class ConnectionStatusBar extends StatefulWidget {
  const ConnectionStatusBar({
    super.key,
    required this.status,
    required this.isChecking,
  });

  final bool isChecking;
  final String status;

  @override
  State<ConnectionStatusBar> createState() => _ConnectionStatusBarState();
}

class _ConnectionStatusBarState extends State<ConnectionStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.status == 'آفلاین'
        ? Colors.red[400]
        : widget.status.contains('وای‌فای')
            ? Colors.green[400]
            : Colors.blue[400];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color?.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isChecking)
                    LoadingAnimationWidget.staggeredDotsWave(
                      color: color ?? Colors.grey,
                      size: 20,
                    )
                  else
                    Icon(
                      widget.status == 'آفلاین'
                          ? Icons.cloud_off_rounded
                          : widget.status.contains('وای‌فای')
                              ? Icons.wifi_rounded
                              : Icons.signal_cellular_4_bar_rounded,
                      color: color,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    widget.status,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
