import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService instance = CrashReportingService._();

  File? _logFile;

  Future<void> initialize() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _logFile = File('${dir.path}${Platform.pathSeparator}crash_reports.log');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
    } catch (_) {
      // Best-effort setup, do not crash app bootstrap.
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required bool fatal,
    String source = 'unknown',
  }) async {
    final payload = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'fatal': fatal,
      'source': source,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      'releaseMode': kReleaseMode,
    };

    try {
      final sink = _logFile;
      if (sink != null) {
        await sink.writeAsString(
          '${jsonEncode(payload)}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (_) {
      // Avoid recursive crash loop if writing fails.
    }
  }
}
