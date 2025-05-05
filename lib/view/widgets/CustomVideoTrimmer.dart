import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_compress/video_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomVideoTrimmer extends ConsumerStatefulWidget {
  // تغییر به ConsumerStatefulWidget
  final dynamic videoFile;
  final Function(File) onVideoSaved;
  final bool isWeb;
  final Duration maxDuration;

  const CustomVideoTrimmer({
    Key? key,
    required this.videoFile,
    required this.onVideoSaved,
    this.isWeb = kIsWeb,
    this.maxDuration = const Duration(minutes: 1),
  }) : super(key: key);

  @override
  ConsumerState<CustomVideoTrimmer> createState() =>
      _CustomVideoTrimmerState(); // تغییر به ConsumerState
}

class _CustomVideoTrimmerState extends ConsumerState<CustomVideoTrimmer> {
  // تغییر به ConsumerState
  late VideoPlayerController _controller;
  double _startPos = 0.0;
  double _endPos = 1.0;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isTrimming = false;
  Duration _videoDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  final double _thumbWidth = 10;
  Subscription? _progressSubscription;
  List<Uint8List> _thumbnails = [];
  bool _loadingThumbnails = false;
  int _compressionProgress = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _progressSubscription?.unsubscribe();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() => _isInitialized = false);

      if (widget.isWeb) {
        _controller =
            VideoPlayerController.networkUrl(Uri.parse(widget.videoFile));
      } else {
        _controller = VideoPlayerController.file(widget.videoFile as File);
      }

      await _controller.initialize();
      _videoDuration = _controller.value.duration;

      if (_videoDuration > widget.maxDuration) {
        _endPos =
            widget.maxDuration.inMilliseconds / _videoDuration.inMilliseconds;
      }

      await _controller.seekTo(_getStartPosition());
      _controller.addListener(_videoListener);

      setState(() => _isInitialized = true);

      // آغاز پخش ویدیو به صورت خودکار
      _controller.play();
      setState(() => _isPlaying = true);

      // شروع بارگذاری تصاویر بندانگشتی
      _loadThumbnails();
    } catch (e) {
      debugPrint('خطا در راه‌اندازی پخش‌کننده: $e');
      _showError('خطا در بارگذاری ویدیو');
    }
  }

  Future<void> _loadThumbnails() async {
    if (widget.isWeb) return; // در وب فعلا پشتیبانی نمی‌شود

    setState(() => _loadingThumbnails = true);

    try {
      final int duration = _videoDuration.inMilliseconds;
      const int thumbnailsCount = 10; // تعداد تصاویر بندانگشتی

      List<Uint8List> thumbnails = [];

      for (int i = 0; i < thumbnailsCount; i++) {
        final position = (duration * i ~/ thumbnailsCount).toInt();
        await _controller.seekTo(Duration(milliseconds: position));
        await Future.delayed(const Duration(milliseconds: 100));

        // به دلیل محدودیت‌های فعلی، این قسمت به صورت کامنت باقی می‌ماند
        // در اینجا می‌توانید از یک پکیج دیگر برای گرفتن فریم استفاده کنید
        // مثلا: video_thumbnail یا video_compress

        // اینجا فقط برای نمایش است و فریم‌ها واقعی نیستند
        // تصویر خالی اضافه می‌کنیم
        thumbnails.add(Uint8List(0));
      }

      setState(() {
        _thumbnails = thumbnails;
        _loadingThumbnails = false;
      });

      // بازگشت به موقعیت اولیه پخش
      await _controller.seekTo(_getStartPosition());
    } catch (e) {
      debugPrint('خطا در بارگذاری تصاویر بندانگشتی: $e');
      setState(() => _loadingThumbnails = false);
    }
  }

  void _videoListener() {
    if (!mounted) return;

    final position = _controller.value.position;
    setState(() => _currentPosition = position);

    // بررسی رسیدن به انتهای قسمت انتخاب شده
    if (position >= _getEndPosition()) {
      _controller.seekTo(_getStartPosition());

      // اگر در حال پخش است، ادامه می‌دهیم
      if (_isPlaying) {
        _controller.play();
      }
    }
  }

  Duration _getStartPosition() {
    final milliseconds = (_startPos * _videoDuration.inMilliseconds).round();
    return Duration(milliseconds: milliseconds.abs());
  }

  Duration _getEndPosition() {
    final milliseconds = (_endPos * _videoDuration.inMilliseconds).round();
    return Duration(milliseconds: milliseconds.abs());
  }

  Duration get _selectedDuration => _getEndPosition() - _getStartPosition();

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _trimVideo() async {
    if (_isTrimming) return;

    setState(() {
      _isTrimming = true;
      _compressionProgress = 0;
    });

    try {
      // بررسی مدت زمان
      if (_selectedDuration.inMilliseconds <= 0) {
        throw Exception('مدت زمان انتخاب شده باید بیشتر از صفر باشد');
      }

      if (_selectedDuration > widget.maxDuration) {
        throw Exception(
            'مدت زمان انتخاب شده نمی‌تواند بیشتر از ${widget.maxDuration.inMinutes} دقیقه باشد');
      }

      // برای حالت وب فقط فایل اصلی را برمی‌گردانیم
      if (widget.isWeb) {
        if (mounted) {
          Navigator.pop(context, widget.videoFile);
        }
        return;
      }

      final startMs = (_startPos * _videoDuration.inMilliseconds).toInt();
      final endMs = (_endPos * _videoDuration.inMilliseconds).toInt();
      final duration = endMs - startMs;

      debugPrint('شروع برش ویدیو: شروع=${startMs}ms، مدت=${duration}ms');

      // توقف پخش قبل از برش
      await _controller.pause();
      setState(() => _isPlaying = false);

      // دریافت پیشرفت فشرده‌سازی
      _progressSubscription?.unsubscribe();
      _progressSubscription =
          VideoCompress.compressProgress$.subscribe((progress) {
        debugPrint('پیشرفت فشرده‌سازی: $progress%');
        setState(() => _compressionProgress = progress.round());
      });

      final MediaInfo? result = await VideoCompress.compressVideo(
        (widget.videoFile as File).path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        startTime: startMs ~/ 1000,
        duration: duration ~/ 1000,
      );

      if (result?.file == null || !File(result!.file!.path).existsSync()) {
        throw Exception('خطا در ذخیره ویدیو');
      }

      debugPrint('ویدیو با موفقیت برش خورد: ${result.file!.path}');

      // برگرداندن نتیجه
      if (mounted) {
        Navigator.pop(context, result.file);
      }
    } catch (e) {
      debugPrint('خطا در _trimVideo: $e');
      _showError(e.toString());
    } finally {
      _progressSubscription?.unsubscribe();
      _progressSubscription = null;
      setState(() => _isTrimming = false);
    }
  }

  Widget _buildProgressBar() {
    if (!_isInitialized) return const SizedBox();

    double progress = 0.0;
    if (_currentPosition > _getStartPosition()) {
      progress = (_currentPosition - _getStartPosition()).inMilliseconds /
          _selectedDuration.inMilliseconds;
    }

    return Container(
      height: 2,
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: Colors.grey[800],
        valueColor: const AlwaysStoppedAnimation(Colors.blue),
      ),
    );
  }

  Widget _buildTrimmerArea() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // پس‌زمینه فریم‌های ویدیو (تصاویر بندانگشتی)
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: _loadingThumbnails
                ? Center(child: Text('در حال بارگذاری فریم‌ها...'))
                : Row(
                    children: List.generate(_thumbnails.length, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          // اینجا در پیاده‌سازی واقعی باید تصاویر بندانگشتی نمایش داده شود
                        ),
                      );
                    }),
                  ),
          ),

          // نوار اسلایدر برای برش
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 50,
              trackShape: _CustomTrackShape(),
              thumbColor: Colors.blue,
              thumbShape:
                  RoundSliderThumbShape(enabledThumbRadius: _thumbWidth),
              overlayShape:
                  RoundSliderOverlayShape(overlayRadius: _thumbWidth * 1.5),
              valueIndicatorShape: PaddleSliderValueIndicatorShape(),
              valueIndicatorColor: Colors.blue,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            child: RangeSlider(
              values: RangeValues(_startPos, _endPos),
              onChanged: (RangeValues values) {
                setState(() {
                  _startPos = values.start;
                  _endPos = values.end;
                });
                _controller.seekTo(_getStartPosition());
              },
              onChangeEnd: (RangeValues values) {
                _controller.seekTo(_getStartPosition());
                if (_isPlaying) _controller.play();
              },
              labels: RangeLabels(
                _formatDuration(_getStartPosition()),
                _formatDuration(_getEndPosition()),
              ),
              divisions: 100,
              min: 0.0,
              max: 1.0,
            ),
          ),

          // مدت زمان انتخاب شده
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'مدت انتخاب شده: ${_formatDuration(_selectedDuration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        // بررسی می‌کنیم که آیا در حال برش هستیم
        return !_isTrimming;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ویرایش ویدیو'),
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          elevation: 0,
          actions: [
            if (_isInitialized)
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                    _isPlaying ? _controller.play() : _controller.pause();
                  });
                },
              ),
          ],
        ),
        body: Column(
          children: [
            // بخش ویدیو پلیر
            Expanded(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        _isInitialized ? _controller.value.aspectRatio : 16 / 9,
                    child: _isInitialized
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_controller),
                              // نشانگر قسمت در حال پخش
                              if (_isPlaying)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildProgressBar(),
                                ),
                            ],
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // بخش برش ویدیو
            if (_isInitialized) _buildTrimmerArea(),

            // دکمه‌ها و اطلاعات در پایین صفحه
            if (_isInitialized)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // نمایش وضعیت پیشرفت فشرده‌سازی
                    if (_isTrimming)
                      Column(
                        children: [
                          Text(
                            'در حال پردازش: $_compressionProgress%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _compressionProgress / 100,
                            backgroundColor: Colors.grey[300],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // دکمه‌های عملیات
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isTrimming ? null : _trimVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: _isTrimming
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.content_cut, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'برش و ذخیره ویدیو',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // توضیحات
                    const SizedBox(height: 8),
                    Text(
                      'حداکثر مدت مجاز: ${_formatDuration(widget.maxDuration)}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// کلاس سفارشی برای تغییر شکل اسلایدر
class _CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 10;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
