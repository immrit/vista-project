// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:voice_message_package/voice_message_package.dart';
// import '../../../model/MusicModel.dart';
// import '../../../provider/MusicProvider.dart';

// class MusicPlayerScreen extends ConsumerStatefulWidget {
//   final MusicModel music;

//   const MusicPlayerScreen({super.key, required this.music});

//   @override
//   ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
// }

// class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen> {
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       extendBodyBehindAppBar: true,
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               theme.colorScheme.primary.withOpacity(0.8),
//               theme.colorScheme.surface,
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               // Album Art
//               Hero(
//                 tag: widget.music.id,
//                 child: Container(
//                   width: MediaQuery.of(context).size.width * 0.8,
//                   height: MediaQuery.of(context).size.width * 0.8,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.2),
//                         blurRadius: 20,
//                         offset: const Offset(0, 10),
//                       ),
//                     ],
//                   ),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(20),
//                     child: widget.music.coverUrl != null
//                         ? CachedNetworkImage(
//                             imageUrl: widget.music.coverUrl!,
//                             fit: BoxFit.cover,
//                             placeholder: (context, url) => const Center(
//                                 child: CircularProgressIndicator()),
//                           )
//                         : Container(
//                             color: theme.colorScheme.primaryContainer,
//                             child: const Icon(Icons.music_note, size: 80),
//                           ),
//                   ),
//                 ),
//               ),

//               // Song Info
//               Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   children: [
//                     Text(
//                       widget.music.title,
//                       style: theme.textTheme.headlineSmall?.copyWith(
//                         fontWeight: FontWeight.bold,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(
//                           widget.music.artist,
//                           style: theme.textTheme.titleMedium?.copyWith(
//                             color: theme.textTheme.bodySmall?.color,
//                           ),
//                         ),
//                         if (widget.music.isVerified) ...[
//                           const SizedBox(width: 4),
//                           Icon(Icons.verified,
//                               color: theme.colorScheme.primary, size: 16),
//                         ],
//                       ],
//                     ),
//                   ],
//                 ),
//               ),

//               // Voice Message Player
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: VoiceMessageView(
//                   audioSrc: widget.music.musicUrl,
//                   played: false,
//                   me: false,
//                   meBgColor: theme.colorScheme.primary,
//                   mePlayIconColor: theme.colorScheme.onPrimary,
//                   contactBgColor: theme.colorScheme.surface,
//                   contactFgColor: theme.colorScheme.onSurface,
//                   contactPlayIconColor: theme.colorScheme.primary,
//                   duration: ref.watch(musicPlayerProvider.notifier).duration ??
//                       const Duration(seconds: 0),
//                   onPlay: () {
//                     ref.read(musicPlayerProvider.notifier).togglePlayPause();
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
