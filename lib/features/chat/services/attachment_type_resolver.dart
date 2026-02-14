import 'dart:io';

import 'package:path/path.dart' as p;

import 'upload_policy_service.dart';

class AttachmentTypeResolver {
  const AttachmentTypeResolver();

  static const Set<String> _canonicalTypes = {
    'image',
    'voice',
    'audio',
    'document',
  };

  static const Set<String> _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  static const Set<String> _audioExts = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'flac',
  };

  static bool isCanonicalType(String? value) {
    if (value == null) return false;
    return _canonicalTypes.contains(value.trim().toLowerCase());
  }

  String? canonicalizeFromType(String? value) {
    return _normalizeKnownType(value);
  }

  String resolve({
    required ChatSendMode sendMode,
    required File file,
    String? policyType,
    String? existingType,
  }) {
    if (sendMode == ChatSendMode.gallery || sendMode == ChatSendMode.camera) {
      return 'image';
    }

    final normalizedExisting = _normalizeKnownType(existingType);
    if (normalizedExisting != null) {
      return normalizedExisting;
    }

    final normalizedPolicy = _normalizeKnownType(policyType);
    if (normalizedPolicy != null) {
      return normalizedPolicy;
    }

    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    if (_imageExts.contains(ext)) return 'image';
    if (_audioExts.contains(ext)) return 'audio';
    if (ext == 'pdf') return 'document';

    final header = _readHeader(file);
    if (_isImageByHeader(header)) return 'image';
    if (_isPdfByHeader(header)) return 'document';
    if (_isAudioByHeader(header)) return 'audio';

    return 'document';
  }

  String? _normalizeKnownType(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    if (_canonicalTypes.contains(normalized)) return normalized;
    if (normalized == 'file' || normalized == 'pdf') return 'document';
    if (normalized.startsWith('image')) return 'image';
    if (normalized.startsWith('audio')) return 'audio';
    if (normalized == 'mp3' || normalized == 'm4a' || normalized == 'aac') {
      return 'audio';
    }

    return null;
  }

  List<int> _readHeader(File file) {
    try {
      final raf = file.openSync(mode: FileMode.read);
      try {
        final fileLen = file.lengthSync();
        final maxLen = fileLen < 16 ? fileLen : 16;
        if (maxLen <= 0) return const <int>[];
        return raf.readSync(maxLen);
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return const <int>[];
    }
  }

  bool _isImageByHeader(List<int> header) {
    if (header.length >= 3 &&
        header[0] == 0xFF &&
        header[1] == 0xD8 &&
        header[2] == 0xFF) {
      return true;
    }
    if (header.length >= 8 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      return true;
    }
    if (header.length >= 6 &&
        header[0] == 0x47 &&
        header[1] == 0x49 &&
        header[2] == 0x46) {
      return true;
    }
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      return true;
    }
    if (header.length >= 2 && header[0] == 0x42 && header[1] == 0x4D) {
      return true;
    }
    // HEIC/HEIF often starts with ISOBMFF (....ftyp)
    if (header.length >= 12 &&
        header[4] == 0x66 &&
        header[5] == 0x74 &&
        header[6] == 0x79 &&
        header[7] == 0x70) {
      final brand = String.fromCharCodes(header.sublist(8, 12)).toLowerCase();
      if (brand == 'heic' ||
          brand == 'heix' ||
          brand == 'hevc' ||
          brand == 'heif' ||
          brand == 'mif1') {
        return true;
      }
    }
    return false;
  }

  bool _isPdfByHeader(List<int> header) {
    if (header.length < 4) return false;
    return header[0] == 0x25 &&
        header[1] == 0x50 &&
        header[2] == 0x44 &&
        header[3] == 0x46;
  }

  bool _isAudioByHeader(List<int> header) {
    if (header.length >= 3 &&
        header[0] == 0x49 &&
        header[1] == 0x44 &&
        header[2] == 0x33) {
      return true;
    }
    if (header.length >= 2 && header[0] == 0xFF && (header[1] & 0xF0) == 0xF0) {
      return true;
    }
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x41 &&
        header[10] == 0x56 &&
        header[11] == 0x45) {
      return true;
    }
    if (header.length >= 4 &&
        header[0] == 0x4F &&
        header[1] == 0x67 &&
        header[2] == 0x67 &&
        header[3] == 0x53) {
      return true;
    }
    if (header.length >= 4 &&
        header[0] == 0x66 &&
        header[1] == 0x4C &&
        header[2] == 0x61 &&
        header[3] == 0x43) {
      return true;
    }
    if (header.length >= 8 &&
        header[4] == 0x66 &&
        header[5] == 0x74 &&
        header[6] == 0x79 &&
        header[7] == 0x70) {
      return true;
    }
    return false;
  }
}
