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
  bool _isChecking = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

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
    final color = _connectionStatus == 'آفلاین'
        ? Colors.red
        : _connectionStatus.contains('وای‌فای')
            ? Colors.green
            : Colors.blue;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: ValueKey(_connectionStatus),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isChecking)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          if (!_isChecking) ...[
            Icon(
              _connectionStatus == 'آفلاین'
                  ? Icons.cloud_off
                  : _connectionStatus.contains('وای‌فای')
                      ? Icons.wifi
                      : Icons.signal_cellular_alt,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            _connectionStatus,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
      initialIndex: 1, // اضافه کردن این خط

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
