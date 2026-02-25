// lib/features/chat/widgets/gif_picker_widget.dart
//
// ویجت انتخاب GIF - مشابه ویستا
//
// ویژگی‌ها:
// ✅ جستجوی GIF از Tenor
// ✅ نمایش آبشاری (Masonry Grid)
// ✅ کش کردن تصاویر
// ✅ Debounce برای جستجو

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/gif_service.dart';

class GifPickerWidget extends StatefulWidget {
  final Function(String gifUrl) onGifSelected;

  const GifPickerWidget({
    super.key,
    required this.onGifSelected,
  });

  @override
  State<GifPickerWidget> createState() => _GifPickerWidgetState();
}

class _GifPickerWidgetState extends State<GifPickerWidget>
    with AutomaticKeepAliveClientMixin {
  final GifService _gifService = GifService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  List<GifItem> _gifs = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _gifs = [];
    });
    
    try {
      final gifs = await _gifService.getTrendingGifs();
      if (mounted) {
        setState(() {
          _gifs = gifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _gifs = [];
    });
    
    try {
      final gifs = await _gifService.searchGifs(query);
      if (mounted) {
        setState(() {
          _gifs = gifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query != _searchQuery) {
        _searchQuery = query;
        _performSearch(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // برای حفظ وضعیت تب
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 🔍 نوار جستجوی گیف
        Container(
          height: 44,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textAlignVertical: TextAlignVertical.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'جستجو در گیف‌ها...',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.grey,
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // 🎞️ لیست گیف‌ها
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.primaryColor,
                  ),
                )
              : _hasError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'خطا در بارگذاری گیف‌ها',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadTrending,
                            child: const Text('تلاش مجدد'),
                          ),
                        ],
                      ),
                    )
                  : _gifs.isEmpty
                      ? Center(
                          child: Text(
                            'موردی یافت نشد',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : MasonryGridView.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          itemCount: _gifs.length,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          itemBuilder: (context, index) {
                            final gif = _gifs[index];
                            return _buildGifItem(gif, isDark);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildGifItem(GifItem gif, bool isDark) {
    return InkWell(
      onTap: () {
        print('🎞️ ========== GIF TAPPED ==========');
        print('🎞️ GIF URL: ${gif.url}');
        HapticFeedback.lightImpact();
        print('🎞️ Calling widget.onGifSelected...');
        widget.onGifSelected(gif.url);
        print('🎞️ widget.onGifSelected called');
        print('🎞️ ========== GIF TAPPED END ==========');
      },
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          child: CachedNetworkImage(
            imageUrl: gif.previewUrl.isNotEmpty ? gif.previewUrl : gif.url,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              child: Icon(
                Icons.error_outline,
                color: Colors.grey[400],
                size: 24,
              ),
            ),
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );
  }
}

