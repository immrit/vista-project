import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:Vista/provider/theme_provider.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/app_settings_entity.dart';
import 'package:Vista/widgets/VideoPlayerConfig.dart';
import 'package:path_provider/path_provider.dart';
import '../DB/settings_cache_service.dart';
import '../services/animation_controller_service.dart';
import '../services/video_autoplay_service.dart';
import '../services/image_quality_service.dart';
import '../services/cache_manager.dart';
import '../core/data/cache/cache_repository.dart';
// import '../view/widgets/VideoPlayerConfig.dart';
// import '/model/notificationModel.dart';
import '/model/publicPostModel.dart';
import '../services/voice_cache_service.dart';
import '../features/posts/data/go_posts_repository.dart';
import '../DB/profile_cache_service.dart';
// Import security provider

export 'security_provider.dart';
export '../features/auth/providers/auth_controller.dart';

export '../features/profile/providers/profile_controller.dart';
// profileProvider and profileUpdateProvider moved to profile_controller.dart

// user_settings providers
final userSettingsByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    final settingsCache = SettingsCacheService();

    final cachedSettings = settingsCache.getCachedUserSettings(userId);
    if (cachedSettings != null) {
      return cachedSettings;
    }

    await settingsCache.cacheUserSettings(userId);

    final settings = settingsCache.getCachedUserSettings(userId);
    return settings;
  } catch (e) {
    debugPrint('Error fetching user_settings for $userId: $e');
    return null;
  }
});

final currentUserSettingsProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final userId = await TokenStorage.getUserId();
    if (userId == null || userId.isEmpty) return null;
    return SettingsCacheService().getUserSettings(userId);
  } catch (e) {
    debugPrint('Error fetching current user_settings: $e');
    return null;
  }
});
final videoPositionProvider =
    StateProvider.family<Duration, String>((ref, videoId) {
  return Duration.zero;
});

// Video Player Settings Providers
class DataSaverNotifier extends StateNotifier<bool> {
  DataSaverNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final value = await VideoPlayerConfig().getDataSaverMode();
    state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await VideoPlayerConfig().setDataSaverMode(value);
  }
}

final dataSaverProvider = StateNotifierProvider<DataSaverNotifier, bool>((ref) {
  return DataSaverNotifier();
});

class AutoQualityNotifier extends StateNotifier<bool> {
  AutoQualityNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final value = await VideoPlayerConfig().getAutoQuality();
    state = value;
  }

  Future<void> set(bool value) async {
    state = value;
    await VideoPlayerConfig().setAutoQuality(value);
  }
}

final autoQualityProvider =
    StateNotifierProvider<AutoQualityNotifier, bool>((ref) {
  return AutoQualityNotifier();
});

final videoQualityProvider = StateProvider<String>((ref) => 'auto');

final videoPlayerConfigProvider = Provider<VideoPlayerConfig>((ref) {
  return VideoPlayerConfig();
});

// Video Position Cache Provider
final videoPositionsProvider =
    StateProvider.family<Duration, String>((ref, videoId) {
  return Duration.zero;
});

// Video Player Theme Provider
final videoPlayerThemeProvider = Provider<VideoPlayerTheme>((ref) {
  final isDark = ref.watch(dynamicThemeProvider).brightness == Brightness.dark;
  return VideoPlayerTheme(
    isDark: isDark,
    accentColor: isDark ? Colors.white : Colors.black,
    backgroundColor: isDark ? Colors.black : Colors.white,
  );
});

class VideoPlayerTheme {
  final bool isDark;
  final Color accentColor;
  final Color backgroundColor;

  VideoPlayerTheme({
    required this.isDark,
    required this.accentColor,
    required this.backgroundColor,
  });
}

// Video Playback State Provider
final playbackStateProvider =
    StateProvider.family<PlaybackState, String>((ref, videoId) {
  return PlaybackState();
});

