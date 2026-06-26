import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../model/publicPostModel.dart';
import '../../utils/avatar_asset_utils.dart';
import '../../services/vista_story_image_preloader.dart';
import 'verification_badge_icon.dart';
import 'vista_story_share_theme.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// ویجت قالب استوری Vista — طراحی شبیه X / Threads
class VistaStoryTemplateWidget extends StatelessWidget {
  final PublicPostModel post;
  final String? customBackgroundText;
  final Color? backgroundColor;
  final Color? textColor;
  final String? customPostText;
  final String? customImageUrl;
  final GlobalKey? repaintBoundaryKey;
  final VistaStoryShareTheme theme;
  final Uint8List? avatarBytes;
  final Uint8List? postImageBytes;
  final Uint8List? videoThumbnailBytes;

  const VistaStoryTemplateWidget({
    super.key,
    required this.post,
    this.customBackgroundText,
    this.backgroundColor,
    this.textColor,
    this.customPostText,
    this.customImageUrl,
    this.repaintBoundaryKey,
    this.theme = VistaStoryShareTheme.dark,
    this.avatarBytes,
    this.postImageBytes,
    this.videoThumbnailBytes,
  });

  static const _cardWidth = 860.0;
  static const _cardRadius = 28.0;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: SizedBox(
        width: 1080,
        height: 1920,
        child: Stack(
          children: [
            _buildBackground(),
            Align(
              alignment: const Alignment(0, -0.08),
              child: _buildPostCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return CustomPaint(
      size: const Size(1080, 1920),
      painter: VistaStoryBackgroundPainter(theme: theme),
    );
  }

  Widget _buildPostCard() {
    final displayText = customPostText ?? post.content;
    final imageUrl = customImageUrl ?? post.imageUrl ?? '';
    final isRtl = _isPersianText(displayText);
    final hasImage = post.hasImage || postImageBytes != null;
    final hasVideo = post.hasVideo && !hasImage;
    final hasMusic = post.hasMusic;
    final hasMedia = hasImage || hasVideo;
    final cardShadowColor = switch (theme) {
      VistaStoryShareTheme.dark => Colors.black.withValues(alpha: 0.45),
      VistaStoryShareTheme.light => Colors.black.withValues(alpha: 0.16),
      VistaStoryShareTheme.vista => Colors.black.withValues(alpha: 0.14),
    };

    return Container(
      width: _cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 80,
            offset: const Offset(0, 32),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 32, 36, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBrandMark(),
                const SizedBox(height: 28),
                _buildAuthorRow(displayText: displayText),
                if (displayText.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildPostContent(displayText, isRtl: isRtl),
                ],
                if (hasMusic) ...[
                  const SizedBox(height: 24),
                  _buildMusicSection(isRtl: isRtl),
                ],
              ],
            ),
          ),
          if (hasImage) ...[
            const SizedBox(height: 28),
            _buildPostImage(imageUrl),
          ] else if (hasVideo) ...[
            const SizedBox(height: 28),
            _buildVideoSection(),
          ],
          _buildPostFooter(isRtl: isRtl, compact: hasMedia || hasMusic),
          _buildBrandFooter(),
        ],
      ),
    );
  }

  Widget _buildBrandMark() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'lib/utils/images/logo/black-logo.png',
        width: 36,
        height: 36,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.bolt_rounded,
          color: Colors.black,
          size: 32,
        ),
      ),
    );
  }

  StoryPostAuthor get _author => StoryPostAuthor.fromPost(post);

  bool _isRtlLayout(String text) {
    return _isPersianText(text);
  }

  Widget _buildAuthorRow({required String displayText}) {
    final author = _author;
    final isRtl = _isRtlLayout('$displayText ${author.username} ${author.fullName}');

    return Align(
      alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(author: author),
          const SizedBox(width: 20),
          _buildAuthorInfo(author: author, isRtl: isRtl),
        ],
      ),
    );
  }

  Widget _buildAvatar({required StoryPostAuthor author}) {
    const radius = 34.0;
    const size = radius * 2;
    final avatarUrl = author.avatarUrl;

    Widget child;
    if (avatarBytes != null && avatarBytes!.isNotEmpty) {
      child = Image.memory(
        avatarBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    } else {
      final assetPath = AvatarAssetUtils.assetPathFrom(avatarUrl);
      if (assetPath != null) {
        child = Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } else if (avatarUrl.isNotEmpty) {
        child = Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _buildAvatarFallback(author: author),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(
              color: Color(0xFFEFEFEF),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        );
      } else {
        child = Center(child: _buildAvatarFallback(author: author));
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFE8E8E8),
          width: 2,
        ),
        color: const Color(0xFFEFEFEF),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildAvatarFallback({StoryPostAuthor? author}) {
    final resolved = author ?? _author;
    final initial = resolved.fullName.isNotEmpty
        ? resolved.fullName[0].toUpperCase()
        : resolved.username.isNotEmpty
            ? resolved.username[0].toUpperCase()
            : 'U';

    return Text(
      initial,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF666666),
        fontSize: 28,
      ),
    );
  }

  Widget _buildAuthorInfo({
    required StoryPostAuthor author,
    required bool isRtl,
  }) {
    final hasDistinctName = author.fullName.isNotEmpty &&
        author.fullName.toLowerCase() != author.username.toLowerCase();
    final primaryText =
        hasDistinctName ? author.fullName : author.username;

    return Column(
      crossAxisAlignment:
          isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Flexible(
              child: Text(
                primaryText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  color: AppColors.darkBackground,
                  height: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (post.isVerified) ...[
              const SizedBox(width: 8),
              VerificationBadgeIcon(
                isVerified: post.isVerified,
                verificationType: post.verificationType,
                role: post.profiles?['role']?.toString(),
                size: 24,
              ),
            ],
          ],
        ),
        if (hasDistinctName) ...[
          const SizedBox(height: 4),
          Text(
            author.username,
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF737373),
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPostContent(String displayText, {required bool isRtl}) {
    final limitedText = displayText.length > 280
        ? '${displayText.substring(0, 280)}…'
        : displayText;

    return Text(
      limitedText,
      style: const TextStyle(
        fontSize: 34,
        color: Color(0xFF141414),
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      ),
      textAlign: isRtl ? TextAlign.right : TextAlign.left,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 10,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPostImage(String imageUrl) {
    if (postImageBytes != null && postImageBytes!.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.memory(
          postImageBytes!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildImageFallback(),
        placeholder: (_, __) => _buildImageFallback(showSpinner: true),
      ),
    );
  }

  Widget _buildImageFallback({bool showSpinner = false}) {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: Center(
        child: showSpinner
            ? const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.image_outlined,
                size: 64,
                color: Color(0xFFBDBDBD),
              ),
      ),
    );
  }

  Widget _buildVideoSection() {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoThumbnailBytes != null && videoThumbnailBytes!.isNotEmpty)
            Image.memory(
              videoThumbnailBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.darkSurface, AppColors.darkSurfaceVariant],
                ),
              ),
              child: const Icon(
                Icons.videocam_outlined,
                size: 72,
                color: Color(0x66FFFFFF),
              ),
            ),
          Container(color: Colors.black.withValues(alpha: 0.18)),
          Center(child: _buildPlayButton()),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 56,
      ),
    );
  }

  Widget _buildMusicSection({required bool isRtl}) {
    final title = _resolveMusicTitle();
    final artist = _author.username;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1DB954), Color(0xFF169C46)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 32,
          ),
        ],
      ),
    );
  }

  String _resolveMusicTitle() {
    final direct = post.title?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final url = post.musicUrl?.trim() ?? '';
    if (url.isEmpty) return 'موزیک';

    final uri = Uri.tryParse(url);
    final lastSegment = (uri?.pathSegments.isNotEmpty ?? false)
        ? uri!.pathSegments.last
        : url.split('/').last;
    final withoutExtension =
        lastSegment.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final normalized = withoutExtension
        .replaceFirst(RegExp(r'^[^_]+_[0-9]+_'), '')
        .replaceAll('_', ' ')
        .trim();

    return normalized.isEmpty ? 'موزیک' : normalized;
  }

  Widget _buildPostFooter({required bool isRtl, required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(36, 28, 36, compact ? 24 : 28),
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        children: [
          _buildStat(
            icon: post.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            count: post.hideLikeCount ? null : post.likeCount,
            color: post.isLiked
                ? const Color(0xFFE0245E)
                : const Color(0xFF737373),
          ),
          const SizedBox(width: 28),
          _buildStat(
            icon: Icons.chat_bubble_outline_rounded,
            count: post.hideCommentCount ? null : post.commentCount,
          ),
          const Spacer(),
          Text(
            _formatDate(post.createdAt),
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    int? count,
    Color color = const Color(0xFF737373),
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 30, color: color),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            _formatNumber(count),
            style: TextStyle(
              fontSize: 26,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBrandFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'lib/utils/images/logo/black-logo.png',
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.bolt_rounded,
              size: 20,
              color: Color(0xFF737373),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Vista',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF737373),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          const Text(
            'cafevista.ir',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} روز';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه';
    }
    return 'اکنون';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  bool _isPersianText(String text) {
    final persianRegex = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    );
    return persianRegex.hasMatch(text);
  }
}

