import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/chat/widgets/voice_message_bubble.dart';
import '../../../features/music/screens/MusicDownloadManager.dart';

class PostMusicBubble extends ConsumerWidget {
  final String postId;
  final String musicUrl;
  final DateTime createdAt;
  final String? title;
  final String? artist;
  final String? avatarUrl;
  final EdgeInsetsGeometry margin;

  const PostMusicBubble({
    super.key,
    required this.postId,
    required this.musicUrl,
    required this.createdAt,
    this.title,
    this.artist,
    this.avatarUrl,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedUrl = musicUrl.trim();
    if (normalizedUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final resolvedTitle = _resolveTrackTitle(title, normalizedUrl);
    final resolvedArtist = _resolveTrackArtist(artist, resolvedTitle);

    final downloadInfo = ref.watch(
      musicDownloadManagerProvider.select((state) => state[normalizedUrl]),
    );
    final localPath = downloadInfo?.localPath;

    return Container(
      margin: margin,
      alignment: Alignment.centerLeft,
      child: VoiceMessageBubble(
        messageId: 'post_audio_$postId',
        audioUrl: normalizedUrl,
        localFilePath: localPath,
        durationSeconds: null,
        isMe: false,
        time: createdAt,
        senderName: artist,
        senderAvatarUrl: avatarUrl,
        attachmentType: 'audio',
        audioTitle: resolvedTitle,
        audioArtist: resolvedArtist,
      ),
    );
  }

  String _resolveTrackTitle(String? maybeTitle, String url) {
    final direct = maybeTitle?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final uri = Uri.tryParse(url);
    final lastSegment = (uri?.pathSegments.isNotEmpty ?? false)
        ? uri!.pathSegments.last
        : url.split('/').last;

    final withoutExtension = lastSegment.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final normalized = withoutExtension
        .replaceFirst(RegExp(r'^[^_]+_[0-9]+_'), '')
        .replaceAll('_', ' ')
        .trim();

    return normalized.isEmpty ? 'Music' : normalized;
  }

  String? _resolveTrackArtist(String? maybeArtist, String resolvedTitle) {
    final direct = maybeArtist?.trim();
    if (direct == null || direct.isEmpty) return null;
    if (_deriveArtistFromTrackText(resolvedTitle) != null) return null;
    return direct;
  }

  String? _deriveArtistFromTrackText(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    final separators = <String>[' - ', ' | ', ' / ', '_'];
    for (final sep in separators) {
      final idx = normalized.indexOf(sep);
      if (idx > 0) {
        final candidate = normalized.substring(0, idx).trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return null;
  }
}
