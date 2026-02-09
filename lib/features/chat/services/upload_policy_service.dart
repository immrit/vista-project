import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../model/ProfileModel.dart';

enum ChatSendMode { gallery, camera, file }

class AllowedFileResult {
  final bool isAllowed;
  final int maxBytes;
  final String? attachmentType;
  final String? error;

  const AllowedFileResult._({
    required this.isAllowed,
    required this.maxBytes,
    this.attachmentType,
    this.error,
  });

  factory AllowedFileResult.allowed({
    required int maxBytes,
    required String attachmentType,
  }) {
    return AllowedFileResult._(
      isAllowed: true,
      maxBytes: maxBytes,
      attachmentType: attachmentType,
    );
  }

  factory AllowedFileResult.rejected({
    required int maxBytes,
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
  };

  static const Set<String> _allowedFileExts = {
    ..._imageExts,
    'pdf',
    'mp3',
  };

  int maxBytesFor(ProfileModel? profile) {
    return profile?.role == 'premium' ? premiumMaxBytes : normalMaxBytes;
  }

  AllowedFileResult validateFile({
    required File file,
    required ProfileModel? profile,
    required ChatSendMode mode,
  }) {
    final maxBytes = maxBytesFor(profile);
    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
    final bytes = file.lengthSync();

    if (ext.isEmpty) {
      return AllowedFileResult.rejected(
        maxBytes: maxBytes,
        error: 'File type could not be detected.',
      );
    }

    if (bytes > maxBytes) {
      final maxMb = maxBytes ~/ (1024 * 1024);
      return AllowedFileResult.rejected(
        maxBytes: maxBytes,
        error: 'File size exceeds ${maxMb}MB.',
      );
    }

    final header = _readHeader(file);
    final matchesImage = _isImageByExt(ext) && _isImageByHeader(header);
    final matchesPdf = ext == 'pdf' && _isPdfByHeader(header);
    final matchesMp3 = ext == 'mp3' && _isMp3ByHeader(header);

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
        error: 'Only image, PDF, and MP3 files are allowed.',
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
        attachmentType: 'pdf',
      );
    }

    if (ext == 'mp3') {
      if (!matchesMp3) {
        return AllowedFileResult.rejected(
          maxBytes: maxBytes,
          error: 'MP3 file content is invalid.',
        );
      }
      return AllowedFileResult.allowed(
        maxBytes: maxBytes,
        attachmentType: 'mp3',
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
    return false;
  }

  bool _isPdfByHeader(List<int> header) {
    if (header.length < 4) return false;
    return header[0] == 0x25 &&
        header[1] == 0x50 &&
        header[2] == 0x44 &&
        header[3] == 0x46;
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
}
