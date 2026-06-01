import 'dart:async';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:Vista/services/http_client_factory.dart';

enum SystemFeature {
  login('login'),
  chat('chat'),
  posts('posts'),
  comments('comments'),
  feed('feed'),
  stories('stories'),
  uploads('uploads'),
  payments('payments');

  const SystemFeature(this.key);
  final String key;
}

class FeatureDisabledException implements Exception {
  final SystemFeature feature;
  final String message;

  const FeatureDisabledException(
    this.feature, [
    this.message = 'This feature is temporarily disabled by admin.',
  ]);

  @override
  String toString() => message;
}

class MaintenanceModeException implements Exception {
  const MaintenanceModeException();

  @override
  String toString() => 'The service is currently in maintenance mode.';
}

class SystemAlert {
  final String id;
  final String severity;
  final String scope;
  final String message;
  final String? feature;

  const SystemAlert({
    required this.id,
    required this.severity,
    required this.scope,
    required this.message,
    this.feature,
  });

  factory SystemAlert.fromJson(Map<String, dynamic> json) {
    return SystemAlert(
      id: '${json['id'] ?? ''}',
      severity: '${json['severity'] ?? 'info'}',
      scope: '${json['scope'] ?? 'global'}',
      message: '${json['message'] ?? ''}',
      feature: json['feature'] == null ? null : '${json['feature']}',
    );
  }
}

class SystemStatus {
  final bool maintenance;
  final Map<String, bool> features;
  final List<SystemAlert> alerts;
  final int schemaVersion;
  final DateTime? generatedAt;

  const SystemStatus({
    required this.maintenance,
    required this.features,
    this.alerts = const [],
    this.schemaVersion = 1,
    this.generatedAt,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    final root = _asMap(json['data']).isNotEmpty ? _asMap(json['data']) : json;
    final features = <String, bool>{};

    void mergeEnabledMap(Object? value) {
      final map = _asMap(value);
      for (final entry in map.entries) {
        final parsed = _readBool(entry.value);
        if (parsed != null) {
          features[_normalizeKey(entry.key)] = parsed;
        }
      }
    }

    void mergeKillSwitchMap(Object? value) {
      final map = _asMap(value);
      for (final entry in map.entries) {
        final disabled = _readDisabledBool(entry.value);
        if (disabled != null) {
          features[_normalizeKey(entry.key)] = !disabled;
        }
      }
    }

    mergeEnabledMap(root['features']);
    mergeEnabledMap(root['feature_flags']);
    mergeEnabledMap(root['featureFlags']);
    mergeEnabledMap(root['flags']);
    mergeKillSwitchMap(root['kill_switches']);
    mergeKillSwitchMap(root['killSwitches']);
    mergeKillSwitchMap(root['kill_switch']);
    mergeKillSwitchMap(root['killSwitch']);

    for (final feature in SystemFeature.values) {
      final enabled = _readBoolFromAny(root, _enabledKeys[feature] ?? const []);
      if (enabled != null) features[feature.key] = enabled;

      final disabled =
          _readDisabledBoolFromAny(root, _disabledKeys[feature] ?? const []);
      if (disabled != null) features[feature.key] = !disabled;

      final nestedEnabled = _readBoolFromAny(
        features.cast<String, dynamic>(),
        [
          ...(_enabledKeys[feature] ?? const <String>[]),
          ...(_featureAliases[feature] ?? const <String>[]),
        ],
      );
      if (nestedEnabled != null) features[feature.key] = nestedEnabled;
    }

    return SystemStatus(
      maintenance: _readBoolFromAny(root, const [
            'maintenance',
            'maintenance_mode',
            'maintenanceMode',
            'is_maintenance',
            'isMaintenance',
          ]) ??
          false,
      features: features,
      alerts: _readAlerts(root),
      schemaVersion: _readInt(root['schema_version']) ?? 1,
      generatedAt: DateTime.tryParse('${root['generated_at'] ?? ''}'),
    );
  }
}

class SystemStatusService {
  static final SystemStatusService instance = SystemStatusService._internal();
  SystemStatusService._internal();

