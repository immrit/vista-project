import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../domain/entities/entities.dart';
import '../../core/story_enums.dart';
import '../providers/story_providers.dart';
import '../widgets/sticker_factory.dart';
import 'story_progress_bar.dart';
import 'story_header.dart';
import 'story_actions.dart';
import 'story_viewers_sheet.dart';
import '../../../../utils/const.dart';

/// صفحه پخش استوری
class StoryPlayerScreen extends ConsumerStatefulWidget {
  final List<StoryUser> users;
  final int initialUserIndex;
  final int initialStoryIndex;

  const StoryPlayerScreen({
    super.key,
    required this.users,
    required this.initialUserIndex,
    this.initialStoryIndex = 0,
  });

  @override
  ConsumerState<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends ConsumerState<StoryPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late PageController _pageController;
  VideoPlayerController? _videoController;

  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  bool _isPaused = false;
  bool _isLoading = true;
  bool _showingViewers = false;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _currentStoryIndex = widget.initialStoryIndex;

    _progressController = AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: StoryConstants.defaultStoryDurationSeconds),
    )..addStatusListener(_onProgressComplete);

    _pageController = PageController(initialPage: _currentUserIndex);

    // Full screen immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initializeStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  StoryUser get _currentUser => widget.users[_currentUserIndex];
  Story get _currentStory => _currentUser.stories[_currentStoryIndex];
  bool get _isOwnStory => _currentStory.userId == supabase.auth.currentUser?.id;

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStory();
    }
  }

  Future<void> _initializeStory() async {
    setState(() => _isLoading = true);

    _progressController.reset();

    // Track view
    final repository = ref.read(storyRepositoryProvider);
    await repository.trackView(_currentStory.id);

    if (_currentStory.media.isVideo) {
      await _initVideo();
    } else {
      await _preloadImage();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _progressController.forward();
    }
  }

  Future<void> _initVideo() async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(_currentStory.media.url),
    );

    try {
      await _videoController!.initialize();

      // Set duration based on video length
      final videoDuration = _videoController!.value.duration;
      _progressController.duration = videoDuration;

      _videoController!.play();
      _videoController!.setLooping(false);
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  Future<void> _preloadImage() async {
    try {
      await precacheImage(
        CachedNetworkImageProvider(_currentStory.media.url),
        context,
      );
    } catch (e) {
      debugPrint('Error preloading image: $e');
    }
  }

  void _nextStory() {
    if (_currentStoryIndex < _currentUser.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _initializeStory();
    } else if (_currentUserIndex < widget.users.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _initializeStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _initializeStory();
    } else if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex = widget.users[_currentUserIndex].stories.length - 1;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _initializeStory();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _progressController.stop();
        _videoController?.pause();
      } else {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  void _onTapDown(TapDownDetails details) {
    if (_showingViewers) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth * 0.3) {
      _previousStory();
    } else if (dx > screenWidth * 0.7) {
      _nextStory();
    } else {
      _togglePause();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _progressController.stop();
    _videoController?.pause();
    setState(() => _isPaused = true);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_showingViewers) {
      _progressController.forward();
      _videoController?.play();
      setState(() => _isPaused = false);
    }
  }

  void _showViewers() {
    setState(() {
      _showingViewers = true;
      _isPaused = true;
    });
    _progressController.stop();
    _videoController?.pause();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoryViewersSheet(
        storyId: _currentStory.id,
        onClose: () {
          Navigator.pop(context);
          setState(() => _showingViewers = false);
          if (!_isPaused) {
            _progressController.forward();
            _videoController?.play();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          } else if (_isOwnStory &&
              details.primaryVelocity != null &&
              details.primaryVelocity! < -300) {
            _showViewers();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // محتوای استوری
            _buildContent(),

            // نوار پیشرفت
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: StoryProgressBar(
                storiesCount: _currentUser.stories.length,
                currentIndex: _currentStoryIndex,
                controller: _progressController,
              ),
            ),

            // هدر
            Positioned(
              top: MediaQuery.of(context).padding.top + 24,
              left: 0,
              right: 0,
              child: StoryHeader(
                user: _currentUser,
                story: _currentStory,
                onClose: () => Navigator.of(context).pop(),
                onOptions: () => _showOptions(),
              ),
            ),

            // اکشن‌ها (پایین صفحه)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 16,
              right: 16,
              child: StoryActions(
                story: _currentStory,
                isOwnStory: _isOwnStory,
                onReply: (message) => _replyToStory(message),
                onReact: (reaction) => _reactToStory(reaction),
                onViewers: _isOwnStory ? _showViewers : null,
              ),
            ),

            // لودینگ
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background media (image or video)
        _buildMediaBackground(),

        // Interactive elements (stickers, text) from Story Editor
        ..._buildInteractiveElements(),
      ],
    );
  }

  Widget _buildMediaBackground() {
    if (_currentStory.media.isVideo && _videoController != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: _currentStory.media.url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheHeight: 1600, // Optimize memory usage
      placeholder: (context, url) => Container(color: Colors.black),
      errorWidget: (context, url, error) {
        debugPrint('Story Image Error: $error'); // Log detail error
        return const Center(
          child: Icon(Icons.error, color: Colors.white, size: 48),
        );
      },
    );
  }

  List<Widget> _buildInteractiveElements() {
    final elements = _currentStory.interactiveElements;
    if (elements == null || elements.isEmpty) return [];

    return elements.map((element) {
      return Positioned(
        left: element.x,
        top: element.y,
        child: Transform.rotate(
          angle: element.rotation,
          child: Transform.scale(
            scale: element.scale,
            child: GestureDetector(
              onTap: () => _handleElementTap(element),
              child: StickerFactory.buildSticker(
                element,
                isEditable: false, // Viewer mode - tap triggers interaction
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _handleElementTap(dynamic element) {
    // Handle different sticker types in viewer mode
    switch (element.interactionType) {
      case StoryInteractionType.poll:
        _showPollVoteDialog(element);
        break;
      case StoryInteractionType.link:
        _openLink(element.interactionData?['url']);
        break;
      case StoryInteractionType.location:
        _openLocation(element.interactionData);
        break;
      case StoryInteractionType.mention:
        _openProfile(element.interactionData?['username']);
        break;
      case StoryInteractionType.hashtag:
        _openHashtag(element.interactionData?['hashtag']);
        break;
      default:
        debugPrint('Tapped element: ${element.interactionType}');
    }
  }

  void _showPollVoteDialog(dynamic element) {
    final data = element.interactionData ?? {};
    final question = data['question'] ?? 'سوال';
    final option1 = data['option1'] ?? 'گزینه ۱';
    final option2 = data['option2'] ?? 'گزینه ۲';

    _progressController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _votePoll(0, ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(option1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _votePoll(1, ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(option2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) {
      if (!_isPaused) _progressController.forward();
    });
  }

  Future<void> _votePoll(int optionIndex, BuildContext ctx) async {
    Navigator.pop(ctx);
    final repository = ref.read(storyRepositoryProvider);
    await repository.voteOnPoll(_currentStory.id, optionIndex.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رأی شما ثبت شد')),
      );
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null) return;
    debugPrint('Opening link: $url');
    // TODO: Use url_launcher to open link
    // await launchUrl(Uri.parse(url));
  }

  void _openLocation(Map<String, dynamic>? data) {
    if (data == null) return;
    final lat = data['latitude'];
    final lng = data['longitude'];
    debugPrint('Opening location: $lat, $lng');
    // TODO: Open map with lat/lng
  }

  void _openProfile(String? username) {
    if (username == null) return;
    debugPrint('Opening profile: @$username');
    // TODO: Navigate to profile screen
  }

  void _openHashtag(String? hashtag) {
    if (hashtag == null) return;
    debugPrint('Opening hashtag: #$hashtag');
    // TODO: Navigate to hashtag search
  }

  void _showOptions() {
    _progressController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (_isOwnStory) ...[
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('مشاهده‌کنندگان'),
                  onTap: () {
                    Navigator.pop(context);
                    _showViewers();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('حذف استوری',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => _deleteStory(),
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report),
                  title: const Text('گزارش'),
                  onTap: () => _reportStory(),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('اشتراک‌گذاری'),
                onTap: () => _shareStory(),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (!_isPaused) {
        _progressController.forward();
      }
    });
  }

  Future<void> _deleteStory() async {
    Navigator.pop(context); // Close bottom sheet

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف استوری'),
        content: const Text('آیا از حذف این استوری مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
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
      final repository = ref.read(storyRepositoryProvider);
      await repository.deleteStory(_currentStory.id);
      ref.invalidate(activeStoriesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('استوری حذف شد')),
        );
      }
    }
  }

  Future<void> _reportStory() async {
    Navigator.pop(context);

    final reasons = [
      'محتوای نامناسب',
      'محتوای خشونت‌آمیز',
      'اسپم',
      'نقض حق نشر',
      'سایر موارد',
    ];

    final selectedReason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گزارش استوری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map((reason) => ListTile(
                    title: Text(reason),
                    onTap: () => Navigator.pop(context, reason),
                  ))
              .toList(),
        ),
      ),
    );

    if (selectedReason != null) {
      final repository = ref.read(storyRepositoryProvider);
      await repository.reportStory(_currentStory.id, selectedReason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('گزارش شما ثبت شد')),
        );
      }
    }
  }

  void _shareStory() {
    Navigator.pop(context);
    // TODO: Implement share
  }

  Future<void> _replyToStory(String message) async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.replyToStory(_currentStory.id, message);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پاسخ ارسال شد')),
      );
    }
  }

  Future<void> _reactToStory(StoryReactionType reaction) async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.reactToStory(_currentStory.id, reaction);
  }
}
