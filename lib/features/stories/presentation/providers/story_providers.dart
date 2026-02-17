import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/story_repository.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/i_story_repository.dart';
import '../../core/story_enums.dart';

// ========== Repository Provider ==========

final storyRepositoryProvider = Provider<IStoryRepository>((ref) {
  return StoryRepository();
});

// ========== استوری‌های فعال ==========

final activeStoriesProvider =
    FutureProvider.autoDispose<List<StoryUser>>((ref) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getActiveStories();

  return result.fold(
    (error) => throw Exception(error),
    (data) => data,
  );
});

// ========== استوری‌های یک کاربر ==========

final userStoriesProvider =
    FutureProvider.autoDispose.family<List<Story>, String>((ref, userId) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getUserStories(userId);

  return result.fold(
    (error) => throw Exception(error),
    (data) => data,
  );
});

// ========== بازدیدکنندگان استوری ==========

final storyViewsProvider = FutureProvider.autoDispose
    .family<List<StoryView>, String>((ref, storyId) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getStoryViews(storyId);

  return result.fold(
    (error) => throw Exception(error),
    (data) => data,
  );
});

// ========== Highlights یک کاربر ==========

final userHighlightsProvider = FutureProvider.autoDispose
    .family<List<StoryHighlight>, String>((ref, userId) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getUserHighlights(userId);

  return result.fold(
    (error) => throw Exception(error),
    (data) => data,
  );
});

// ========== تعداد Highlights کاربر ==========

final highlightCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getHighlightCount(userId);

  return result.fold(
    (error) => 0,
    (data) => data,
  );
});

// ========== دوستان نزدیک ==========

final closeFriendsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getCloseFriends();

  return result.fold(
    (error) => [],
    (data) => data,
  );
});

// ========== State Notifier برای آپلود استوری ==========

class StoryUploadState {
  final StoryUploadStatus status;
  final double progress;
  final String? error;
  final Story? uploadedStory;

  const StoryUploadState({
    this.status = StoryUploadStatus.idle,
    this.progress = 0,
    this.error,
    this.uploadedStory,
  });

  StoryUploadState copyWith({
    StoryUploadStatus? status,
    double? progress,
    String? error,
    Story? uploadedStory,
  }) {
    return StoryUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
      uploadedStory: uploadedStory ?? this.uploadedStory,
    );
  }

  bool get isUploading =>
      status == StoryUploadStatus.uploading ||
      status == StoryUploadStatus.compressing ||
      status == StoryUploadStatus.processing;
  bool get isCompleted => status == StoryUploadStatus.completed;
  bool get hasError => status == StoryUploadStatus.error;
}

class StoryUploadNotifier extends StateNotifier<StoryUploadState> {
  final IStoryRepository _repository;
  final Ref _ref;

  StoryUploadNotifier(this._repository, this._ref)
      : super(const StoryUploadState());

  Future<bool> uploadStory(StoryUploadParams params) async {
    try {
      state = state.copyWith(
        status: StoryUploadStatus.compressing,
        progress: 0,
        error: null,
      );

      state = state.copyWith(
        status: StoryUploadStatus.uploading,
        progress: 0.3,
      );

      final result = await _repository.uploadStory(params);

      return result.fold(
        (error) {
          state = state.copyWith(
            status: StoryUploadStatus.error,
            error: error,
          );
          return false;
        },
        (story) {
          state = state.copyWith(
            status: StoryUploadStatus.completed,
            progress: 1.0,
            uploadedStory: story,
          );

          // Refresh stories list
          _ref.invalidate(activeStoriesProvider);

          return true;
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: StoryUploadStatus.error,
        error: 'خطا در آپلود استوری',
      );
      return false;
    }
  }

  void reset() {
    state = const StoryUploadState();
  }
}

final storyUploadProvider =
    StateNotifierProvider.autoDispose<StoryUploadNotifier, StoryUploadState>(
        (ref) {
  final repository = ref.watch(storyRepositoryProvider);
  return StoryUploadNotifier(repository, ref);
});

// ========== State Notifier برای پلیر استوری ==========

class StoryPlayerState {
  final int currentUserIndex;
  final int currentStoryIndex;
  final bool isPaused;
  final bool isLoading;
  final Set<String> viewedStoryIds;

  const StoryPlayerState({
    this.currentUserIndex = 0,
    this.currentStoryIndex = 0,
    this.isPaused = false,
    this.isLoading = true,
    this.viewedStoryIds = const {},
  });