  static const Duration _cacheTtl = Duration(seconds: 20);

  SystemStatus? _cachedStatus;
  DateTime? _lastFetchAt;
  Future<SystemStatus?>? _inFlightFetch;

  SystemStatus? get cachedStatus => _cachedStatus;
  List<SystemAlert> get activeAlerts => _cachedStatus?.alerts ?? const [];
  SystemAlert? get firstCriticalAlert {
    final alerts = activeAlerts;
    for (final alert in alerts) {
      if (alert.severity.toLowerCase() == 'critical') return alert;
    }
    return alerts.isEmpty ? null : alerts.first;
  }

  Future<SystemStatus?> fetchStatus({bool force = false}) async {
    if (!force && !_isStale && _cachedStatus != null) {
      return _cachedStatus;
    }

    final inFlight = _inFlightFetch;
    if (inFlight != null) return inFlight;

    final future = _fetchStatus();
    _inFlightFetch = future;
    try {
      return await future;
    } finally {
      _inFlightFetch = null;
    }
  }

  Future<SystemStatus?> refreshIfStale() => fetchStatus();

  Future<void> ensureFeatureEnabled(
    SystemFeature feature, {
    bool forceRefresh = false,
  }) async {
    final status = await fetchStatus(force: forceRefresh);
    if (status?.maintenance == true) {
      throw const MaintenanceModeException();
    }
    if (!_isFeatureEnabledFromStatus(status, feature)) {
      throw FeatureDisabledException(feature);
    }
  }

  bool isFeatureEnabled(String featureKey) {
    if (_cachedStatus == null) return true;
    return _isEnabledByAliases(_cachedStatus!, featureKey);
  }

  bool isSystemFeatureEnabled(SystemFeature feature) {
    return _isFeatureEnabledFromStatus(_cachedStatus, feature);
  }

  bool get _isStale {
    final lastFetchAt = _lastFetchAt;
    if (lastFetchAt == null) return true;
    return DateTime.now().difference(lastFetchAt) > _cacheTtl;
  }

  Future<SystemStatus?> _fetchStatus() async {
    final dio = createPinnedDioClient(baseUrl: EnvConfig.apiBaseUrl);
    final paths = <String>[
      '/v1/system/status',
      '/api/v1/system/status',
      '/system/status',
    ];

    for (final path in paths) {
      try {
        final response = await dio.get(path);
        if (response.statusCode == 200 && response.data is Map) {
          _cachedStatus = SystemStatus.fromJson(
            (response.data as Map).cast<String, dynamic>(),
          );
          _lastFetchAt = DateTime.now();
          return _cachedStatus;
        }
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != 404 && status != 405) {
          break;
        }
      } catch (_) {
        break;
      }
    }

    _lastFetchAt = DateTime.now();
    return _cachedStatus;
  }

  bool _isFeatureEnabledFromStatus(
    SystemStatus? status,
    SystemFeature feature,
  ) {
    if (status == null) return true;
    for (final alias in _featureAliases[feature] ?? const <String>[]) {
      final value = status.features[_normalizeKey(alias)];
      if (value != null) return value;
    }
    return true;
  }

  bool _isEnabledByAliases(SystemStatus status, String featureKey) {
    final normalized = _normalizeKey(featureKey);
    final exact = status.features[normalized];
    if (exact != null) return exact;

    for (final aliases in _featureAliases.values) {
      if (aliases.map(_normalizeKey).contains(normalized)) {
        for (final alias in aliases) {
          final value = status.features[_normalizeKey(alias)];
          if (value != null) return value;
        }
      }
    }
    return true;
  }
}

