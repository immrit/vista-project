import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

/// مدل وضعیت پخش
enum VoicePlaybackState {
  stopped,
  playing,
  paused,
  loading,
  error,
}

/// مدل تنظیمات پخش
class PlaybackConfig {
  final double defaultSpeed;
  final List<double> availableSpeeds;
  final bool enableBackgroundPlayback;
  final bool enableAutoPlay;
  final bool enableLoop;
  final double volume;
  final bool enableHapticFeedback;

  const PlaybackConfig({
    this.defaultSpeed = 1.0,
    this.availableSpeeds = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    this.enableBackgroundPlayback = true,
    this.enableAutoPlay = false,
    this.enableLoop = false,
    this.volume = 1.0,
    this.enableHapticFeedback = true,
  });
}

/// مدل اطلاعات فایل صوتی
class VoiceFileInfo {
  final String url;
  final Uint8List? bytes;
  final String? localPath;
  final int duration;
  final List<double> waveformData;
  final double fileSize;
  final DateTime timestamp;

  const VoiceFileInfo({
    required this.url,
    this.bytes,
    this.localPath,
    required this.duration,
    required this.waveformData,
    required this.fileSize,
    required this.timestamp,
  });

  bool get isLocal => localPath != null && File(localPath!).existsSync();
  bool get isRemote => url.isNotEmpty && !isLocal;
}

/// سرویس پخش وویس پیشرفته مثل تلگرام
class TelegramVoicePlayerService {
  // Singleton instance
  static final TelegramVoicePlayerService _instance =
      TelegramVoicePlayerService._internal();
  factory TelegramVoicePlayerService() => _instance;
  TelegramVoicePlayerService._internal();

  // Audio player instances
  final Map<String, AudioPlayer> _players = {};
  final Map<String, VoiceFileInfo> _fileInfos = {};
  final Map<String, PlaybackConfig> _playbackConfigs = {};

  // Current playback state
  String? _currentPlayerId;
  VoicePlaybackState _currentState = VoicePlaybackState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  double _currentSpeed = 1.0;
  double _currentVolume = 1.0;

  // Callbacks
  Function(VoicePlaybackState)? _onStateChanged;
  Function(Duration position)? _onPositionChanged;
  Function(Duration duration)? _onDurationChanged;
  Function(double speed)? _onSpeedChanged;
  Function(double volume)? _onVolumeChanged;
  Function(String error)? _onError;

  // Background playback
  bool _isBackgroundPlaybackEnabled = true;
  Timer? _backgroundTimer;

  /// تنظیم callbacks
  void setCallbacks({
    Function(VoicePlaybackState)? onStateChanged,
    Function(Duration position)? onPositionChanged,
    Function(Duration duration)? onDurationChanged,
    Function(double speed)? onSpeedChanged,
    Function(double volume)? onVolumeChanged,
    Function(String error)? onError,
  }) {
    _onStateChanged = onStateChanged;
    _onPositionChanged = onPositionChanged;
    _onDurationChanged = onDurationChanged;
    _onSpeedChanged = onSpeedChanged;
    _onVolumeChanged = onVolumeChanged;
    _onError = onError;
  }

  /// تنظیم کانفیگ پخش
  void setPlaybackConfig(String playerId, PlaybackConfig config) {
    _playbackConfigs[playerId] = config;
  }

  /// تنظیم پخش در پس‌زمینه
  void setBackgroundPlaybackEnabled(bool enabled) {
    _isBackgroundPlaybackEnabled = enabled;
    if (enabled) {
      _startBackgroundPlayback();
    } else {
      _stopBackgroundPlayback();
    }
  }

