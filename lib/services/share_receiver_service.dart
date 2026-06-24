import 'dart:async';
import 'package:flutter/services.dart';

/// مدل داده‌ای که از Android دریافت می‌شود
class SharedContent {
  final String mimeType;
  final String? text;
  final List<String> filePaths;
  final bool isMultiple;

  const SharedContent({
    required this.mimeType,
    this.text,
    required this.filePaths,
    required this.isMultiple,
  });

  bool get hasFiles => filePaths.isNotEmpty;
  bool get isText => mimeType.startsWith('text/') || (filePaths.isEmpty && text != null);
  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isMedia => isImage || isVideo;

  factory SharedContent.fromMap(Map<dynamic, dynamic> map) {
    return SharedContent(
      mimeType: (map['type'] as String?) ?? '*/*',
      text: map['text'] as String?,
      filePaths: List<String>.from((map['filePaths'] as List?) ?? []),
      isMultiple: (map['isMultiple'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'SharedContent(type=$mimeType, text=$text, files=${filePaths.length}, multiple=$isMultiple)';
}

/// Singleton service برای دریافت share intents از Android
///
/// Android → MethodChannel → این سرویس → Stream → UI
class ShareReceiverService {
  ShareReceiverService._();
  static final ShareReceiverService instance = ShareReceiverService._();

  static const _channel = MethodChannel('ir.coffevista.vista/share_receiver');

  final _controller = StreamController<SharedContent>.broadcast();

  /// Stream که هر بار share جدیدی می‌رسد emit می‌کند
  Stream<SharedContent> get stream => _controller.stream;

  bool _initialized = false;

  /// راه‌اندازی listener — باید یک بار صدا زده شود
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // دریافت share های جدید وقتی اپ در حال اجراست
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final map = call.arguments as Map<dynamic, dynamic>?;
        if (map != null) {
          _controller.add(SharedContent.fromMap(map));
        }
      }
    });
  }

  /// بررسی share اولیه — وقتی اپ از intent باز می‌شود
  Future<SharedContent?> getInitialShare() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialShare');
      if (result != null) {
        return SharedContent.fromMap(result);
      }
    } catch (e) {
      // نادیده گرفتن خطا
    }
    return null;
  }

  void dispose() {
    _controller.close();
  }
}
