import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/CommentModel.dart';
import '../services/comment_repository.dart';

// وضعیت‌های مختلف کامنت‌ها
class CommentsState {
  final List<CommentModel> comments;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isAddingComment;
  final bool isDeletingComment;
  final bool isUpdatingComment;
  final Map<String, bool> loadingReplies;

  const CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isAddingComment = false,
    this.isDeletingComment = false,
    this.isUpdatingComment = false,
    this.loadingReplies = const {},
  });

  CommentsState copyWith({
    List<CommentModel>? comments,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isAddingComment,
    bool? isDeletingComment,
    bool? isUpdatingComment,
    Map<String, bool>? loadingReplies,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isAddingComment: isAddingComment ?? this.isAddingComment,
      isDeletingComment: isDeletingComment ?? this.isDeletingComment,
      isUpdatingComment: isUpdatingComment ?? this.isUpdatingComment,
      loadingReplies: loadingReplies ?? this.loadingReplies,
    );
  }
}

// وضعیت ویرایش کامنت
class CommentEditState {
  final String? editingCommentId;
  final String editingContent;
  final bool isEditing;

  const CommentEditState({
    this.editingCommentId,
    this.editingContent = '',
    this.isEditing = false,
  });

  CommentEditState copyWith({
    String? editingCommentId,
    String? editingContent,
    bool? isEditing,
  }) {
    return CommentEditState(
      editingCommentId: editingCommentId ?? this.editingCommentId,
      editingContent: editingContent ?? this.editingContent,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

// ارائه‌دهنده مخزن کامنت‌ها
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository(Supabase.instance.client);
});

// ارائه‌دهنده کامنت‌های یک پست
final commentsProvider =
    StateNotifierProvider.family<CommentsNotifier, CommentsState, String>(
  (ref, postId) {
    final repository = ref.watch(commentRepositoryProvider);
    return CommentsNotifier(repository, postId);
  },
);

// ارائه‌دهنده تعداد کامنت‌ها
final commentsCountProvider =
    FutureProvider.family<int, String>((ref, postId) async {
  final repository = ref.watch(commentRepositoryProvider);
  return await repository.getCommentsCount(postId);
});

// ارائه‌دهنده آخرین کامنت‌ها
final latestCommentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final repository = ref.watch(commentRepositoryProvider);
  return await repository.getLatestComments(postId, limit: 3);
});

// ارائه‌دهنده کامنت‌های پین شده
final pinnedCommentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final repository = ref.watch(commentRepositoryProvider);
  return await repository.getPinnedComments(postId);
});

// ارائه‌دهنده کامنت‌های تو در تو
final nestedCommentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final repository = ref.watch(commentRepositoryProvider);
  return await repository.getNestedComments(postId);
});

// ارائه‌دهنده وضعیت ویرایش کامنت
final commentEditStateProvider =
    StateNotifierProvider<CommentEditNotifier, CommentEditState>((ref) {
  return CommentEditNotifier();
});

class CommentEditNotifier extends StateNotifier<CommentEditState> {
  CommentEditNotifier() : super(const CommentEditState());

  void startEditing(String commentId, String content) {
    state = state.copyWith(
      editingCommentId: commentId,
      editingContent: content,
      isEditing: true,
    );
  }

  void updateContent(String content) {
    state = state.copyWith(editingContent: content);
  }

  void cancelEditing() {
    state = const CommentEditState();
  }

  void finishEditing() {
    state = const CommentEditState();
  }
}

class CommentsNotifier extends StateNotifier<CommentsState> {
  final CommentRepository _repository;
  final String _postId;
  static const int _pageSize = 20;

  CommentsNotifier(this._repository, this._postId)
      : super(const CommentsState()) {
    loadComments();
  }

  Future<CommentModel?> addReply({
    required String postId,
    required String content,
    required String parentCommentId, // می‌تواند کامنت اصلی یا ریپلای باشد
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final newReply = await _repository.addComment(
        postId: postId,
        content: content,
        parentCommentId: parentCommentId,
      );

      // پیدا کردن کامنت والد و اضافه کردن ریپلای جدید
      final updatedComments = _addReplyToCommentTree(state.comments, newReply);

      state = state.copyWith(
        comments: updatedComments,
        isLoading: false,
      );

      return newReply;
    } catch (e) {
      state = state.copyWith(
        error: 'مشکلی در ارسال پاسخ پیش آمد. لطفا دوباره تلاش کنید.',
        isLoading: false,
      );
      return null;
    }
  }

