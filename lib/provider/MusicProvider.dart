import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../model/MusicModel.dart';
import '../services/MusicService.dart';

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
  // اضافه کردن لیست پخش
  final List<MusicModel> _playlist = [];
  int _currentIndex = -1;

  MusicPlayerNotifier(this._ref) : super(const AsyncValue.data(Duration.zero)) {
    final player = _ref.read(audioPlayerProvider);
    player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // وقتی آهنگ تمام می‌شود، به آهنگ بعدی برو
        playNext();
      }
    });

    player.positionStream.listen((position) {
      _ref.read(musicPositionProvider.notifier).state = position;
    });

    player.durationStream.listen((duration) {
      _ref.read(musicDurationProvider.notifier).state = duration;
    });
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
      debugPrint('Error stopping music: $e');
    }
  }

  Future<void> playMusic(MusicModel music) async {
    final player = _ref.read(audioPlayerProvider);

    try {
      // بررسی اینکه آیا این آهنگ قبلاً در پلی‌لیست اضافه شده است
      int existingIndex =
          _playlist.indexWhere((m) => m.musicUrl == music.musicUrl);

      if (existingIndex != -1) {
        // اگر این آهنگ در حال حاضر درحال پخش است، فقط وضعیت پخش را تغییر دهید
        if (_currentIndex == existingIndex) {
          togglePlayPause();
          return;
        }

        // در غیر این صورت، به آن آهنگ بروید
        _currentIndex = existingIndex;
      } else {
        // آهنگ را به پلی‌لیست اضافه کنید و آن را بعنوان آهنگ فعلی تنظیم کنید
        _playlist.add(music);
        _currentIndex = _playlist.length - 1;
      }

      await player.stop();
      await player.setUrl(music.musicUrl);
      _duration = player.duration;

      _ref.read(currentlyPlayingProvider.notifier).state =
          AsyncValue.data(_playlist[_currentIndex]);
      _ref.read(isPlayingProvider.notifier).state = true;

      await player.play();
    } catch (e, stack) {
      print('Error playing music: $e');
      state = AsyncValue.error(e, stack);
      _ref.read(isPlayingProvider.notifier).state = false;
      rethrow;
    }
  }

  // اضافه کردن متد برای پخش آهنگ بعدی
  Future<void> playNext() async {
    if (_playlist.isEmpty || _currentIndex >= _playlist.length - 1) {
      return; // پایان پلی‌لیست
    }

    _currentIndex++;
    final player = _ref.read(audioPlayerProvider);

    try {
      await player.stop();
      await player.setUrl(_playlist[_currentIndex].musicUrl);
      _duration = player.duration;

      _ref.read(currentlyPlayingProvider.notifier).state =
          AsyncValue.data(_playlist[_currentIndex]);
      _ref.read(isPlayingProvider.notifier).state = true;

      await player.play();
    } catch (e, stack) {
      print('Error playing next music: $e');
      state = AsyncValue.error(e, stack);
      _ref.read(isPlayingProvider.notifier).state = false;
    }
  }

  // اضافه کردن متد برای پخش آهنگ قبلی
  Future<void> playPrevious() async {
    if (_playlist.isEmpty || _currentIndex <= 0) {
      return; // ابتدای پلی‌لیست
    }

    _currentIndex--;
    final player = _ref.read(audioPlayerProvider);

    try {
      await player.stop();
      await player.setUrl(_playlist[_currentIndex].musicUrl);
      _duration = player.duration;

      _ref.read(currentlyPlayingProvider.notifier).state =
          AsyncValue.data(_playlist[_currentIndex]);
      _ref.read(isPlayingProvider.notifier).state = true;

      await player.play();
    } catch (e, stack) {
      print('Error playing previous music: $e');
      state = AsyncValue.error(e, stack);
      _ref.read(isPlayingProvider.notifier).state = false;
    }
  }

  // اضافه کردن متد برای توقف کامل
  // void stop() async {
  //   final player = _ref.read(audioPlayerProvider);
  //   await player.stop();
  //   _ref.read(isPlayingProvider.notifier).state = false;
  //   _ref.read(currentlyPlayingProvider.notifier).state =
  //       const AsyncValue.data(null);
  // }

  void togglePlayPause() async {
    final player = _ref.read(audioPlayerProvider);
    try {
      if (player.playing) {
        await player.pause();
      } else {
        // اگر آهنگی در حال پخش نیست، از اولین آهنگ پلی‌لیست شروع کن
        if (_currentIndex == -1 && _playlist.isNotEmpty) {
          _currentIndex = 0;
          await playMusic(_playlist[0]);
          return;
        }
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

// اضافه کردن provider برای لیست پخش
final playlistProvider = StateProvider<List<MusicModel>>((ref) => []);

// اضافه کردن provider برای شماره آهنگ فعلی
final currentIndexProvider = StateProvider<int>((ref) => -1);
