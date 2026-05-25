import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../auth/providers/auth_controller.dart';
import '../../../security/logging_utility.dart';

enum ModerationReason {
  inappropriateContent('محتوای نامناسب'),
  harassment('آزار و اذیت'),
  spam('اسپم'),
  impersonation('جعل هویت'),
  scam('کلاهبرداری'),
  hateSpeech('سخنان نفرت‌انگیز'),
  violence('خشونت'),
  other('سایر موارد');

  final String persianLabel;
  const ModerationReason(this.persianLabel);
}

class ModerationResult {
  final bool success;
  final String? error;
  final String? message;

  const ModerationResult({
    required this.success,
    this.error,
    this.message,
  });

  factory ModerationResult.success([String? message]) {
    return ModerationResult(success: true, message: message);
  }

  factory ModerationResult.failure(String error) {
    return ModerationResult(success: false, error: error);
  }
}

class BlockStatus {
  final bool isBlocked;
  final bool isBlockedBy;
  final DateTime? blockedAt;
  final DateTime? blockedByAt;

  const BlockStatus({
    required this.isBlocked,
    required this.isBlockedBy,
    this.blockedAt,
    this.blockedByAt,
  });

  bool get hasAnyBlock => isBlocked || isBlockedBy;
  bool get canSendMessage => !hasAnyBlock;

  factory BlockStatus.noBlock() {
    return const BlockStatus(isBlocked: false, isBlockedBy: false);
  }
}

class UserModerationService {
  late final Dio _dio;
  final Map<String, ({BlockStatus status, DateTime cachedAt})> _blockCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  UserModerationService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${EnvConfig.apiBaseUrl ?? 'http://10.0.2.2:8080'}/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<ModerationResult> blockUser(String userId) async {
    try {
      await _dio.post(
        '/me/block',
        data: {'target_user_id': userId},
        options: await _authOptions(),
      );
      _invalidateCache(userId);
      return ModerationResult.success('کاربر با موفقیت مسدود شد');
    } catch (e) {
      return ModerationResult.failure('خطا در مسدود کردن کاربر: $e');
    }
  }

  Future<ModerationResult> unblockUser(String userId) async {
    try {
      await _dio.post(
        '/me/unblock',
        data: {'target_user_id': userId},
        options: await _authOptions(),
      );
      _invalidateCache(userId);
      return ModerationResult.success('مسدودیت کاربر برداشته شد');
    } catch (e) {
      return ModerationResult.failure('خطا در رفع مسدودیت: $e');
    }
  }

  Future<ModerationResult> reportUser({
    required String userId,
    required ModerationReason reason,
    String? additionalInfo,
  }) async {
    try {
      await _dio.post(
        '/profiles/report',
        data: {
          'user_id': userId,
          'reason': reason.name,
          if (additionalInfo != null) 'additional_details': additionalInfo,
        },
        options: await _authOptions(),
      );
      return ModerationResult.success('گزارش شما ثبت شد');
    } catch (e) {
      return ModerationResult.failure('خطا در ثبت گزارش: $e');
    }
  }

  Future<BlockStatus> getBlockStatus(String userId,
      {bool useCache = true}) async {
    if (useCache && _blockCache.containsKey(userId)) {
      final cached = _blockCache[userId]!;
      if (DateTime.now().difference(cached.cachedAt) < _cacheDuration) {
        return cached.status;
      }
      _blockCache.remove(userId);
    }
    try {
      final response = await _dio.get(
        '/me/block-status/$userId',
        options: await _authOptions(),
      );
      final data = _asMap(response.data);
      final status = BlockStatus(
        isBlocked: data['is_blocked'] == true,
        isBlockedBy: data['is_blocked_by'] == true,
        blockedAt: DateTime.tryParse(data['blocked_at']?.toString() ?? ''),
        blockedByAt: DateTime.tryParse(data['blocked_by_at']?.toString() ?? ''),
      );
      _blockCache[userId] = (status: status, cachedAt: DateTime.now());
      return status;
    } catch (e, stack) {
      logError('Failed to load block status', error: e, stackTrace: stack);
      return BlockStatus.noBlock();
    }
  }

  Future<bool> isUserBlocked(String userId) async {
    return (await getBlockStatus(userId)).isBlocked;
  }

  Future<bool> isCurrentUserBlocked(String userId) async {
    return (await getBlockStatus(userId)).isBlockedBy;
  }

  void _invalidateCache(String userId) {
    _blockCache.remove(userId);
  }

  void clearCache() {
    _blockCache.clear();
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final response = await _dio.get(
        '/me/blocked-users',
        options: await _authOptions(),
      );
      return _asList(_asMap(response.data)['profiles'])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<int> getBlockedUsersCount() async {
    return (await getBlockedUsers()).length;
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    return const [];
  }
}
