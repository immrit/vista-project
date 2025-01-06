import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class _PublicPostsScreenState extends ConsumerState<PublicPostsScreen> {
  String _connectionStatus = '';
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (mounted) {
        _updateConnectionStatus(result);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      if (mounted) {
        setState(() => _connectionStatus = 'آفلاین');
      }
      // Retry after 3 seconds
      Future.delayed(const Duration(seconds: 3), _initConnectivity);
    }
  }

// متد _updateConnectionStatus را به این صورت تغییر دهید
  void _updateConnectionStatus(ConnectivityResult result) async {
    if (!mounted) return;

    // بررسی واقعی اتصال به اینترنت
    bool hasInternet = false;
    try {
      final response = await Future.any<dynamic>([
        Supabase.instance.client.from('posts').select().limit(1),
        Future<dynamic>.delayed(
            const Duration(seconds: 5), () => throw 'timeout'),
      ]);
      hasInternet = response != null;
    } catch (e) {
      hasInternet = false;
    }

    setState(() {
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
        case ConnectivityResult.none:
          _connectionStatus = 'آفلاین';
          break;
        default:
          _connectionStatus = 'آفلاین';
      }
    });
  }

// متد initState را هم به این صورت تغییر دهید
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
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = ref.watch(themeProvider);
    final getProfile = ref.watch(profileProvider);

    return DefaultTabController(
      length: 2,
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
                    : Text(
                        _connectionStatus,
                        key: ValueKey('connection-status'),
                        style: TextStyle(
                          fontSize: 16,
                          color: _connectionStatus == 'آفلاین'
                              ? Colors.red
                              : Colors.amber,
                        ),
                      ),
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

        // Get posts and refresh their comments
        final posts = await ref.read(fetchPublicPosts.future);
        for (final post in posts) {
          ref.refresh(commentsProvider(post.id));
        }
      },
      child: postsAsyncValue.when(
        data: (posts) => _buildPostList(context, ref, posts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('دسترسی به اینترنت قطع است :('),
            IconButton(
              iconSize: 50,
              splashColor: Colors.transparent,
              color: Colors.white,
              onPressed: () {
                ref.invalidate(fetchPublicPosts);
                ref.invalidate(commentsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        )),
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
        // Refresh posts
        ref.refresh(fetchFollowingPostsProvider);

        // Get posts and refresh their comments
        final posts = await ref.read(fetchFollowingPostsProvider.future);
        for (final post in posts) {
          ref.refresh(commentsProvider(post.id));
        }
      },
      child: followingPostsAsyncValue.when(
        data: (posts) => _buildPostList(context, ref, posts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('دسترسی به اینترنت قطع است :('),
            IconButton(
              iconSize: 50,
              splashColor: Colors.transparent,
              color: Colors.white,
              onPressed: () {
                ref.invalidate(fetchPublicPosts);
                ref.invalidate(commentsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        )),
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
                      : NetworkImage(post.avatarUrl),
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
            // اضافه کردن نمایش تصویر در صورت وجود
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              PostImageViewer(imageUrl: post.imageUrl!),
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
                        showCommentsBottomSheet(
                            context, ref, post.id, post.userId);
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
      );
    },
  );
}

class LinkifyText extends StatelessWidget {
  final String text;
  final Function(String) onTap;
  final TextStyle? linkStyle;

  const LinkifyText({
    super.key,
    required this.text,
    required this.onTap,
    this.linkStyle,
  });

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
  // Regex for both URLs and hashtags
  final pattern = RegExp(
    r'(#\w+)|((https?:\/\/)?([\w\-])+\.{1}([a-zA-Z]{2,63})([\/\w-]*)*\/?\??([^\s<>\#]*)?)',
    multiLine: true,
  );

  List<TextSpan> spans = [];
  int start = 0;

  for (Match match in pattern.allMatches(content)) {
    // Add text before match
    if (match.start > start) {
      spans.add(TextSpan(text: content.substring(start, match.start)));
    }

    final matchedText = match.group(0)!;

    if (matchedText.startsWith('#')) {
      // Handle hashtag
      spans.add(
        TextSpan(
          text: matchedText,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // Handle hashtag tap - could navigate to search/hashtag page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(
                    initialHashtag: matchedText,
                  ),
                ),
              );
            },
        ),
      );
    } else {
      // Handle URL
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

  // Add remaining text
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
