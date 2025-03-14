import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../model/MusicModel.dart';
import '../../../provider/MusicProvider.dart';
import 'AddMusicScreen.dart';

class MusicListScreen extends ConsumerStatefulWidget {
  const MusicListScreen({super.key});

  @override
  ConsumerState<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends ConsumerState<MusicListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      ref.read(musicListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicState = ref.watch(musicListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('موزیک‌ها'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddMusicScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(musicListProvider.notifier).refresh();
        },
        child: musicState.when(
          data: (musics) => ListView.builder(
            controller: _scrollController,
            itemCount: musics.length + (musicState.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == musics.length) {
                return const Center(child: CircularProgressIndicator());
              }

              final music = musics[index];
              return _buildMusicCard(music);
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('خطا در بارگیری موزیک‌ها: $error'),
          ),
        ),
      ),
      bottomSheet: ref.watch(currentlyPlayingProvider).whenData((music) {
            if (music == null) return const SizedBox.shrink();
            return _buildMiniPlayer(music);
          }).value ??
          const SizedBox.shrink(),
    );
  }

  Widget _buildMusicCard(MusicModel music) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: () {
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => MusicPlayerScreen(music: music),
          //   ),
          // );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: music.coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: music.coverUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[300],
                  child: const Icon(Icons.music_note),
                ),
        ),
        title: Text(music.title),
        subtitle: Text(music.artist),
        trailing: Text('${music.playCount} پخش'),
      ),
    );
  }

  Widget _buildMiniPlayer(MusicModel music) {
    final isPlaying = ref.watch(isPlayingProvider);

    return GestureDetector(
      onTap: () {
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => MusicPlayerScreen(music: music),
        //   ),
        // );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            if (music.coverUrl != null)
              CachedNetworkImage(
                imageUrl: music.coverUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      music.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      music.artist,
                      style: TextStyle(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                ref.read(musicPlayerProvider.notifier).togglePlayPause();
              },
            ),
          ],
        ),
      ),
    );
  }
}
