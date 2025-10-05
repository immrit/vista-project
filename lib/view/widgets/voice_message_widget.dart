import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../provider/voice_settings_provider.dart';
import '../../provider/provider.dart';
import '../../services/voice_cache_service.dart';
import '../../services/global_voice_manager.dart';

/// ویجت نمایش پیام وویس مدرن و شیک مثل تلگرام
class VoiceMessageWidget extends ConsumerStatefulWidget {
  final String audioUrl;
  final Uint8List? audioBytes;
  final List<double>? waveformData;
  final bool isMe;
  final bool isPreview;
  final int? duration;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    this.audioBytes,
    this.waveformData,
    required this.isMe,
    this.isPreview = false,
    this.duration,
    this.onDelete,
    this.onReply,
  });

  @override
  ConsumerState<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends ConsumerState<VoiceMessageWidget> {
  late AudioPlayer _audioPlayer;
  late PlayerController _waveformController;

  bool _isInitialized = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isCached = false;
  double _downloadProgress = 0.0;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  String? _error;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _waveformController = PlayerController();
    _initializeWaveform();
    _setupAudioPlayer();
  }

  bool _hasCheckedAutoDownload = false;

  /// بررسی اینکه آیا باید وویس خودکار دانلود شود
  void _checkAutoDownload() {
    if (_hasCheckedAutoDownload || _isDownloaded || _isDownloading) return;

    _hasCheckedAutoDownload = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final autoDownloadSettings = ref.read(autoDownloadProvider);
        final voiceSettings = ref.read(voiceSettingsProvider);

        // بررسی تنظیمات دانلود خودکار رسانه
        bool shouldAutoDownload = false;
        switch (autoDownloadSettings.voices) {
          case 'always':
            shouldAutoDownload = true;
            break;
          case 'wifi':
            // TODO: بررسی وضعیت Wi-Fi
            shouldAutoDownload = true; // موقتاً true
            break;
          case 'never':
            shouldAutoDownload = false;
            break;
        }

        // همچنین بررسی تنظیمات وویس
        if (shouldAutoDownload && voiceSettings.shouldAutoDownload()) {
          print('🔄 Auto-downloading voice: ${widget.audioUrl}');
          _downloadAndInitializePlayer();
        }
      }
    });
  }

  void _setupAudioPlayer() {
    // تنظیمات اولیه برای just_audio
    _audioPlayer.setVolume(1.0);
    _audioPlayer.setSpeed(1.0);

    // تنظیم listeners
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _totalDuration = duration);
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() => _isPlaying = playerState.playing);

        // اگر پخش تمام شد، به ابتدا برگرد
        if (playerState.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          setState(() => _isPlaying = false);
        }
      }
    });
  }

  Future<void> _initializeWaveform() async {
    // فقط waveform را آماده می‌کنیم، فایل را دانلود نمی‌کنیم
    if (widget.waveformData != null && widget.waveformData!.isNotEmpty) {
      // اگر waveform data موجود است، از آن استفاده می‌کنیم
      setState(() {
        _totalDuration = Duration(seconds: widget.duration ?? 0);
      });
    }
  }

  Future<File> _downloadAudioFile(String url) async {
    final uri = Uri.parse(url);
    final fileName = path.basename(uri.path);
    final tempDir = await getTemporaryDirectory();
    final localFile = File(path.join(tempDir.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}_$fileName'));

    final request = http.Request('GET', uri);
    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception('خطا در دانلود فایل: ${streamedResponse.statusCode}');
    }

    final totalBytes = streamedResponse.contentLength ?? 0;
    int downloadedBytes = 0;

    final sink = localFile.openWrite();

    await for (final chunk in streamedResponse.stream) {
      if (!_isDownloading) {
        // اگر دانلود لغو شده، فایل را حذف کن
        await localFile.delete();
        return localFile; // فایل خالی برگردان، exception پرتاب نکن
      }

      sink.add(chunk);
      downloadedBytes += chunk.length;

      if (totalBytes > 0) {
        setState(() {
          _downloadProgress = downloadedBytes / totalBytes;
        });
      }
    }

    await sink.close();
    return localFile;
  }

  Future<void> _downloadAndInitializePlayer() async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
        _error = null;
      });

      if (widget.audioUrl.isEmpty) {
        throw Exception('URL فایل صوتی خالی است');
      }

      final voiceSettings = ref.read(voiceSettingsProvider);
      final voiceCacheService = VoiceCacheService();

      File? localFile;

      // ابتدا بررسی کش
      if (voiceSettings.cacheEnabled) {
        localFile = await voiceCacheService.getCachedFile(widget.audioUrl);
        if (localFile != null) {
          setState(() {
            _isCached = true;
          });
        }
      }

      // اگر فایل کش نشده، دانلود کن
      if (localFile == null) {
        localFile = await _downloadAudioFile(widget.audioUrl);

        // کش کردن فایل اگر کش فعال است
        if (voiceSettings.cacheEnabled) {
          final cachedFilePath = await voiceCacheService.cacheLocalVoiceFile(
              widget.audioUrl, localFile);
          if (cachedFilePath != null) {
            // استفاده از فایل کش شده به جای فایل موقت
            localFile = File(cachedFilePath);
            print('✅ Voice file cached: $cachedFilePath');
          }
        }
      } else {
        print('✅ Using cached voice file: ${localFile.path}');
      }

      if (!_isDownloading) return;

      setState(() {
        _localFilePath = localFile!.path;
        _isDownloaded = true;
        _isDownloading = false;
      });

      // آماده‌سازی فایل صوتی
      await _audioPlayer.setFilePath(localFile.path);

      // انتظار برای بارگذاری کامل
      await Future.delayed(const Duration(milliseconds: 1000));

      final duration = _audioPlayer.duration;
      if (duration == null || duration.inSeconds == 0) {
        throw Exception('فایل صوتی قابل پخش نیست');
      }

      setState(() {
        _isInitialized = true;
        _totalDuration = duration;
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        if (e.toString() != 'Exception: دانلود لغو شد') {
          _error = e.toString();
        }
      });
    }
  }

  Future<void> _playPause() async {
    try {
      final shouldAutoDownload = ref.read(shouldAutoDownloadVoiceProvider);

      // اگر دانلود خودکار فعال است و فایل دانلود نشده
      if (shouldAutoDownload && !_isDownloaded && !_isDownloading) {
        await _downloadAndInitializePlayer();
        return;
      }

      // اگر دانلود خودکار غیرفعال است و فایل دانلود نشده
      if (!shouldAutoDownload && !_isDownloaded && !_isDownloading) {
        await _downloadAndInitializePlayer();
        return;
      }

      if (_isDownloading) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        return;
      }

      if (!_isInitialized) {
        await _downloadAndInitializePlayer();
        return;
      }

      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // اطمینان از تنظیمات صدا
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setSpeed(1.0);

        // استفاده از GlobalVoiceManager برای مدیریت پخش
        final voiceManager = GlobalVoiceManager();
        await voiceManager.playVoice(widget.audioUrl, _audioPlayer);

        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خطا در پخش وویس'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _seekTo(double progress) {
    if (!_isInitialized || _totalDuration.inMilliseconds == 0) return;

    final position = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round(),
    );

    final clampedPosition = Duration(
      milliseconds: position.inMilliseconds
          .clamp(0, _totalDuration.inMilliseconds - 100), // 100ms قبل از انتها
    );

    _audioPlayer.seek(clampedPosition);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // نمایش خطا به صورت toast
    if (_error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('خطا در پخش وویس'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          // پاک کردن خطا بعد از نمایش
          setState(() {
            _error = null;
          });
        }
      });
    }

    // بررسی auto-download با Consumer
    return Consumer(
      builder: (context, ref, child) {
        // چک کردن تنظیمات دانلود خودکار
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDownloaded && !_isDownloading) {
            _checkAutoDownload();
          }
        });

        return _buildVoiceWidget(isDark);
      },
    );
  }

  Widget _buildVoiceWidget(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? (isDark ? const Color(0xFF1E40AF) : const Color(0xFF3B82F6))
            : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // دکمه پلی/دانلود/لغو
          Tooltip(
            message: _isDownloading
                ? 'در حال دانلود...'
                : (_isCached
                    ? 'فایل کش شده - آماده پخش'
                    : (_isDownloaded
                        ? 'دانلود شده - آماده پخش'
                        : 'برای دانلود کلیک کنید')),
            child: GestureDetector(
              onTap: _playPause,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDownloading
                      ? Colors.red
                      : (_isCached
                          ? const Color(0xFF8B5CF6) // بنفش برای کش شده
                          : (_isDownloaded
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isDownloading
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: _downloadProgress,
                              strokeWidth: 2.5,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                          Text(
                            '${(_downloadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Icon(
                        _isDownloading
                            ? Icons.close_rounded
                            : (_isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // waveform مدرن
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox;
                final localPosition = box.globalToLocal(details.globalPosition);
                final progress = localPosition.dx / box.size.width;
                _seekTo(progress);
              },
              child: SizedBox(
                height: 24,
                child: Stack(
                  children: [
                    // Background progress bar
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: (widget.isMe
                                ? Colors.white
                                : (isDark
                                    ? Colors.white
                                    : Colors.grey.shade800))
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Download progress indicator
                    if (_isDownloading)
                      Container(
                        height: 4,
                        width: _downloadProgress *
                            MediaQuery.of(context).size.width *
                            0.4,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    // Playback progress indicator
                    if (!_isDownloading && _totalDuration.inMilliseconds > 0)
                      Container(
                        height: 4,
                        width: (MediaQuery.of(context).size.width * 0.4) *
                            (_currentPosition.inMilliseconds /
                                    _totalDuration.inMilliseconds)
                                .clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF10B981)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // تایم کد
          Text(
            _formatDuration(_totalDuration),
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    print('🗑️ Disposing VoiceMessageWidget for: ${widget.audioUrl}');

    // توقف پخش از طریق GlobalVoiceManager
    try {
      final voiceManager = GlobalVoiceManager();
      if (voiceManager.isPlaying(widget.audioUrl)) {
        voiceManager.stopCurrentVoice();
      }
      _audioPlayer.stop();
    } catch (e) {
      print('⚠️ Error stopping audio player: $e');
    }

    // dispose players
    _audioPlayer.dispose();
    _waveformController.dispose();

    // پاک کردن فایل موقت اگر وجود دارد
    if (_localFilePath != null) {
      try {
        final file = File(_localFilePath!);
        if (file.existsSync()) {
          file.deleteSync();
          print('🗑️ Deleted temporary voice file: $_localFilePath');
        }
      } catch (e) {
        print('⚠️ Error deleting temporary file: $e');
      }
    }

    super.dispose();
  }
}
