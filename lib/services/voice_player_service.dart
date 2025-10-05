import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/services.dart';

/// سرویس پخش وویس حرفه‌ای مثل تلگرام و واتساپ
class VoicePlayerService {
  static final VoicePlayerService _instance = VoicePlayerService._internal();
  factory VoicePlayerService() => _instance;
  VoicePlayerService._internal();

  // Player controllers
  final Map<String, PlayerController> _players = {};
  final Map<String, StreamSubscription> _stateSubscriptions = {};
  final Map<String, StreamSubscription> _positionSubscriptions = {};

  // Current playing voice
  String? _currentPlayingId;
  String? _previousPlayingId;

  // Callbacks برای هر voiceId
  final Map<String, Function(String voiceId, bool isPlaying)?>
  _playStateCallbacks = {};
  final Map<String, Function(String voiceId, Duration position)?>
  _positionCallbacks = {};
  final Map<String, Function(String voiceId, Duration duration)?>
  _durationCallbacks = {};

  /// تنظیم callbacks برای یک voiceId خاص
  void setCallbacksForVoice(
    String voiceId, {
    Function(String voiceId, bool isPlaying)? onPlayStateChanged,
    Function(String voiceId, Duration position)? onPositionChanged,
    Function(String voiceId, Duration duration)? onDurationChanged,
  }) {
    _playStateCallbacks[voiceId] = onPlayStateChanged;
    _positionCallbacks[voiceId] = onPositionChanged;
    _durationCallbacks[voiceId] = onDurationChanged;
  }

  /// پاک کردن callbacks برای یک voiceId خاص
  void clearCallbacksForVoice(String voiceId) {
    try {
      // پاک کردن callbackها
      _playStateCallbacks.remove(voiceId);
      _positionCallbacks.remove(voiceId);
      _durationCallbacks.remove(voiceId);

      // لغو subscriptions اگر وجود دارند
      _stateSubscriptions[voiceId]?.cancel();
      _positionSubscriptions[voiceId]?.cancel();

      _stateSubscriptions.remove(voiceId);
      _positionSubscriptions.remove(voiceId);

      print("✅ Callbacks and subscriptions cleared for voiceId: $voiceId");
    } catch (e) {
      print("⚠️ خطا در پاک کردن callbacks برای $voiceId: $e");
    }
  }

  /// تنظیم callbacks (برای سازگاری با کد قدیمی)
  void setCallbacks({
    Function(String voiceId, bool isPlaying)? onPlayStateChanged,
    Function(String voiceId, Duration position)? onPositionChanged,
    Function(String voiceId, Duration duration)? onDurationChanged,
  }) {
    // این متد برای سازگاری با کد قدیمی نگه داشته شده
    // اما توصیه می‌شود از setCallbacksForVoice استفاده کنید
  }

  /// پاک کردن همه callbacks
  void clearCallbacks() {
    _playStateCallbacks.clear();
    _positionCallbacks.clear();
    _durationCallbacks.clear();
  }

