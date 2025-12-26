// lib/features/chat/widgets/voice_recorder_widget.dart
//
// ویجت ضبط صدا با UX مشابه تلگرام (DrKLO)
//
// ویژگی‌ها:
// ✅ انیمیشن قفل (Lock) که از پایین به بالا میاد و با حرکت انگشت هماهنگه
// ✅ اسلاید برای لغو (Slide to Cancel) با افکت معروف تلگرام
// ✅ بزرگ شدن دکمه میکروفون هنگام نگه داشتن
// ✅ ویژوالایزر (Waveform) با استفاده از ویجت موجود
// ✅ تایمر ضبط با فونت monospace
// ✅ حالت قفل شده با UI متفاوت

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_recorder_service.dart';
import 'package:Vista/widgets/enhanced_voice_visualizer.dart';

/// ویجت ضبط صدا مدرن و جذاب
class TelegramVoiceRecorder extends ConsumerStatefulWidget {
  final Function(String path, int duration) onSend;
  final VoidCallback? onLock;
  final VoidCallback? onCancel;
  // رنگ پس‌زمینه پنل ضبط (باید همرنگ تکست باکس شما باشه)
  final Color? backgroundColor;

  const TelegramVoiceRecorder({
    super.key,
    required this.onSend,
    this.onLock,
    this.onCancel,
    this.backgroundColor,
  });

  @override
  ConsumerState<TelegramVoiceRecorder> createState() =>
      _TelegramVoiceRecorderState();
}

