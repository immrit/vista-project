import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import '../app/app_initialization.dart';
import '../security/logging_utility.dart';
import 'shared_audio_player_service.dart';

/// Centralized voice player service using just_audio.
/// Replaces per-widget AudioPlayer instances with a single shared player.
class VoicePlayerState {
  final String? voiceId;
  final bool isPlaying;
  final bool isLoading;
  final Duration duration;
  final Duration position;
  final double speed;
  final String? errorMessage;

  const VoicePlayerState({
    this.voiceId,
    required this.isPlaying,
    required this.isLoading,
    required this.duration,
    required this.position,
    required this.speed,
    this.errorMessage,
  });

  factory VoicePlayerState.initial() => const VoicePlayerState(
        voiceId: null,
        isPlaying: false,
        isLoading: false,
        duration: Duration.zero,
        position: Duration.zero,
        speed: 1.0,
        errorMessage: null,
      );

  VoicePlayerState copyWith({
    String? voiceId,
    bool? isPlaying,
    bool? isLoading,
    Duration? duration,
    Duration? position,
    double? speed,
    String? errorMessage,
  }) {
    return VoicePlayerState(
      voiceId: voiceId ?? this.voiceId,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      speed: speed ?? this.speed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class VoicePlayerService {
  static final VoicePlayerService _instance = VoicePlayerService._internal();
  factory VoicePlayerService() => _instance;
  VoicePlayerService._internal() {
    _init();
  }

  final AudioPlayer _player = SharedAudioPlayerService.instance.player;
  final BehaviorSubject<VoicePlayerState> _stateController =
      BehaviorSubject.seeded(VoicePlayerState.initial());

  Stream<VoicePlayerState> get playerStateStream => _stateController.stream;
  VoicePlayerState get latestState => _stateController.value;

  String? _currentVoiceId;
  String? _currentUrl;
  bool _isPreparing = false;
  String? _errorMessage;

  void _init() {
    // Listen to player streams and broadcast consolidated state
    _player.playerStateStream.listen((playerState) {
      _broadcastState();

      // Haptic on start
      if (playerState.playing) {
        HapticFeedback.lightImpact();
      }

      // auto-reset only for active voice playback.
      if (_currentVoiceId != null &&
          playerState.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });

    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _isPreparing = false;
        _errorMessage = _buildUserFacingError(error);
        _broadcastState();
        logError(
          'VoicePlayerService playback event error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    _player.durationStream.listen((d) => _broadcastState());
    _player.positionStream.listen((p) => _broadcastState());
  }

  void _broadcastState() {
    final state = VoicePlayerState(
      voiceId: _currentVoiceId,
      isPlaying: _player.playing,
      isLoading: _isPreparing,
      duration: _player.duration ?? Duration.zero,
      position: _player.position,
      speed: _player.speed,
      errorMessage: _errorMessage,
    );
    if (!_stateController.isClosed) _stateController.add(state);
  }

  /// Toggles play / pause for given voiceId. If a different voiceId is
  /// requested, the previous one will be stopped and the new one prepared.
  Future<void> playOrPause(
    String voiceId,
    String url, {
    String? localFilePath,
    String? title,
    String? artist,
    String? artUrl,
    String? conversationId,
    String? conversationTitle,
    String? attachmentType,
  }) async {
    try {
      _errorMessage = null;
      final uri = _resolvePlaybackUri(url, localFilePath);
      final sourceKey = uri.toString();
      // If a different voice is requested, stop current and prepare new
      if (_currentVoiceId != voiceId || _currentUrl != sourceKey) {
        await _player.stop();
        _currentVoiceId = voiceId;
        _currentUrl = sourceKey;
        _isPreparing = true;
        _broadcastState();

        // Build MediaItem so OS-level media notification controls are shown.
        final mediaItem = _buildMediaItem(
          voiceId: voiceId,
          url: url,
          title: title,
          artist: artist,
          artUrl: artUrl,
          conversationId: conversationId,
          conversationTitle: conversationTitle,
          attachmentType: attachmentType,
        );
        await _setAudioSourceWithFallback(uri, mediaItem);

        _isPreparing = false;
        _broadcastState();
        await _player.play();
        return;
      }

      // same voiceId: toggle
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (e, st) {
      if (_isAudioHandlerInitError(e)) {
        AppInitialization.disableAudioBackgroundForSession(
          reason: e,
          stackTrace: st,
        );
      }
      _isPreparing = false;
      _errorMessage = _buildUserFacingError(e);
      _broadcastState();
      logError(
        'VoicePlayerService.playOrPause failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Uri _resolvePlaybackUri(String url, String? localFilePath) {
    if (localFilePath != null && localFilePath.trim().isNotEmpty) {
      final localFile = File(localFilePath.trim());
      if (localFile.existsSync()) {
        return Uri.file(localFile.path);
      }
    }
    return Uri.parse(url);
  }

  Future<void> _setAudioSourceWithFallback(Uri uri, MediaItem mediaItem) async {
    var audioReady = AppInitialization.isAudioBackgroundReady;
    if (!audioReady) {
      audioReady = await AppInitialization.ensureAudioBackgroundReady();
      if (!audioReady) {
        // Force a re-init attempt in case the previous init failed transiently.
        audioReady = await AppInitialization.ensureAudioBackgroundReady(
          forceRetry: true,
        );
      }
    }

    if (!audioReady) {
      logWarning(
        'Audio background not ready, using plain audio source fallback',
      );
      await _setAudioSourceSafely(AudioSource.uri(uri));
      return;
    }

    try {
      await _setAudioSourceSafely(AudioSource.uri(uri, tag: mediaItem));
    } catch (e, st) {
      if (!_isAudioHandlerInitError(e)) rethrow;

      AppInitialization.disableAudioBackgroundForSession(
        reason: e,
        stackTrace: st,
      );

      // Try to recover media session once so notification controls can appear.
      final recovered = await AppInitialization.ensureAudioBackgroundReady(
        forceRetry: true,
      );
      if (recovered) {
        try {
          await _setAudioSourceSafely(AudioSource.uri(uri, tag: mediaItem));
          return;
        } catch (retryError, retryStack) {
          logWarning(
            'Audio handler recovery retry failed, falling back to plain source',
            error: retryError,
            stackTrace: retryStack,
          );
        }
      }

      logWarning(
        'Audio handler initialization error, retrying with plain source',
        error: e,
        stackTrace: st,
      );
      await _setAudioSourceSafely(AudioSource.uri(uri));
    }
  }

  Future<void> _setAudioSourceSafely(AudioSource source) async {
    final completer = Completer<void>();

    runZonedGuarded(() async {
      try {
        await _player.setAudioSource(source);
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    }, (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    });

    await completer.future;
  }

  bool _isAudioHandlerInitError(Object error) {
    final raw = error.toString();
    return raw.contains('LateInitializationError') ||
        raw.contains('_audioHandler') ||
        error.runtimeType.toString().contains('LateInitializationError');
  }

  String _buildUserFacingError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('lateinitializationerror') ||
        raw.contains('_audiohandler')) {
      return 'Audio service is still starting. Tap retry.';
    }
    if (raw.contains('audio background service is not ready')) {
      return 'Audio service is not ready yet. Tap retry.';
    }
    if (raw.contains('source')) {
      return 'Unable to load this voice message. Tap retry.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'Network error while playing voice message.';
    }
    return 'Voice playback failed. Tap retry.';
  }

  Future<void> stop() async {
    await _player.stop();
    _currentVoiceId = null;
    _currentUrl = null;
    _broadcastState();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }

  MediaItem _buildMediaItem({
    required String voiceId,
    required String url,
    String? title,
    String? artist,
    String? artUrl,
    String? conversationId,
    String? conversationTitle,
    String? attachmentType,
  }) {
    final normalizedType = (attachmentType ?? '').toLowerCase();
    final defaultTitle = normalizedType == 'audio' ? 'Music' : 'Voice message';
    final inferredTitle = _deriveTitleFromUrl(url);
    final resolvedTitle = (title?.trim().isNotEmpty ?? false)
        ? title!.trim()
        : (inferredTitle?.isNotEmpty ?? false)
            ? inferredTitle!
            : defaultTitle;
    final resolvedArtist = _resolveArtist(
      explicitArtist: artist,
      title: resolvedTitle,
      url: url,
      conversationTitle: conversationTitle,
    );
    final artUri = (artUrl?.trim().isNotEmpty ?? false)
        ? Uri.tryParse(artUrl!.trim())
        : null;

    return MediaItem(
      id: voiceId,
      title: resolvedTitle,
      artist: resolvedArtist,
      album: 'Chat',
      artUri: artUri,
      extras: {
        'source': 'chat',
        'voice_id': voiceId,
        'media_url': url,
        'conversation_id': conversationId ?? '',
        'attachment_type': normalizedType,
      },
    );
  }

  String _resolveArtist({
    String? explicitArtist,
    required String title,
    required String url,
    String? conversationTitle,
  }) {
    final direct = explicitArtist?.trim();
    if (direct != null && direct.isNotEmpty && direct != 'Vista Chat') {
      return direct;
    }

    final fromTitle = _deriveArtistFromTrackText(title);
    if (fromTitle != null && fromTitle.isNotEmpty) {
      return fromTitle;
    }

    final fromUrlName = _deriveArtistFromTrackText(_deriveTitleFromUrl(url));
    if (fromUrlName != null && fromUrlName.isNotEmpty) {
      return fromUrlName;
    }

    final conversation = conversationTitle?.trim();
    if (conversation != null && conversation.isNotEmpty) {
      return conversation;
    }

    return 'Unknown artist';
  }

  String? _deriveArtistFromTrackText(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;

    final separators = <String>[' - ', ' – ', ' — ', ' | ', ' / ', '_'];
    for (final sep in separators) {
      final idx = normalized.indexOf(sep);
      if (idx > 0) {
        final candidate = normalized.substring(0, idx).trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return null;
  }

  String? _deriveTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isEmpty) return null;
      var name = Uri.decodeComponent(uri.pathSegments.last).trim();
      if (name.isEmpty) return null;

      final dot = name.lastIndexOf('.');
      if (dot > 0) {
        name = name.substring(0, dot);
      }

      name = name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      if (name.isEmpty) return null;

      return name;
    } catch (_) {
      return null;
    }
  }
}

// Convenience singleton accessor
VoicePlayerService get voicePlayerService => VoicePlayerService();
