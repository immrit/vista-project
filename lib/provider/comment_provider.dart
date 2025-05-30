// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// // وضعیت‌های مختلف کامنت‌ها
// class CommentsState {
//   final List<CommentModel> comments;
//   final bool isLoading;
//   final String? error;
//   final bool hasMore;
//   final int currentPage;

//   const CommentsState({
//     this.comments = const [],
//     this.isLoading = false,
//     this.error,
//     this.hasMore = true,
//     this.currentPage = 0,
//   });

//   CommentsState copyWith({
//     List<CommentModel>? comments,
//     bool? isLoading,
//     String? error,
//     bool? hasMore,
//     int? currentPage,
//   }) {
//     return CommentsState(
//       comments: comments ?? this.comments,
//       isLoading: isLoading ?? this.isLoading,
//       error: error ?? this.error,
//       hasMore: hasMore ?? this.hasMore,
//       currentPage: currentPage ?? this.currentPage,
//     );
//   }
// }

// // ارائه‌دهنده مخزن کامنت‌ها
// final commentRepositoryProvider = Provider<CommentRepository>((ref) {
//   return CommentRepository(Supabase.instance.client);
// });

// // ارائه‌دهنده کامنت‌های یک پست
// final commentsProvider =
//     StateNotifierProvider.family<CommentsNotifier, CommentsState, String>(
//   (ref, postId) {
//     final repository = ref.watch(commentRepositoryProvider);
//     return CommentsNotifier(repository, postId);
//   },
// );

// class CommentsNotifier extends StateNotifier<CommentsState> {
//   final CommentRepository _repository;
//   final String _postId;
//   static const int _pageSize = 20;

//   CommentsNotifier(this._repository, this._postId)
//       : super(const CommentsState()) {
//     loadComments();
//   }

//   // بارگذاری کامنت‌ها
//   Future<void> loadComments({bool refresh = false}) async {
//     if (state.isLoading && !refresh) return;

//     if (refresh) {
//       state = state.copyWith(
//         isLoading: true,
//         error: null,
//         currentPage: 0,
//         hasMore: true,
//       );
//     } else {
//       state = state.copyWith(isLoading: true, error: null);
//     }

//     try {
//       final comments = await _repository.getComments(
//         postId: _postId,
//         page: refresh ? 0 : state.currentPage,
//         limit: _pageSize,
//       );

//       if (refresh) {
//         state = state.copyWith(
//           comments: comments,
//           isLoading: false,
//           hasMore: comments.length >= _pageSize,
//           currentPage: 1,
//         );
//       } else {
//         final allComments = [...state.comments, ...comments];
//         state = state.copyWith(
//           comments: allComments,
//           isLoading: false,
//           hasMore: comments.length >= _pageSize,
//           currentPage: state.currentPage + 1,
//         );
//       }
//     } catch (e) {
//       state = state.copyWith(
//         isLoading: false,
//         error: 'خطا در بارگذاری کامنت‌ها: ${e.toString()}',
//       );
//     }
//   }

//   // اضافه کردن کامنت جدید
//   Future<bool> addComment(String content, {String? parentCommentId}) async {
//     try {
//       final newComment = await _repository.addComment(
//         postId: _postId,
//         content: content,
//         parentCommentId: parentCommentId,
//       );

//       if (parentCommentId == null) {
//         // کامنت اصلی
//         state = state.copyWith(
//           comments: [newComment, ...state.comments],
//         );
//       } else {
//         // پاسخ به کامنت
//         final updatedComments = state.comments.map((comment) {
//           if (comment.id == parentCommentId) {
//             return comment.copyWith(
//               replies: [newComment, ...comment.replies],
//             );
//           }
//           return comment;
//         }).toList();

//         state = state.copyWith(comments: updatedComments);
//       }

//       return true;
//     } catch (e) {
//       state = state.copyWith(
//         error: 'خطا در ارسال کامنت: ${e.toString()}',
//       );
//       return false;
//     }
//   }

//   // حذف کامنت
//   Future<bool> deleteComment(String commentId,
//       {String? parentCommentId}) async {
//     try {
//       await _repository.deleteComment(commentId);

//       if (parentCommentId == null) {
//         // حذف کامنت اصلی
//         final updatedComments =
//             state.comments.where((comment) => comment.id != commentId).toList();
//         state = state.copyWith(comments: updatedComments);
//       } else {
//         // حذف پاسخ
//         final updatedComments = state.comments.map((comment) {
//           if (comment.id == parentCommentId) {
//             final updatedReplies = comment.replies
//                 .where((reply) => reply.id != commentId)
//                 .toList();
//             return comment.copyWith(replies: updatedReplies);
//           }
//           return comment;
//         }).toList();

//         state = state.copyWith(comments: updatedComments);
//       }

//       return true;
//     } catch (e) {
//       state = state.copyWith(
//         error: 'خطا در حذف کامنت: ${e.toString()}',
//       );
//       return false;
//     }
//   }

//   // بارگذاری پاسخ‌های یک کامنت
//   Future<void> loadReplies(String commentId) async {
//     try {
//       final replies = await _repository.getReplies(commentId);

//       final updatedComments = state.comments.map((comment) {
//         if (comment.id == commentId) {
//           return comment.copyWith(replies: replies);
//         }
//         return comment;
//       }).toList();

//       state = state.copyWith(comments: updatedComments);
//     } catch (e) {
//       state = state.copyWith(
//         error: 'خطا در بارگذاری پاسخ‌ها: ${e.toString()}',
//       );
//     }
//   }

//   // پاک کردن خطا
//   void clearError() {
//     state = state.copyWith(error: null);
//   }
// }
