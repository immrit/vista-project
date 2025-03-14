import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../service/MusicService.dart';

class AddMusicScreen extends ConsumerStatefulWidget {
  const AddMusicScreen({super.key});

  @override
  ConsumerState<AddMusicScreen> createState() => _AddMusicScreenState();
}

class _AddMusicScreenState extends ConsumerState<AddMusicScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  File? _selectedMusic;
  File? _selectedCover;
  bool _isLoading = false;
  final List<String> _selectedGenres = [];

  final _genres = ['پاپ', 'راک', 'سنتی', 'رپ', 'جاز', 'کلاسیک'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('انتشار موزیک'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'نام آهنگ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _artistController,
              decoration: const InputDecoration(
                labelText: 'نام خواننده',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Select Music File
            ElevatedButton.icon(
              onPressed: _pickMusicFile,
              icon: const Icon(Icons.music_note),
              label: Text(_selectedMusic == null
                  ? 'انتخاب فایل موزیک'
                  : 'فایل انتخاب شد'),
            ),

            const SizedBox(height: 16),

            // Select Cover Image
            ElevatedButton.icon(
              onPressed: _pickCoverImage,
              icon: const Icon(Icons.image),
              label: Text(
                  _selectedCover == null ? 'انتخاب کاور' : 'کاور انتخاب شد'),
            ),

            if (_selectedCover != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedCover!,
                  height: 150,
                  width: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Genre Selection
            Wrap(
              spacing: 8,
              children: _genres.map((genre) {
                final isSelected = _selectedGenres.contains(genre);
                return FilterChip(
                  label: Text(genre),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGenres.add(genre);
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _publishMusic,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('انتشار موزیک'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMusicFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedMusic = File(result.files.single.path!);
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedCover = File(pickedFile.path);
      });
    }
  }

  Future<void> _publishMusic() async {
    if (_selectedMusic == null ||
        _titleController.text.isEmpty ||
        _artistController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً تمام فیلدهای ضروری را پر کنید')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final musicService = MusicService();

      // Upload music file
      final musicUrl = await musicService.uploadMusic(_selectedMusic!);

      // Upload cover if selected
      String? coverUrl;
      if (_selectedCover != null) {
        coverUrl = await musicService.uploadCover(_selectedCover!);
      }

      // Publish music
      await musicService.publishMusic(
        title: _titleController.text,
        artist: _artistController.text,
        musicUrl: musicUrl,
        coverUrl: coverUrl,
        genres: _selectedGenres,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('موزیک با موفقیت منتشر شد')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در انتشار موزیک: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
