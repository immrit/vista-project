import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../model/ProfileModel.dart';

enum ChatSendMode { gallery, camera, file }

class AllowedFileResult {
  final bool isAllowed;
  final int? maxBytes;
  final String? attachmentType;
  final String? error;

  const AllowedFileResult._({
    required this.isAllowed,
    required this.maxBytes,
    this.attachmentType,
    this.error,
  });

  factory AllowedFileResult.allowed({
    required int? maxBytes,
    required String attachmentType,
  }) {
    return AllowedFileResult._(
      isAllowed: true,
      maxBytes: maxBytes,
      attachmentType: attachmentType,
    );
  }

  factory AllowedFileResult.rejected({
    required int? maxBytes,
    required String error,
  }) {
    return AllowedFileResult._(
      isAllowed: false,
      maxBytes: maxBytes,
      error: error,
    );
  }
}

class UploadPolicyService {
  const UploadPolicyService();

  static const int normalMaxBytes = 10 * 1024 * 1024;
  static const int premiumMaxBytes = 50 * 1024 * 1024;

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

  static const Set<String> _allowedFileExts = {
    ..._imageExts,
    'pdf',
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'flac',
  };

  int? maxBytesFor(ProfileModel? profile) {
    if (profile?.hasUnlimitedPrivileges == true) return null;
    if (profile?.hasPremiumPrivileges == true) return premiumMaxBytes;
    return normalMaxBytes;
  }

  AllowedFileResult validateFile({
    required File file,
    required ProfileModel? profile,
    required ChatSendMode mode,
  }) {
    final maxBytes = maxBytesFor(profile);
    var ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    final bytes = file.lengthSync();

    if (maxBytes != null && bytes > maxBytes) {
      final maxMb = maxBytes ~/ (1024 * 1024);
      return AllowedFileResult.rejected(
        maxBytes: maxBytes,
        error: 'File size exceeds ${maxMb}MB.',
      );
    }

    final header = _readHeader(file);
    if (ext.isEmpty) {
      ext = _inferExtensionByHeader(header);
      if (ext.isEmpty) {
        return AllowedFileResult.rejected(
          maxBytes: maxBytes,
          error: 'File type could not be detected.',
        );
      }
    }
    final matchesImage = _isImageByExt(ext) && _isImageByHeader(header);
    final matchesPdf = ext == 'pdf' && _isPdfByHeader(header);

    if (mode == ChatSendMode.gallery || mode == ChatSendMode.camera) {
      if (!matchesImage) {
        return AllowedFileResult.rejected(
          maxBytes: maxBytes,
          error: 'Only image files are allowed in gallery/camera mode.',
        );
      }
      return AllowedFileResult.allowed(
        maxBytes: maxBytes,
        attachmentType: 'image',
      );
    }

    if (!_allowedFileExts.contains(ext)) {
      return AllowedFileResult.rejected(
        maxBytes: maxBytes,
        error: 'Only image, PDF, and audio files are allowed.',
      );
    }

    if (_isImageByExt(ext)) {
      if (!matchesImage) {
        return AllowedFileResult.rejected(
          maxBytes: maxBytes,
          error: 'Image file content is invalid.',
        );
      }
      return AllowedFileResult.allowed(
        maxBytes: maxBytes,
        attachmentType: 'image',
      );
    }

    if (ext == 'pdf') {
      if (!matchesPdf) {
        return AllowedFileResult.rejected(
          maxBytes: maxBytes,
          error: 'PDF file content is invalid.',
        );
      }
      return AllowedFileResult.allowed(
        maxBytes: maxBytes,
        attachmentType: 'document',
      );
    }

    if (_isAudioByExt(ext)) {
      final matchesAudio = _isAudioByHeader(ext, header);
      if (!matchesAudio && header.isEmpty) {
        return AllowedFileResult.rejected(
          maxBytes: maxBytes,
          error: 'Audio file content is invalid.',
        );
      }
      // Some valid audio files may not expose a strict magic header
      // in the first bytes (depending on recorder/exporter/container).
      // Keep extension whitelist as the primary guard to avoid false rejects.
      return AllowedFileResult.allowed(
        maxBytes: maxBytes,
        attachmentType: 'audio',
      );
    }

    return AllowedFileResult.rejected(
      maxBytes: maxBytes,
      error: 'Unsupported file type.',
    );
  }

  List<int> _readHeader(File file) {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final maxLen = file.lengthSync() < 12 ? file.lengthSync() : 12;
      return raf.readSync(maxLen);
    } finally {
      raf.closeSync();
    }
  }

  bool _isImageByExt(String ext) => _imageExts.contains(ext);

  bool _isImageByHeader(List<int> header) {
    if (header.length >= 3 &&
        header[0] == 0xFF &&
        header[1] == 0xD8 &&
        header[2] == 0xFF) {
      return true; // jpg
    }
    if (header.length >= 8 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      return true; // png
    }
    if (header.length >= 6 &&
        header[0] == 0x47 &&
        header[1] == 0x49 &&
        header[2] == 0x46) {
      return true; // gif
    }
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      return true; // webp
    }
    if (header.length >= 2 && header[0] == 0x42 && header[1] == 0x4D) {
      return true; // bmp
    }
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
        return true; // heic/heif
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

  bool _isAudioByExt(String ext) {
    return const {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'}.contains(ext);
  }

  bool _isAudioByHeader(String ext, List<int> header) {
    switch (ext) {
      case 'mp3':
        return _isMp3ByHeader(header);
      case 'wav':
        return header.length >= 12 &&
            header[0] == 0x52 &&
            header[1] == 0x49 &&
            header[2] == 0x46 &&
            header[3] == 0x46 &&
            header[8] == 0x57 &&
            header[9] == 0x41 &&
            header[10] == 0x56 &&
            header[11] == 0x45;
      case 'ogg':
        return header.length >= 4 &&
            header[0] == 0x4F &&
            header[1] == 0x67 &&
            header[2] == 0x67 &&
            header[3] == 0x53;
      case 'flac':
        return header.length >= 4 &&
            header[0] == 0x66 &&
            header[1] == 0x4C &&
            header[2] == 0x61 &&
            header[3] == 0x43;
      case 'm4a':
        return header.length >= 8 &&
            header[4] == 0x66 &&
            header[5] == 0x74 &&
            header[6] == 0x79 &&
            header[7] == 0x70;
      case 'aac':
        return (header.length >= 2 &&
                header[0] == 0xFF &&
                (header[1] & 0xF0) == 0xF0) ||
            (header.length >= 8 &&
                header[4] == 0x66 &&
                header[5] == 0x74 &&
                header[6] == 0x79 &&
                header[7] == 0x70);
      default:
        return false;
    }
  }

  bool _isMp3ByHeader(List<int> header) {
    if (header.length >= 3 &&
        header[0] == 0x49 &&
        header[1] == 0x44 &&
        header[2] == 0x33) {
      return true; // ID3
    }
    if (header.length >= 2 && header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
      return true; // MPEG frame sync
    }
    return false;
  }

  String _inferExtensionByHeader(List<int> header) {
    if (_isPdfByHeader(header)) return 'pdf';
    if (_isImageByHeader(header)) return 'jpg';
    if (_isAudioByHeader('mp3', header) ||
        _isAudioByHeader('aac', header) ||
        _isAudioByHeader('wav', header) ||
        _isAudioByHeader('ogg', header) ||
        _isAudioByHeader('flac', header) ||
        _isAudioByHeader('m4a', header)) {
      return 'm4a';
    }
    return '';
  }
}