  /// آماده‌سازی پلیر برای یک وویس
  Future<bool> prepareVoice(String voiceId, String audioPath) async {
    try {
      print("🎵 آماده‌سازی پلیر برای وویس: $voiceId");

      // اگر پلیر قبلی وجود دارد، آن را متوقف کن
      if (_players.containsKey(voiceId)) {
        await stopVoice(voiceId);
      }

      // ایجاد پلیر جدید
      final playerController = PlayerController();
      _players[voiceId] = playerController;

      // آماده‌سازی پلیر
      print("🎵 آماده‌سازی پلیر برای وویس: $voiceId");
      print("🎵 مسیر فایل: $audioPath");

      await playerController.preparePlayer(
        path: audioPath,
        shouldExtractWaveform: true,
      );

      // تنظیم subscriptions
      _setupPlayerSubscriptions(voiceId, playerController);

      // دریافت مدت زمان با تاخیر برای اطمینان از بارگذاری کامل
      await Future.delayed(const Duration(milliseconds: 500));
      final duration = Duration(milliseconds: playerController.maxDuration);

      // اگر duration صفر است، دوباره تلاش می‌کنیم
      if (duration.inMilliseconds == 0) {
        await Future.delayed(const Duration(milliseconds: 1000));
        final retryDuration = Duration(
          milliseconds: playerController.maxDuration,
        );
        if (retryDuration.inMilliseconds > 0) {
          final callback = _durationCallbacks[voiceId];
          if (callback != null) {
            try {
              callback(voiceId, retryDuration);
            } catch (e) {
              print("⚠️ خطا در فراخوانی callback duration برای $voiceId: $e");
            }
          }
          print(
            "✅ پلیر آماده شد: $voiceId (${retryDuration.inSeconds}s) - retry",
          );
        } else {
          print("⚠️ مدت زمان فایل در دسترس نیست: $voiceId");
        }
      } else {
        final callback = _durationCallbacks[voiceId];
        if (callback != null) {
          try {
            callback(voiceId, duration);
          } catch (e) {
            print("⚠️ خطا در فراخوانی callback duration برای $voiceId: $e");
          }
        }
        print("✅ پلیر آماده شد: $voiceId (${duration.inSeconds}s)");
      }

      return true;
    } catch (e) {
      print("❌ خطا در آماده‌سازی پلیر: $e");

      // اگر فایل آنلاین است، دوباره تلاش می‌کنیم
      if (audioPath.startsWith('http')) {
        print("🔄 تلاش مجدد برای فایل آنلاین...");
        try {
          final retryController = _players[voiceId];
          if (retryController != null) {
            await Future.delayed(const Duration(seconds: 1));
            await retryController.preparePlayer(
              path: audioPath,
              shouldExtractWaveform:
                  false, // برای فایل‌های آنلاین waveform را غیرفعال می‌کنیم
            );

            _setupPlayerSubscriptions(voiceId, retryController);

            // دریافت مدت زمان
            await Future.delayed(const Duration(milliseconds: 500));
            final duration = Duration(
              milliseconds: retryController.maxDuration,
            );
            if (duration.inMilliseconds > 0) {
              final callback = _durationCallbacks[voiceId];
              if (callback != null) {
                try {
                  callback(voiceId, duration);
                } catch (e) {
                  print(
                    "⚠️ خطا در فراخوانی callback duration برای $voiceId: $e",
                  );
                }
              }
              print(
                "✅ پلیر آنلاین آماده شد: $voiceId (${duration.inSeconds}s)",
              );
              return true;
            }
          }
        } catch (retryError) {
          print("❌ خطا در تلاش مجدد: $retryError");
        }
      }

      _cleanupPlayer(voiceId);
      return false;
    }
  }

  /// تنظیم subscriptions برای پلیر
  void _setupPlayerSubscriptions(
    String voiceId,
    PlayerController playerController,
  ) {
    // State subscription
    _stateSubscriptions[voiceId] = playerController.onPlayerStateChanged.listen((
      state,
    ) {
      final isPlaying = state.isPlaying;
      final callback = _playStateCallbacks[voiceId];
      if (callback != null) {
        try {
          // Triple check that callback still exists and is not null (maximum race condition protection)
          if (_playStateCallbacks.containsKey(voiceId) &&
              _playStateCallbacks[voiceId] != null) {
            callback(voiceId, isPlaying);
          }
        } catch (e) {
          print("⚠️ خطا در فراخوانی callback playState برای $voiceId: $e");
          // Remove the problematic callback immediately
          _playStateCallbacks.remove(voiceId);
        }
      }

      if (isPlaying) {
        _previousPlayingId = _currentPlayingId;
        _currentPlayingId = voiceId;

        // متوقف کردن پلیر قبلی
        if (_previousPlayingId != null && _previousPlayingId != voiceId) {
          pauseVoice(_previousPlayingId!);
        }

        // Haptic feedback
        HapticFeedback.lightImpact();
      } else {
        if (_currentPlayingId == voiceId) {
          _currentPlayingId = null;
        }
      }
    });

    // Position subscription
    _positionSubscriptions[voiceId] = playerController.onCurrentDurationChanged
        .listen((position) {
          final callback = _positionCallbacks[voiceId];
          if (callback != null) {
            try {
              // Triple check that callback still exists and is not null (maximum race condition protection)
              if (_positionCallbacks.containsKey(voiceId) &&
                  _positionCallbacks[voiceId] != null) {
                callback(voiceId, Duration(milliseconds: position));
              }
            } catch (e) {
              print("⚠️ خطا در فراخوانی callback position برای $voiceId: $e");
              // Remove the problematic callback immediately
              _positionCallbacks.remove(voiceId);
            }
          }
        });
  }

