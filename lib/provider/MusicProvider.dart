import '../security/logging_utility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../model/MusicModel.dart';
import '../services/MusicService.dart';
import '../app/app_initialization.dart';
import '../services/shared_audio_player_service.dart';

final audioPlayerProvider =
    Provider<AudioPlayer>((ref) => SharedAudioPlayerService.instance.player);

final musicListProvider =
    StateNotifierProvider<MusicListNotifier, AsyncValue<List<MusicModel>>>(
        (ref) {
  return MusicListNotifier(MusicService());
});

class MusicListNotifier extends StateNotifier<AsyncValue<List<MusicModel>>> {
  final MusicService _musicService;
  int _currentPage = 0;
  static const int _perPage = 20;
  bool _hasMore = true;
  bool _isLoading = false;

  MusicListNotifier(this._musicService) : super(const AsyncValue.loading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      final musics = await _musicService.fetchMusics(
        limit: _perPage,
        offset: 0,
      );
      _currentPage = 1;
      _hasMore = musics.length >= _perPage;
      state = AsyncValue.data(musics);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;

    try {
      final moreSongs = await _musicService.fetchMusics(
        limit: _perPage,
        offset: _currentPage * _perPage,
      );

      _hasMore = moreSongs.length >= _perPage;
      _currentPage++;

      final currentSongs = state.value ?? [];
      state = AsyncValue.data([...currentSongs, ...moreSongs]);
    } catch (e) {
      logInfo('Error loading more songs: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    _currentPage = 0;
    _hasMore = true;
    await loadInitial();
  }
}

final currentlyPlayingProvider = StateProvider<AsyncValue<MusicModel?>>((ref) {
  return const AsyncValue.data(null);
});

final musicPlayerProvider =
    StateNotifierProvider<MusicPlayerNotifier, AsyncValue<Duration>>((ref) {
  return MusicPlayerNotifier(ref);
});

final playbackConfigProvider = StateProvider<PlaybackConfig>((ref) {
  return PlaybackConfig(
    volume: 1.0,
    speed: 1.0,
    loopMode: LoopMode.off,
  );
});

class PlaybackConfig {
  final double volume;
  final double speed;
  final LoopMode loopMode;

  PlaybackConfig({
    required this.volume,
    required this.speed,
    required this.loopMode,
  });

  PlaybackConfig copyWith({
    double? volume,
    double? speed,
    LoopMode? loopMode,
  }) {
    return PlaybackConfig(
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      loopMode: loopMode ?? this.loopMode,
    );
  }
}

final musicDurationProvider = StateProvider<Duration?>((ref) => null);
final musicPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

class MusicPlayerNotifier extends StateNotifier<AsyncValue<Duration>> {
  final Ref _ref;
  Duration? _duration;
  final List<MusicModel> _playlist = [];
  int _currentIndex = -1;

  MusicPlayerNotifier(this._ref) : super(const AsyncValue.data(Duration.zero)) {
    final player = _ref.read(audioPlayerProvider);

    player.positionStream.listen((position) {
      _ref.read(musicPositionProvider.notifier).state = position;
    });

    player.durationStream.listen((duration) {
      _duration = duration;
      _ref.read(musicDurationProvider.notifier).state = duration;
    });

    player.currentIndexStream.listen((index) {
      _currentIndex = index ?? -1;
      _syncCurrentTrack();
    });

    player.playerStateStream.listen((playerState) {
      _ref.read(isPlayingProvider.notifier).state = playerState.playing;
      if (playerState.processingState == ProcessingState.completed &&
          !player.hasNext) {
        _ref.read(isPlayingProvider.notifier).state = false;
      }
    });
  }

  Uri? _resolveArtUri(MusicModel music) {
    final cover = music.coverUrl?.trim() ?? '';
    if (cover.isNotEmpty) return Uri.tryParse(cover);

    final avatar = music.avatarUrl.trim();
    if (avatar.isNotEmpty) return Uri.tryParse(avatar);
    return null;
  }

  AudioSource _buildTrackSource(
    MusicModel music, {
    required bool includeMediaTag,
  }) {
    final title = music.title.trim().isNotEmpty ? music.title : 'Music';
    final artist =
        music.artist.trim().isNotEmpty ? music.artist : music.username;
    final uri = Uri.parse(music.musicUrl);

    if (!includeMediaTag) {
      return AudioSource.uri(uri);
    }

    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: music.id.isNotEmpty ? music.id : music.musicUrl,
        title: title,
        artist: artist,
        album: 'Vista',
        artUri: _resolveArtUri(music),
        extras: {
          'music_url': music.musicUrl,
          'user_id': music.userId,
          'username': music.username,
        },
      ),
    );
  }

