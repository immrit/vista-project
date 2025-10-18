import 'dart:async';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// سرویس بهینه‌سازی اتصالات real-time برای جلوگیری از timeout و crash
class RealtimeConnectionOptimizer {
  static final RealtimeConnectionOptimizer _instance =
      RealtimeConnectionOptimizer._internal();
  factory RealtimeConnectionOptimizer() => _instance;
  RealtimeConnectionOptimizer._internal();

  // مدیریت اتصالات
  final Map<String, StreamSubscription> _activeConnections = {};
  final Map<String, DateTime> _lastConnectionTime = {};
  final Map<String, int> _connectionAttempts = {};

  // تنظیمات - timeout طولانی‌تر برای اتصالات مشکل‌دار
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration backoffDelay = Duration(seconds: 8);
  static const int maxRetries = 5;

  // وضعیت شبکه
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  Timer? _healthCheckTimer;

  bool _isInitialized = false;

  /// مقداردهی اولیه optimizer
  Future<void> initialize() async {
    if (_isInitialized) return;

    developer.log('🔧 Initializing Realtime Connection Optimizer...',
        name: 'RealtimeOptimizer');

    try {
      // نظارت بر وضعیت شبکه
      await _setupNetworkMonitoring();

      // راه‌اندازی health check
      _startHealthCheck();

      _isInitialized = true;
      developer.log('✅ Realtime Connection Optimizer initialized',
          name: 'RealtimeOptimizer');
    } catch (e) {
      developer.log('❌ Failed to initialize optimizer: $e',
          name: 'RealtimeOptimizer');
      rethrow;
    }
  }

