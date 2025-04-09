import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/MusicModel.dart';
import '../../../provider/MusicProvider.dart';

class MiniMusicPlayer extends ConsumerStatefulWidget {
  const MiniMusicPlayer({Key? key}) : super(key: key);

  @override
  ConsumerState<MiniMusicPlayer> createState() => _MiniMusicPlayerState();
}

class _MiniMusicPlayerState extends ConsumerState<MiniMusicPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // شروع از پایین صفحه
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // استفاده از .valueOrNull برای جلوگیری از خطاهای احتمالی
    final currentlyPlaying = ref.watch(currentlyPlayingProvider).valueOrNull;
    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(musicPositionProvider);
    final duration = ref.watch(musicDurationProvider);

    // اگر موسیقی در حال پخش نباشد، مینی پلیر را مخفی کن
    if (currentlyPlaying == null) {
      // به صورت ایمن انیمیشن را معکوس کن
      if (_animationController.isCompleted) {
        _animationController.reverse();
      }
      return const SizedBox.shrink();
    } else {
      // به صورت ایمن انیمیشن را اجرا کن
      if (!_animationController.isCompleted) {
        _animationController.forward();
      }
    }

    final progress =
        position != null && duration != null && duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _offsetAnimation,
      child: Material(
        elevation: 8,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // نوار پیشرفت
              LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
                minHeight: 2,
              ),

              // محتوای اصلی پلیر
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      // تصویر موسیقی
                      Hero(
                        tag: 'music_${currentlyPlaying.id}',
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200],
                          ),
                          child: currentlyPlaying.avatarUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: currentlyPlaying.avatarUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.music_note, size: 24),
                                  ),
                                )
                              : const Icon(Icons.music_note, size: 24),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // اطلاعات موسیقی
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentlyPlaying.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              currentlyPlaying.artist,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // دکمه‌های کنترل
                      Row(
                        children: [
                          // دکمه پخش/توقف
                          IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 32,
                              // color: Theme.of(context).primaryColor,
                            ),
                            onPressed: () {
                              // برای اطمینان از وجود متد togglePlayPause
                              try {
                                ref
                                    .read(musicPlayerProvider.notifier)
                                    .togglePlayPause();
                              } catch (e) {
                                debugPrint("خطا در togglePlayPause: $e");
                              }
                            },
                          ),

                          // دکمه بستن
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              // برای اطمینان از وجود متد stop
                              try {
                                ref.read(musicPlayerProvider.notifier).stop();
                              } catch (e) {
                                debugPrint("خطا در stop: $e");
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
