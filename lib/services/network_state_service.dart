// lib/services/network_state_service.dart
//
// سرویس مدیریت وضعیت شبکه
// 
// این سرویس:
// ✅ وضعیت اینترنت رو real-time تشخیص میده
// ✅ کیفیت اتصال رو measure میکنه
// ✅ تغییرات رو با minimum delay گزارش میده
// ✅ Battery-efficient هست
//

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../model/network_state.dart';
import '../security/logging_utility.dart';

class NetworkStateService {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final NetworkStateService _instance = NetworkStateService._internal();
  factory NetworkStateService() => _instance;
  NetworkStateService._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // 📡 STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════════

  final _stateController = StreamController<NetworkState>.broadcast();
  Stream<NetworkState> get stateStream => _stateController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 CURRENT STATE
  // ═══════════════════════════════════════════════════════════════════════════

  NetworkState _currentState = NetworkState.initial();
  NetworkState get currentState => _currentState;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔌 SUBSCRIPTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // ═══════════════════════════════════════════════════════════════════════════
  // ⏱️ TIMERS & MONITORING
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _qualityCheckTimer;
  Timer? _reconnectTimer;
  DateTime? _lastDisconnectTime;
  int _consecutiveFailures = 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚙️ CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════

  static const Duration _qualityCheckInterval = Duration(seconds: 30);
  static const Duration _reconnectCheckInterval = Duration(seconds: 5);
  static const int _maxConsecutiveFailures = 3;
  static const Duration _pingTimeout = Duration(seconds: 5);

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎛️ FLAGS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isInitialized = false;
  bool _isDisposed = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚀 INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize service
  Future<void> initialize() async {
    if (_isInitialized) {
      logInfo('⚠️ NetworkStateService already initialized');
      return;
    }

    logInfo('🚀 Initializing NetworkStateService...');

    try {
      // ✅ Check initial connectivity
      await _checkInitialState();

      // ✅ Listen to connectivity changes
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen(_onConnectivityChanged);

      // ✅ Start quality monitoring
      _startQualityMonitoring();

      _isInitialized = true;
      logInfo('✅ NetworkStateService initialized successfully');
      logInfo('   Initial state: $_currentState');
    } catch (e, stack) {
      logInfo('❌ Failed to initialize NetworkStateService: $e');
      logInfo('Stack trace: $stack');
      
      // Set default connected state if initialization fails
      _updateState(NetworkState.connected());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔍 INITIAL STATE CHECK
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check initial network state
  Future<void> _checkInitialState() async {
    try {
      // Check connectivity type
      final connectivityResult = await Connectivity().checkConnectivity();
      final connectionType = _mapConnectivityToType(connectivityResult);

      // Check actual internet access
      final hasInternet = await _checkInternetAccess();

      // Measure initial quality
      NetworkQuality quality = NetworkQuality.none;
      int? latency;

      if (hasInternet) {
        latency = await _measureLatency();
        quality = _calculateQuality(latency);
      }

      _updateState(NetworkState(
        isConnected: hasInternet,
        connectionType: connectionType,
        quality: quality,
        lastChecked: DateTime.now(),
        latencyMs: latency,
      ));
    } catch (e) {
      logInfo('⚠️ Error checking initial state: $e');
      _updateState(NetworkState.initial());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📡 CONNECTIVITY CHANGE HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    if (_isDisposed) return;
    
    logInfo('📡 Connectivity changed: $result');

    final connectionType = _mapConnectivityToType(result);

    // Update state immediately with new connection type
    _updateState(_currentState.copyWith(
      connectionType: connectionType,
      lastChecked: DateTime.now(),
    ));

    // Schedule internet check
    _scheduleInternetCheck();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ CONNECTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Handle connection established
  Future<void> _onConnected() async {
    if (_isDisposed) return;
    
    _lastDisconnectTime = null;
    _consecutiveFailures = 0;
    _reconnectTimer?.cancel();

    // Measure quality
    final latency = await _measureLatency();
    final quality = _calculateQuality(latency);

    _updateState(_currentState.copyWith(
      isConnected: true,
      quality: quality,
      latencyMs: latency,
      lastChecked: DateTime.now(),
    ));

    logInfo('✅ Connected - Quality: ${quality.name}, Latency: ${latency}ms');
  }

  /// Handle disconnection
  void _onDisconnected() {
    if (_isDisposed) return;
    
    _lastDisconnectTime = DateTime.now();
    _consecutiveFailures++;

    _updateState(_currentState.copyWith(
      isConnected: false,
      quality: NetworkQuality.none,
      lastChecked: DateTime.now(),
    ));

    logInfo('❌ Disconnected (failures: $_consecutiveFailures)');

    // Start aggressive reconnection monitoring
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      _startReconnectionMonitoring();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔄 INTERNET CHECK
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if there is actual internet access
  Future<bool> _checkInternetAccess() async {
    try {
      // Try to connect to Google DNS
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // Try alternative check
      try {
        final result = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e2) {
        return false;
      }
    }
  }

  /// Schedule internet connectivity check
  void _scheduleInternetCheck() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (_isDisposed) return;

      try {
        final hasInternet = await _checkInternetAccess();

        if (hasInternet != _currentState.isConnected) {
          if (hasInternet) {
            await _onConnected();
          } else {
            _onDisconnected();
          }
        }
      } catch (e) {
        logInfo('⚠️ Internet check failed: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 QUALITY MONITORING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start quality monitoring
  void _startQualityMonitoring() {
    _qualityCheckTimer?.cancel();
    _qualityCheckTimer = Timer.periodic(_qualityCheckInterval, (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (!_currentState.isConnected) return;

      try {
        final latency = await _measureLatency();
        final quality = _calculateQuality(latency);

        // Only update if quality changed significantly
        if (quality != _currentState.quality ||
            (latency != null &&
                (_currentState.latencyMs == null ||
                    (latency - _currentState.latencyMs!).abs() > 100))) {
          _updateState(_currentState.copyWith(
            quality: quality,
            latencyMs: latency,
            lastChecked: DateTime.now(),
          ));

          logInfo('📊 Quality updated: ${quality.name} (${latency}ms)');
        }
      } catch (e) {
        logInfo('⚠️ Quality check failed: $e');
      }
    });
  }

  /// Start aggressive reconnection monitoring
  void _startReconnectionMonitoring() {
    logInfo('🔄 Starting reconnection monitoring...');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(_reconnectCheckInterval, (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (_currentState.isConnected) {
        timer.cancel();
        logInfo('✅ Reconnection successful, stopping monitor');
        return;
      }

      try {
        final hasInternet = await _checkInternetAccess();
        if (hasInternet) {
          timer.cancel();
          await _onConnected();
        }
      } catch (e) {
        logInfo('⚠️ Reconnection check failed: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📏 LATENCY MEASUREMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Measure network latency using ping
  Future<int?> _measureLatency() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Ping Google DNS (reliable and fast)
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: _pingTimeout,
      );

      socket.destroy();
      stopwatch.stop();

      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      // Try alternative endpoint
      try {
        final stopwatch = Stopwatch()..start();
        
        final socket = await Socket.connect(
          '1.1.1.1', // Cloudflare DNS
          53,
          timeout: _pingTimeout,
        );
        
        socket.destroy();
        stopwatch.stop();
        
        return stopwatch.elapsedMilliseconds;
      } catch (e2) {
        logInfo('⚠️ Latency measurement failed: $e2');
        return null;
      }
    }
  }

  /// Calculate network quality based on latency
  NetworkQuality _calculateQuality(int? latencyMs) {
    if (latencyMs == null) return NetworkQuality.poor;

    if (latencyMs < 50) {
      return NetworkQuality.excellent; // <50ms = عالی
    } else if (latencyMs < 150) {
      return NetworkQuality.good; // 50-150ms = خوب
    } else if (latencyMs < 300) {
      return NetworkQuality.fair; // 150-300ms = متوسط
    } else {
      return NetworkQuality.poor; // >300ms = ضعیف
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🗺️ MAPPING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Map ConnectivityResult to ConnectionType
  ConnectionType _mapConnectivityToType(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectionType.wifi;
      case ConnectivityResult.mobile:
        return ConnectionType.cellular;
      case ConnectivityResult.ethernet:
        return ConnectionType.ethernet;
      case ConnectivityResult.vpn:
        return ConnectionType.vpn;
      case ConnectivityResult.none:
      default:
        return ConnectionType.none;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔄 STATE UPDATE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update state and notify listeners
  void _updateState(NetworkState newState) {
    if (_isDisposed) return;

    _currentState = newState;

    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 PUBLIC METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Force refresh network state
  Future<void> refresh() async {
    logInfo('🔄 Force refreshing network state...');
    await _checkInitialState();
  }

  /// Check if can perform operation
  bool canPerform(NetworkOperation operation) {
    switch (operation) {
      case NetworkOperation.sendMessage:
        return _currentState.canSendMessage;
      case NetworkOperation.downloadMedia:
        return _currentState.canDownloadMedia;
      case NetworkOperation.uploadMedia:
        return _currentState.isConnected && _currentState.hasGoodQuality;
      case NetworkOperation.syncData:
        return _currentState.isConnected;
    }
  }

  /// Get connection statistics
  Map<String, dynamic> getStats() {
    return {
      'isConnected': _currentState.isConnected,
      'connectionType': _currentState.connectionType.name,
      'quality': _currentState.quality.name,
      'qualityText': _currentState.qualityText,
      'latencyMs': _currentState.latencyMs,
      'consecutiveFailures': _consecutiveFailures,
      'lastDisconnect': _lastDisconnectTime?.toIso8601String(),
      'lastChecked': _currentState.lastChecked.toIso8601String(),
    };
  }

  /// Get time since last disconnect
  Duration? get timeSinceDisconnect {
    if (_lastDisconnectTime == null) return null;
    return DateTime.now().difference(_lastDisconnectTime!);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧹 DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dispose service
  void dispose() {
    if (_isDisposed) return;

    logInfo('🧹 Disposing NetworkStateService...');

    _isDisposed = true;
    _connectivitySubscription?.cancel();
    _qualityCheckTimer?.cancel();
    _reconnectTimer?.cancel();
    _stateController.close();

    logInfo('✅ NetworkStateService disposed');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📋 ENUMS
// ═══════════════════════════════════════════════════════════════════════════

/// انواع عملیات شبکه
enum NetworkOperation {
  sendMessage,
  downloadMedia,
  uploadMedia,
  syncData,
}