class PlaybackState {
  final bool isPlaying;
  final bool isBuffering;
  final bool isMuted;
  final Duration position;
  final Duration duration;

  PlaybackState({
    this.isPlaying = false,
    this.isBuffering = false,
    this.isMuted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    bool? isBuffering,
    bool? isMuted,
    Duration? position,
    Duration? duration,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isMuted: isMuted ?? this.isMuted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class ReelsNotifier extends StateNotifier<List<PublicPostModel>> {
  ReelsNotifier() : super([]);

  void updateReel(PublicPostModel updatedReel) {
    state = [
      for (final reel in state)
        if (reel.id == updatedReel.id) updatedReel else reel
    ];
  }
}

final autoPlayProvider = StateNotifierProvider<AutoPlayNotifier, bool>((ref) {
  return AutoPlayNotifier();
});

class AutoPlayNotifier extends StateNotifier<bool> {
  final VideoAutoplayService _videoAutoplayService = VideoAutoplayService();

  AutoPlayNotifier() : super(true) {
    _load();
  }

  void _load() async {
    await _videoAutoplayService.loadSettings();
    state = _videoAutoplayService.shouldAutoPlay();
  }

  void set(bool value) async {
    await _videoAutoplayService.setAutoPlay(value);
    state = _videoAutoplayService.shouldAutoPlay();
  }

  void refresh() async {
    await _videoAutoplayService.loadSettings();
    state = _videoAutoplayService.shouldAutoPlay();
  }
}

// Font size settings provider
class MessageFontSizeNotifier extends StateNotifier<double> {
  Isar? _isar;

  MessageFontSizeNotifier() : super(14.0) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadFontSize();
    } catch (e) {}
  }

  Future<void> _loadFontSize() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null && settings.messageFontSize != null) {
        state = settings.messageFontSize!;
      }
    } catch (e) {}
  }

  Future<void> setFontSize(double size) async {
    state = size;
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false // Default
            ..selectedColor = 'white' // Default
            ..messageFontSize = size;
        } else {
          settings.messageFontSize = size;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {}
  }

  String getFontSizeLabel(double size) {
    if (size <= 11.0) return 'خیلی کوچک';
    if (size <= 13.0) return 'کوچک';
    if (size <= 15.0) return 'متوسط';
    if (size <= 17.0) return 'بزرگ';
    return 'خیلی بزرگ';
  }
}

final messageFontSizeProvider =
    StateNotifierProvider<MessageFontSizeNotifier, double>((ref) {
  return MessageFontSizeNotifier();
});

// Auto download settings provider
class AutoDownloadSettings {
  final String photos; // 'always', 'wifi', 'never'
  final String voices; // 'always', 'wifi', 'never'

  AutoDownloadSettings({
    this.photos = 'wifi',
    this.voices = 'wifi',
  });

  AutoDownloadSettings copyWith({
    String? photos,
    String? voices,
  }) {
    return AutoDownloadSettings(
      photos: photos ?? this.photos,
      voices: voices ?? this.voices,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photos': photos,
      'voices': voices,
    };
  }

  static AutoDownloadSettings fromMap(Map<String, dynamic> map) {
    return AutoDownloadSettings(
      photos: map['photos'] ?? 'wifi',
      voices: map['voices'] ?? 'wifi',
    );
  }
}

class AutoDownloadNotifier extends StateNotifier<AutoDownloadSettings> {
  Isar? _isar;