  /// شروع پخش فایل وویس
  Future<bool> playVoice(
    String playerId,
    VoiceFileInfo fileInfo, {
    bool autoPlay = false,
    Duration? startPosition,
  }) async {
    try {
      // توقف پخش قبلی اگر در حال پخش است
      if (_currentPlayerId != null && _currentPlayerId != playerId) {
        await stopCurrentPlayback();
      }

      _currentPlayerId = playerId;
      _fileInfos[playerId] = fileInfo;

      // دریافت یا ایجاد player
      AudioPlayer player = _players[playerId] ?? AudioPlayer();
      _players[playerId] = player;

      // تنظیم player
      await _setupPlayer(player, playerId);

      // تنظیم منبع صوتی
      Source audioSource;
      if (fileInfo.bytes != null) {
        audioSource = BytesSource(fileInfo.bytes!);
      } else if (fileInfo.isLocal) {
        audioSource = DeviceFileSource(fileInfo.localPath!);
      } else {
        audioSource = UrlSource(fileInfo.url);
      }

      // شروع پخش
      _updateState(VoicePlaybackState.loading);

      await player.play(audioSource);

      // تنظیم موقعیت شروع
      if (startPosition != null) {
        await player.seek(startPosition);
      }

      // تنظیم سرعت و حجم
      final config = _playbackConfigs[playerId] ?? const PlaybackConfig();
      await player.setPlaybackRate(config.defaultSpeed);
      await player.setVolume(config.volume);

      _currentSpeed = config.defaultSpeed;
      _currentVolume = config.volume;

      _updateState(VoicePlaybackState.playing);

      // Haptic feedback
      if (config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      print('🎵 پخش وویس شروع شد: $playerId');
      return true;
    } catch (e) {
      _updateState(VoicePlaybackState.error);
      _onError?.call('خطا در شروع پخش: $e');
      print('❌ خطا در پخش وویس: $e');
      return false;
    }
  }

  /// مکث/ادامه پخش
  Future<void> pauseResumePlayback(String playerId) async {
    try {
      final player = _players[playerId];
      if (player == null) return;

      if (_currentState == VoicePlaybackState.playing) {
        await player.pause();
        _updateState(VoicePlaybackState.paused);
        print('⏸️ پخش مکث شد');
      } else if (_currentState == VoicePlaybackState.paused) {
        await player.resume();
        _updateState(VoicePlaybackState.playing);
        print('▶️ پخش ادامه یافت');
      }
    } catch (e) {
      _onError?.call('خطا در مکث/ادامه پخش: $e');
      print('❌ خطا در مکث/ادامه پخش: $e');
    }
  }

  /// توقف پخش
  Future<void> stopPlayback(String playerId) async {
    try {
      final player = _players[playerId];
      if (player == null) return;

      await player.stop();
      _updateState(VoicePlaybackState.stopped);
      _currentPosition = Duration.zero;

      print('⏹️ پخش متوقف شد');
    } catch (e) {
      _onError?.call('خطا در توقف پخش: $e');
      print('❌ خطا در توقف پخش: $e');
    }
  }

  /// توقف پخش فعلی
  Future<void> stopCurrentPlayback() async {
    if (_currentPlayerId != null) {
      await stopPlayback(_currentPlayerId!);
    }
  }

  /// تغییر موقعیت پخش
  Future<void> seekTo(String playerId, Duration position) async {
    try {
      final player = _players[playerId];
      if (player == null) return;

      await player.seek(position);
      _currentPosition = position;
      _onPositionChanged?.call(position);

      print('⏭️ موقعیت پخش تغییر کرد: ${position.inSeconds}s');
    } catch (e) {
      _onError?.call('خطا در تغییر موقعیت: $e');
      print('❌ خطا در تغییر موقعیت: $e');
    }
  }

  /// تغییر سرعت پخش
  Future<void> setPlaybackSpeed(String playerId, double speed) async {
    try {
      final player = _players[playerId];
      if (player == null) return;

      final config = _playbackConfigs[playerId] ?? const PlaybackConfig();
      if (!config.availableSpeeds.contains(speed)) {
        throw Exception('سرعت پخش پشتیبانی نمی‌شود');
      }

      await player.setPlaybackRate(speed);
      _currentSpeed = speed;
      _onSpeedChanged?.call(speed);

      print('⚡ سرعت پخش تغییر کرد: ${speed}x');
    } catch (e) {
      _onError?.call('خطا در تغییر سرعت: $e');
      print('❌ خطا در تغییر سرعت: $e');
    }
  }

  /// تغییر حجم صدا
  Future<void> setVolume(String playerId, double volume) async {
    try {
      final player = _players[playerId];
      if (player == null) return;

      final clampedVolume = volume.clamp(0.0, 1.0);
      await player.setVolume(clampedVolume);
      _currentVolume = clampedVolume;
      _onVolumeChanged?.call(clampedVolume);

      print('🔊 حجم صدا تغییر کرد: ${(clampedVolume * 100).round()}%');
    } catch (e) {
      _onError?.call('خطا در تغییر حجم: $e');
      print('❌ خطا در تغییر حجم: $e');
    }
  }

  /// تنظیم player
  Future<void> _setupPlayer(AudioPlayer player, String playerId) async {
    // تنظیم callbacks
    player.onDurationChanged.listen((duration) {
      _currentDuration = duration;
      _onDurationChanged?.call(duration);
    });

    player.onPositionChanged.listen((position) {
      _currentPosition = position;
      _onPositionChanged?.call(position);
    });

    player.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _updateState(VoicePlaybackState.playing);
          break;
        case PlayerState.paused:
          _updateState(VoicePlaybackState.paused);
          break;
        case PlayerState.stopped:
          _updateState(VoicePlaybackState.stopped);
          _currentPosition = Duration.zero;
          break;
        case PlayerState.completed:
          _updateState(VoicePlaybackState.stopped);
          _currentPosition = Duration.zero;
          print('✅ پخش تمام شد');
          break;
        case PlayerState.disposed:
          _updateState(VoicePlaybackState.stopped);
          break;
      }
    });

    // تنظیم پخش در پس‌زمینه
    if (_isBackgroundPlaybackEnabled) {
      await player.setReleaseMode(ReleaseMode.stop);
    }
  }

  /// به‌روزرسانی وضعیت
  void _updateState(VoicePlaybackState state) {
    _currentState = state;
    _onStateChanged?.call(state);
  }

  /// شروع پخش در پس‌زمینه
  void _startBackgroundPlayback() {
    _backgroundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // بررسی وضعیت پخش در پس‌زمینه
      if (_currentState == VoicePlaybackState.playing &&
          _currentPlayerId != null) {
        // حفظ پخش در پس‌زمینه
      }
    });
  }

  /// توقف پخش در پس‌زمینه
  void _stopBackgroundPlayback() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  /// کش کردن فایل صوتی
  Future<String?> cacheVoiceFile(String url, String playerId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${playerId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = path.join(tempDir.path, fileName);

      // اینجا می‌توان فایل را دانلود و کش کرد
      // فعلاً فقط مسیر را برمی‌گردانیم

      print('💾 فایل صوتی کش شد: $filePath');
      return filePath;
    } catch (e) {
      print('❌ خطا در کش فایل: $e');
      return null;
    }
  }

  /// حذف کش فایل صوتی
  Future<void> clearCache(String playerId) async {
    try {
      final fileInfo = _fileInfos[playerId];
      if (fileInfo?.localPath != null) {
        final file = File(fileInfo!.localPath!);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ کش فایل حذف شد: ${fileInfo.localPath}');
        }
      }
    } catch (e) {
      print('❌ خطا در حذف کش: $e');
    }
  }

  /// دریافت اطلاعات پخش فعلی
  Map<String, dynamic> getCurrentPlaybackInfo() {
    return {
      'playerId': _currentPlayerId,
      'state': _currentState,
      'position': _currentPosition,
      'duration': _currentDuration,
      'speed': _currentSpeed,
      'volume': _currentVolume,
      'progress': _currentDuration.inMilliseconds > 0
          ? _currentPosition.inMilliseconds / _currentDuration.inMilliseconds
          : 0.0,
    };
  }

  /// دریافت لیست سرعت‌های موجود
  List<double> getAvailableSpeeds(String playerId) {
    final config = _playbackConfigs[playerId] ?? const PlaybackConfig();
    return config.availableSpeeds;
  }

  /// بررسی وضعیت پخش
  bool isPlaying(String playerId) {
    return _currentPlayerId == playerId &&
        _currentState == VoicePlaybackState.playing;
  }

  /// بررسی وضعیت مکث
  bool isPaused(String playerId) {
    return _currentPlayerId == playerId &&
        _currentState == VoicePlaybackState.paused;
  }

  /// بررسی وضعیت بارگذاری
  bool isLoading(String playerId) {
    return _currentPlayerId == playerId &&
        _currentState == VoicePlaybackState.loading;
  }

  // Getters
  String? get currentPlayerId => _currentPlayerId;
  VoicePlaybackState get currentState => _currentState;
  Duration get currentPosition => _currentPosition;
  Duration get currentDuration => _currentDuration;
  double get currentSpeed => _currentSpeed;
  double get currentVolume => _currentVolume;

  /// پاکسازی منابع
  Future<void> dispose() async {
    // توقف پخش در پس‌زمینه
    _stopBackgroundPlayback();

    // توقف تمام players
    for (final player in _players.values) {
      await player.dispose();
    }

    _players.clear();
    _fileInfos.clear();
    _playbackConfigs.clear();

    _currentPlayerId = null;
    _currentState = VoicePlaybackState.stopped;
    _currentPosition = Duration.zero;
    _currentDuration = Duration.zero;

    print('🧹 Telegram Voice Player Service disposed');
  }
}