  StoryPlayerState copyWith({
    int? currentUserIndex,
    int? currentStoryIndex,
    bool? isPaused,
    bool? isLoading,
    Set<String>? viewedStoryIds,
  }) {
    return StoryPlayerState(
      currentUserIndex: currentUserIndex ?? this.currentUserIndex,
      currentStoryIndex: currentStoryIndex ?? this.currentStoryIndex,
      isPaused: isPaused ?? this.isPaused,
      isLoading: isLoading ?? this.isLoading,
      viewedStoryIds: viewedStoryIds ?? this.viewedStoryIds,
    );
  }
}

class StoryPlayerNotifier extends StateNotifier<StoryPlayerState> {
  final IStoryRepository _repository;
  final List<StoryUser> users;

  StoryPlayerNotifier(this._repository, this.users, int initialUserIndex,
      [int initialStoryIndex = 0])
      : super(StoryPlayerState(
            currentUserIndex: initialUserIndex,
            currentStoryIndex: initialStoryIndex));

  StoryUser get currentUser => users[state.currentUserIndex];
  Story get currentStory => currentUser.stories[state.currentStoryIndex];

  int get totalStoriesCount =>
      users.fold(0, (sum, user) => sum + user.stories.length);

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setPaused(bool paused) {
    state = state.copyWith(isPaused: paused);
  }

  Future<void> markCurrentAsViewed() async {
    final storyId = currentStory.id;
    if (!state.viewedStoryIds.contains(storyId)) {
      await _repository.trackView(storyId);
      state = state.copyWith(
        viewedStoryIds: {...state.viewedStoryIds, storyId},
      );
    }
  }

  bool nextStory() {
    if (state.currentStoryIndex < currentUser.stories.length - 1) {
      state = state.copyWith(
        currentStoryIndex: state.currentStoryIndex + 1,
        isLoading: true,
      );
      return true;
    } else if (state.currentUserIndex < users.length - 1) {
      state = state.copyWith(
        currentUserIndex: state.currentUserIndex + 1,
        currentStoryIndex: 0,
        isLoading: true,
      );
      return true;
    }
    return false; // پایان استوری‌ها
  }

  bool previousStory() {
    if (state.currentStoryIndex > 0) {
      state = state.copyWith(
        currentStoryIndex: state.currentStoryIndex - 1,
        isLoading: true,
      );
      return true;
    } else if (state.currentUserIndex > 0) {
      final prevUserIndex = state.currentUserIndex - 1;
      state = state.copyWith(
        currentUserIndex: prevUserIndex,
        currentStoryIndex: users[prevUserIndex].stories.length - 1,
        isLoading: true,
      );
      return true;
    }
    return false;
  }

  void goToUser(int userIndex) {
    if (userIndex >= 0 && userIndex < users.length) {
      state = state.copyWith(
        currentUserIndex: userIndex,
        currentStoryIndex: 0,
        isLoading: true,
      );
    }
  }

  Future<void> reactToStory(StoryReactionType reaction) async {
    await _repository.reactToStory(currentStory.id, reaction);
  }

  Future<void> replyToStory(String message) async {
    await _repository.replyToStory(currentStory.id, message);
  }
}

final storyPlayerProvider = StateNotifierProvider.autoDispose.family<
    StoryPlayerNotifier,
    StoryPlayerState,
    ({
      List<StoryUser> users,
      int initialIndex,
      int initialStoryIndex
    })>((ref, params) {
  final repository = ref.watch(storyRepositoryProvider);
  return StoryPlayerNotifier(
      repository, params.users, params.initialIndex, params.initialStoryIndex);
});

typedef StoryPollResultsArgs = ({String storyId, String elementId});

final storyPollResultsProvider = FutureProvider.autoDispose
    .family<StoryPollResult, StoryPollResultsArgs>((ref, args) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getPollResults(
    storyId: args.storyId,
    elementId: args.elementId,
  );

  return result.fold(
    (error) => throw Exception(error),
    (data) => data,
  );
});

final storyQuestionAnswersProvider = FutureProvider.autoDispose
    .family<List<StoryQuestionAnswer>, String>((ref, storyId) async {
  final repository = ref.watch(storyRepositoryProvider);
  final result = await repository.getStoryQuestionAnswers(storyId);

  return result.fold(
    (error) => throw Exception(error),
    (data) => data,
  );
});