  ConcatenatingAudioSource _buildQueueSource({
    required bool includeMediaTag,
  }) {
    return ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: _playlist
          .map((item) =>
              _buildTrackSource(item, includeMediaTag: includeMediaTag))
          .toList(growable: false),
    );
  }

  Future<bool> _ensureMediaControlsReady() async {
    if (AppInitialization.isAudioBackgroundReady) return true;
    var ready = await AppInitialization.ensureAudioBackgroundReady();
    if (ready) return true;
    ready =
        await AppInitialization.ensureAudioBackgroundReady(forceRetry: true);
    return ready;
  }

  bool _isAudioHandlerInitError(Object error) {
    final raw = error.toString();
    return raw.contains('LateInitializationError') ||
        raw.contains('_audioHandler') ||
        error.runtimeType.toString().contains('LateInitializationError');
  }

  void _syncCurrentTrack() {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) {
      _ref.read(currentlyPlayingProvider.notifier).state =
          const AsyncValue.data(null);
      return;
    }

    _ref.read(currentlyPlayingProvider.notifier).state =
        AsyncValue.data(_playlist[_currentIndex]);
  }

  Future<void> _setQueueAndPlay({
    required int initialIndex,
    Duration initialPosition = Duration.zero,
  }) async {
    if (_playlist.isEmpty) return;

    final player = _ref.read(audioPlayerProvider);
    final mediaControlsReady = await _ensureMediaControlsReady();

    try {
      final queue = _buildQueueSource(includeMediaTag: mediaControlsReady);
      await player.setAudioSource(
        queue,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
    } catch (e, st) {
      if (!_isAudioHandlerInitError(e)) rethrow;

      AppInitialization.disableAudioBackgroundForSession(
        reason: e,
        stackTrace: st,
      );

      final recovered =
          await AppInitialization.ensureAudioBackgroundReady(forceRetry: true);
      final fallbackQueue =
          _buildQueueSource(includeMediaTag: recovered /* false => plain */);
      await player.setAudioSource(
        fallbackQueue,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
    }

    _currentIndex = initialIndex;
    _syncCurrentTrack();
    await player.play();
    _ref.read(isPlayingProvider.notifier).state = true;
  }

  Future<void> stop() async {
    final player = _ref.read(audioPlayerProvider);
    try {
      await player.stop();
      _ref.read(currentlyPlayingProvider.notifier).state =
          const AsyncValue.data(null);
      _ref.read(isPlayingProvider.notifier).state = false;
      _ref.read(musicPositionProvider.notifier).state = Duration.zero;
      _ref.read(musicDurationProvider.notifier).state = null;
      _playlist.clear();
      _currentIndex = -1;
    } catch (e) {
      logDebug('Error stopping music: $e');
    }
  }

  Future<void> playMusic(MusicModel music) async {
    final player = _ref.read(audioPlayerProvider);

    try {
      var existingIndex =
          _playlist.indexWhere((item) => item.musicUrl == music.musicUrl);

      if (existingIndex == -1) {
        _playlist.add(music);
        existingIndex = _playlist.length - 1;
      } else {
        _playlist[existingIndex] = music;
      }

      if (_currentIndex == existingIndex) {
        if (player.playing) {
          await player.pause();
          _ref.read(isPlayingProvider.notifier).state = false;
        } else {
          await player.play();
          _ref.read(isPlayingProvider.notifier).state = true;
        }
        return;
      }

      await _setQueueAndPlay(initialIndex: existingIndex);
    } catch (e, stack) {
      logInfo('Error playing music: $e');
      state = AsyncValue.error(e, stack);
      _ref.read(isPlayingProvider.notifier).state = false;
      rethrow;
    }
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    final player = _ref.read(audioPlayerProvider);
    try {
      if (player.hasNext) {
        await player.seekToNext();
        await player.play();
        return;
      }

      if (_currentIndex < _playlist.length - 1) {
        final nextIndex = _currentIndex + 1;
        await _setQueueAndPlay(initialIndex: nextIndex);
      }
    } catch (e, stack) {
      logInfo('Error playing next music: $e');
      state = AsyncValue.error(e, stack);
      _ref.read(isPlayingProvider.notifier).state = false;
    }
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    final player = _ref.read(audioPlayerProvider);
    try {
      if (player.hasPrevious) {
        await player.seekToPrevious();
        await player.play();
        return;
      }

      if (_currentIndex > 0) {
        final previousIndex = _currentIndex - 1;
        await _setQueueAndPlay(initialIndex: previousIndex);
      }
    } catch (e, stack) {
      logInfo('Error playing previous music: $e');
      state = AsyncValue.error(e, stack);
      _ref.read(isPlayingProvider.notifier).state = false;
    }
  }

  Future<void> togglePlayPause() async {
    final player = _ref.read(audioPlayerProvider);
    try {
      if (player.playing) {
        await player.pause();
      } else {
        if (_currentIndex == -1 && _playlist.isNotEmpty) {
          await _setQueueAndPlay(initialIndex: 0);
          return;
        }
        await player.play();
      }
      _ref.read(isPlayingProvider.notifier).state = player.playing;
    } catch (e) {
      logDebug('Error toggling play/pause: $e');
    }
  }

  void seek(Duration position) {
    _ref.read(audioPlayerProvider).seek(position);
  }

  Duration? get duration => _duration;

  Future<void> setVolume(double volume) async {
    await _ref.read(audioPlayerProvider).setVolume(volume);
    final config = _ref.read(playbackConfigProvider);
    _ref.read(playbackConfigProvider.notifier).state =
        config.copyWith(volume: volume);
  }

  Future<void> setSpeed(double speed) async {
    await _ref.read(audioPlayerProvider).setSpeed(speed);
    final config = _ref.read(playbackConfigProvider);
    _ref.read(playbackConfigProvider.notifier).state =
        config.copyWith(speed: speed);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _ref.read(audioPlayerProvider).setLoopMode(mode);
    final config = _ref.read(playbackConfigProvider);
    _ref.read(playbackConfigProvider.notifier).state =
        config.copyWith(loopMode: mode);
  }
}

class AudioPlayerNotifier extends StateNotifier<Duration> {
  final AudioPlayer _player;

  AudioPlayerNotifier(this._player) : super(Duration.zero) {
    _player.positionStream.listen((position) {
      state = position;
    });
  }

  Future<void> playAudio(String url) async {
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      logInfo('Error playing audio: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final audioPlayerControllerProvider =
    StateNotifierProvider<AudioPlayerNotifier, Duration>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return AudioPlayerNotifier(player);
});

final isPlayingProvider = StateProvider<bool>((ref) => false);
final playlistProvider = StateProvider<List<MusicModel>>((ref) => []);
final currentIndexProvider = StateProvider<int>((ref) => -1);
