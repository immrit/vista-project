import '../security/logging_utility.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// Centralized database manager to prevent SQLite synchronization conflicts
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  // Database instances
  Database? _settingsDatabase;
  Database? _recentSearchesDatabase;

  // Initialization flags
  bool _isInitializing = false;
  final Map<String, bool> _initializationStatus = {};

  /// Get or create settings database
  Future<Database> getSettingsDatabase() async {
    if (_settingsDatabase != null) {
      return _settingsDatabase!;
    }

    if (_isInitializing) {
      // Wait for initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _settingsDatabase!;
    }

    _isInitializing = true;
    try {
      String dbPath = 'settings.db';
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = '${appDir.path}/settings.db';
      }

      _settingsDatabase = await databaseFactoryIo.openDatabase(
        dbPath,
        version: 1,
        onVersionChanged: (database, oldVersion, newVersion) {
          // Handle database version changes if needed
        },
      );

      _initializationStatus['settings'] = true;
      logInfo('✅ Settings database initialized successfully');
      return _settingsDatabase!;
    } catch (e) {
      logInfo('❌ Failed to initialize settings database: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Get or create recent searches database
  Future<Database> getRecentSearchesDatabase() async {
    if (_recentSearchesDatabase != null) {
      return _recentSearchesDatabase!;
    }

    try {
      String dbPath = 'recent_searches.db';
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = '${appDir.path}/recent_searches.db';
      }

      _recentSearchesDatabase = await databaseFactoryIo.openDatabase(
        dbPath,
        version: 1,
        onVersionChanged: (database, oldVersion, newVersion) {
          // Handle database version changes if needed
        },
      );

      _initializationStatus['recent_searches'] = true;
      logInfo('✅ Recent searches database initialized successfully');
      return _recentSearchesDatabase!;
    } catch (e) {
      logInfo('❌ Failed to initialize recent searches database: $e');
      rethrow;
    }
  }

  /// Initialize all databases at startup
  Future<void> initializeAllDatabases() async {
    if (_initializationStatus['settings'] == true &&
        _initializationStatus['recent_searches'] == true) {
      logInfo('✅ All databases already initialized');
      return;
    }

    logInfo('🚀 Initializing all databases...');

    try {
      // Initialize databases sequentially to avoid conflicts
      await getSettingsDatabase();
      await getRecentSearchesDatabase();

      logInfo('✅ All databases initialized successfully');
    } catch (e) {
      logInfo('❌ Failed to initialize databases: $e');
      rethrow;
    }
  }

  /// Close all databases
  Future<void> closeAllDatabases() async {
    try {
      if (_settingsDatabase != null) {
        await _settingsDatabase!.close();
        _settingsDatabase = null;
        _initializationStatus['settings'] = false;
      }

      if (_recentSearchesDatabase != null) {
        await _recentSearchesDatabase!.close();
        _recentSearchesDatabase = null;
        _initializationStatus['recent_searches'] = false;
      }

      logInfo('✅ All databases closed successfully');
    } catch (e) {
      logInfo('❌ Error closing databases: $e');
    }
  }

  /// Check if a database is initialized
  bool isDatabaseInitialized(String databaseName) {
    return _initializationStatus[databaseName] == true;
  }

  /// Get database status
  Map<String, bool> getDatabaseStatus() {
    return Map.from(_initializationStatus);
  }
}
