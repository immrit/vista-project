import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'telegram_voice_service.dart';
import 'telegram_voice_upload_service.dart';
import 'telegram_voice_player_service.dart';

/// سرویس یکپارچه وویس تلگرام - مدیریت کامل چرخه حیات وویس
class TelegramVoiceIntegrationService {
  // Singleton instance
  static final TelegramVoiceIntegrationService _instance =
      TelegramVoiceIntegrationService._internal();
  factory TelegramVoiceIntegrationService() => _instance;
  TelegramVoiceIntegrationService._internal();

  // Service instances
  final TelegramVoiceService _voiceService = TelegramVoiceService();
  final TelegramVoiceUploadService _uploadService =
      TelegramVoiceUploadService();
  final TelegramVoicePlayerService _playerService =
      TelegramVoicePlayerService();

  // Integration state
  bool _isInitialized = false;
  String? _currentConversationId;
  final Map<String, VoiceRecordingData> _recordings = {};
  final Map<String, VoiceUploadResult> _uploads = {};

  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _voiceService.initialize();
    _isInitialized = true;

    print('🎙️ Telegram Voice Integration Service initialized');
  }

  /// تنظیم conversation ID فعلی
  void setCurrentConversation(String conversationId) {
    _currentConversationId = conversationId;
  }

  /// شروع ضبط وویس با تنظیمات پیشرفته
  Future<bool> startVoiceRecording({
    RecordingConfig? config,
    Function(bool)? onRecordingStateChanged,
    Function(int)? onDurationChanged,
    Function(List<double>)? onWaveformDataChanged,
    Function(bool)? onLockedStateChanged,
    Function(bool)? onCancelingStateChanged,
    Function(bool)? onPausedStateChanged,
    Function(double)? onAmplitudeChanged,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // تنظیم callbacks
    _voiceService.setCallbacks(
      onRecordingStateChanged: onRecordingStateChanged,
      onDurationChanged: onDurationChanged,
      onWaveformDataChanged: onWaveformDataChanged,
      onLockedStateChanged: onLockedStateChanged,
      onCancelingStateChanged: onCancelingStateChanged,
      onPausedStateChanged: onPausedStateChanged,
      onAmplitudeChanged: onAmplitudeChanged,
    );

    // تنظیم کانفیگ
    if (config != null) {
      _voiceService.setRecordingConfig(config);
    }

    return await _voiceService.startRecording();
  }

  /// توقف ضبط وویس
  Future<VoiceRecordingData?> stopVoiceRecording() async {
    final recordingData = await _voiceService.stopRecording();
    if (recordingData != null) {
      _recordings[recordingData.filePath] = recordingData;
    }
    return recordingData;
  }

  /// لغو ضبط وویس
  Future<void> cancelVoiceRecording() async {
    await _voiceService.cancelRecording();
  }

  /// قفل/باز کردن قفل ضبط
  void lockVoiceRecording() => _voiceService.lockRecording();
  void unlockVoiceRecording() => _voiceService.unlockRecording();

  /// مکث/ادامه ضبط
  Future<void> pauseResumeVoiceRecording() async {
    await _voiceService.pauseResumeRecording();
  }

  /// آپلود وویس با مدیریت کامل
  Future<VoiceUploadResult> uploadVoiceRecording(
    VoiceRecordingData recordingData, {
    String? conversationId,
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    final targetConversationId = conversationId ?? _currentConversationId;
    if (targetConversationId == null) {
      throw Exception('Conversation ID not set');
    }

    final result = await _uploadService.uploadVoiceFile(
      recordingData,
      targetConversationId,
      onProgress: onProgress,
      onStatusChanged: onStatusChanged,
    );

    if (result.isSuccess) {
      _uploads[result.fileUrl] = result;
    }

    return result;
  }

  /// آپلود وویس از فایل
  Future<VoiceUploadResult> uploadVoiceFile(
    File voiceFile,
    int duration,
    List<double> waveformData, {
    String? conversationId,
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    final targetConversationId = conversationId ?? _currentConversationId;
    if (targetConversationId == null) {
      throw Exception('Conversation ID not set');
    }

    final recordingData = VoiceRecordingData(
      filePath: voiceFile.path,
      duration: duration,
      waveformData: waveformData,
      fileSize: await voiceFile.length() / 1024,
      timestamp: DateTime.now(),
    );

    return await uploadVoiceRecording(
      recordingData,
      conversationId: targetConversationId,
      onProgress: onProgress,
      onStatusChanged: onStatusChanged,
    );
  }

  /// آپلود وویس از bytes
  Future<VoiceUploadResult> uploadVoiceBytes(
    Uint8List voiceBytes,
    String fileName,
    int duration,
    List<double> waveformData, {
    String? conversationId,
    Function(double progress)? onProgress,
    Function(String status)? onStatusChanged,
  }) async {
    final targetConversationId = conversationId ?? _currentConversationId;
    if (targetConversationId == null) {
      throw Exception('Conversation ID not set');
    }

    return await _uploadService.uploadVoiceFileWeb(
      voiceBytes,
      fileName,
      targetConversationId,
      duration,
      waveformData,
      onProgress: onProgress,
      onStatusChanged: onStatusChanged,
    );
  }

  /// پخش وویس
  Future<bool> playVoice(
    String audioUrl, {
    Uint8List? audioBytes,
    String? localPath,
    int duration = 0,
    List<double> waveformData = const [],
    PlaybackConfig? config,
    Duration? startPosition,
    Function(VoicePlaybackState)? onStateChanged,
    Function(Duration position)? onPositionChanged,
    Function(Duration duration)? onDurationChanged,
    Function(double speed)? onSpeedChanged,
    Function(double volume)? onVolumeChanged,
    Function(String error)? onError,
  }) async {
    final playerId =
        '${audioUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}';

    // تنظیم callbacks
    _playerService.setCallbacks(
      onStateChanged: onStateChanged,
      onPositionChanged: onPositionChanged,
      onDurationChanged: onDurationChanged,
      onSpeedChanged: onSpeedChanged,
      onVolumeChanged: onVolumeChanged,
      onError: onError,
    );

    // تنظیم کانفیگ
    if (config != null) {
      _playerService.setPlaybackConfig(playerId, config);
    }

    final fileInfo = VoiceFileInfo(
      url: audioUrl,
      bytes: audioBytes,
      localPath: localPath,
      duration: duration,
      waveformData: waveformData,
      fileSize: audioBytes?.length.toDouble() ?? 0,
      timestamp: DateTime.now(),
    );

    return await _playerService.playVoice(playerId, fileInfo,
        startPosition: startPosition);
  }

  /// کنترل پخش
  Future<void> pauseResumePlayback(String playerId) async {
    await _playerService.pauseResumePlayback(playerId);
  }

  Future<void> stopPlayback(String playerId) async {
    await _playerService.stopPlayback(playerId);
  }

  Future<void> seekTo(String playerId, Duration position) async {
    await _playerService.seekTo(playerId, position);
  }

  Future<void> setPlaybackSpeed(String playerId, double speed) async {
    await _playerService.setPlaybackSpeed(playerId, speed);
  }

  Future<void> setVolume(String playerId, double volume) async {
    await _playerService.setVolume(playerId, volume);
  }

  /// حذف وویس
  Future<bool> deleteVoice(String fileUrl) async {
    final success = await _uploadService.deleteVoiceFile(fileUrl);
    if (success) {
      _uploads.remove(fileUrl);
    }
    return success;
  }

  /// دریافت اطلاعات وویس
  Future<Map<String, dynamic>?> getVoiceInfo(String fileUrl) async {
    return await _uploadService.getVoiceFileInfo(fileUrl);
  }

  /// کش کردن وویس
  Future<String?> cacheVoice(String url, String playerId) async {
    return await _playerService.cacheVoiceFile(url, playerId);
  }

  /// پاکسازی کش
  Future<void> clearCache(String playerId) async {
    await _playerService.clearCache(playerId);
  }

  /// دریافت وضعیت فعلی
  Map<String, dynamic> getCurrentState() {
    return {
      'isInitialized': _isInitialized,
      'currentConversationId': _currentConversationId,
      'isRecording': _voiceService.isRecording,
      'isLocked': _voiceService.isLocked,
      'recordingDuration': _voiceService.recordingDuration,
      'currentPlayerId': _playerService.currentPlayerId,
      'playbackState': _playerService.currentState.toString(),
      'playbackPosition': _playerService.currentPosition.inSeconds,
      'playbackDuration': _playerService.currentDuration.inSeconds,
      'playbackSpeed': _playerService.currentSpeed,
      'volume': _playerService.currentVolume,
      'recordingsCount': _recordings.length,
      'uploadsCount': _uploads.length,
    };
  }

  /// دریافت لیست ضبط‌ها
  List<VoiceRecordingData> getRecordings() {
    return _recordings.values.toList();
  }

  /// دریافت لیست آپلودها
  List<VoiceUploadResult> getUploads() {
    return _uploads.values.toList();
  }

  /// پاکسازی منابع
  Future<void> dispose() async {
    await _voiceService.dispose();
    await _playerService.dispose();
    _uploadService.dispose();

    _recordings.clear();
    _uploads.clear();
    _isInitialized = false;
    _currentConversationId = null;

    print('🧹 Telegram Voice Integration Service disposed');
  }
}
