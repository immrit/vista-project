import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/story_enums.dart';
import '../../../../utils/env_config.dart';

String _parseMediaUrl(dynamic value) {
  if (value == null) return '';
  if (value is List) return value.isNotEmpty ? value.first?.toString() ?? '' : '';
  
  String result = value.toString();
  if (result.startsWith('[') && result.endsWith(']')) {
    try {
      final List parsed = json.decode(result);
      if (parsed.isNotEmpty) result = parsed.first?.toString() ?? '';
    } catch (_) {}
  }
  if (result.startsWith('{') && result.endsWith('}')) {
    final inner = result.substring(1, result.length - 1);
    final parts = inner.split(',');
    if (parts.isNotEmpty) result = parts.first.trim();
  }

  if (result.isNotEmpty && !result.startsWith('http')) {
    final baseUrl = EnvConfig.apiBaseUrl.replaceFirst('api.', 's3.');
    final cleanPath = result.startsWith('/') ? result.substring(1) : result;
    return '$baseUrl/$cleanPath';
  }
  return result;
}

/// مدل رسانه استوری
@immutable
class StoryMedia {
  final String url;
  final StoryMediaType type;
  final int? durationSeconds; // فقط برای ویدیو
  final String? thumbnailUrl; // فقط برای ویدیو
  final String? filter;
  final Map<String, dynamic>? metadata;

  const StoryMedia({
    required this.url,
    required this.type,
    this.durationSeconds,
    this.thumbnailUrl,
    this.filter,
    this.metadata,
  });

  bool get isVideo => type == StoryMediaType.video;
  bool get isImage => type == StoryMediaType.image;

  StoryMedia copyWith({
    String? url,
    StoryMediaType? type,
    int? durationSeconds,
    String? thumbnailUrl,
    String? filter,
    Map<String, dynamic>? metadata,
  }) {
    return StoryMedia(
      url: url ?? this.url,
      type: type ?? this.type,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      filter: filter ?? this.filter,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type.name,
      'duration_seconds': durationSeconds,
      'thumbnail_url': thumbnailUrl,
      'filter': filter,
      'metadata': metadata,
    };
  }

  factory StoryMedia.fromMap(Map<String, dynamic> map) {
    return StoryMedia(
      url: _parseMediaUrl(map['url'] ?? map['media_url']),
      type: StoryMediaType.values.firstWhere(
        (e) => e.name == (map['type'] ?? map['media_type'] ?? 'image'),
        orElse: () => StoryMediaType.image,
      ),
      durationSeconds: map['duration_seconds'],
      thumbnailUrl: map['thumbnail_url'] != null ? _parseMediaUrl(map['thumbnail_url']) : null,
      filter: map['filter'],
      metadata: map['metadata'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryMedia && other.url == url && other.type == type;
  }

  @override
  int get hashCode => url.hashCode ^ type.hashCode;
}
