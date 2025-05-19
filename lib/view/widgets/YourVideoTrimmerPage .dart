import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import '../../../model/UserModel.dart';
import '../screen/Settings/vistaStore/store.dart'; // اضافه کردن import

class YourVideoTrimmerPage extends StatefulWidget {
  final File videoFile;
  final Duration maxDuration;

  const YourVideoTrimmerPage({
    Key? key,
    required this.videoFile,
    required this.maxDuration,
  }) : super(key: key);

  @override
  _YourVideoTrimmerPageState createState() => _YourVideoTrimmerPageState();
}

class _YourVideoTrimmerPageState extends State<YourVideoTrimmerPage> {
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0.0;
  double _endValue = 0.0;

  bool _isPlaying = false;
  bool _progressVisibility = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  void _loadVideo() {
    _trimmer.loadVideo(videoFile: widget.videoFile);
  }

  Future<void> _saveVideo() async {
    setState(() {
      _progressVisibility = true;
    });

    final selectedDurationMs = _endValue - _startValue;
    final maxDurationMs = widget.maxDuration.inMilliseconds;

    if (selectedDurationMs <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('لطفاً محدوده زمانی معتبری را انتخاب کنید')),
        );
      }
      setState(() => _progressVisibility = false);
      return;
    }

    if (selectedDurationMs > maxDurationMs) {
      if (mounted) {
        // پیام خطای بهتر برای کاربران عادی و پریمیوم
        final message = widget.maxDuration.inMinutes == 2
            ? 'شما کاربر پریمیوم هستید و حداکثر می‌توانید ویدیوی ۲ دقیقه‌ای آپلود کنید.'
            : 'کاربران عادی می‌توانند ویدیوی حداکثر ۱ دقیقه‌ای آپلود کنند. برای افزایش این محدودیت، اکانت خود را ارتقا دهید.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      setState(() => _progressVisibility = false);
      return;
    }

    _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      onSave: (outputPath) {
        setState(() => _progressVisibility = false);
        if (outputPath != null && outputPath.isNotEmpty) {
          debugPrint('OUTPUT PATH: $outputPath');
          Navigator.pop(context, outputPath);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('خطا در ذخیره ویدیو یا مسیر خروجی نامعتبر.')),
          );
        }
      },
    );
  }

  Widget _buildUserBadgeInfo() {
    final bool isPremiumUser = widget.maxDuration.inMinutes == 2;
    final String badgeType = isPremiumUser ? 'ویژه' : 'عادی';

    IconData badgeIcon = Icons.person_outline;
    List<Color> gradientColors;

    // تعیین آیکون و رنگ بر اساس نوع نشان
    if (isPremiumUser) {
      switch (VerificationType) {
        case VerificationType.blueTick:
          badgeIcon = Icons.verified;
          gradientColors = [Colors.blue.shade400, Colors.blue.shade700];
          break;
        case VerificationType.goldTick:
          badgeIcon = Icons.workspace_premium;
          gradientColors = [Colors.amber.shade400, Colors.amber.shade700];
          break;
        case VerificationType.blackTick:
          badgeIcon = Icons.verified_user;
          gradientColors = [Colors.grey.shade800, Colors.black];
          break;
        default:
          gradientColors = [Colors.blue.shade800, Colors.blue.shade900];
      }
    } else {
      gradientColors = [Colors.blue.shade800, Colors.blue.shade900];
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(badgeIcon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'کاربر $badgeType',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPremiumUser
                      ? 'شما می‌توانید ویدیوهای تا ۲ دقیقه آپلود کنید'
                      : 'کاربران نشان‌دار می‌توانند ویدیوهای تا ۲ دقیقه آپلود کنند',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isPremiumUser) // فقط برای کاربران عادی
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Material(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('برای دریافت نشان با پشتیبانی تماس بگیرید'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => VerificationBadgeStore())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium,
                              color: Colors.black87, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'پریمیوم شوید',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !Navigator.of(context).userGestureInProgress && !_progressVisibility,
      child: SafeArea(
        bottom: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('برش ویدیو',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.black,
            elevation: 0,
            actions: [
              if (!_progressVisibility)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.check, color: Colors.white),
                    onPressed: _saveVideo,
                  ),
                ),
            ],
          ),
          body: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: <Widget>[
                  // اضافه کردن نمایش وضعیت کاربر در ابتدای لیست
                  _buildUserBadgeInfo(),

                  // نمایشگر پیشرفت
                  if (_progressVisibility)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.grey,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: 6,
                      ),
                    ),

                  // پیش‌نمایش ویدیو
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.blue.withOpacity(0.3), width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: VideoViewer(trimmer: _trimmer),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // تایم لاین برش
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: TrimViewer(
                      trimmer: _trimmer,
                      viewerHeight: 60,
                      viewerWidth: MediaQuery.of(context).size.width - 64,
                      maxVideoLength: widget.maxDuration,
                      durationStyle: DurationStyle.FORMAT_MM_SS,
                      editorProperties: TrimEditorProperties(
                        borderPaintColor: Colors.blue,
                        borderWidth: 4,
                        borderRadius: 5,
                        circlePaintColor: Colors.white,
                        scrubberWidth: 2,
                      ),
                      areaProperties: TrimAreaProperties.edgeBlur(
                        thumbnailQuality: 75,
                      ),
                      onChangeStart: (value) => _startValue = value,
                      onChangeEnd: (value) => _endValue = value,
                      onChangePlaybackState: (value) =>
                          setState(() => _isPlaying = value),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // دکمه پخش/توقف
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          bool playbackState =
                              await _trimmer.videoPlaybackControl(
                            startValue: _startValue,
                            endValue: _endValue,
                          );
                          setState(() => _isPlaying = playbackState);
                        },
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