  // متد کمکی برای اضافه کردن ریپلای به درخت کامنت‌ها (recursive)
  List<CommentModel> _addReplyToCommentTree(
    List<CommentModel> comments,
    CommentModel newReply,
  ) {
    return comments.map((comment) {
      // اگر این کامنت والد ریپلای جدید است
      if (comment.id == newReply.parentCommentId) {
        // Add new reply to the beginning to keep newest first, assuming newReply is the newest
        final updatedReplies = [newReply, ...comment.replies];
        return comment.copyWith(replies: updatedReplies);
      }

      // اگر ریپلای در زیرمجموعه‌های این کامنت است (جستجوی recursive)
      final updatedReplies = _addReplyToCommentTree(comment.replies, newReply);
      if (updatedReplies != comment.replies) {
        return comment.copyWith(replies: updatedReplies);
      }

      return comment;
    }).toList();
  }

  // متد برای بارگذاری ریپلای‌های یک کامنت خاص
  Future<void> loadRepliesForComment(String commentId) async {
    try {
      // تنظیم loading state برای این کامنت
      final loadingStates = Map<String, bool>.from(state.loadingReplies);
      loadingStates[commentId] = true;
      state = state.copyWith(loadingReplies: loadingStates);

      // دریافت ریپلای‌ها
      final replies = await _repository.getReplies(commentId);

      // به‌روزرسانی کامنت با ریپلای‌های جدید
      final updatedComments =
          _updateCommentReplies(state.comments, commentId, replies);

      // حذف loading state
      loadingStates.remove(commentId);

      state = state.copyWith(
        comments: updatedComments,
        loadingReplies: loadingStates,
      );
    } catch (e) {
      final loadingStates = Map<String, bool>.from(state.loadingReplies);
      loadingStates.remove(commentId);

      state = state.copyWith(
        error: 'مشکلی در بارگذاری پاسخ‌ها پیش آمد. لطفا دوباره تلاش کنید.',
        loadingReplies: loadingStates,
      );
    }
  }

