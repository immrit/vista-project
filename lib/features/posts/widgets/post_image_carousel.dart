import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Read-side image carousel for posts with multiple images.
///
/// Swipeable [PageView] with a soft dot indicator + counter pill. Fills the
/// parent's constraints, so callers wrap it in an [AspectRatio] / [SizedBox].
/// For single-image posts callers can keep their existing render; this is meant
/// for `post.hasMultipleImages`.
class PostImageCarousel extends StatefulWidget {
  const PostImageCarousel({
    super.key,
    required this.imageUrls,
    this.borderRadius,
    this.onImageTap,
    this.heroTagPrefix,
  });

  final List<String> imageUrls;
  final BorderRadius? borderRadius;

  /// Called with the tapped image index (e.g. to open a full-screen viewer).
  final ValueChanged<int>? onImageTap;
  final String? heroTagPrefix;

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  late final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    final radius = widget.borderRadius ?? BorderRadius.circular(8);
    final count = urls.length;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final image = CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child:
                          Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                );
                final tappable = widget.onImageTap == null
                    ? image
                    : GestureDetector(
                        onTap: () => widget.onImageTap!(i),
                        child: image,
                      );
                final prefix = widget.heroTagPrefix;
                return prefix == null
                    ? tappable
                    : Hero(tag: '$prefix$i', child: tappable);
              },
            ),
          ),
          // counter pill
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_page + 1}/$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // dot indicator
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
