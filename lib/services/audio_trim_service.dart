import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../security/logging_utility.dart';

/// Cuts [source] down to the [start]..[end] range and re-encodes it as AAC
/// (.m4a) so every input format (mp3/wav/ogg/flac/wma) lands on one
/// predictable, small output codec regardless of what the user picked.
class AudioTrimService {
  static Future<File> trim({
    required File source,
    required Duration start,
    required Duration end,
  }) async {
    final clipDuration = end - start;
    if (clipDuration <= Duration.zero) {
      throw Exception('بازه انتخابی برش موزیک نامعتبر است');
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/trimmed_music_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final startSeconds = start.inMilliseconds / 1000;
    final durationSeconds = clipDuration.inMilliseconds / 1000;

    // -ss before -i = fast seek; re-encoding (not -c copy) keeps the cut
    // sample-accurate regardless of the source codec's keyframe spacing.
    final command = '-y -ss $startSeconds -i "${source.path}" '
        '-t $durationSeconds -vn -acodec aac -b:a 128k "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      logError('AudioTrimService: ffmpeg failed: $logs');
      throw Exception('برش موزیک با خطا مواجه شد');
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw Exception('فایل برش‌خورده موزیک ساخته نشد');
    }
    return outputFile;
  }
}