  AutoDownloadNotifier() : super(AutoDownloadSettings()) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadSettings();
    } catch (e) {}
  }

  Future<void> _loadSettings() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null) {
        state = state.copyWith(
          photos: settings.autoDownloadPhotos,
          voices: settings.autoDownloadVoices,
        );
      }
    } catch (e) {}
  }

  Future<void> updatePhotoSetting(String setting) async {
    state = state.copyWith(photos: setting);
    await _saveSettings();

    await _applyAutoDownloadSettings();
  }

  Future<void> updateVoiceSetting(String setting) async {
    state = state.copyWith(voices: setting);
    await _saveSettings();

    await _applyAutoDownloadSettings();
  }

  Future<void> _applyAutoDownloadSettings() async {
    try {
      if (state.photos == 'never') {
        await _clearPhotoCache();
      }
      if (state.voices == 'never') {
        await _clearVoiceCache();
      }
    } catch (e) {}
  }

  Future<void> _clearPhotoCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final chatImagesDir = Directory('${appDir.path}/chat_images');
      if (await chatImagesDir.exists()) {
        await chatImagesDir.delete(recursive: true);
      }
    } catch (e) {}
  }

  Future<void> _clearVoiceCache() async {
    try {
      final voiceCacheService = VoiceCacheService();
      await voiceCacheService.clearAllCache();
    } catch (e) {}
  }

  Future<void> _saveSettings() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false
            ..selectedColor = 'white'
            ..autoDownloadPhotos = state.photos
            ..autoDownloadVoices = state.voices;
        } else {
          settings.autoDownloadPhotos = state.photos;
          settings.autoDownloadVoices = state.voices;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {}
  }

  String getSettingLabel(String setting) {
    switch (setting) {
      case 'always':
        return 'همیشه';
      case 'wifi':
        return 'فقط با وای فای';
      case 'never':
        return 'هرگز';
      default:
        return 'نامشخص';
    }
  }
}

final autoDownloadProvider =
    StateNotifierProvider<AutoDownloadNotifier, AutoDownloadSettings>((ref) {
  return AutoDownloadNotifier();
});

// Performance settings provider
class PerformanceSettings {
  final bool batterySaverMode;
  final bool smartCache;
  final bool messagePreloading;

  PerformanceSettings({
    this.batterySaverMode = false,
    this.smartCache = true,
    this.messagePreloading = true,
  });

  PerformanceSettings copyWith({
    bool? batterySaverMode,
    bool? smartCache,
    bool? messagePreloading,
  }) {
    return PerformanceSettings(
      batterySaverMode: batterySaverMode ?? this.batterySaverMode,
      smartCache: smartCache ?? this.smartCache,
      messagePreloading: messagePreloading ?? this.messagePreloading,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batterySaverMode': batterySaverMode,
      'smartCache': smartCache,
      'messagePreloading': messagePreloading,
    };
  }

  static PerformanceSettings fromMap(Map<String, dynamic> map) {
    return PerformanceSettings(
      batterySaverMode: map['batterySaverMode'] ?? false,
      smartCache: map['smartCache'] ?? true,
      messagePreloading: map['messagePreloading'] ?? true,
    );
  }
}

class PerformanceNotifier extends StateNotifier<PerformanceSettings> {
  Isar? _isar;

