import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../domain/entities/entities.dart';
import '../../domain/entities/story_editor_models.dart' as editor_models;
import '../../core/story_enums.dart' hide StoryInteractionType;
import '../providers/story_providers.dart';
import '../widgets/sticker_factory.dart';
import 'story_progress_bar.dart';
import 'story_header.dart';
import 'story_actions.dart';
import 'story_viewers_sheet.dart';
import '../../../../utils/navigation_helper.dart';
import '../../../../utils/user_friendly_error_utils.dart';
import '../../../../services/current_user_service.dart';
import '../../../chat/screens/modern_chat_screen.dart';
import '../../../../model/message_model.dart';
import '../../../chat/utils/story_reply_media_utils.dart';
import '../../../chat/providers/chat_providers.dart';
import '../../../../provider/optimized_conversations_provider.dart';
import '../../utils/story_preloader.dart';

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
  VideoPlayerController? _videoController;

  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  bool _isPaused = false;
  bool _isLoading = true;
  bool _showingViewers = false;
  bool _isLongPressing = false;
  bool _videoError = false;
  // Set while delete/report keep their own confirm dialog open, so the
  // options-sheet close callback doesn't auto-resume playback under it.
  bool _suspendAutoResume = false;
  StoryReplyPermission _replyPermission = StoryReplyPermission.everyone;
  bool _canReplyToStory = true;
  final Map<String, StoryPollResult> _pollResultsCache = {};
  final Set<String> _submittingPollVotes = {};
  final AudioPlayer _musicPreviewPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _musicPlayerStateSub;
  Timer? _musicPreviewStopTimer;
  String? _playingMusicElementId;
  String? _currentUserId;
  bool _isReplySending = false;

  // Stores the pointer-down position so onTap (which is arena-resolved)
  // can decide prev/pause/next without firing when a child sticker wins.
  Offset? _lastTapPosition;
  int _userTransitionDirection = 1; // 1 => next user, -1 => previous user.

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
  void deactivate() {
    // ref is still valid here; using it in dispose() throws StateError.
    ref.invalidate(activeStoriesProvider);
    super.deactivate();
  }

  @override
  void dispose() {
    _dragOffsetY.dispose();
    _progressController.dispose();
    _videoController?.dispose();
    _musicPreviewStopTimer?.cancel();
    _musicPlayerStateSub?.cancel();
    _musicPreviewPlayer.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  StoryUser get _currentUser => widget.users[_currentUserIndex];
  Story get _currentStory => _currentUser.stories[_currentStoryIndex];
  bool get _isOwnStory => _currentStory.userId == _currentUserId;
  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStory();
    }
  }

  /// Stops the progress timer AND the video together — every sheet/dialog
  /// must use this instead of stopping only the timer, otherwise video
  /// stories keep playing (audio included) behind the sheet and drift out
  /// of sync with the progress bar.
  void _pausePlayback() {
    _progressController.stop();
    _videoController?.pause();
  }

  /// Resumes both unless the user has explicitly paused or the viewers
  /// sheet is showing.
  void _resumePlaybackIfIdle() {
    if (_isPaused || _showingViewers || !mounted) return;
    _progressController.forward();
    _videoController?.play();
  }

  Future<void> _initializeStory() async {
    await _stopMusicPreview();
    setState(() {
      _isLoading = true;
      _videoError = false;
      // A pause belongs to the story it was made on; a story change always
      // starts playing. Leaving this true made sheet-close callbacks skip
      // their resume and froze the new story until an extra tap.
      _isPaused = false;
    });

    _progressController.reset();

    _currentUserId = await CurrentUserService.instance.resolveUserId();

    // PERF: never gate media start on network. trackView is fire-and-forget
    // analytics; reply state applies itself via setState when it returns.
    final repository = ref.read(storyRepositoryProvider);
    final storyId = _currentStory.id;

    unawaited(repository.trackView(storyId));
    unawaited(_loadReplyState());

    // Preload the next 10 stories in the background
    StoryPreloader.preloadNextStories(
      context, 
      widget.users, 
      _currentUserIndex, 
      _currentStoryIndex, 
      count: 10,
      maxVideos: 2,
    );

    // Optimistically update seen rings in the active stories provider.
    if (mounted) {
      ref.read(sessionSeenStoriesProvider.notifier).markSeen(storyId);
    }

    if (_currentStory.media.isVideo) {
      await _initVideo();
    } else {
      await _preloadImage();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      // On a failed video load, hold the timer: auto-advancing over a black
      // screen hides the failure. The error UI offers retry/skip instead.
      if (!_videoError) {
        _progressController.forward();
      }
    }
  }

  /// Loads reply permission from the authoritative /reply-access endpoint.
  Future<void> _loadReplyState() async {
    if (_isOwnStory) {
      if (!mounted) return;
      setState(() {
        _replyPermission = StoryReplyPermission.everyone;
        _canReplyToStory = false;
      });
      return;
    }

    final repository = ref.read(storyRepositoryProvider);
    final requestedStoryId = _currentStory.id;
    final accessResult =
        await repository.getStoryReplyAccess(requestedStoryId);

    // User may have advanced to another story while the request was in flight.
    if (!mounted || _currentStory.id != requestedStoryId) return;
    accessResult.fold(
      (_) {
        final canReply = _currentStory.viewerCanReply;
        setState(() {
          _canReplyToStory = canReply;
          _replyPermission = canReply
              ? StoryReplyPermission.everyone
              : StoryReplyPermission.off;
        });
      },
      (access) {
        setState(() {
          _canReplyToStory = access.canReply;
          _replyPermission = access.permission;
        });
      },
    );
  }

  Future<void> _initVideo() async {
    final currentStoryUrl = _currentStory.media.url;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(currentStoryUrl),
    );

    _videoController?.dispose();
    _videoController = controller;

    try {
      await controller.initialize();
      
      // If unmounted or user skipped to another story, dispose and abort
      if (!mounted || _videoController != controller) {
        controller.dispose();
        return;
      }

      // Set duration based on video length
      final videoDuration = controller.value.duration;
      _progressController.duration = videoDuration;

      // Listener for buffering logic
      controller.addListener(() {
        if (!mounted || _videoController != controller) return;
        if (controller.value.isBuffering) {
          if (_progressController.isAnimating) {
            _progressController.stop();
          }
        } else if (controller.value.isPlaying && !_isPaused) {
          if (!_progressController.isAnimating) {
            _progressController.forward();
          }
        }
      });

      controller.play();
      controller.setLooping(false);
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted && _videoController == controller) {
        setState(() => _videoError = true);
      }
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
      _userTransitionDirection = 1;
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
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
      _userTransitionDirection = -1;
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex = widget.users[_currentUserIndex].stories.length - 1;
      });
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

  // onTap is arena-resolved: fires only when no child GestureDetector wins.
  // This prevents sticker taps from also triggering prev/next/pause.
  void _onTap() {
    if (_showingViewers) return;
    final pos = _lastTapPosition;
    if (pos == null) return;
    _lastTapPosition = null;

    final screenWidth = MediaQuery.of(context).size.width;
    final dx = pos.dx;
    final leftActionIsNext = _isRtl;

    if (dx < screenWidth * 0.3) {
      if (leftActionIsNext) {
        _nextStory();
      } else {
        _previousStory();
      }
    } else if (dx > screenWidth * 0.7) {
      if (leftActionIsNext) {
        _previousStory();
      } else {
        _nextStory();
      }
    } else {
      _togglePause();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _progressController.stop();
    _videoController?.pause();
    setState(() {
      _isPaused = true;
      _isLongPressing = true;
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_showingViewers) {
      _progressController.forward();
      _videoController?.play();
      setState(() {
        _isPaused = false;
        _isLongPressing = false;
      });
    } else {
      setState(() => _isLongPressing = false);
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

  // PERF: drag offset lives in a ValueNotifier so pointer moves only rebuild
  // the transform wrapper below — never the media/sticker subtree.
  final ValueNotifier<double> _dragOffsetY = ValueNotifier<double>(0.0);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Prevent keyboard from crushing video
      body: GestureDetector(
        // Store position on down so onTap can use it.
        onTapDown: (d) => _lastTapPosition = d.globalPosition,
        // onTap is arena-resolved — child sticker taps win and suppress this.
        onTap: _onTap,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onVerticalDragUpdate: (details) {
          _dragOffsetY.value += details.delta.dy;
        },
        onVerticalDragEnd: (details) {
          // If dragged down significantly or flicked down
          if (_dragOffsetY.value > 100 ||
              (details.primaryVelocity ?? 0) > 500) {
            Navigator.of(context).pop();
          } else if (_isOwnStory && (details.primaryVelocity ?? 0) < -500) {
            // Flick up for own story -> Show Viewers
            _showViewers();
            _dragOffsetY.value = 0;
          } else {
            // Snap back
            _dragOffsetY.value = 0;
          }
        },
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffsetY,
          // Heavy subtree built once per state change, reused across drag frames.
          child: _buildAnimatedStoryContent(),
          builder: (context, dragOffsetY, storyContent) {
            // Calculate scale based on drag offset (max scale down to 0.8)
            final double scale =
                1.0 - (dragOffsetY.abs() / screenHeight * 0.3);
            final atRest = dragOffsetY == 0;

            return AnimatedContainer(
              duration: atRest
                  ? const Duration(milliseconds: 200)
                  : Duration.zero,
              transform: Matrix4.translationValues(0, dragOffsetY, 0)
                ..scale(scale),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(atRest ? 0 : 20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(atRest ? 0 : 20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // محتوای استوری
                    storyContent!,

                    // نوار پیشرفت
                    if (atRest && !_isLongPressing) // Hide UI when dragging or long pressing
                      Positioned(
                        top: topPadding + 8,
                        left: 8,
                        right: 8,
                        child: StoryProgressBar(
                          storiesCount: _currentUser.stories.length,
                          currentIndex: _currentStoryIndex,
                          controller: _progressController,
                        ),
                      ),

                    // هدر
                    if (atRest && !_isLongPressing) // Hide UI when dragging or long pressing
                      Positioned(
                        top: topPadding + 24,
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
                    if (atRest && !_isLongPressing) // Hide UI when dragging or long pressing
                      Positioned(
                        bottom: bottomPadding + 20,
                        left: 16,
                        right: 16,
                        child: StoryActions(
                          story: _currentStory,
                          isOwnStory: _isOwnStory,
                          storyOwnerUsername: _currentUser.username,
                          replyPermission: _replyPermission,
                          canReply: _canReplyToStory && !_isReplySending,
                          isReplySending: _isReplySending,
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
          },
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
        if (!_isLoading) ..._buildInteractiveElements(),
      ],
    );
  }

  /// Adds an Social-like transition only when switching between users.
  Widget _buildAnimatedStoryContent() {
    final rtlFactor = _isRtl ? -1.0 : 1.0;
    final signedDir = _userTransitionDirection * rtlFactor;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final bool isNext = child.key == ValueKey('story_${_currentUserIndex}_$_currentStoryIndex');
        
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final value = animation.value;
            // When entering (value goes 0->1)
            // When exiting (value goes 1->0)
            
            // We want the new screen to rotate from 90 degrees to 0.
            // We want the old screen to rotate from 0 to -90 degrees.
            final rotation = isNext ? (1 - value) * (math.pi / 2) * signedDir : -value * (math.pi / 2) * signedDir;
            
            // Alignment depends on direction
            final alignment = signedDir > 0
                ? (isNext ? Alignment.centerRight : Alignment.centerLeft)
                : (isNext ? Alignment.centerLeft : Alignment.centerRight);

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(rotation),
              alignment: alignment,
              child: Opacity(
                opacity: isNext ? value : 1 - value,
                child: child,
              ),
            );
          },
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey('story_${_currentUserIndex}_$_currentStoryIndex'),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildMediaBackground() {
    if (_currentStory.media.isVideo && _videoError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text(
              'ویدیو لود نشد',
              style: TextStyle(color: Colors.white70, fontFamily: 'Vazirmatn'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _initializeStory,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'تلاش مجدد',
                style: TextStyle(fontFamily: 'Vazirmatn'),
              ),
            ),
          ],
        ),
      );
    }

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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StickerFactory.buildSticker(
                  element,
                  isEditable: false, // Viewer mode - tap triggers interaction
                ),
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
        // Enrich backend results with option text from the story element data
        // (backend stores vote counts only, not the original text).
        final rawData = element.interactionData ?? const {};
        final optionTexts = _extractPollOptions(rawData);
        final rawQuestion = rawData['question']?.toString().trim() ?? '';
        final enriched = result.data!.copyWith(
          question:
              rawQuestion.isNotEmpty ? rawQuestion : result.data!.question,
          options: result.data!.options.map((opt) {
            final label = opt.optionIndex < optionTexts.length
                ? optionTexts[opt.optionIndex]
                : '';
            return opt.copyWith(
              text: label.isNotEmpty ? label : opt.text,
            );
          }).toList(),
        );
        cached = enriched;
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

    _pausePlayback();
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
                      fontFamily: 'Vazirmatn',
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
                          style: const TextStyle(fontFamily: 'Vazirmatn'),
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
      _resumePlaybackIfIdle();
    });
  }

  void _showPollResultsBottomSheet(
      StoryElement element, StoryPollResult result) {
    _pausePlayback();
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
                fontFamily: 'Vazirmatn',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${result.totalVotes} رای',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamily: 'Vazirmatn',
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
      _resumePlaybackIfIdle();
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
                  fontFamily: 'Vazirmatn',
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
            fontFamily: 'Vazirmatn',
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

    _pausePlayback();

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
                      fontFamily: 'Vazirmatn',
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
                      style: const TextStyle(fontFamily: 'Vazirmatn'),
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
      _resumePlaybackIfIdle();
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
    _pausePlayback();

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
      // Delete/report open a follow-up dialog and manage the resume
      // themselves — resuming here would let the story advance underneath
      // that dialog and change _currentStory before the action runs.
      if (!_suspendAutoResume) {
        _resumePlaybackIfIdle();
      }
    });
  }

  Future<void> _deleteStory() async {
    // Pin the story id NOW — if playback advanced while any dialog was up,
    // reading _currentStory later would delete the WRONG story.
    final storyId = _currentStory.id;
    _suspendAutoResume = true;
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
    _suspendAutoResume = false;
    if (!mounted) return;

    if (confirmed != true) {
      _resumePlaybackIfIdle();
      return;
    }

    final repository = ref.read(storyRepositoryProvider);
    final result = await repository.deleteStory(storyId);

    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(activeStoriesProvider);
      Navigator.of(context).pop();
      UserFriendlyErrorUtils.showSuccessSnackBar(context, 'استوری حذف شد');
    } else {
      _resumePlaybackIfIdle();
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        result.error ?? 'خطا در حذف استوری',
      );
    }
  }

  Future<void> _reportStory() async {
    // Pin the story id NOW — same wrong-target hazard as _deleteStory.
    final storyId = _currentStory.id;
    _suspendAutoResume = true;
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
    _suspendAutoResume = false;
    if (!mounted) return;

    if (selectedReason == null) {
      _resumePlaybackIfIdle();
      return;
    }

    final repository = ref.read(storyRepositoryProvider);
    final result = await repository.reportStory(storyId, selectedReason);

    if (!mounted) return;
    _resumePlaybackIfIdle();
    if (result.isSuccess) {
      UserFriendlyErrorUtils.showSuccessSnackBar(context, 'گزارش شما ثبت شد');
    } else {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        result.error ?? 'خطا در ثبت گزارش',
      );
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
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    if (!_canReplyToStory || _isReplySending) {
      final blockedMessage = switch (_replyPermission) {
        StoryReplyPermission.off => 'پاسخ به این استوری غیرفعال است',
        StoryReplyPermission.following =>
          'فقط دنبال‌شده‌های صاحب استوری می‌توانند پاسخ دهند',
        StoryReplyPermission.everyone => 'پاسخ به این استوری در دسترس نیست',
      };
      UserFriendlyErrorUtils.showErrorSnackBar(context, blockedMessage);
      return;
    }

    setState(() => _isReplySending = true);
    _progressController.stop();
    _videoController?.pause();

    final repository = ref.read(storyRepositoryProvider);
    final result = await repository.replyToStory(_currentStory.id, trimmed);

    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _isReplySending = false);
      if (!_isPaused) {
        _progressController.forward();
        _videoController?.play();
      }
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        result.error ?? 'خطا در ارسال پاسخ',
      );
      return;
    }

    // Mirror note replies: also deliver as a DM with story context.
    final conversationId = await _resolveConversationWithOwner();
    if (conversationId != null && mounted) {
      final ownerUsername = _currentUser.username;
      final storyReplyMeta = _buildStoryReplyMeta();
      final dmResult =
          await ref.read(chatActionControllerProvider.notifier).sendMessage(
                conversationId: conversationId,
                content: trimmed,
                replyToMessageId: 'story:${_currentStory.id}',
                replyToContent: jsonEncode(storyReplyMeta.toJson()),
                replyToSenderName: 'استوری $ownerUsername',
                replyToKind: 'story',
              );

      if (!mounted) return;
      if (!dmResult.isSuccess) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          dmResult.error ?? 'پاسخ در چت ثبت نشد',
        );
      } else {
        await ref.read(optimizedConversationsProvider.notifier).refresh();
      }
    }

    if (!mounted) return;
    setState(() => _isReplySending = false);
    if (!_isPaused && !_showingViewers) {
      _progressController.forward();
      _videoController?.play();
    }

    _showReplySuccessWithDMOption(conversationId: conversationId);
  }

  StoryReplyData _buildStoryReplyMeta() {
    final thumbnailUrl = StoryReplyMediaUtils.thumbnailFromStory(_currentStory);

    return StoryReplyData(
      storyId: _currentStory.id,
      storyOwnerId: _currentStory.userId,
      storyOwnerUsername: _currentUser.username,
      storyOwnerAvatarUrl: _currentUser.avatarUrl,
      storyThumbnailUrl: thumbnailUrl,
      storyMediaType: _currentStory.media.isVideo ? 'video' : 'image',
      storyCreatedAt: _currentStory.createdAt,
      storyExpiresAt: _currentStory.expiresAt,
      replyKind: 'reply',
      storyCaption: _currentStory.caption?.trim(),
    );
  }

  /// Finds or creates a DM conversation with the story owner.
  Future<String?> _resolveConversationWithOwner() async {
    final ownerId = _currentStory.userId.trim();
    if (ownerId.isEmpty) return null;

    final conversations =
        ref.read(optimizedConversationsProvider).conversations;
    for (final conversation in conversations) {
      if (conversation.otherUserId == ownerId) {
        return conversation.id;
      }
    }

    final createResult =
        await ref.read(chatRepositoryProvider).createConversation(ownerId);
    if (!createResult.isSuccess || createResult.data == null) {
      return null;
    }
    return createResult.data!.id;
  }

  /// Shows a success snackbar with an "Open Chat" action that navigates to
  /// the DM conversation with the story owner.
  void _showReplySuccessWithDMOption({String? conversationId}) {
    final ownerUserId = _currentStory.userId;
    final ownerUsername = _currentUser.username;
    final ownerAvatar = _currentUser.avatarUrl;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('پاسخ ارسال شد'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'مشاهده در چت',
          onPressed: () {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ModernChatScreen(
                  args: ChatScreenArgs(
                    conversationId: conversationId ?? '',
                    otherUserId: ownerUserId,
                    otherUserName: ownerUsername,
                    otherUserAvatar: ownerAvatar,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _reactToStory(StoryReactionType reaction) async {
    final repository = ref.read(storyRepositoryProvider);
    await repository.reactToStory(_currentStory.id, reaction);
  }
}
