// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:intl/intl.dart';

// class CustomVideoTrimmer extends StatefulWidget {
//   final File videoFile;
//   final void Function(File trimmedFile) onVideoSaved;

//   const CustomVideoTrimmer({
//     super.key,
//     required this.videoFile,
//     required this.onVideoSaved,
//   });

//   @override
//   State<CustomVideoTrimmer> createState() => _CustomVideoTrimmerState();
// }

// class _CustomVideoTrimmerState extends State<CustomVideoTrimmer> {
//   late VideoPlayerController _controller;
//   double _startValue = 0.0;
//   double _endValue = 60.0;
//   Duration _videoDuration = Duration.zero;
//   bool _saving = false;
//   bool _isPlaying = false;

//   // فرمت زمان به صورت دقیقه:ثانیه
//   String _formatDuration(double seconds) {
//     final Duration duration = Duration(seconds: seconds.round());
//     final minutes = duration.inMinutes;
//     final remainingSeconds = duration.inSeconds % 60;
//     return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
//   }

//   @override
//   void initState() {
//     super.initState();
//     _init();
//   }

//   Future<void> _init() async {
//     _controller = VideoPlayerController.file(widget.videoFile);
//     await _controller.initialize();

//     // نمایش یک ثانیه تایم لاین برای ویدیوهای کوتاه
//     setState(() {
//       _videoDuration = _controller.value.duration;
//       _endValue = _videoDuration.inSeconds > 60
//           ? 60
//           : _videoDuration.inSeconds.toDouble();

//       // برای ویدیوهای کوتاه از یک ثانیه، حداقل یک ثانیه قرار دهیم
//       if (_endValue < 1) _endValue = 1;
//     });

//     // اضافه کردن لیسنر برای تشخیص اتمام ویدیو
//     _controller.addListener(_videoListener);
//   }

//   void _videoListener() {
//     // وقتی ویدیو به انتها رسید، به ابتدای بازه انتخابی برگردد
//     if (_controller.value.position >= Duration(seconds: _endValue.toInt())) {
//       _controller.seekTo(Duration(seconds: _startValue.toInt()));
//       if (!_controller.value.isPlaying) {
//         setState(() {
//           _isPlaying = false;
//         });
//       }
//     }

//     // بروزرسانی وضعیت پخش
//     if (_controller.value.isPlaying != _isPlaying) {
//       setState(() {
//         _isPlaying = _controller.value.isPlaying;
//       });
//     }
//   }

//   // تبدیل ثانیه به فرمت مناسب FFmpeg (HH:MM:SS.ms)
//   String _formatTimeToFFmpeg(double seconds) {
//     final Duration duration = Duration(milliseconds: (seconds * 1000).toInt());
//     int hours = duration.inHours;
//     int minutes = duration.inMinutes % 60;
//     int secs = duration.inSeconds % 60;
//     int milliseconds = duration.inMilliseconds % 1000;

//     return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
//   }

//   Future<void> _trimVideo() async {
//     if (_endValue - _startValue < 1) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('طول ویدیو باید حداقل یک ثانیه باشد'),
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//       return;
//     }

//     setState(() => _saving = true);