  /// راه‌اندازی نظارت بر شبکه
  Future<void> _setupNetworkMonitoring() async {
    try {
      // بررسی وضعیت فعلی شبکه
      final result = await Connectivity().checkConnectivity();
      _isOnline = result != ConnectivityResult.none;

      // گوش دادن به تغییرات شبکه
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;

        if (!wasOnline && _isOnline) {
          developer.log('🌐 Network restored - reconnecting...',
              name: 'RealtimeOptimizer');
          _reconnectAll();
        } else if (wasOnline && !_isOnline) {
          developer.log('🌐 Network lost - pausing connections...',
              name: 'RealtimeOptimizer');
          _pauseAllConnections();
        }
      });
    } catch (e) {
      developer.log('⚠️ Network monitoring setup failed: $e',
          name: 'RealtimeOptimizer');
    }
  }

  /// شروع health check
  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _performHealthCheck();
    });
  }

  /// بررسی سلامت اتصالات
  void _performHealthCheck() {
    if (!_isOnline) return;

    final now = DateTime.now();
    final staleConnections = <String>[];

    // شناسایی اتصالات کند یا قطع شده
    for (final entry in _lastConnectionTime.entries) {
      final timeSinceLastActivity = now.difference(entry.value);
      if (timeSinceLastActivity > const Duration(minutes: 5)) {
        staleConnections.add(entry.key);
      }
    }

    // بازسازی اتصالات کند
    for (final connectionId in staleConnections) {
      developer.log('🔄 Reconnecting stale connection: $connectionId',
          name: 'RealtimeOptimizer');
      _reconnectConnection(connectionId);
    }

    if (kDebugMode && _activeConnections.isNotEmpty) {
      developer.log(
          '📊 Health check: ${_activeConnections.length} active connections',
          name: 'RealtimeOptimizer');
    }
  }

  /// ایجاد اتصال بهینه‌شده
  Stream<T> createOptimizedStream<T>(
    String connectionId,
    Stream<T> Function() streamBuilder, {
    Duration? timeout,
    int? maxRetries,
  }) {
    final effectiveTimeout = timeout ?? connectionTimeout;
    final effectiveMaxRetries =
        maxRetries ?? RealtimeConnectionOptimizer.maxRetries;

    return Stream.fromFuture(_createConnection(
      connectionId,
      streamBuilder,
      effectiveTimeout,
      effectiveMaxRetries,
    )).asyncExpand((stream) => stream);
  }

  /// ایجاد اتصال داخلی
  Future<Stream<T>> _createConnection<T>(
    String connectionId,
    Stream<T> Function() streamBuilder,
    Duration timeout,
    int maxRetries,
  ) async {
    developer.log('🔗 Creating optimized connection: $connectionId',
        name: 'RealtimeOptimizer');

    // لغو اتصال قبلی اگر وجود دارد
    await _closeConnection(connectionId);

    int attempt = 0;
    while (attempt < maxRetries) {
      if (!_isOnline) {
        developer.log('🌐 Waiting for network...', name: 'RealtimeOptimizer');
        await _waitForNetwork();
      }

      try {
        final stream = streamBuilder().timeout(timeout).handleError((error) {
          developer.log('❌ Stream error for $connectionId: $error',
              name: 'RealtimeOptimizer');
          _handleConnectionError(connectionId, error);
        });

        // ثبت اتصال موفق
        final subscription = stream.listen(
          (data) => _updateLastActivity(connectionId),
          onError: (error) => _handleConnectionError(connectionId, error),
          onDone: () => _handleConnectionDone(connectionId),
        );

        _activeConnections[connectionId] = subscription;
        _updateLastActivity(connectionId);
        _connectionAttempts[connectionId] = 0;

        developer.log('✅ Connection established: $connectionId',
            name: 'RealtimeOptimizer');
        return stream;
      } catch (e) {
        attempt++;
        _connectionAttempts[connectionId] = attempt;

        if (attempt >= maxRetries) {
          developer.log('💀 Max retries reached for $connectionId: $e',
              name: 'RealtimeOptimizer');
          rethrow;
        }

        final delay = backoffDelay * attempt;
        developer.log(
            '🔄 Retrying $connectionId in ${delay.inSeconds}s (attempt $attempt/$maxRetries)',
            name: 'RealtimeOptimizer');
        await Future.delayed(delay);
      }
    }

    throw Exception('Failed to establish connection: $connectionId');
  }

  /// بستن اتصال
  Future<void> _closeConnection(String connectionId) async {
    final subscription = _activeConnections.remove(connectionId);
    await subscription?.cancel();
    _lastConnectionTime.remove(connectionId);
    _connectionAttempts.remove(connectionId);
  }

  /// به‌روزرسانی زمان آخرین فعالیت
  void _updateLastActivity(String connectionId) {
    _lastConnectionTime[connectionId] = DateTime.now();
  }

  /// مدیریت خطاهای اتصال
  void _handleConnectionError(String connectionId, dynamic error) {
    developer.log('⚠️ Connection error for $connectionId: $error',
        name: 'RealtimeOptimizer');

    // اگر خطای timeout یا network باشد، بازسازی کن
    if (error.toString().contains('timeout') ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      Timer(reconnectDelay, () => _reconnectConnection(connectionId));
    }
  }

  /// مدیریت بسته شدن اتصال
  void _handleConnectionDone(String connectionId) {
    developer.log('🔌 Connection closed: $connectionId',
        name: 'RealtimeOptimizer');
    _activeConnections.remove(connectionId);
  }

  /// بازسازی یک اتصال
  void _reconnectConnection(String connectionId) {
    developer.log('🔄 Reconnecting: $connectionId', name: 'RealtimeOptimizer');
    // بازسازی باید از طریق streamBuilder اصلی انجام شود
    _closeConnection(connectionId);
  }

  /// انتظار برای بازگشت شبکه
  Future<void> _waitForNetwork() async {
    while (!_isOnline) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// توقف همه اتصالات (هنگام قطع شبکه)
  void _pauseAllConnections() {
    developer.log('⏸️ Pausing all connections', name: 'RealtimeOptimizer');
    // اتصالات خودشان timeout می‌شوند
  }

  /// بازسازی همه اتصالات (هنگام بازگشت شبکه)
  void _reconnectAll() {
    developer.log('🔄 Reconnecting all connections', name: 'RealtimeOptimizer');
    // اتصالات جدید از طریق streamBuilder ایجاد می‌شوند
  }

  /// دریافت آمار اتصالات
  Map<String, dynamic> getConnectionStats() {
    return {
      'active_connections': _activeConnections.length,
      'is_online': _isOnline,
      'total_connection_attempts':
          _connectionAttempts.values.fold(0, (sum, attempts) => sum + attempts),
      'connections': _activeConnections.keys.toList(),
    };
  }

  /// بستن همه اتصالات
  Future<void> closeAllConnections() async {
    developer.log('🔌 Closing all connections', name: 'RealtimeOptimizer');

    final futures = _activeConnections.keys.map(_closeConnection).toList();
    await Future.wait(futures);

    developer.log('✅ All connections closed', name: 'RealtimeOptimizer');
  }

  /// dispose کامل
  void dispose() {
    _healthCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    closeAllConnections();
    _isInitialized = false;
  }
}
