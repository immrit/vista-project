import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../chat/screens/modern_chat_screen.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/story_editor_models.dart' as editor_models;
import '../../domain/repositories/i_story_repository.dart';
import '../providers/story_providers.dart';
import '../../../../utils/const.dart';
import '../../../../utils/user_friendly_error_utils.dart';
import '../../../../widgets/verification_badge_icon.dart';

/// پنل insight استوری: بازدیدها / نظرسنجی‌ها / پاسخ‌های سوال
class StoryViewersSheet extends ConsumerWidget {
  final String storyId;
  final Story? story;
  final VoidCallback onClose;

  const StoryViewersSheet({
    super.key,
    required this.storyId,
    this.story,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewsAsync = ref.watch(storyViewsProvider(storyId));
    final questionAnswersAsync =
        ref.watch(storyQuestionAnswersProvider(storyId));
    final pollElements = _extractPollElements(story);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return DefaultTabController(
      length: 3,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.insights_rounded, color: textColor),
                      const SizedBox(width: 8),
                      Text(
                        'Insight استوری',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontFamily: 'Vazir',
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(Icons.close, color: textColor),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  indicatorColor: textColor,
                  labelColor: textColor,
                  unselectedLabelColor: textColor.withOpacity(0.6),
                  labelStyle: const TextStyle(
                    fontFamily: 'Vazir',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'بازدیدها'),
                    Tab(text: 'نظرسنجی‌ها'),
                    Tab(text: 'پاسخ‌های سوال'),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildViewsTab(
                        context,
                        ref,
                        viewsAsync,
                        scrollController,
                        textColor,
                      ),
                      _buildPollsTab(
                        context,
                        ref,
                        pollElements,
                        scrollController,
                        textColor,
                      ),
                      _buildQuestionAnswersTab(
                        context,
                        ref,
                        questionAnswersAsync,
                        scrollController,
                        textColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewsTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<StoryView>> viewsAsync,
    ScrollController scrollController,
    Color textColor,
  ) {
    return viewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(
        textColor: textColor,
        onRetry: () => ref.invalidate(storyViewsProvider(storyId)),
      ),
      data: (views) {
        if (views.isEmpty) {
          return _buildEmptyState(
            textColor: textColor,
            icon: Icons.visibility_off_outlined,
            message: 'هنوز کسی استوری شما را ندیده',
          );
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: views.length,
          itemBuilder: (context, index) {
            final view = views[index];
            return ListTile(
              onTap: () {
                onClose();
                Navigator.pushNamed(
                  context,
                  '/profile',
                  arguments: {
                    'userId': view.viewerId,
                    'username': view.viewerUsername ?? 'کاربر',
                  },
                );
              },
              leading: CircleAvatar(
                backgroundImage: view.viewerAvatarUrl != null
                    ? CachedNetworkImageProvider(view.viewerAvatarUrl!)
                    : const AssetImage(defaultAvatarUrl) as ImageProvider,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      view.viewerUsername ?? 'کاربر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFamily: 'Vazir',
                      ),
                    ),
                  ),
                  if (view.isVerified)
                    VerificationBadgeIcon(
                      isVerified: view.isVerified,
                      verificationType: view.verificationType,
                      role: view.role,
                      size: 16,
                    ),
                ],
              ),
              subtitle: Text(
                _getTimeAgo(view.viewedAt),
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 12,
                  fontFamily: 'Vazir',
                ),
              ),
              trailing: view.reaction != null
                  ? Text(
                      view.reaction!.emoji,
                      style: const TextStyle(fontSize: 20),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildPollsTab(
    BuildContext context,
    WidgetRef ref,
    List<StoryElement> pollElements,
    ScrollController scrollController,
    Color textColor,
  ) {
    if (pollElements.isEmpty) {
      return _buildEmptyState(
        textColor: textColor,
        icon: Icons.poll_outlined,
        message: 'نظرسنجی‌ای روی این استوری وجود ندارد',
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: pollElements.length,
      itemBuilder: (context, index) {
        final element = pollElements[index];
        final elementId = _resolveElementId(element);
        if (elementId == null) {
          return Card(
            color: Colors.white10,
            child: const ListTile(
              title: Text(
                'نظرسنجی قدیمی (بدون elementId)',
                style: TextStyle(color: Colors.white70, fontFamily: 'Vazir'),
              ),
            ),
          );
        }

        final pollAsync = ref.watch(
          storyPollResultsProvider((storyId: storyId, elementId: elementId)),
        );

        return pollAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => Card(
            color: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'خطا در دریافت نتایج نظرسنجی',
                style: TextStyle(color: textColor, fontFamily: 'Vazir'),
              ),
            ),
          ),
          data: (result) => Card(
            color: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.question,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Vazir',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${result.totalVotes} رای',
                    style: TextStyle(
                      color: textColor.withOpacity(0.65),
                      fontSize: 12,
                      fontFamily: 'Vazir',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...result.options.map((option) {
                    final ratio = (option.percentage / 100).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option.text,
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'Vazir',
                                  ),
                                ),
                              ),
                              Text(
                                '${option.percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.greenAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionAnswersTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<StoryQuestionAnswer>> answersAsync,
    ScrollController scrollController,
    Color textColor,
  ) {
    return answersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(
        textColor: textColor,
        onRetry: () => ref.invalidate(storyQuestionAnswersProvider(storyId)),
      ),
      data: (answers) {
        if (answers.isEmpty) {
          return _buildEmptyState(
            textColor: textColor,
            icon: Icons.question_answer_outlined,
            message: 'هنوز پاسخی برای سوال‌ها ثبت نشده',
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(10),
          itemCount: answers.length,
          itemBuilder: (context, index) {
            final answer = answers[index];
            return Card(
              color: Colors.white10,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: answer.respondentAvatarUrl != null
                      ? CachedNetworkImageProvider(answer.respondentAvatarUrl!)
                      : const AssetImage(defaultAvatarUrl) as ImageProvider,
                ),
                title: Text(
                  answer.respondentUsername,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      answer.answer,
                      style: TextStyle(color: textColor, fontFamily: 'Vazir'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeAgo(answer.createdAt),
                      style: TextStyle(
                        color: textColor.withOpacity(0.65),
                        fontSize: 11,
                        fontFamily: 'Vazir',
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: 'رفتن به چت',
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  color: textColor,
                  onPressed: () => _openChatWithRespondent(context, answer),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openChatWithRespondent(
    BuildContext context,
    StoryQuestionAnswer answer,
  ) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        UserFriendlyErrorUtils.showErrorSnackBar(
            context, 'ابتدا وارد حساب شوید');
        return;
      }
      if (answer.respondentId == currentUserId) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'نمی‌توانید با خودتان چت باز کنید',
        );
        return;
      }

      final conversationId = await supabase.rpc(
        'create_or_get_conversation',
        params: {
          'current_user_id': currentUserId,
          'target_user_id': answer.respondentId,
        },
      );

      if (!context.mounted) return;

      if (conversationId == null) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          'ایجاد مکالمه ممکن نشد',
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModernChatScreen(
            args: ChatScreenArgs(
              conversationId: conversationId.toString(),
              otherUserName: answer.respondentUsername,
              otherUserAvatar: answer.respondentAvatarUrl,
              otherUserId: answer.respondentId,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      UserFriendlyErrorUtils.showErrorSnackBar(context, e);
    }
  }

  List<StoryElement> _extractPollElements(Story? story) {
    final elements = story?.interactiveElements ?? const <StoryElement>[];
    return elements
        .where(
          (item) =>
              item.interactionType == editor_models.StoryInteractionType.poll,
        )
        .toList();
  }

  String? _resolveElementId(StoryElement element) {
    final direct = element.elementId?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final fromData = element.interactionData?['elementId']?.toString().trim() ??
        element.interactionData?['element_id']?.toString().trim() ??
        element.interactionData?['id']?.toString().trim();
    if (fromData != null && fromData.isNotEmpty) return fromData;
    return null;
  }

  Widget _buildErrorState({
    required Color textColor,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 44, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            'خطا در بارگذاری',
            style: TextStyle(color: textColor, fontFamily: 'Vazir'),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required Color textColor,
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: textColor.withOpacity(0.35)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.75),
              fontFamily: 'Vazir',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    return timeago.format(dateTime, locale: 'fa');
  }
}
