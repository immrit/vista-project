import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;

/// Lightweight image dimension resolver for chat media bubbles.
class ChatImageDimensions {
  ChatImageDimensions._();

  static final Map<String, SizeInt> _cache = <String, SizeInt>{};

  static Future<SizeInt?> resolve({
    required String cacheKey,
    int? knownWidth,
    int? knownHeight,
    String? localPath,
    String? networkUrl,
  }) async {
    if (knownWidth != null &&
        knownHeight != null &&
        knownWidth > 0 &&
        knownHeight > 0) {
      final resolved = SizeInt(knownWidth, knownHeight);
      _cache[cacheKey] = resolved;
      return resolved;
    }

    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final local = localPath?.trim();
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (file.existsSync()) {
        final resolved = await _decodeFile(file);
        if (resolved != null) {
          _cache[cacheKey] = resolved;
          return resolved;
        }
      }
    }

    final url = networkUrl?.trim();
    if (url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      try {
        final fileInfo = await DefaultCacheManager().getFileFromCache(url);
        final cachedFile = fileInfo?.file;
        if (cachedFile != null && cachedFile.existsSync()) {
          final resolved = await _decodeFile(cachedFile);
          if (resolved != null) {
            _cache[cacheKey] = resolved;
            return resolved;
          }
        }
      } catch (_) {
        // Fall through to network probe.
      }

      final probed = await _probeNetworkDimensions(url);
      if (probed != null) {
        _cache[cacheKey] = probed;
        return probed;
      }
    }

    return null;
  }

  static void remember(String cacheKey, SizeInt dimensions) {
    _cache[cacheKey] = dimensions;
  }

  static Future<SizeInt?> fromImageProvider(ImageProvider provider) async {
    try {
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<SizeInt?>();
      late ImageStreamListener listener;

      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          stream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.complete(
              SizeInt(info.image.width, info.image.height),
            );
          }
        },
        onError: (Object _, StackTrace? __) {
          stream.removeListener(listener);
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      stream.addListener(listener);
      return completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          stream.removeListener(listener);
          return null;
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<SizeInt?> _decodeFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return _decodeBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<SizeInt?> _probeNetworkDimensions(String url) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      return _decodeFile(file);
    } catch (_) {
      return null;
    }
  }

  static Future<SizeInt?> _decodeBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null && decoded.width > 0 && decoded.height > 0) {
        final oriented = img.bakeOrientation(decoded);
        return SizeInt(oriented.width, oriented.height);
      }
    } catch (_) {
      // Fall through to Flutter codec.
    }

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final resolved = SizeInt(image.width, image.height);
      image.dispose();
      codec.dispose();
      return resolved;
    } catch (_) {
      return null;
    }
  }
}

class SizeInt {
  final int width;
  final int height;

  const SizeInt(this.width, this.height);
}
