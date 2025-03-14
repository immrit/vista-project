import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../model/MusicModel.dart';
import '../service/MusicService.dart';

final audioPlayerProvider = Provider((ref) => AudioPlayer());

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
      // Handle error but keep current state
      print('Error loading more songs: $e');
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

// اضافه کردن provider های جدید برای کنترل پخش
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

// Provider برای مدت زمان کل موسیقی
final musicDurationProvider = StateProvider<Duration?>((ref) => null);

// Provider برای موقعیت فعلی پخش
final musicPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

class MusicPlayerNotifier extends StateNotifier<AsyncValue<Duration>> {
  final Ref _ref;
  Duration? _duration;

  MusicPlayerNotifier(this._ref) : super(const AsyncValue.data(Duration.zero)) {
    final player = _ref.read(audioPlayerProvider);
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        player.seek(Duration.zero);
        player.pause();
        _ref.read(isPlayingProvider.notifier).state = false;
      }
    });

    player.positionStream.listen((position) {
      _ref.read(musicPositionProvider.notifier).state = position;
    });

    player.durationStream.listen((duration) {
      _ref.read(musicDurationProvider.notifier).state = duration;
    });
  }

  Future<void> playMusic(MusicModel music) async {
    final player = _ref.read(audioPlayerProvider);

    try {
      await player.stop();

      final audioSource = AudioSource.uri(
        Uri.parse(music.musicUrl),
        tag: MediaItem(
          id: music.id,
          title: music.title,
          artist: music.artist,
          artUri: music.coverUrl != null ? Uri.parse(music.coverUrl!) : null,
        ),
      );

      await player.setAudioSource(audioSource);
      _duration = player.duration;

      _ref.read(currentlyPlayingProvider.notifier).state =
          AsyncValue.data(music);
      _ref.read(isPlayingProvider.notifier).state = true;

      await player.play();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      _ref.read(isPlayingProvider.notifier).state = false;
      rethrow;
    }
  }

  void togglePlayPause() async {
    final player = _ref.read(audioPlayerProvider);
    try {
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
      _ref.read(isPlayingProvider.notifier).state = player.playing;
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
    }
  }

  void seek(Duration position) {
    _ref.read(audioPlayerProvider).seek(position);
  }

  Duration? get duration => _duration;

  void setVolume(double volume) {
    _ref.read(audioPlayerProvider).setVolume(volume);
    final config = _ref.read(playbackConfigProvider);
    _ref.read(playbackConfigProvider.notifier).state =
        config.copyWith(volume: volume);
  }

  void setSpeed(double speed) {
    _ref.read(audioPlayerProvider).setSpeed(speed);
    final config = _ref.read(playbackConfigProvider);
    _ref.read(playbackConfigProvider.notifier).state =
        config.copyWith(speed: speed);
  }

  void setLoopMode(LoopMode mode) {
    _ref.read(audioPlayerProvider).setLoopMode(mode);
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

  void playAudio(String url) async {
    try {
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void stop() {
    _player.stop();
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
