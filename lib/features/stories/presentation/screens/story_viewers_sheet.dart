import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../providers/story_providers.dart';
import '../../domain/repositories/i_story_repository.dart';
import '../../../../utils/const.dart';

/// پنل بازدیدکنندگان استوری
class StoryViewersSheet extends ConsumerWidget {
  final String storyId;
  final VoidCallback onClose;

  const StoryViewersSheet({
    super.key,
    required this.storyId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewsAsync = ref.watch(storyViewsProvider(storyId));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // هندل
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // عنوان
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: textColor),
                    const SizedBox(width: 8),
                    Text(
                      'بازدیدکنندگان',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
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

              const Divider(),

              // لیست بازدیدکنندگان
              Expanded(
                child: viewsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('خطا در بارگذاری',
                            style: TextStyle(color: textColor)),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(storyViewsProvider(storyId)),
                          child: const Text('تلاش مجدد'),
                        ),
                      ],
                    ),
                  ),
                  data: (views) {
                    if (views.isEmpty) {
                      return _buildEmptyState(textColor);
                    }
                    return _buildViewersList(
                        context, views, scrollController, textColor);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 64,
            color: textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'هنوز کسی استوری شما را ندیده',
            style: TextStyle(
              fontSize: 16,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewersList(
    BuildContext context,
    List<StoryView> views,
    ScrollController scrollController,
    Color textColor,
  ) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: views.length,
      itemBuilder: (context, index) {
        final view = views[index];
        return _buildViewerTile(context, view, textColor);
      },
    );
  }

  Widget _buildViewerTile(
      BuildContext context, StoryView view, Color textColor) {
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
          Text(
            view.viewerUsername ?? 'کاربر',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          if (view.isVerified) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: Colors.blue, size: 16),
          ],
        ],
      ),
      subtitle: Text(
        _getTimeAgo(view.viewedAt),
        style: TextStyle(
          color: textColor.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: view.reaction != null
          ? Text(view.reaction!.emoji, style: const TextStyle(fontSize: 20))
          : null,
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    return timeago.format(dateTime, locale: 'fa');
  }
}