  /// پخش وویس
  Future<bool> playVoice(String voiceId) async {
    try {
      final playerController = _players[voiceId];
      if (playerController == null) {
        print("❌ پلیر برای وویس $voiceId یافت نشد");
        return false;
      }

      print("▶️ شروع پخش وویس: $voiceId");
      await playerController.startPlayer();
      return true;
    } catch (e) {
      print("❌ خطا در پخش وویس: $e");
      return false;
    }
  }

  /// مکث وویس
  Future<bool> pauseVoice(String voiceId) async {
    try {
      final playerController = _players[voiceId];
      if (playerController == null) return false;

      print("⏸️ مکث وویس: $voiceId");
      await playerController.pausePlayer();
      return true;
    } catch (e) {
      print("❌ خطا در مکث وویس: $e");
      return false;
    }
  }

  /// توقف وویس
  Future<bool> stopVoice(String voiceId) async {
    try {
      final playerController = _players[voiceId];
      if (playerController == null) return false;

      print("⏹️ توقف وویس: $voiceId");
      await playerController.stopPlayer();
      return true;
    } catch (e) {
      print("❌ خطا در توقف وویس: $e");
      return false;
    }
  }

  /// جستجو در وویس
  Future<bool> seekVoice(String voiceId, Duration position) async {
    try {
      final playerController = _players[voiceId];
      if (playerController == null) return false;

      await playerController.seekTo(position.inMilliseconds);
      return true;
    } catch (e) {
      print("❌ خطا در جستجو: $e");
      return false;
    }
  }

  /// دریافت وضعیت پخش
  bool isPlaying(String voiceId) {
    return _currentPlayingId == voiceId;
  }

  /// دریافت پلیر کنترلر
  PlayerController? getPlayerController(String voiceId) {
    return _players[voiceId];
  }

  /// پاکسازی پلیر
  void _cleanupPlayer(String voiceId) {
    _stateSubscriptions[voiceId]?.cancel();
    _positionSubscriptions[voiceId]?.cancel();
    _players[voiceId]?.dispose();

    _stateSubscriptions.remove(voiceId);
    _positionSubscriptions.remove(voiceId);
    _players.remove(voiceId);

    // پاک کردن callback‌ها
    _playStateCallbacks.remove(voiceId);
    _positionCallbacks.remove(voiceId);
    _durationCallbacks.remove(voiceId);

    if (_currentPlayingId == voiceId) {
      _currentPlayingId = null;
    }
  }

  /// پاکسازی تمام پلیرها
  void dispose() {
    for (final voiceId in _players.keys.toList()) {
      _cleanupPlayer(voiceId);
    }
    print("🧹 سرویس پخش وویس پاکسازی شد");
  }

  /// دریافت وویس در حال پخش
  String? get currentPlayingId => _currentPlayingId;

  /// توقف تمام پلیرها
  Future<void> stopAllVoices() async {
    for (final voiceId in _players.keys.toList()) {
      await stopVoice(voiceId);
    }
  }
}
