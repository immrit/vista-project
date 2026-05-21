import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers/auth_controller.dart';
import '../model/MusicModel.dart';
import 'backend_upload_service.dart';

class MusicService {
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: '${dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080'}/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<String> uploadMusic(File file) async {
    final userId = await _currentUserId();
    final extension = extensionFromPath(file.path);
    final fileName =
        'music/$userId/${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}';

    final upload = await BackendUploadService.uploadFile(
      file: file,
      objectKey: fileName,
      contentType: _audioContentType(extension),
    );
    return upload.url;
  }

  Future<String?> uploadCover(File file) async {
    final userId = await _currentUserId();
    final extension = extensionFromPath(file.path);
    final fileName =
        'music/$userId/covers/${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}';

    final upload = await BackendUploadService.uploadFile(
      file: file,
      objectKey: fileName,
      contentType: _imageContentType(extension),
    );
    return upload.url;
  }

  Future<MusicModel> publishMusic({
    required String title,
    required String artist,
    required String musicUrl,
    String? coverUrl,
    required List<String> genres,
  }) async {
    final response = await _dio.post(
      '/music',
      data: {
        'title': title,
        'artist': artist,
        'music_url': musicUrl,
        if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
        'genres': genres,
      },
      options: await _authOptions(),
    );
    return MusicModel.fromMap(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<MusicModel>> fetchMusics({int limit = 20, int offset = 0}) async {
    final response = await _dio.get(
      '/music',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = data['music'] as List? ?? const [];
    return rows
        .map((item) =>
            MusicModel.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<void> incrementPlayCount(String musicId) async {
    if (musicId.isEmpty) return;
    await _dio.post('/music/$musicId/play', options: await _authOptions());
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<String> _currentUserId() async {
    final storedUserId = await TokenStorage.getUserId();
    if (storedUserId != null && storedUserId.isNotEmpty) {
      return storedUserId;
    }

    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('User not authenticated');
    }

    final user = await AuthRepository().me(accessToken);
    await TokenStorage.saveUserId(user.id);
    return user.id;
  }

  String extensionFromPath(String filePath) =>
      extension(filePath).toLowerCase();

  String _audioContentType(String extension) {
    switch (extension) {
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }

  String _imageContentType(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
