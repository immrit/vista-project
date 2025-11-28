// lib/features/chat/providers/attachment_provider.dart
//
// Provider برای مدیریت پیوست‌ها
//

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_attachment_service.dart';

/// State برای آپلود پیوست
class AttachmentUploadState {
  final bool isUploading;
  final double progress;
  final String? error;
  final AttachmentResult? result;

  const AttachmentUploadState({
    this.isUploading = false,
    this.progress = 0,
    this.error,
    this.result,
  });

  AttachmentUploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    AttachmentResult? result,
  }) {
    return AttachmentUploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      error: error,
      result: result ?? this.result,
    );
  }
}

/// State برای ضبط صدا
class VoiceRecordingState {
  final bool isRecording;
  final bool isPaused;
  final int duration;
  final List<double> waveform;
  final File? recordedFile;
  final String? error;

  const VoiceRecordingState({
    this.isRecording = false,
    this.isPaused = false,
    this.duration = 0,
    this.waveform = const [],
    this.recordedFile,
    this.error,
  });

  VoiceRecordingState copyWith({
    bool? isRecording,
    bool? isPaused,
    int? duration,
    List<double>? waveform,
    File? recordedFile,
    String? error,
  }) {
    return VoiceRecordingState(
      isRecording: isRecording ?? this.isRecording,
      isPaused: isPaused ?? this.isPaused,
      duration: duration ?? this.duration,
      waveform: waveform ?? this.waveform,
      recordedFile: recordedFile,
      error: error,
    );
  }
}

/// Provider برای سرویس پیوست
final chatAttachmentServiceProvider = Provider<ChatAttachmentService>((ref) {
  return ChatAttachmentService();
});

/// Provider برای وضعیت آپلود (به ازای هر conversation)
final attachmentUploadStateProvider = StateNotifierProvider.family<
    AttachmentUploadNotifier, AttachmentUploadState, String>(
  (ref, conversationId) => AttachmentUploadNotifier(
    ref.watch(chatAttachmentServiceProvider),
    conversationId,
  ),
);

/// Notifier برای آپلود پیوست
class AttachmentUploadNotifier extends StateNotifier<AttachmentUploadState> {
  final ChatAttachmentService _service;
  final String conversationId;

  AttachmentUploadNotifier(this._service, this.conversationId)
      : super(const AttachmentUploadState());

  void _onProgress(double progress) {
    state = state.copyWith(progress: progress);
  }

  /// انتخاب و آپلود عکس از گالری
  Future<AttachmentResult> pickAndUploadImageFromGallery() async {
    state = state.copyWith(isUploading: true, progress: 0, error: null);
    
    final result = await _service.pickImageFromGallery(
      conversationId: conversationId,
      onProgress: _onProgress,
    );

    state = state.copyWith(
      isUploading: false,
      progress: result.success ? 1.0 : 0,
      error: result.error,
      result: result,
    );

    return result;
  }

  /// گرفتن عکس از دوربین و آپلود
  Future<AttachmentResult> pickAndUploadImageFromCamera() async {
    state = state.copyWith(isUploading: true, progress: 0, error: null);
    
    final result = await _service.pickImageFromCamera(
      conversationId: conversationId,
      onProgress: _onProgress,
    );

    state = state.copyWith(
      isUploading: false,
      progress: result.success ? 1.0 : 0,
      error: result.error,
      result: result,
    );

    return result;
  }

  /// انتخاب و آپلود ویدیو
  Future<AttachmentResult> pickAndUploadVideo() async {
    state = state.copyWith(isUploading: true, progress: 0, error: null);
    
    final result = await _service.pickVideoFromGallery(
      conversationId: conversationId,
      onProgress: _onProgress,
    );

    state = state.copyWith(
      isUploading: false,
      progress: result.success ? 1.0 : 0,
      error: result.error,
      result: result,
    );

    return result;
  }

  /// انتخاب و آپلود فایل
  Future<AttachmentResult> pickAndUploadFile() async {
    state = state.copyWith(isUploading: true, progress: 0, error: null);
    
    final result = await _service.pickFile(
      conversationId: conversationId,
      onProgress: _onProgress,
    );

    state = state.copyWith(
      isUploading: false,
      progress: result.success ? 1.0 : 0,
      error: result.error,
      result: result,
    );

    return result;
  }

  /// آپلود فایل صوتی ضبط شده
  Future<AttachmentResult> uploadVoiceMessage(File file, int duration) async {
    state = state.copyWith(isUploading: true, progress: 0, error: null);
    
    final result = await _service.uploadVoiceMessage(
      audioFile: file,
      conversationId: conversationId,
      duration: duration,
      onProgress: _onProgress,
    );

    state = state.copyWith(
      isUploading: false,
      progress: result.success ? 1.0 : 0,
      error: result.error,
      result: result,
    );

    return result;
  }

  /// پاک کردن state
  void reset() {
    state = const AttachmentUploadState();
  }
}

/// Provider برای وضعیت ضبط صدا
final voiceRecordingStateProvider =
    StateNotifierProvider.autoDispose<VoiceRecordingNotifier, VoiceRecordingState>(
  (ref) => VoiceRecordingNotifier(ref.watch(chatAttachmentServiceProvider)),
);

/// Notifier برای ضبط صدا
class VoiceRecordingNotifier extends StateNotifier<VoiceRecordingState> {
  final ChatAttachmentService _service;

  VoiceRecordingNotifier(this._service) : super(const VoiceRecordingState());

  /// شروع ضبط
  Future<bool> startRecording() async {
    final success = await _service.startVoiceRecording(
      onRecordingStateChanged: (isRecording) {
        state = state.copyWith(isRecording: isRecording);
      },
      onDurationChanged: (duration) {
        state = state.copyWith(duration: duration);
      },
      onWaveformDataChanged: (waveform) {
        state = state.copyWith(waveform: waveform);
      },
    );

    if (!success) {
      state = state.copyWith(error: 'خطا در شروع ضبط');
    }

    return success;
  }

  /// توقف ضبط
  Future<File?> stopRecording() async {
    final file = await _service.stopVoiceRecording();
    state = state.copyWith(
      isRecording: false,
      recordedFile: file,
    );
    return file;
  }

  /// لغو ضبط
  Future<void> cancelRecording() async {
    await _service.cancelVoiceRecording();
    state = const VoiceRecordingState();
  }

  /// پاک کردن state
  void reset() {
    state = const VoiceRecordingState();
  }
}

/// Provider ساده برای چک کردن وضعیت آپلود
final isUploadingProvider = Provider.family<bool, String>((ref, conversationId) {
  return ref.watch(attachmentUploadStateProvider(conversationId)).isUploading;
});

/// Provider برای progress آپلود
final uploadProgressProvider = Provider.family<double, String>((ref, conversationId) {
  return ref.watch(attachmentUploadStateProvider(conversationId)).progress;
});