class VistaStoryBackgroundPainter extends CustomPainter {
  final VistaStoryShareTheme theme;

  VistaStoryBackgroundPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    switch (theme) {
      case VistaStoryShareTheme.dark:
        _paintDark(canvas, size);
      case VistaStoryShareTheme.light:
        _paintLight(canvas, size);
      case VistaStoryShareTheme.vista:
        _paintVista(canvas, size);
    }
  }

  void _paintDark(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF030303),
            Color(0xFF0D0D0D),
            Color(0xFF060606),
            Color(0xFF101010),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ).createShader(rect),
    );

    _drawGlow(
      canvas,
      size,
      center: Offset(size.width * 0.5, size.height * 0.38),
      color: Colors.white.withValues(alpha: 0.09),
      radiusFactor: 0.5,
    );
    _drawGlow(
      canvas,
      size,
      center: Offset(size.width * 0.18, size.height * 0.2),
      color: const Color(0xFF4A6FA5).withValues(alpha: 0.06),
      radiusFactor: 0.28,
    );
    _drawGlow(
      canvas,
      size,
      center: Offset(size.width * 0.82, size.height * 0.72),
      color: AppColors.secondary.withValues(alpha: 0.05),
      radiusFactor: 0.32,
    );

    _drawRings(
      canvas,
      size,
      color: Colors.white.withValues(alpha: 0.05),
      strokeWidth: 1.5,
    );
    _drawRing(
      canvas,
      Offset(size.width * 0.5, size.height * 0.82),
      size.width * 0.55,
      Colors.white.withValues(alpha: 0.025),
      1,
    );
    _drawDotGrid(canvas, size, color: Colors.white.withValues(alpha: 0.018));
    _drawVignette(canvas, size);
    _drawWatermark(
      canvas,
      size,
      color: Colors.white.withValues(alpha: 0.02),
      fontSize: 140,
      centerY: size.height * 0.9,
      rotation: -math.pi / 14,
    );
  }

  void _paintLight(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7F2EC),
            Color(0xFFEDE6DE),
            Color(0xFFE4DDD6),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    _drawColorBlob(
      canvas,
      center: Offset(size.width * 0.85, size.height * 0.15),
      radius: size.width * 0.45,
      color: const Color(0xFFFFB4A2).withValues(alpha: 0.22),
    );
    _drawColorBlob(
      canvas,
      center: Offset(size.width * 0.12, size.height * 0.78),
      radius: size.width * 0.4,
      color: const Color(0xFFB4C5FF).withValues(alpha: 0.18),
    );
    _drawColorBlob(
      canvas,
      center: Offset(size.width * 0.55, size.height * 0.55),
      radius: size.width * 0.35,
      color: const Color(0xFFFFD6A5).withValues(alpha: 0.12),
    );
    _drawDotGrid(canvas, size, color: Colors.black.withValues(alpha: 0.04));
  }

  void _paintVista(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final ringPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 120;

    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.1),
      size.width * 0.4,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.5),
      size.width * 0.35,
      ringPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.9),
      size.width * 0.45,
      ringPaint,
    );

    _drawVistaRingText(
      canvas,
      size.width * 0.1,
      size.height * 0.1,
      size.width * 0.4,
    );
    _drawVistaRingText(
      canvas,
      size.width * 0.9,
      size.height * 0.5,
      size.width * 0.35,
    );
    _drawVistaRingText(
      canvas,
      size.width * 0.2,
      size.height * 0.9,
      size.width * 0.45,
    );
  }

  void _drawVistaRingText(
    Canvas canvas,
    double centerX,
    double centerY,
    double radius,
  ) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'VISTA',
        style: TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final circumference = 2 * math.pi * radius;
    final repetitions =
        (circumference / (textPainter.width * 1.05)).floor().clamp(4, 18);

    for (int i = 0; i < repetitions; i++) {
      final angle = (i / repetitions) * 2 * math.pi;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double strokeWidth,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  void _drawVignette(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.45);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.75)),
    );
  }

  void _drawColorBlob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawDotGrid(Canvas canvas, Size size, {required Color color}) {
    const spacing = 48.0;
    final paint = Paint()..color = color;

    for (double y = spacing; y < size.height; y += spacing) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  void _drawGlow(
    Canvas canvas,
    Size size, {
    required Offset center,
    required Color color,
    double radiusFactor = 0.55,
  }) {
    final radius = size.width * radiusFactor;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawRings(
    Canvas canvas,
    Size size, {
    required Color color,
    required double strokeWidth,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.18),
      size.width * 0.42,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.72),
      size.width * 0.38,
      paint,
    );
  }

  void _drawWatermark(
    Canvas canvas,
    Size size, {
    required Color color,
    double fontSize = 120,
    double? centerY,
    double rotation = -math.pi / 12,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'VISTA',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: fontSize * 0.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(size.width * 0.5, centerY ?? size.height * 0.88);
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VistaStoryBackgroundPainter oldDelegate) {
    return oldDelegate.theme != theme;
  }
}
