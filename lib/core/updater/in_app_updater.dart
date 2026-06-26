import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' hide appFlavor;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:Vista/core/app_config.dart';

class UpdateInfo {
  final bool updateAvailable;
  final String? downloadUrl;
  final String? versionName;
  final bool isMandatory;
  final int minSupportedVersionCode;
  final String? sha256;

  UpdateInfo({
    required this.updateAvailable,
    this.downloadUrl,
    this.versionName,
    this.isMandatory = false,
    this.minSupportedVersionCode = 1,
    this.sha256,
  });
}

class InAppUpdater {
  static const MethodChannel _channel = MethodChannel('ir.coffevista.updater');
  final Dio _dio = Dio();

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      final response = await _dio.get(
        '$backendUrl/api/v1/system/check-update',
        queryParameters: {
          'version_code': currentVersionCode,
          'flavor': appFlavor,
        },
      );

      final data = response.data;
      if (data['update_available'] == true) {
        final v = data['app_version'];
        return UpdateInfo(
          updateAvailable: true,
          downloadUrl: v['download_url'],
          versionName: v['version_name'],
          isMandatory: v['is_mandatory'] ?? false,
          minSupportedVersionCode: v['min_supported_version_code'] ?? 1,
          sha256: v['sha256'],
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return UpdateInfo(updateAvailable: false);
  }

  Future<String?> downloadApk(String url, Function(double) onProgress, {String? expectedSha256}) async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/vista_update.apk';

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final file = File(savePath);
        final bytes = await file.readAsBytes();
        final digest = sha256.convert(bytes);
        if (digest.toString() != expectedSha256) {
          debugPrint('SHA256 mismatch! Expected $expectedSha256, got $digest');
          await file.delete();
          return null;
        }
      }

      return savePath;
    } catch (e) {
      debugPrint('Download failed: $e');
      return null;
    }
  }

  Future<void> installApk(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('installApk', {'filePath': filePath});
      } catch (e) {
        debugPrint("Failed to install APK: $e");
      }
    }
  }
}
