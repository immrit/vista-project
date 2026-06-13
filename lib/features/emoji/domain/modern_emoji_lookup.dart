import 'dart:convert';

import 'package:flutter/services.dart';

class ModernEmojiLookup {
  ModernEmojiLookup._();

  static final ModernEmojiLookup instance = ModernEmojiLookup._();

  static const String _assetMapPath =
      'lib/features/emoji/data/modern_emoji_map.json';

  final Map<String, String> _emojiToAsset = <String, String>{};
  bool _loaded = false;
  Future<void>? _loadingFuture;

  bool get isLoaded => _loaded;

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    _loadingFuture ??= _loadInternal();
    return _loadingFuture!;
  }

  String? assetPathFor(String emoji) {
    if (!_loaded) return null;
    final direct = _emojiToAsset[emoji];
    if (direct != null) return direct;

    final withoutVs16 = emoji.replaceAll('\uFE0F', '');
    final fallback = _emojiToAsset[withoutVs16];
    if (fallback != null) return fallback;

    final withVs16 = _ensureVs16(emoji);
    return _emojiToAsset[withVs16];
  }

  bool hasAsset(String emoji) => assetPathFor(emoji) != null;

  String _ensureVs16(String value) {
    if (value.contains('\uFE0F')) return value;
    if (value.runes.length == 1) {
      return '$value\uFE0F';
    }
    return value;
  }

  Future<void> _loadInternal() async {
    try {
      final raw = await rootBundle.loadString(_assetMapPath);
      final decoded = jsonDecode(raw);

      Map<String, dynamic> source;
      if (decoded is Map<String, dynamic>) {
        if (decoded['map'] is Map<String, dynamic>) {
          source = decoded['map'] as Map<String, dynamic>;
        } else {
          source = decoded;
        }
      } else {
        source = <String, dynamic>{};
      }

      _emojiToAsset.clear();
      source.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          _emojiToAsset[key] = value;
        }
      });
      _loaded = true;
    } catch (_) {
      _emojiToAsset.clear();
      _loaded = false;
    } finally {
      _loadingFuture = null;
    }
  }
}