  // متد کمکی برای به‌روزرسانی ریپلای‌های یک کامنت (recursive)
  List<CommentModel> _updateCommentReplies(
    List<CommentModel> comments,
    String commentId,
    List<CommentModel> newReplies,
  ) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return comment.copyWith(replies: newReplies);
      }

      // جستجوی recursive در ریپلای‌ها
      final updatedReplies =
          _updateCommentReplies(comment.replies, commentId, newReplies);
      if (updatedReplies != comment.replies) {
        return comment.copyWith(replies: updatedReplies);
      }

      return comment;
    }).toList();
  }

  // متد برای پیدا کردن کامنت یا ریپلای با ID (recursive)
  CommentModel? findCommentById(String commentId,
      [List<CommentModel>? searchList]) {
    final comments = searchList ?? state.comments;

    for (final comment in comments) {
      if (comment.id == commentId) {
        return comment;
      }

      // جستجو در ریپلای‌ها
      final foundInReplies = findCommentById(commentId, comment.replies);
      if (foundInReplies != null) {
        return foundInReplies;
      }
    }
    return null;
  }

  // متد برای دریافت path یک کامنت (برای نمایش thread)
  List<String> getCommentPath(String commentId) {
    final comment = findCommentById(commentId);
    if (comment == null) return [];

    final path = <String>[commentId];
    String? currentParentId = comment.parentCommentId;

    while (currentParentId != null) {
      path.insert(0, currentParentId);
      final parentComment = findCommentById(currentParentId);
      currentParentId = parentComment?.parentCommentId;
    }

    return path;
  }

  // بارگذاری کامنت‌ها
  Future<void> loadComments({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    if (state.isLoadingMore && !refresh) return;

    if (refresh) {
      state = state.copyWith(
        isRefreshing: true,
        error: null,
        currentPage: 0,
        hasMore: true,
      );
    } else {
      if (!state.hasMore) return;
      if (state.currentPage == 0) {
        state = state.copyWith(isLoading: true, error: null);
      } else {
        state = state.copyWith(isLoadingMore: true, error: null);
      }
    }

    try {
      // دریافت همه کامنت‌ها (flat)
      final allComments = await _repository.getCommentsWithReplies(
        postId: _postId,
        page: refresh ? 0 : state.currentPage,
        limit: _pageSize,
      );

      // ساختاردهی درختی
      final tree = buildCommentTree(allComments);

      if (refresh) {
        state = state.copyWith(
          comments: tree,
          isLoading: false,
          isRefreshing: false,
          hasMore: false, // چون همه کامنت‌ها را گرفتیم
          currentPage: 1,
        );
      } else {
        // اگر صفحه‌بندی داری، باید به درستی اضافه کنی
        state = state.copyWith(
          comments: [...state.comments, ...tree],
          isLoading: false,
          isLoadingMore: false,
          hasMore: false,
          currentPage: state.currentPage + 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: 'مشکلی در بارگذاری کامنت‌ها پیش آمد. لطفا دوباره تلاش کنید.',
      );
    }
  }

  // ساخت درخت کامنت‌ها
  List<CommentModel> buildCommentTree(List<CommentModel> allComments) {
    final Map<String, CommentModel> commentMap = {
      for (var comment in allComments) comment.id: comment.copyWith(replies: [])
    };

    final List<CommentModel> rootComments = [];

    for (var comment in allComments) {
      if (comment.parentCommentId == null) {
        rootComments.add(commentMap[comment.id]!);
      } else {
        final parent = commentMap[comment.parentCommentId];
        if (parent != null) {
          parent.replies.add(commentMap[comment.id]!);
        }
      }
    }

    // مرتب‌سازی والدها و ریپلای‌ها بر اساس تاریخ
    void sortReplies(List<CommentModel> comments) {
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (var comment in comments) {
        sortReplies(comment.replies);
      }
    }

    sortReplies(rootComments);

    return rootComments;
  }

  // بارگذاری کامنت‌های تو در تو
  Future<void> loadNestedComments() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final comments = await _repository.getNestedComments(_postId);
      state = state.copyWith(
        comments: comments,
        isLoading: false,
        hasMore: false,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'مشکلی در بارگذاری کامنت‌ها پیش آمد. لطفا دوباره تلاش کنید.',
      );
    }
  }

  // اضافه کردن کامنت جدید
  Future<bool> addComment(String content, {String? parentCommentId}) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isAddingComment: true, error: null);

    try {
      final newComment = await _repository.addComment(
        postId: _postId,
        content: content.trim(),
        parentCommentId: parentCommentId,
      );

      if (parentCommentId == null) {
        state = state.copyWith(
          comments: [newComment, ...state.comments],
          isAddingComment: false,
        );
      } else {
        final updatedComments =
            _addReplyToCommentTree(state.comments, newComment);
        state = state.copyWith(
          comments: updatedComments,
          isAddingComment: false,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isAddingComment: false, // Ensure state is reset on failure
        error: 'مشکلی در ارسال کامنت پیش آمد. لطفا دوباره تلاش کنید.',
      );
      return false;
    }
  }

  // حذف کامنت
  Future<bool> deleteComment(String commentId,
      {String? parentCommentId}) async {
    state = state.copyWith(isDeletingComment: true, error: null);

    try {
      await _repository.deleteComment(commentId);

      if (parentCommentId == null) {
        // حذف کامنت اصلی
        final updatedComments =
            state.comments.where((comment) => comment.id != commentId).toList();
        state = state.copyWith(
          comments: updatedComments,
          isDeletingComment: false,
        );
      } else {
        // حذف پاسخ
        final updatedComments = state.comments.map((comment) {
          if (comment.id == parentCommentId) {
            final updatedReplies = comment.replies
                .where((reply) => reply.id != commentId)
                .toList();
            return comment.copyWith(replies: updatedReplies);
          }
          return comment;
        }).toList();

        state = state.copyWith(
          comments: updatedComments,
          isDeletingComment: false,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isDeletingComment: false,
        error: 'مشکلی در حذف کامنت پیش آمد. لطفا دوباره تلاش کنید.',
      );
      return false;
    }
  }

  // ویرایش کامنت
  Future<bool> updateComment(String commentId, String newContent,
      {String? parentCommentId}) async {
    if (newContent.trim().isEmpty) return false;

    state = state.copyWith(isUpdatingComment: true, error: null);

    try {
      // پیدا کردن کامنتی که قرار است ویرایش شود
      final commentToUpdate = findCommentById(commentId);
      if (commentToUpdate == null) {
        state =
            state.copyWith(isUpdatingComment: false, error: 'کامنت پیدا نشد');
        return false;
      }

      // بررسی اینکه آیا کاربر لاگین شده، صاحب کامنت است
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      if (supabaseUser == null) {
        state = state.copyWith(
            isUpdatingComment: false, error: 'کاربر وارد نشده است');
        return false;
      }
      if (commentToUpdate.userId != supabaseUser.id) {
        state = state.copyWith(
            isUpdatingComment: false,
            error: 'شما اجازه ویرایش این کامنت را ندارید');
        return false;
      }

      // بررسی دسترسی ویرایش بر اساس اطلاعات پروفایل نویسنده کامنت (که در CommentModel موجود است)
      final hasEditAccess = commentToUpdate.isVerified ||
          commentToUpdate.verificationType == VerificationType.blackTick ||
          commentToUpdate.verificationType == VerificationType.goldTick ||
          commentToUpdate.verificationType == VerificationType.blueTick;

      if (!hasEditAccess) {
        state = state.copyWith(
          isUpdatingComment: false,
          error: 'برای ویرایش کامنت، حساب شما باید تایید شده باشد.',
        );
        return false;
      }

      final updatedComment = await _repository.updateComment(
        commentId: commentId,
        content: newContent.trim(),
      );

      if (parentCommentId == null) {
        // ویرایش کامنت اصلی
        final updatedComments = state.comments.map((comment) {
          if (comment.id == commentId) {
            return updatedComment;
          }
          return comment;
        }).toList();

        state = state.copyWith(
          comments: updatedComments,
          isUpdatingComment: false,
        );
      } else {
        // ویرایش پاسخ
        final updatedComments = state.comments.map((comment) {
          if (comment.id == parentCommentId) {
            final updatedReplies = comment.replies.map((reply) {
              if (reply.id == commentId) {
                return updatedComment;
              }
              return reply;
            }).toList();
            return comment.copyWith(replies: updatedReplies);
          }
          return comment;
        }).toList();

        state = state.copyWith(
          comments: updatedComments,
          isUpdatingComment: false,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdatingComment: false,
        error: 'مشکلی در ویرایش کامنت پیش آمد. لطفا دوباره تلاش کنید.',
      );
      return false;
    }
  }

  // بارگذاری پاسخ‌های یک کامنت
  Future<void> loadReplies(String commentId) async {
    final currentLoadingReplies = Map<String, bool>.from(state.loadingReplies);
    currentLoadingReplies[commentId] = true;

    state = state.copyWith(
      loadingReplies: currentLoadingReplies,
      error: null,
    );

    try {
      final replies = await _repository.getReplies(commentId);

      final updatedComments = state.comments.map((comment) {
        if (comment.id == commentId) {
          // ساخت یک آرایه جدید از پاسخ‌ها به جای تغییر مستقیم آرایه موجود
          List<CommentModel> updatedReplies = List.from(replies);
          return comment.copyWith(replies: updatedReplies);
        }
        return comment;
      }).toList();

      final updatedLoadingReplies =
          Map<String, bool>.from(state.loadingReplies);
      updatedLoadingReplies.remove(commentId);

      state = state.copyWith(
        comments: updatedComments,
        loadingReplies: updatedLoadingReplies,
      );
    } catch (e) {
      print('Error loading replies: $e');
      final updatedLoadingReplies =
          Map<String, bool>.from(state.loadingReplies);
      updatedLoadingReplies.remove(commentId);

      state = state.copyWith(
        loadingReplies: updatedLoadingReplies,
        error: 'مشکلی در بارگذاری پاسخ‌ها پیش آمد. لطفا دوباره تلاش کنید.',
      );
    }
  }

  // جستجو در کامنت‌ها
  Future<void> searchComments(String query) async {
    if (query.trim().isEmpty) {
      await loadComments(refresh: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final searchResults = await _repository.searchComments(
        postId: _postId,
        query: query.trim(),
      );

      state = state.copyWith(
        comments: searchResults,
        isLoading: false,
        hasMore: false,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'مشکلی در جستجو پیش آمد. لطفا دوباره تلاش کنید.',
      );
    }
  }

  // پین کامنت
  Future<bool> pinComment(String commentId, bool isPinned) async {
    try {
      final success = await _repository.pinComment(commentId, isPinned);
      if (success) {
        final updatedComments = state.comments.map((comment) {
          if (comment.id == commentId) {
            // اگر فیلد isPinned در مدل موجود باشد
            // return comment.copyWith(isPinned: isPinned);
            return comment; // فعلاً بدون تغییر
          }
          return comment;
        }).toList();

        state = state.copyWith(comments: updatedComments, error: null);
      }
      return success;
    } catch (e) {
      state = state.copyWith(
        error: 'مشکلی در پین کردن کامنت پیش آمد. لطفا دوباره تلاش کنید.',
      );
      return false;
    }
  }

  // دریافت کامنت‌ها بر اساس تاریخ
  Future<void> loadCommentsByDateRange(
      DateTime startDate, DateTime endDate) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final comments = await _repository.getCommentsByDateRange(
        postId: _postId,
        startDate: startDate,
        endDate: endDate,
      );

      state = state.copyWith(
        comments: comments,
        isLoading: false,
        hasMore: false,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:
            'مشکلی در بارگذاری کامنت‌ها بر اساس تاریخ پیش آمد. لطفا دوباره تلاش کنید.',
      );
    }
  }

  // پاک کردن خطا
  void clearError() {
    state = state.copyWith(error: null);
  }

  // بازنشانی state
  void reset() {
    state = const CommentsState();
    loadComments();
  }

  // دریافت کامنت خاص
  CommentModel? getCommentById(String commentId) {
    for (final comment in state.comments) {
      if (comment.id == commentId) {
        return comment;
      }

      // جستجو در پاسخ‌ها
      for (final reply in comment.replies) {
        if (reply.id == commentId) {
          return reply;
        }
      }
    }
    return null;
  }

  // تبدیل کامنت به thread
  Future<List<CommentModel>> getCommentThread(String commentId) async {
    try {
      return await _repository.getCommentThread(commentId);
    } catch (e) {
      state = state.copyWith(
        error: 'مشکلی در دریافت اطلاعات کامنت پیش آمد. لطفا دوباره تلاش کنید.',
      );
      return [];
    }
  }

  // بارگذاری صفحه بعدی
  Future<void> loadMoreComments() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    await loadComments();
  }

  // رفرش کامنت‌ها
  Future<void> refreshComments() async {
    await loadComments(refresh: true);
  }

  // رفرش کامنت‌های تو در تو
  Future<void> refreshNestedComments() async {
    await loadNestedComments();
  }

  // دریافت آمار کامنت‌ها
  int get totalComments => state.comments.length;
  int get totalReplies =>
      state.comments.fold(0, (sum, comment) => sum + comment.replies.length);

  // بررسی اینکه آیا کاربر فعلی صاحب کامنت است
  bool isOwner(CommentModel comment) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null && comment.userId == currentUserId;
  }

  // دریافت کامنت‌های کاربر فعلی
  List<CommentModel> get myComments {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    final userComments = <CommentModel>[];

    for (final comment in state.comments) {
      if (comment.userId == currentUserId) {
        userComments.add(comment);
      }

      // جستجو در پاسخ‌ها
      for (final reply in comment.replies) {
        if (reply.userId == currentUserId) {
          userComments.add(reply);
        }
      }
    }

    return userComments;
  }

  // بررسی وضعیت بارگذاری پاسخ‌ها
  bool isLoadingReplies(String commentId) {
    return state.loadingReplies[commentId] ?? false;
  }

  // دریافت تعداد پاسخ‌های یک کامنت
  int getRepliesCount(String commentId) {
    final comment = getCommentById(commentId);
    return comment?.replies.length ?? 0;
  }

  // بررسی اینکه آیا کامنت پاسخ‌هایی دارد یا نه
  bool hasReplies(String commentId) {
    return getRepliesCount(commentId) > 0;
  }

  // سورت کردن کامنت‌ها
  void sortComments({required bool ascending}) {
    final sortedComments = [...state.comments];
    sortedComments.sort((a, b) {
      return ascending
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt);
    });

    state = state.copyWith(comments: sortedComments);
  }

  // فیلتر کردن کامنت‌ها بر اساس کاربر
  void filterByUser(String userId) {
    final filteredComments = state.comments.where((comment) {
      return comment.userId == userId ||
          comment.replies.any((reply) => reply.userId == userId);
    }).toList();

    state = state.copyWith(comments: filteredComments, hasMore: false);
  }

  // حذف فیلتر و بازگشت به حالت عادی
  Future<void> clearFilter() async {
    await loadComments(refresh: true);
  }
}
