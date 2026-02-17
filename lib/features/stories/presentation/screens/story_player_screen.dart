import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

import '../../domain/entities/entities.dart';
import '../../domain/entities/story_editor_models.dart' as editor_models;
import '../../domain/repositories/i_story_repository.dart';
import '../../core/story_enums.dart' hide StoryInteractionType;
import '../providers/story_providers.dart';
import '../widgets/sticker_factory.dart';
import 'story_progress_bar.dart';
import 'story_header.dart';
import 'story_actions.dart';
import 'story_viewers_sheet.dart';
import '../../../../utils/const.dart';
import '../../../../utils/navigation_helper.dart';
import '../../../../utils/user_friendly_error_utils.dart';

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
  StoryReplyPermission _replyPermission = StoryReplyPermission.everyone;
  bool _canReplyToStory = true;
  final Map<String, StoryPollResult> _pollResultsCache = {};
  final Set<String> _submittingPollVotes = {};
  final AudioPlayer _musicPreviewPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _musicPlayerStateSub;
  Timer? _musicPreviewStopTimer;
  String? _playingMusicElementId;

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

    _musicPlayerStateSub =
        _musicPreviewPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed ||
          !state.playing) {
        setState(() {
          _playingMusicElementId = null;
        });
      }
    });

    _initializeStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    _videoController?.dispose();
    _musicPreviewStopTimer?.cancel();
    _musicPlayerStateSub?.cancel();
    _musicPreviewPlayer.dispose();
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
    await _stopMusicPreview();
    setState(() => _isLoading = true);

    _progressController.reset();

    // Track view + resolve reply permission state for current story.
    final repository = ref.read(storyRepositoryProvider);
    await repository.trackView(_currentStory.id);
    await _loadReplyState(repository);

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

  Future<void> _loadReplyState(IStoryRepository repository) async {
    if (_isOwnStory) {
      if (!mounted) return;
      setState(() {
        _replyPermission = StoryReplyPermission.everyone;
        _canReplyToStory = false;
      });
      return;
    }

    final permissionResult = await repository.getStoryReplyPermission(
      userId: _currentStory.userId,
    );
    final canReplyResult = await repository.canReplyToStory(
      storyId: _currentStory.id,
      ownerId: _currentStory.userId,
    );

    if (!mounted) return;
    setState(() {
      _replyPermission = permissionResult.data ?? StoryReplyPermission.everyone;
      _canReplyToStory = canReplyResult.data ?? false;
    });
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
    final wasPausedBeforeSheet = _isPaused;

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
        story: _currentStory,
        onClose: () {
          Navigator.pop(context);
        },
      ),
    ).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _showingViewers = false;
        _isPaused = wasPausedBeforeSheet;
      });
      if (!wasPausedBeforeSheet) {
        _progressController.forward();
        _videoController?.play();
      }
    });
  }

  double _dragOffsetY = 0.0;

  @override
  Widget build(BuildContext context) {
    // Calculate scale based on drag offset (max scale down to 0.8)
    final double scale =
        1.0 - (_dragOffsetY.abs() / MediaQuery.of(context).size.height * 0.3);

    return Scaffold(
      backgroundColor:
          Colors.black, // Keep background black so it reveals behind
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffsetY += details.delta.dy;
          });
        },
        onVerticalDragEnd: (details) {
          // If dragged down significantly or flicked down
          if (_dragOffsetY > 100 || (details.primaryVelocity ?? 0) > 500) {
            Navigator.of(context).pop();
          } else if (_isOwnStory && (details.primaryVelocity ?? 0) < -500) {
            // Flick up for own story -> Show Viewers
            _showViewers();
            setState(() => _dragOffsetY = 0);
          } else {
            // Snap back
            setState(() => _dragOffsetY = 0);
          }
        },
        child: AnimatedContainer(
          duration: _dragOffsetY == 0
              ? const Duration(milliseconds: 200)
              : Duration.zero,
          transform: Matrix4.translationValues(0, _dragOffsetY, 0)
            ..scale(scale),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_dragOffsetY == 0 ? 0 : 20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_dragOffsetY == 0 ? 0 : 20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // محتوای استوری
                _buildContent(),

                // نوار پیشرفت
                if (_dragOffsetY == 0) // Hide UI when dragging for cleaner look
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
                if (_dragOffsetY == 0) // Hide UI when dragging
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
                if (_dragOffsetY == 0) // Hide UI when dragging
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 16,
                    right: 16,
                    child: StoryActions(
                      story: _currentStory,
                      isOwnStory: _isOwnStory,
                      storyOwnerUsername: _currentUser.username,
                      replyPermission: _replyPermission,
                      canReply: _canReplyToStory,
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

    final storySize = MediaQuery.of(context).size;
    return List<Widget>.generate(elements.length, (index) {
      final element = elements[index];
      final left = _resolveElementCoordinate(
        absolute: element.x,
        normalized: element.xNorm,
        maxSize: storySize.width,
      );
      final top = _resolveElementCoordinate(
        absolute: element.y,
        normalized: element.yNorm,
        maxSize: storySize.height,
      );

      return Positioned(
        left: left,
        top: top,
        child: Transform.rotate(
          angle: element.rotation,
          child: Transform.scale(
            scale: element.scale,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleElementTap(element, index),
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

  double _resolveElementCoordinate({
    required double absolute,
    required double? normalized,
    required double maxSize,
  }) {
    if (normalized != null && normalized.isFinite && maxSize > 0) {
      return normalized.clamp(0.0, 1.0) * maxSize;
    }
    if (!absolute.isFinite) return 0;
    return absolute;
  }

  String? _resolveElementId(StoryElement element, int index) {
    final fromElement = element.elementId?.trim();
    if (fromElement != null && fromElement.isNotEmpty) return fromElement;

    final fromData = element.interactionData?['elementId']?.toString().trim() ??
        element.interactionData?['element_id']?.toString().trim() ??
        element.interactionData?['id']?.toString().trim();

    if (fromData != null && fromData.isNotEmpty) return fromData;
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<String> _extractPollOptions(Map<String, dynamic> data) {
    final rawOptions = data['options'];
    if (rawOptions is List) {
      final list = rawOptions
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
      if (list.length >= 2) {
        return [list[0], list[1]];
      }
    }

    final option1 = data['option1']?.toString().trim();
    final option2 = data['option2']?.toString().trim();
    return [
      (option1 != null && option1.isNotEmpty) ? option1 : 'گزینه ۱',
      (option2 != null && option2.isNotEmpty) ? option2 : 'گزینه ۲',
    ];
  }

  void _handleElementTap(StoryElement element, int index) {
    switch (element.interactionType) {
      case editor_models.StoryInteractionType.poll:
        _handlePollTap(element, index);
        break;
      case editor_models.StoryInteractionType.question:
        _showQuestionAnswerSheet(element, index);
        break;
      case editor_models.StoryInteractionType.link:
        _openLink(element.interactionData?['url']?.toString());
        break;
      case editor_models.StoryInteractionType.location:
      case editor_models.StoryInteractionType.weather:
        _openLocation(element.interactionData);
        break;
      case editor_models.StoryInteractionType.mention:
        _openProfile(element.interactionData?['username']?.toString());
        break;
      case editor_models.StoryInteractionType.hashtag:
        _openHashtag(element.interactionData?['hashtag']?.toString());
        break;
      case editor_models.StoryInteractionType.music:
        _toggleMusicPreview(element, index);
        break;
      case editor_models.StoryInteractionType.countdown:
        _showCountdownInfo(element);
        break;
      case editor_models.StoryInteractionType.gif:
      case editor_models.StoryInteractionType.date:
      case editor_models.StoryInteractionType.photo:
      case editor_models.StoryInteractionType.none:
        break;
    }
  }

  Future<void> _handlePollTap(StoryElement element, int index) async {
    final elementId = _resolveElementId(element, index);
    if (elementId == null || elementId.isEmpty) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'این نظرسنجی نسخه قدیمی است و قابل رأی دادن نیست',
        );
      }
      return;
    }

    StoryPollResult? cached = _pollResultsCache[elementId];
    if (cached == null) {
      final repository = ref.read(storyRepositoryProvider);
      final result = await repository.getPollResults(
        storyId: _currentStory.id,
        elementId: elementId,
      );

      if (result.isSuccess && result.data != null) {
        cached = result.data!;
        _pollResultsCache[elementId] = cached;
      }
    }

    if (cached?.hasVoted == true) {
      _showPollResultsBottomSheet(element, cached!);
      return;
    }

    _showPollVoteBottomSheet(
      element: element,
      elementId: elementId,
      existingResult: cached,
    );
  }

  void _showPollVoteBottomSheet({
    required StoryElement element,
    required String elementId,
    StoryPollResult? existingResult,
  }) {
    final data = element.interactionData ?? const {};
    final question = (existingResult?.question.trim().isNotEmpty ?? false)
        ? existingResult!.question
        : (data['question']?.toString().trim().isNotEmpty ?? false)
            ? data['question'].toString()
            : 'نظرسنجی';
    final options = (existingResult?.options.isNotEmpty ?? false)
        ? existingResult!.options
            .map((option) => option.text)
            .toList(growable: false)
        : _extractPollOptions(data);

    _progressController.stop();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSubmitting = _submittingPollVotes.contains(elementId);
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Vazir',
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (int i = 0; i < options.length; i++) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() {});
                                await _votePoll(
                                  element: element,
                                  elementId: elementId,
                                  optionIndex: i,
                                  sheetContext: ctx,
                                );
                                if (mounted) {
                                  setModalState(() {});
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: i.isEven ? Colors.blue : Colors.pink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          options[i],
                          style: const TextStyle(fontFamily: 'Vazir'),
                        ),
                      ),
                    ),
                    if (i != options.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      if (!_isPaused) _progressController.forward();
    });
  }

  void _showPollResultsBottomSheet(
      StoryElement element, StoryPollResult result) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.question.trim().isNotEmpty
                  ? result.question
                  : (element.interactionData?['question']?.toString() ??
                      'نتایج نظرسنجی'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazir',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${result.totalVotes} رای',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamily: 'Vazir',
              ),
            ),
            const SizedBox(height: 16),
            ...result.options.map((option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildPollResultRow(option, result.userOptionIndex),
                )),
          ],
        ),
      ),
    ).then((_) {
      if (!_isPaused) _progressController.forward();
    });
  }

  Widget _buildPollResultRow(
    StoryPollOptionResult option,
    int? userOptionIndex,
  ) {
    final isSelected = userOptionIndex == option.optionIndex;
    final ratio = (option.percentage / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontFamily: 'Vazir',
                ),
              ),
            ),
            Text(
              '${option.percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
              isSelected ? Colors.greenAccent : Colors.blueAccent,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${option.votes} رای',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontFamily: 'Vazir',
          ),
        ),
      ],
    );
  }

  Future<void> _votePoll({
    required StoryElement element,
    required String elementId,
    required int optionIndex,
    required BuildContext sheetContext,
  }) async {
    if (_submittingPollVotes.contains(elementId)) return;
    setState(() {
      _submittingPollVotes.add(elementId);
    });

    final repository = ref.read(storyRepositoryProvider);
    final voteResult = await repository.voteOnPoll(
      storyId: _currentStory.id,
      elementId: elementId,
      optionIndex: optionIndex,
    );

    if (!mounted) return;

    if (voteResult.isSuccess) {
      ref.invalidate(
        storyPollResultsProvider(
          (storyId: _currentStory.id, elementId: elementId),
        ),
      );

      final result = await repository.getPollResults(
        storyId: _currentStory.id,
        elementId: elementId,
      );

      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        _pollResultsCache[elementId] = result.data!;
        if (sheetContext.mounted) {
          Navigator.of(sheetContext).pop();
        }
        _showPollResultsBottomSheet(element, result.data!);
      } else {
        if (sheetContext.mounted) {
          Navigator.of(sheetContext).pop();
        }
      }

      UserFriendlyErrorUtils.showSuccessSnackBar(context, 'رای شما ثبت شد');
    } else {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        voteResult.error ?? 'خطا در ثبت رای',
      );
    }

    if (mounted) {
      setState(() {
        _submittingPollVotes.remove(elementId);
      });
    }
  }

  void _showQuestionAnswerSheet(StoryElement element, int index) {
    final elementId = _resolveElementId(element, index);
    if (elementId == null || elementId.isEmpty) {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        'این سوال نسخه قدیمی است و قابل پاسخ نیست',
      );
      return;
    }

    final question = element.interactionData?['question']?.toString().trim();
    final answerController = TextEditingController();
    bool isSubmitting = false;

    _progressController.stop();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    question?.isNotEmpty == true ? question! : 'پاسخ به سوال',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Vazir',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: answerController,
                    autofocus: true,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'پاسخ خود را بنویسید...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final answer = answerController.text.trim();
                            if (answer.isEmpty) {
                              UserFriendlyErrorUtils.showErrorSnackBar(
                                context,
                                'پاسخ نمی‌تواند خالی باشد',
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            final success = await _submitQuestionAnswer(
                              elementId: elementId,
                              answer: answer,
                            );
                            if (!mounted) return;
                            setModalState(() => isSubmitting = false);
                            if (success && ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          },
                    child: Text(
                      isSubmitting ? 'در حال ارسال...' : 'ارسال پاسخ',
                      style: const TextStyle(fontFamily: 'Vazir'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      answerController.dispose();
      if (!_isPaused) {
        _progressController.forward();
      }
    });
  }

  Future<bool> _submitQuestionAnswer({
    required String elementId,
    required String answer,
  }) async {
    final repository = ref.read(storyRepositoryProvider);
    final result = await repository.submitQuestionAnswer(
      storyId: _currentStory.id,
      elementId: elementId,
      answer: answer,
    );

    if (!mounted) return false;

    if (result.isSuccess) {
      ref.invalidate(storyQuestionAnswersProvider(_currentStory.id));
      UserFriendlyErrorUtils.showSuccessSnackBar(context, 'پاسخ شما ثبت شد');
      return true;
    }

    UserFriendlyErrorUtils.showErrorSnackBar(
      context,
      result.error ?? 'خطا در ثبت پاسخ',
    );
    return false;
  }

  Future<void> _toggleMusicPreview(StoryElement element, int index) async {
    final elementId = _resolveElementId(element, index) ?? 'music_$index';
    final data = element.interactionData ?? const {};
    final musicUrl =
        data['musicUrl']?.toString() ?? data['music_url']?.toString() ?? '';

    if (musicUrl.trim().isEmpty) {
      UserFriendlyErrorUtils.showErrorSnackBar(
          context, 'لینک موزیک معتبر نیست');
      return;
    }

    try {
      if (_playingMusicElementId == elementId && _musicPreviewPlayer.playing) {
        await _stopMusicPreview();
        return;
      }

      final startSec =
          _toInt(data['startSec']) ?? _toInt(data['start_sec']) ?? 0;
      final durationSec =
          _toInt(data['durationSec']) ?? _toInt(data['duration_sec']) ?? 30;

      await _musicPreviewPlayer.stop();
      _musicPreviewStopTimer?.cancel();

      await _musicPreviewPlayer.setUrl(musicUrl.trim());
      if (startSec > 0) {
        await _musicPreviewPlayer.seek(Duration(seconds: startSec));
      }
      await _musicPreviewPlayer.play();

      if (mounted) {
        setState(() {
          _playingMusicElementId = elementId;
        });
      }

      if (durationSec > 0) {
        _musicPreviewStopTimer =
            Timer(Duration(seconds: durationSec), () async {
          await _stopMusicPreview();
        });
      }
    } catch (e) {
      if (!mounted) return;
      UserFriendlyErrorUtils.showErrorSnackBar(context, e);
    }
  }

  void _showCountdownInfo(StoryElement element) {
    final data = element.interactionData ?? const {};
    final title = data['title']?.toString().trim().isNotEmpty == true
        ? data['title'].toString().trim()
        : 'شمارش معکوس';
    final targetDateRaw =
        data['targetDate']?.toString() ?? data['endDate']?.toString() ?? '';
    final targetDate = DateTime.tryParse(targetDateRaw);

    String message;
    if (targetDate == null) {
      message = '$title: زمان نامعتبر';
    } else {
      final remaining = targetDate.difference(DateTime.now());
      if (remaining.isNegative) {
        message = '$title: زمان به پایان رسیده';
      } else {
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        final mins = remaining.inMinutes % 60;
        message = '$title: $days روز و $hours ساعت و $mins دقیقه باقی مانده';
      }
    }

    UserFriendlyErrorUtils.showSuccessSnackBar(context, message);
  }

  Future<void> _stopMusicPreview() async {
    _musicPreviewStopTimer?.cancel();
    _musicPreviewStopTimer = null;
    try {
      await _musicPreviewPlayer.pause();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _playingMusicElementId = null;
      });
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.trim().isEmpty) {
      UserFriendlyErrorUtils.showErrorSnackBar(context, 'لینک معتبر نیست');
      return;
    }

    Uri? uri = Uri.tryParse(url.trim());
    if (uri == null) {
      UserFriendlyErrorUtils.showErrorSnackBar(context, 'لینک معتبر نیست');
      return;
    }

    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://${url.trim()}');
    }

    if (uri == null ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https')) {
      UserFriendlyErrorUtils.showErrorSnackBar(context, 'لینک معتبر نیست');
      return;
    }

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'امکان باز کردن لینک وجود ندارد',
        );
      }
    } catch (error) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _openLocation(Map<String, dynamic>? data) async {
    if (data == null) {
      UserFriendlyErrorUtils.showErrorSnackBar(
          context, 'موقعیت مکانی معتبر نیست');
      return;
    }

    final lat = _toDouble(data['latitude'] ?? data['lat']);
    final lng = _toDouble(data['longitude'] ?? data['lng']);
    final label = data['name']?.toString() ?? data['city']?.toString() ?? '';

    Uri? mapUri;
    if (lat != null && lng != null) {
      mapUri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    } else if (label.trim().isNotEmpty) {
      mapUri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(label.trim())}',
      );
    }

    if (mapUri == null) {
      UserFriendlyErrorUtils.showErrorSnackBar(
          context, 'موقعیت مکانی معتبر نیست');
      return;
    }

    try {
      final launched =
          await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'امکان باز کردن نقشه وجود ندارد',
        );
      }
    } catch (error) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, error);
      }
    }
  }

  void _openProfile(String? username) {
    if (username == null || username.trim().isEmpty) {
      UserFriendlyErrorUtils.showErrorSnackBar(
          context, 'نام کاربری معتبر نیست');
      return;
    }
    NavigationHelper.navigateToUserProfile(context, username);
  }

  void _openHashtag(String? hashtag) {
    if (hashtag == null || hashtag.trim().isEmpty) {
      UserFriendlyErrorUtils.showErrorSnackBar(context, 'هشتگ معتبر نیست');
      return;
    }
    NavigationHelper.navigateToHashtagPosts(context, hashtag);
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
    Navigator.pop(context);

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
      final result = await repository.deleteStory(_currentStory.id);

      if (!mounted) return;
      if (result.isSuccess) {
        ref.invalidate(activeStoriesProvider);
        Navigator.of(context).pop();
        UserFriendlyErrorUtils.showSuccessSnackBar(context, 'استوری حذف شد');
      } else {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          result.error ?? 'خطا در حذف استوری',
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
      final result =
          await repository.reportStory(_currentStory.id, selectedReason);

      if (!mounted) return;
      if (result.isSuccess) {
        UserFriendlyErrorUtils.showSuccessSnackBar(context, 'گزارش شما ثبت شد');
      } else {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          result.error ?? 'خطا در ثبت گزارش',
        );
      }
    }
  }

  Future<void> _shareStory() async {
    Navigator.pop(context);

    final owner = _currentUser.username.trim().isNotEmpty
        ? _currentUser.username.trim()
        : 'کاربر';
    final caption = _currentStory.caption?.trim() ?? '';
    final mediaUrl = _currentStory.media.url.trim();

    final payload = StringBuffer('استوری $owner در Vista');
    if (caption.isNotEmpty) {
      payload.write('\n$caption');
    }
    if (mediaUrl.isNotEmpty) {
      payload.write('\n$mediaUrl');
    }

    try {
      await Share.share(payload.toString());
    } catch (error) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _replyToStory(String message) async {
    if (!_canReplyToStory) {
      final blockedMessage = switch (_replyPermission) {
        StoryReplyPermission.off => 'پاسخ به این استوری غیرفعال است',
        StoryReplyPermission.following =>
          'فقط دنبال‌شده‌های صاحب استوری می‌توانند پاسخ دهند',
        StoryReplyPermission.everyone => 'ارسال پاسخ ممکن نیست',
      };
      UserFriendlyErrorUtils.showErrorSnackBar(context, blockedMessage);
      return;
    }

    final repository = ref.read(storyRepositoryProvider);
    final result = await repository.replyToStory(_currentStory.id, message);

    if (!mounted) return;
    if (result.isSuccess) {
      UserFriendlyErrorUtils.showSuccessSnackBar(context, 'پاسخ ارسال شد');
    } else {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        result.error ?? 'خطا در ارسال پاسخ',
      );
    }
  }

  Future<void> _reactToStory(StoryReactionType reaction) async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.reactToStory(_currentStory.id, reaction);
  }
}
