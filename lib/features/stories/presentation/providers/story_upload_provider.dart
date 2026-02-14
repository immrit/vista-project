import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/i_story_repository.dart';
import '../../presentation/providers/story_providers.dart';

// State for story upload
class StoryUploadState {
  final bool isUploading;
  final bool isSuccess;
  final String? error;
  final double progress; // 0.0 to 1.0

  const StoryUploadState({
    this.isUploading = false,
    this.isSuccess = false,
    this.error,
    this.progress = 0.0,
  });

  StoryUploadState copyWith({
    bool? isUploading,
    bool? isSuccess,
    String? error,
    double? progress,
  }) {
    return StoryUploadState(
      isUploading: isUploading ?? this.isUploading,
      isSuccess: isSuccess ?? this.isSuccess,
      error:
          error, // If passed null, it stays null, if passed error, it updates
      progress: progress ?? this.progress,
    );
  }
}

class StoryUploadNotifier extends StateNotifier<StoryUploadState> {
  final IStoryRepository _repository;
  final Ref _ref;

  StoryUploadNotifier(this._repository, this._ref)
      : super(const StoryUploadState());

  Future<void> uploadStory(StoryUploadParams params) async {
    state = state.copyWith(isUploading: true, progress: 0.1, error: null);

    try {
      // Simulate progress for UX (since repo doesn't stream progress yet)
      // In a real app with Dio/Supabase Storage, we would listen to progress.
      _simulateProgress();

      final result = await _repository.uploadStory(params);

      result.fold(
        (error) {
          state = state.copyWith(
              isUploading: false, isSuccess: false, error: error);
        },
        (story) {
          state = state.copyWith(
              isUploading: false, isSuccess: true, progress: 1.0);

          // Refresh active stories so the new story appears immediately
          _ref.invalidate(activeStoriesProvider);
        },
      );
    } catch (e) {
      state = state.copyWith(
          isUploading: false, isSuccess: false, error: e.toString());
    }
  }

  void _simulateProgress() async {
    // Fake progress animation
    for (int i = 1; i <= 8; i++) {
      if (!state.isUploading) return;
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      state = state.copyWith(progress: 0.1 + (i * 0.1));
    }
  }

  void reset() {
    state = const StoryUploadState();
  }
}

final storyUploadProvider =
    StateNotifierProvider<StoryUploadNotifier, StoryUploadState>((ref) {
  final repository = ref.watch(storyRepositoryProvider);
  return StoryUploadNotifier(repository, ref);
});