const Map<SystemFeature, List<String>> _featureAliases = {
  SystemFeature.login: [
    'login',
    'auth',
    'authentication',
    'system_login',
    'login_system',
    'signin',
    'sign_in',
  ],
  SystemFeature.chat: [
    'chat',
    'messaging',
    'messenger',
    'messages',
    'message',
    'chat_messaging',
  ],
  SystemFeature.posts: [
    'posts',
    'post',
    'posting',
    'create_post',
    'send_post',
    'post_create',
  ],
  SystemFeature.comments: [
    'comments',
    'comment',
    'post_comments',
    'commenting',
    'create_comment',
    'comment_create',
  ],
  SystemFeature.feed: [
    'feed',
    'timeline',
    'explore',
    'home_feed',
    'following_feed',
  ],
  SystemFeature.stories: [
    'stories',
    'story',
    'story_create',
    'create_story',
    'highlights',
  ],
  SystemFeature.uploads: [
    'uploads',
    'upload',
    'media_upload',
    'file_upload',
    'presign',
  ],
  SystemFeature.payments: [
    'payments',
    'payment',
    'bazaar',
    'subscription',
    'premium',
  ],
};

const Map<SystemFeature, List<String>> _enabledKeys = {
  SystemFeature.login: ['login_enabled', 'auth_enabled', 'is_login_enabled'],
  SystemFeature.chat: ['chat_enabled', 'messaging_enabled'],
  SystemFeature.posts: ['posts_enabled', 'post_enabled', 'create_post_enabled'],
  SystemFeature.comments: [
    'comments_enabled',
    'comment_enabled',
    'create_comment_enabled',
  ],
  SystemFeature.feed: ['feed_enabled', 'explore_enabled'],
  SystemFeature.stories: ['stories_enabled', 'story_enabled'],
  SystemFeature.uploads: ['uploads_enabled', 'upload_enabled'],
  SystemFeature.payments: ['payments_enabled', 'payment_enabled'],
};

const Map<SystemFeature, List<String>> _disabledKeys = {
  SystemFeature.login: ['login_disabled', 'auth_disabled', 'is_login_disabled'],
  SystemFeature.chat: ['chat_disabled', 'messaging_disabled'],
  SystemFeature.posts: [
    'posts_disabled',
    'post_disabled',
    'create_post_disabled',
  ],
  SystemFeature.comments: [
    'comments_disabled',
    'comment_disabled',
    'create_comment_disabled',
  ],
  SystemFeature.feed: ['feed_disabled', 'explore_disabled'],
  SystemFeature.stories: ['stories_disabled', 'story_disabled'],
  SystemFeature.uploads: ['uploads_disabled', 'upload_disabled'],
  SystemFeature.payments: ['payments_disabled', 'payment_disabled'],
};

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'on', 'enabled', 'active'].contains(normalized)) {
      return true;
    }
    if ([
      'false',
      '0',
      'no',
      'off',
      'disabled',
      'inactive',
      'blocked',
    ].contains(normalized)) {
      return false;
    }
  }
  return null;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<SystemAlert> _readAlerts(Map<String, dynamic> root) {
  final raw = root['alerts'] ?? root['client_alerts'] ?? root['clientAlerts'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => SystemAlert.fromJson(item.cast<String, dynamic>()))
      .where((alert) => alert.id.isNotEmpty || alert.message.isNotEmpty)
      .toList(growable: false);
}

bool? _readBoolFromAny(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    final parsed = _readBool(value);
    if (parsed != null) return parsed;
  }
  return null;
}

bool? _readDisabledBool(Object? value) {
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (['blocked', 'disabled', 'off', 'inactive', 'true', '1', 'yes', 'on']
        .contains(normalized)) {
      return true;
    }
    if (['enabled', 'active', 'false', '0', 'no'].contains(normalized)) {
      return false;
    }
  }
  return _readBool(value);
}

bool? _readDisabledBoolFromAny(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    final parsed = _readDisabledBool(value);
    if (parsed != null) return parsed;
  }
  return null;
}

String _normalizeKey(Object? key) {
  return key
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-_]+'), '');
}