//     // نمایش پیشرفت عملیات
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const AlertDialog(
//         title: Text('در حال برش ویدیو'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             LinearProgressIndicator(),
//             SizedBox(height: 16),
//             Text('لطفا منتظر بمانید...'),
//           ],
//         ),
//       ),
//     );

//     try {
//       // تعیین مسیر و نام فایل خروجی
//       final now = DateTime.now();
//       final formatter = DateFormat('MMMd,yyyy-HH:mm:ss', 'en_US');
//       final timestamp =
//           formatter.format(now).replaceAll(',', '').replaceAll(':', '');
//       final uniqueFileName = "trimmed_video_${now.millisecondsSinceEpoch}.mp4";

//       // پیدا کردن مسیر پوشه temp
//       final tempDir = await getTemporaryDirectory();
//       final trimmerDir = Directory('${tempDir.path}/Trimmer');

//       if (!await trimmerDir.exists()) {
//         await trimmerDir.create(recursive: true);
//         print('Creating');
//       } else {
//         print('Exists');
//       }
//       print('Retrieved Trimmer folder');

//       final outputPath = '${trimmerDir.path}/$uniqueFileName';

//       // تبدیل زمان‌ها به فرمت مناسب FFmpeg
//       final startFormatted = _formatTimeToFFmpeg(_startValue);
//       final endFormatted = _formatTimeToFFmpeg(_endValue);

//       print(
//           'شروع برش ویدیو از ${_startValue.toStringAsFixed(2)} تا ${_endValue.toStringAsFixed(2)} ثانیه');
//       print('زمان شروع: $startFormatted');
//       print('زمان پایان: $endFormatted');
//       print('نام فایل خروجی: $uniqueFileName');
//       print('مسیر فایل خروجی: $outputPath');
//       print('DateTime: ${now.toString()}');
//       print('Formatted: $timestamp');

//       // محاسبه دقیق مدت زمان
//       final durationSec = _endValue - _startValue;
//       final durationFormatted = _formatTimeToFFmpeg(durationSec);

//       // FFmpeg command برای برش ویدیو
//       // از روش -ss و -t استفاده می‌کنیم که دقیق‌تر است
//       final command =
//           '-ss $startFormatted -t $durationFormatted -i "${widget.videoFile.path}" -c:v libx264 -c:a aac -strict experimental -b:a 128k "$outputPath"';

//       print('فرمان FFmpeg: $command');

//       // اجرای دستور FFmpeg
//       final session = await FFmpegKit.execute(command);
//       final returnCode = await session.getReturnCode();

//       // بستن دیالوگ پیشرفت
//       if (Navigator.canPop(context)) {
//         Navigator.of(context).pop();
//       }

//       setState(() => _saving = false);

//       if (ReturnCode.isSuccess(returnCode)) {
//         // برش موفقیت‌آمیز بود
//         final outputFile = File(outputPath);

//         if (await outputFile.exists()) {
//           final fileSize = await outputFile.length();
//           print('فایل ویدیوی برش خورده ایجاد شد: $outputPath');
//           print('اندازه فایل: $fileSize بایت');

//           // فراخوانی تابع بازگشتی با فایل خروجی
//           widget.onVideoSaved(outputFile);

//           // نمایش پیام موفقیت‌آمیز
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('ویدیو با موفقیت برش داده شد'),
//               backgroundColor: Colors.green,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );

//           Navigator.pop(context);
//         } else {
//           _showError('فایل خروجی ایجاد نشد!');
//         }
//       } else {
//         // خطا در برش ویدیو
//         final logs = await session.getAllLogsAsString();
//         print('خطای FFmpeg: $logs');
//         _showError('خطا در برش ویدیو');
//       }
//     } catch (e) {
//       // بستن دیالوگ پیشرفت
//       if (Navigator.canPop(context)) {
//         Navigator.of(context).pop();
//       }

//       setState(() => _saving = false);
//       print('خطا در عملیات برش ویدیو: $e');

//       _showError('خطا در پردازش ویدیو: $e');
//     }
//   }

//   void _showError(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _controller.removeListener(_videoListener);
//     _controller.dispose();
//     super.dispose();
//   }

//   Widget _showSlider() {
//     double maxTrim = (_videoDuration.inSeconds >= 60)
//         ? 60
//         : _videoDuration.inSeconds.toDouble();

//     // برای ویدیوهای کوتاه از یک ثانیه، حداقل یک ثانیه قرار دهیم
//     if (maxTrim < 1) maxTrim = 1;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(_formatDuration(_startValue),
//                   style: const TextStyle(
//                       fontWeight: FontWeight.bold, color: Colors.white)),
//               Text('طول: ${(_endValue - _startValue).toStringAsFixed(1)} ثانیه',
//                   style: const TextStyle(
//                       fontWeight: FontWeight.w500, color: Colors.white70)),
//               Text(_formatDuration(_endValue),
//                   style: const TextStyle(
//                       fontWeight: FontWeight.bold, color: Colors.white)),
//             ],
//           ),
//         ),
//         SliderTheme(
//           data: SliderTheme.of(context).copyWith(
//             activeTrackColor: Theme.of(context).primaryColor,
//             inactiveTrackColor: Colors.grey.shade700,
//             thumbColor: Theme.of(context).primaryColor,
//             overlayColor: Theme.of(context).primaryColor.withOpacity(0.3),
//             rangeThumbShape: const RoundRangeSliderThumbShape(
//               enabledThumbRadius: 8,
//               elevation: 4,
//             ),
//             rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
//             rangeValueIndicatorShape:
//                 const PaddleRangeSliderValueIndicatorShape(),
//             valueIndicatorColor: Theme.of(context).primaryColor,
//             valueIndicatorTextStyle: const TextStyle(color: Colors.white),
//           ),
//           child: RangeSlider(
//             values: RangeValues(_startValue, _endValue),
//             min: 0.0,
//             max: maxTrim,
//             divisions: maxTrim < 10 ? (maxTrim * 10).round() : maxTrim.floor(),
//             labels: RangeLabels(
//                 _formatDuration(_startValue), _formatDuration(_endValue)),
//             onChanged: (values) {
//               double start = values.start;
//               double end = values.end;

//               // حداکثر 60 ثانیه بازه
//               if ((end - start) > 60) {
//                 start = end - 60;
//               }

//               // حداقل 1 ثانیه بازه
//               if ((end - start) < 1 && end < maxTrim) {
//                 end = start + 1;
//               }

//               setState(() {
//                 _startValue = start;
//                 _endValue = end;
//               });

//               // موقعیت ویدیو رو به نقطه شروع منتقل کنیم
//               _controller
//                   .seekTo(Duration(milliseconds: (start * 1000).toInt()));
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF121212),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF1E1E1E),
//         title: const Text('انتخاب بازه ویدیو (تا ۱ دقیقه)'),
//         actions: [
//           IconButton(
//             onPressed: _saving ? null : _trimVideo,
//             icon: const Icon(Icons.check),
//             tooltip: 'ذخیره ویدیو',
//           ),
//         ],
//       ),
//       body: _videoDuration == Duration.zero
//           ? const Center(
//               child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 CircularProgressIndicator(),
//                 SizedBox(height: 16),
//                 Text('در حال بارگذاری ویدیو...',
//                     style: TextStyle(color: Colors.white70))
//               ],
//             ))
//           : Column(
//               children: [
//                 // پلیر ویدیو
//                 Expanded(
//                   flex: 3,
//                   child: Container(
//                     width: double.infinity,
//                     color: Colors.black,
//                     child: Center(
//                       child: AspectRatio(
//                         aspectRatio: _controller.value.aspectRatio,
//                         child: Stack(
//                           alignment: Alignment.center,
//                           children: [
//                             VideoPlayer(_controller),
//                             // کنترل پخش/توقف
//                             GestureDetector(
//                               onTap: () {
//                                 setState(() {
//                                   if (_controller.value.isPlaying) {
//                                     _controller.pause();
//                                   } else {
//                                     // پخش از ابتدای بازه انتخابی
//                                     _controller.seekTo(Duration(
//                                         milliseconds:
//                                             (_startValue * 1000).toInt()));
//                                     _controller.play();
//                                   }
//                                 });
//                               },
//                               child: Container(
//                                 decoration: BoxDecoration(
//                                   color: Colors.black.withOpacity(0.3),
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Icon(
//                                   _controller.value.isPlaying
//                                       ? Icons.pause
//                                       : Icons.play_arrow,
//                                   size: 64,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             ),
//                             // زمان کنونی ویدیو
//                             Positioned(
//                               bottom: 8,
//                               left: 8,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 8, vertical: 4),
//                                 decoration: BoxDecoration(
//                                   color: Colors.black.withOpacity(0.6),
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                                 child: ValueListenableBuilder<VideoPlayerValue>(
//                                   valueListenable: _controller,
//                                   builder: (context, value, child) {
//                                     final position =
//                                         value.position.inMilliseconds / 1000;
//                                     return Text(
//                                       _formatDuration(position),
//                                       style:
//                                           const TextStyle(color: Colors.white),
//                                     );
//                                   },
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//                 // اسلایدر و کنترل‌ها
//                 Expanded(
//                   flex: 2,
//                   child: Container(
//                     padding:
//                         const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
//                     child: Column(
//                       children: [
//                         _showSlider(),
//                         const SizedBox(height: 16),

//                         // دکمه‌های تنظیم دقیق نقطه شروع و پایان
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             // دکمه‌های تنظیم دقیق نقطه شروع
//                             Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 const Text('نقطه شروع',
//                                     style: TextStyle(
//                                         fontSize: 12, color: Colors.white70)),
//                                 Row(
//                                   children: [
//                                     IconButton(
//                                       icon: const Icon(Icons.remove,
//                                           color: Colors.white),
//                                       onPressed: () {
//                                         if (_startValue > 0) {
//                                           setState(() {
//                                             _startValue = (_startValue - 0.5)
//                                                 .clamp(0, _endValue - 1);
//                                           });
//                                           _controller.seekTo(Duration(
//                                               milliseconds: (_startValue * 1000)
//                                                   .toInt()));
//                                         }
//                                       },
//                                     ),
//                                     IconButton(
//                                       icon: const Icon(Icons.add,
//                                           color: Colors.white),
//                                       onPressed: () {
//                                         setState(() {
//                                           _startValue = (_startValue + 0.5)
//                                               .clamp(0, _endValue - 1);
//                                         });
//                                         _controller.seekTo(Duration(
//                                             milliseconds:
//                                                 (_startValue * 1000).toInt()));
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),

//                             // دکمه‌های تنظیم دقیق نقطه پایان
//                             Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 const Text('نقطه پایان',
//                                     style: TextStyle(
//                                         fontSize: 12, color: Colors.white70)),
//                                 Row(
//                                   children: [
//                                     IconButton(
//                                       icon: const Icon(Icons.remove,
//                                           color: Colors.white),
//                                       onPressed: () {
//                                         setState(() {
//                                           _endValue = (_endValue - 0.5).clamp(
//                                               _startValue + 1,
//                                               _videoDuration.inSeconds
//                                                   .toDouble());
//                                         });
//                                       },
//                                     ),
//                                     IconButton(
//                                       icon: const Icon(Icons.add,
//                                           color: Colors.white),
//                                       onPressed: () {
//                                         double maxDuration =
//                                             _videoDuration.inSeconds > 60
//                                                 ? 60
//                                                 : _videoDuration.inSeconds
//                                                     .toDouble();
//                                         setState(() {
//                                           _endValue = (_endValue + 0.5).clamp(
//                                               _startValue + 1, maxDuration);
//                                         });
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//       bottomNavigationBar: _saving
//           ? Container(
//               height: 56,
//               padding: const EdgeInsets.all(16),
//               decoration: const BoxDecoration(
//                 color: Color(0xFF1E1E1E),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black26,
//                     blurRadius: 4,
//                     offset: Offset(0, -2),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   SizedBox(
//                     width: 24,
//                     height: 24,
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(
//                           Theme.of(context).primaryColor),
//                       strokeWidth: 2,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   const Text('در حال ذخیره ویدیو...',
//                       style: TextStyle(color: Colors.white)),
//                 ],
//               ),
//             )
//           : SafeArea(
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Theme.of(context).primaryColor,
//                     foregroundColor: Colors.white,
//                     minimumSize: const Size.fromHeight(50),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     elevation: 4,
//                   ),
//                   onPressed: _saving ? null : _trimVideo,
//                   child: const Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.content_cut),
//                       SizedBox(width: 8),
//                       Text(
//                         'برش و ذخیره ویدیو',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//     );
//   }
// }
