import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final bool updateAvailable;
  final String? downloadUrl;
  final String? versionName;
  final bool isMandatory;

  UpdateInfo({
    required this.updateAvailable,
    this.downloadUrl,
    this.versionName,
    this.isMandatory = false,
  });
}

class InAppUpdater {
  static const MethodChannel _channel = MethodChannel('ir.coffevista.updater');
  final Dio _dio = Dio();
  // Using localhost or your domain
  final String _baseUrl = 'https://coffevista.ir/api/v1'; 

  Future<UpdateInfo> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      final response = await _dio.get(
        '$_baseUrl/system/check-update',
        queryParameters: {
          'version_code': currentVersionCode,
          'flavor': 'bazaar', // Hardcoded here for the override strategy, or could be dynamic
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
        );
      }
    } catch (e) {
      print('Update check failed: $e');
    }
    return UpdateInfo(updateAvailable: false);
  }

  Future<String?> downloadApk(String url, Function(double) onProgress) async {
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
      return savePath;
    } catch (e) {
      print('Download failed: $e');
      return null;
    }
  }

  Future<void> installApk(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('installApk', {'filePath': filePath});
      } catch (e) {
        print("Failed to install APK: $e");
      }
    }
  }
}
