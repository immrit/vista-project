import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/cache_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ImageCacheManagementPage extends ConsumerStatefulWidget {
  final UnifiedCacheManager cacheManager;
  final VoidCallback? onDataChanged;
  
  const ImageCacheManagementPage({
    super.key,
    required this.cacheManager,
    this.onDataChanged,
  });

  @override
  ConsumerState<ImageCacheManagementPage> createState() => _ImageCacheManagementPageState();
}

class _ImageCacheManagementPageState extends ConsumerState<ImageCacheManagementPage> with TickerProviderStateMixin {
  Map<String, List<CachedImageFile>> categoryFiles = {};
  Map<String, bool> categoryExpanded = {};
  Set<String> selectedFiles = {};
  bool isSelectMode = false;
  bool isLoading = true;
  TabController? _tabController;
  
  final List<String> categories = ['story_cache', 'post_cache', 'chat_cache', 'wallpaper_cache'];
  final Map<String, String> categoryNames = {
    'story_cache': 'استوری‌ها',
    'post_cache': 'پست‌ها', 
    'chat_cache': 'چت',
    'wallpaper_cache': 'والپیپرها',
  };
  
  final Map<String, IconData> categoryIcons = {
    'story_cache': Icons.auto_stories_rounded,
    'post_cache': Icons.photo_library_rounded,
    'chat_cache': Icons.chat_rounded,
    'wallpaper_cache': Icons.wallpaper_rounded,
  };