class _TelegramVoiceRecorderState extends ConsumerState<TelegramVoiceRecorder>
    with TickerProviderStateMixin {
  // کنترلرهای انیمیشن
  late AnimationController _scaleController;
  late AnimationController _lockController;
  late AnimationController _cancelController;

  // متغیرهای وضعیت
  bool _isRecording = false;
  bool _isLocked = false;
  double _dragOffset = 0.0;
  double _lockOffset = 0.0;
  Timer? _timer;
  int _recordDuration = 0;

  // سرویس ضبط صدا
  final _voiceRecorder = VoiceRecorderService();

  // ثوابت مشابه تلگرام
  static const double _lockTriggerPosition = -100.0; // فاصله عمودی برای قفل شدن
  static const double _cancelTriggerPosition = -120.0; // فاصله افقی برای لغو
  static const double _micScaleSize = 1.8; // میزان بزرگ شدن میکروفون

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 1.0,
      upperBound: _micScaleSize,
    );

    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cancelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _lockController.dispose();
    _cancelController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // شروع ضبط
  void _startRecording() async {
    final hasPermission = await _voiceRecorder.hasPermission();
    if (!hasPermission) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _isLocked = false;
      _recordDuration = 0;
      _dragOffset = 0;
      _lockOffset = 0;
    });

    _scaleController.forward();
    _lockController.reset();
    _lockController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDuration++;
        });
      }
    });

    await _voiceRecorder.startRecording();
  }

  // پایان ضبط و ارسال
  void _stopAndSend() async {
    if (!_isRecording) return;

    final file = await _voiceRecorder.stopRecording();
    _resetState();

    if (file != null && mounted) {
      widget.onSend(file.path, _recordDuration);
    }
  }

  // لغو ضبط
  void _cancelRecording() async {
    await _voiceRecorder.cancelRecording();
    HapticFeedback.heavyImpact();
    _resetState();
    widget.onCancel?.call();
  }

  // قفل کردن ضبط
  void _lockRecording() {
    if (_isLocked) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isLocked = true;
    });
    // میکروفون برمیگرده به سایز عادی ولی ضبط ادامه داره
    _scaleController.reverse();
    widget.onLock?.call();
  }

  void _resetState() {
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _dragOffset = 0;
      _lockOffset = 0;
      _recordDuration = 0;
    });
    _timer?.cancel();
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLocked) {
      return _buildLockedUi(theme);
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // 1. پنل اسلاید برای لغو (Slide to Cancel)
        if (_isRecording)
          Positioned(
            right: 50,
            bottom: 0,
            left: -MediaQuery.of(context).size.width +
                100, // کشیدن تا انتهای چپ صفحه
            child: Opacity(
              // هرچقدر بیشتر میکشی، متن کمرنگ تر میشه (افکت تلگرام)
              opacity:
                  (1 - (-_dragOffset / _cancelTriggerPosition)).clamp(0.0, 1.0),
              child: Container(
                height: 50,
                padding: const EdgeInsets.only(right: 20),
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      "برای لغو بکشید",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 2. تایمر و نشانگر ضبط (بالای دکمه میکروفون در حالت فشرده)
        if (_isRecording)
          Positioned(
            right: 80 + _dragOffset, // با درگ حرکت میکنه
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.6)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  FadeTransition(
                    opacity:
                        _cancelController.drive(Tween(begin: 1.0, end: 0.0)),
                    child:
                        const Icon(Icons.circle, size: 10, color: Colors.red),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(
                      fontFamily: 'monospace', // فونت شبیه ساعت دیجیتال
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. آیکون قفل (که بالا میره)
        if (_isRecording)
          Positioned(
            right: 6,
            // لاجیک حرکت قفل: هم با انیمیشن اولیه میاد، هم با انگشت حرکت میکنه
            bottom: 60 + (-_lockOffset).clamp(0, 150),
            child: AnimatedBuilder(
              animation: _lockController,
              builder: (context, child) {
                // اگر کاربر خیلی کشید بالا و قفل شد، این آیکون دیگه نشون داده نمیشه
                return Opacity(
                  opacity: _lockOffset < _lockTriggerPosition ? 0.0 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          )
                        ]),
                    child: const Column(
                      children: [
                        Icon(Icons.lock_open, size: 18, color: Colors.grey),
                        Icon(Icons.keyboard_arrow_up,
                            size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // 4. دکمه اصلی میکروفون (Gesture Detector)
        GestureDetector(
          onLongPressStart: (_) => _startRecording(),
          onLongPressEnd: (details) {
            if (_isLocked) return; // اگر قفل شده، رها کردن تاثیری نداره

            // اگر کاربر کشیده بود به سمت چپ (لغو)
            if (_dragOffset < _cancelTriggerPosition) {
              _cancelRecording();
            } else {
              _stopAndSend();
            }
          },
          onLongPressMoveUpdate: (details) {
            if (_isLocked) return;

            // محاسبه درگ (Offset)
            // localOffsetFromOrigin میزان جابجایی نسبت به نقطه شروع لمس رو میده
            final offset = details.localOffsetFromOrigin;

            setState(() {
              // درگ افقی برای لغو (فقط مقادیر منفی یعنی سمت چپ)
              if (offset.dx < 0) {
                _dragOffset = offset.dx;
              }

              // درگ عمودی برای قفل (فقط مقادیر منفی یعنی سمت بالا)
              if (offset.dy < 0) {
                _lockOffset = offset.dy;
              }
            });

            // چک کردن تریگرها
            if (_dragOffset < _cancelTriggerPosition) {
              _cancelRecording();
            } else if (_lockOffset < _lockTriggerPosition) {
              _lockRecording();
            }
          },
          child: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _scaleController.value : 1.0,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : theme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isRecording)
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- بخش اصلاح شده برای رفع مشکل رنگ دکمه و پس‌زمینه ---
  Widget _buildLockedUi(ThemeData theme) {
    final bgColor = widget.backgroundColor ?? theme.cardColor;

    // منطق تعیین رنگ دکمه ارسال:
    // ۱. اگر تم دارک بود و رنگ اصلی سفید/روشن بود -> از آبی تلگرام استفاده کن
    // ۲. در غیر این صورت -> از رنگ اصلی تم استفاده کن
    Color sendBtnColor;
    if (theme.brightness == Brightness.dark &&
        theme.primaryColor.computeLuminance() > 0.5) {
      sendBtnColor = const Color(0xFF3390EC); // Telegram Blue
    } else {
      sendBtnColor = theme.primaryColor;
    }

    // منطق تعیین رنگ آیکون داخل دکمه:
    // اگر رنگ دکمه روشن است -> آیکون سیاه
    // اگر رنگ دکمه تیره است -> آیکون سفید
    final sendIconColor =
        sendBtnColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor, // رنگ پس‌زمینه یکدست با ورودی متن
        // حذف بردر بالا برای جلوگیری از ایجاد خط جداکننده ناخواسته
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
            onPressed: _cancelRecording,
          ),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatDuration(_recordDuration),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  child: EnhancedVoiceVisualizer(
                    waveformData: List.generate(20, (_) => 30.0),
                    isRecording: true,
                    progress: 1.0,
                    primaryColor: sendBtnColor,
                    height: 20,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // دکمه ارسال با کنتراست رنگی اصلاح شده
          GestureDetector(
            onTap: _stopAndSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: sendBtnColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: sendBtnColor.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: sendIconColor, // اینجا رنگ درست اعمال می‌شود
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎤 LEGACY SUPPORT - برای سازگاری با کد قدیمی
// ═══════════════════════════════════════════════════════════════════════════

/// وضعیت ضبط (برای سازگاری)
enum RecordingState {
  idle,
  recording,
  locked,
  cancelled,
}

/// نتیجه ضبط (برای سازگاری)
class VoiceRecordingResult {
  final String filePath;
  final int durationSeconds;
  final List<double> waveformData;

  const VoiceRecordingResult({
    required this.filePath,
    required this.durationSeconds,
    required this.waveformData,
  });
}

/// ویجت ضبط صدا (Legacy - برای سازگاری با کد قدیمی)
/// استفاده از TelegramVoiceRecorder توصیه میشه
@Deprecated('Use TelegramVoiceRecorder instead')
class VoiceRecorderWidget extends ConsumerStatefulWidget {
  final Function(VoiceRecordingResult) onRecordingComplete;
  final VoidCallback? onRecordingStart;
  final VoidCallback? onRecordingCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingStart,
    this.onRecordingCancel,
  });

  @override
  ConsumerState<VoiceRecorderWidget> createState() =>
      _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends ConsumerState<VoiceRecorderWidget> {
  @override
  Widget build(BuildContext context) {
    return TelegramVoiceRecorder(
      onSend: (path, duration) {
        widget.onRecordingComplete(VoiceRecordingResult(
          filePath: path,
          durationSeconds: duration,
          waveformData: [],
        ));
      },
      onCancel: widget.onRecordingCancel,
    );
  }
}
