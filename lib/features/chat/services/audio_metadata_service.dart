import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

class AudioMetadataSnapshot {
  final String displayFileName;
  final String? mimeType;
  final int sizeBytes;
  final int? durationSeconds;
  final String? title;
  final String? artist;
  final String? album;

  const AudioMetadataSnapshot({
    required this.displayFileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.durationSeconds,
    required this.title,
    required this.artist,
    required this.album,
  });
}

class AudioMetadataService {
  const AudioMetadataService();

  Future<AudioMetadataSnapshot> extract({
    required File file,
    required String displayFileName,
    String? mimeTypeHint,
    int? sizeBytesHint,
  }) async {
    final trimmedName = displayFileName.trim();
    final fallbackName =
        trimmedName.isEmpty ? p.basename(file.path) : trimmedName;
    final sizeBytes = sizeBytesHint ?? await file.length();
    final fallbackTitle = _stripExtension(fallbackName);
    final splitName = _splitArtistAndTitle(fallbackTitle);

    String? title;
    String? artist;
    String? album;
    int? durationSeconds;

    try {
      final metadata = readMetadata(file, getImage: false);
      final rawTitle = metadata.title?.trim();
      final rawArtist = metadata.artist?.trim();
      final rawAlbum = metadata.album?.trim();
      title =
          (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : fallbackTitle;
      artist = (rawArtist != null && rawArtist.isNotEmpty) ? rawArtist : null;
      album = (rawAlbum != null && rawAlbum.isNotEmpty) ? rawAlbum : null;
      durationSeconds = metadata.duration?.inSeconds;
    } catch (_) {
      title = fallbackTitle;
      artist = null;
      album = null;
      durationSeconds = null;
    }

    // If tags are incomplete, derive from file name like: "Artist - Track".
    if (title.trim().isEmpty) {
      title = splitName?.$2 ?? fallbackTitle;
    }
    if ((artist == null || artist.isEmpty) && splitName != null) {
      artist = splitName.$1;
    }

    return AudioMetadataSnapshot(
      displayFileName: fallbackName,
      mimeType: mimeTypeHint ?? _guessMimeType(fallbackName),
      sizeBytes: sizeBytes,
      durationSeconds: durationSeconds,
      title: title,
      artist: artist,
      album: album,
    );
  }

  String _stripExtension(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'Audio';
    final ext = p.extension(name);
    if (ext.isEmpty) return name;
    final trimmed = name.substring(0, name.length - ext.length).trim();
    return trimmed.isEmpty ? name : trimmed;
  }

  String? _guessMimeType(String fileName) {
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return null;
    }
  }

  (String, String)? _splitArtistAndTitle(String rawName) {
    final normalized = rawName.trim();
    if (normalized.isEmpty) return null;

    final separators = <String>[' - ', ' | ', ' / ', '_'];
    for (final sep in separators) {
      final idx = normalized.indexOf(sep);
      if (idx > 0 && idx < normalized.length - sep.length) {
        final artist = normalized.substring(0, idx).trim();
        final title = normalized.substring(idx + sep.length).trim();
        if (artist.isNotEmpty && title.isNotEmpty) {
          return (artist, title);
        }
      }
    }
    return null;
  }
}