  PerformanceNotifier() : super(PerformanceSettings()) {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      _loadSettings();
    } catch (e) {}
  }

  Future<void> _loadSettings() async {
    if (_isar == null) return;
    try {
      final settings = await _isar!.appSettingsEntitys.get(1);
      if (settings != null) {
        state = state.copyWith(
          batterySaverMode: settings.batterySaverMode,
          smartCache: settings.smartCache,
          messagePreloading: settings.messagePreloading,
        );
      }
    } catch (e) {}
  }

  Future<void> updateBatterySaver(bool enabled) async {
    state = state.copyWith(batterySaverMode: enabled);
    await _saveSettings();

    // Note: Services are updated below directly
    // if (enabled) {
    //   await _applyBatterySaverMode();
    // } else {
    //   await _disableBatterySaverMode();
    // }

    final animationService = AnimationControllerService();
    await animationService.setBatterySaverMode(enabled);

    final videoAutoplayService = VideoAutoplayService();
    await videoAutoplayService.setBatterySaverMode(enabled);

    final imageQualityService = ImageQualityService();
    await imageQualityService.setBatterySaverMode(enabled);

    final unifiedCacheManager = UnifiedCacheManager();
    unifiedCacheManager.setBatterySaverMode(enabled);
  }

  Future<void> updateSmartCache(bool enabled) async {
    state = state.copyWith(smartCache: enabled);
    await _saveSettings();

    final unifiedCacheManager = UnifiedCacheManager();
    unifiedCacheManager.setSmartCacheEnabled(enabled);

    if (enabled) {
      await CacheRepository().optimize();
    }
  }

  Future<void> updateMessagePreloading(bool enabled) async {
    state = state.copyWith(messagePreloading: enabled);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    if (_isar == null) return;
    try {
      await _isar!.writeTxn(() async {
        var settings = await _isar!.appSettingsEntitys.get(1);
        if (settings == null) {
          settings = AppSettingsEntity()
            ..id = 1
            ..isDark = false
            ..selectedColor = 'white'
            ..batterySaverMode = state.batterySaverMode
            ..smartCache = state.smartCache
            ..messagePreloading = state.messagePreloading;
        } else {
          settings.batterySaverMode = state.batterySaverMode;
          settings.smartCache = state.smartCache;
          settings.messagePreloading = state.messagePreloading;
        }
        await _isar!.appSettingsEntitys.put(settings);
      });
    } catch (e) {}
  }

  /*
  Future<void> _applyBatterySaverMode() async {
    // Legacy Sembast removal
  }

  Future<void> _disableBatterySaverMode() async {
    // Legacy Sembast removal
  }
  */

  String getBatterySaverDescription() {
    return state.batterySaverMode ? 'فعال' : 'غیرفعال';
  }

  String getSmartCacheDescription() {
    return state.smartCache ? 'فعال' : 'غیرفعال';
  }

  String getPreloadingDescription() {
    return state.messagePreloading ? 'فعال' : 'غیرفعال';
  }
}

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceSettings>((ref) {
  return PerformanceNotifier();
});

class ProfilePostsNotifier
    extends StateNotifier<AsyncValue<List<PublicPostModel>>> {
  final String userId;
  final GoPostsRepository _postsRepository = GoPostsRepository();
  final int _limit = 30;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  final List<PublicPostModel> _allPosts = [];

  ProfilePostsNotifier(this.userId) : super(const AsyncValue.loading()) {
    _loadInitialPosts();
  }

  Future<void> _loadInitialPosts() async {
    state = const AsyncValue.loading();
    _offset = 0;
    _hasMore = true;
    _isLoading = false;
    _allPosts.clear();
    await _loadMorePosts();
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;

    try {
      final newPosts = await _postsRepository.getUserPosts(
        userId: userId,
        limit: _limit,
        offset: _offset,
      );

      if (newPosts.isEmpty) {
        _hasMore = false;
        state = AsyncValue.data(List<PublicPostModel>.from(_allPosts));
        return;
      }

      _allPosts.addAll(newPosts);
      _offset += newPosts.length;
      _hasMore = newPosts.length == _limit;

      state = AsyncValue.data(List<PublicPostModel>.from(_allPosts));
    } catch (e) {
      final cachedPosts = await ProfileCacheService().getCachedPosts(userId);
      if (cachedPosts.isNotEmpty) {
        _allPosts
          ..clear()
          ..addAll(cachedPosts);
        _hasMore = false;
        state = AsyncValue.data(List<PublicPostModel>.from(_allPosts));
        debugPrint(
            '⚠️ [ProfilePostsNotifier] Using cached posts for $userId after fetch failure: $e');
        return;
      }
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    await _loadMorePosts();
  }

  Future<void> refresh() async {
    await _loadInitialPosts();
  }

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
}

final profilePostsProvider = StateNotifierProvider.family<ProfilePostsNotifier,
    AsyncValue<List<PublicPostModel>>, String>((ref, userId) {
  return ProfilePostsNotifier(userId);
});

final colorBlindMatrixProvider = StateProvider<List<double>?>((ref) => null);