  final Map<String, Color> categoryColors = {
    'story_cache': Colors.purple,
    'post_cache': Colors.blue,
    'chat_cache': Colors.green,
    'wallpaper_cache': Colors.orange,
  };
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    for (final category in categories) {
      categoryExpanded[category] = true;
    }
    _loadCachedImages();
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadCachedImages() async {
    setState(() => isLoading = true);
    try {
      final Map<String, List<CachedImageFile>> files = {};
      
      for (final category in categories) {
        files[category] = await _getCachedFilesForCategory(category);
      }
      
      setState(() {
        categoryFiles = files;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری فایل‌ها: $e')),
      );
    }
  }
  
  Future<List<CachedImageFile>> _getCachedFilesForCategory(String category) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/flutter_cache_manager/$category');
      
      if (!await cacheDir.exists()) {
        return [];
      }
      
      final List<CachedImageFile> files = [];
      
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final fileName = entity.path.split('/').last.toLowerCase();
            if (_isImageFile(fileName)) {
              final stat = await entity.stat();
              files.add(CachedImageFile(
                path: entity.path,
                name: entity.path.split('/').last,
                size: stat.size,
                lastModified: stat.modified,
                category: category,
              ));
            }
          } catch (e) {
            continue;
          }
        }
      }
      
      // مرتب‌سازی بر اساس آخرین تغییر
      files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      return files;
    } catch (e) {
      return [];
    }
  }
  
  bool _isImageFile(String fileName) {
    return fileName.endsWith('.jpg') ||
           fileName.endsWith('.jpeg') ||
           fileName.endsWith('.png') ||
           fileName.endsWith('.webp') ||
           fileName.endsWith('.gif');
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }
  
  void _toggleSelectMode() {
    setState(() {
      isSelectMode = !isSelectMode;
      if (!isSelectMode) {
        selectedFiles.clear();
      }
    });
  }
  
  void _toggleFileSelection(String filePath) {
    setState(() {
      if (selectedFiles.contains(filePath)) {
        selectedFiles.remove(filePath);
      } else {
        selectedFiles.add(filePath);
      }
    });
  }
  
  void _selectAllInCategory(String category) {
    setState(() {
      final categoryFilesList = categoryFiles[category] ?? [];
      for (final file in categoryFilesList) {
        selectedFiles.add(file.path);
      }
    });
  }
  
  void _selectAll() {
    setState(() {
      for (final files in categoryFiles.values) {
        for (final file in files) {
          selectedFiles.add(file.path);
        }
      }
    });
  }
  
  void _deselectAll() {
    setState(() {
      selectedFiles.clear();
    });
  }
  
  Future<void> _deleteSelectedFiles() async {
    if (selectedFiles.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید حذف'),
        content: Text('آیا مطمئن هستید که می‌خواهید ${selectedFiles.length} فایل را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        int deletedCount = 0;
        double freedSpace = 0;
        
        for (final filePath in selectedFiles) {
          try {
            final file = File(filePath);
            if (await file.exists()) {
              final stat = await file.stat();
              freedSpace += stat.size / (1024 * 1024); // تبدیل به MB
              await file.delete();
              deletedCount++;
            }
          } catch (e) {
            continue;
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount فایل حذف شد • ${freedSpace.toStringAsFixed(1)} MB آزاد شد'),
            backgroundColor: Colors.green,
          ),
        );
        
        widget.onDataChanged?.call();
        await _loadCachedImages();
        setState(() {
          selectedFiles.clear();
          isSelectMode = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف: $e')),
        );
      }
    }
  }
  
  Future<void> _clearCategoryCache(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید پاکسازی'),
        content: Text('آیا مطمئن هستید که می‌خواهید تمام کش ${categoryNames[category]} را پاک کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('پاک‌سازی'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // پاکسازی کش مربوط به دسته
        switch (category) {
          case 'story_cache':
            await widget.cacheManager.storyInstance.emptyCache();
            break;
          case 'post_cache':
            await widget.cacheManager.postInstance.emptyCache();
            break;
          case 'chat_cache':
            await widget.cacheManager.chatInstance.emptyCache();
            break;
          case 'wallpaper_cache':
            await widget.cacheManager.wallpaperInstance.emptyCache();
            break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کش ${categoryNames[category]} پاک‌سازی شد'),
            backgroundColor: Colors.green,
          ),
        );
        
        widget.onDataChanged?.call();
        await _loadCachedImages();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در پاکسازی: $e')),
        );
      }
    }
  }
  
  void _showImagePreview(CachedImageFile imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(imageFile.name),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await File(imageFile.path).delete();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('فایل حذف شد'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      widget.onDataChanged?.call();
                      await _loadCachedImages();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطا در حذف: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imageFile.path),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(categoryIcons[imageFile.category], 
                                   color: categoryColors[imageFile.category], size: 20),
                              const SizedBox(width: 8),
                              Text(categoryNames[imageFile.category] ?? '', 
                                   style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('حجم: ${_formatFileSize(imageFile.size)}'),
                          Text('تاریخ: ${_formatDate(imageFile.lastModified)}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoryTab(String category) {
    final files = categoryFiles[category] ?? [];
    
    return Tab(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(categoryIcons[category], size: 20),
          const SizedBox(height: 4),
          Text(categoryNames[category] ?? '', style: const TextStyle(fontSize: 11)),
          Text('${files.length}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
  
  Widget _buildFileGrid(String category) {
    final files = categoryFiles[category] ?? [];
    
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(categoryIcons[category], size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('هیچ فایلی در ${categoryNames[category]} یافت نشد', 
                 style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // آمار دسته
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: categoryColors[category]?.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text('${files.length}', 
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, 
                                       color: categoryColors[category])),
                  const Text('فایل', style: TextStyle(color: Colors.grey)),
                ],
              ),
              Column(
                children: [
                  Text(_formatFileSize(files.fold(0, (sum, file) => sum + file.size)),
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, 
                                       color: categoryColors[category])),
                  const Text('حجم کل', style: TextStyle(color: Colors.grey)),
                ],
              ),
              TextButton.icon(
                onPressed: isSelectMode ? () => _selectAllInCategory(category) : null,
                icon: const Icon(Icons.select_all_rounded, size: 16),
                label: const Text('انتخاب همه', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: () => _clearCategoryCache(category),
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('پاک‌سازی', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ),
        
        // Grid فایل‌ها
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final isSelected = selectedFiles.contains(file.path);
              
              return GestureDetector(
                onTap: isSelectMode
                    ? () => _toggleFileSelection(file.path)
                    : () => _showImagePreview(file),
                onLongPress: isSelectMode ? null : _toggleSelectMode,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected 
                            ? Border.all(color: Colors.blue, width: 3)
                            : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          children: [
                            Expanded(
                              child: Image.file(
                                File(file.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.broken_image_rounded, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              color: Colors.black.withValues(alpha: 0.7),
                              child: Column(
                                children: [
                                  Text(
                                    file.name.length > 15 
                                        ? '${file.name.substring(0, 12)}...'
                                        : file.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                  Text(
                                    _formatFileSize(file.size),
                                    style: const TextStyle(color: Colors.grey, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSelectMode)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Icon(
                            isSelected ? Icons.check_rounded : null,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalFiles = categoryFiles.values.fold(0, (sum, files) => sum + files.length);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectMode ? '${selectedFiles.length} انتخاب شده' : 'مدیریت تصاویر کش'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        bottom: _tabController != null ? TabBar(
          controller: _tabController,
          tabs: categories.map(_buildCategoryTab).toList(),
          indicatorColor: Colors.blue,
          labelColor: isDark ? Colors.white : Colors.black,
        ) : null,
        actions: [
          if (!isSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: totalFiles > 0 ? _toggleSelectMode : null,
              tooltip: 'انتخاب چندگانه',
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadCachedImages,
              tooltip: 'بروزرسانی',
            ),
          ] else ...[
            TextButton(
              onPressed: selectedFiles.length == totalFiles ? _deselectAll : _selectAll,
              child: Text(selectedFiles.length == totalFiles ? 'لغو همه' : 'انتخاب همه'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: selectedFiles.isEmpty ? null : _deleteSelectedFiles,
              color: Colors.red,
              tooltip: 'حذف انتخاب شده‌ها',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _toggleSelectMode,
              tooltip: 'لغو انتخاب',
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabController != null
              ? TabBarView(
                  controller: _tabController,
                  children: categories.map(_buildFileGrid).toList(),
                )
              : const Center(child: Text('خطا در بارگذاری')),
    );
  }
}

class CachedImageFile {
  final String path;
  final String name;
  final int size;
  final DateTime lastModified;
  final String category;
  
  CachedImageFile({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
    required this.category,
  });
}
