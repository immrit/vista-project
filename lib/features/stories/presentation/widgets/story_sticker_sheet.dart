import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../services/weather_service.dart';
import 'location_picker_sheet.dart';
import 'link_input_sheet.dart';
import 'poll_input_sheet.dart';
import 'mention_input_sheet.dart';
import 'countdown_input_sheet.dart';
import 'questions_input_sheet.dart';
import '../../domain/entities/story_editor_models.dart';

/// Bottom Sheet استیکرهای تعاملی با طراحی Glassmorphism و تب‌بندی
class StoryStickerSheet extends StatefulWidget {
  final Function(String content) onStickerSelected;
  final Function(StoryInteractionType type, Map<String, dynamic> data)?
      onInteractiveStickerSelected;

  const StoryStickerSheet({
    super.key,
    required this.onStickerSelected,
    this.onInteractiveStickerSelected,
  });

  @override
  State<StoryStickerSheet> createState() => _StoryStickerSheetState();
}

class _StoryStickerSheetState extends State<StoryStickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // استیکرهای تعاملی
  static const List<_InteractiveSticker> _interactiveStickers = [
    _InteractiveSticker(
        icon: Icons.location_on_rounded,
        label: 'لوکیشن',
        type: 'location',
        gradient: LinearGradient(colors: [Colors.orange, Colors.red])),
    _InteractiveSticker(
        icon: Icons.alternate_email_rounded,
        label: 'منشن',
        type: 'mention',
        gradient: LinearGradient(colors: [Colors.orange, Colors.yellow])),
    _InteractiveSticker(
        icon: Icons.numbers_rounded,
        label: 'هشتگ',
        type: 'hashtag',
        gradient: LinearGradient(colors: [Colors.blue, Colors.purple])),
    _InteractiveSticker(
        icon: Icons.link_rounded,
        label: 'لینک',
        type: 'link',
        gradient: LinearGradient(colors: [Colors.blue, Colors.cyan])),
    _InteractiveSticker(
        icon: Icons.poll_rounded,
        label: 'نظرسنجی',
        type: 'poll',
        gradient: LinearGradient(colors: [Colors.green, Colors.teal])),
    _InteractiveSticker(
        icon: Icons.question_answer_rounded,
        label: 'سوال',
        type: 'questions',
        gradient: LinearGradient(colors: [Colors.purple, Colors.pink])),
    _InteractiveSticker(
        icon: Icons.timer_rounded,
        label: 'شمارشگر',
        type: 'countdown',
        gradient: LinearGradient(colors: [Colors.redAccent, Colors.pink])),
    _InteractiveSticker(
        icon: Icons.music_note_rounded,
        label: 'موزیک',
        type: 'music',
        gradient: LinearGradient(colors: [Colors.pink, Colors.purple])),
    _InteractiveSticker(
        icon: Icons.gif_box_outlined,
        label: 'GIF',
        type: 'gif',
        gradient: LinearGradient(colors: [Colors.teal, Colors.blue])),
    _InteractiveSticker(
        icon: Icons.image_rounded,
        label: 'عکس',
        type: 'photo',
        gradient: LinearGradient(colors: [Colors.grey, Colors.blueGrey])),
    _InteractiveSticker(
        icon: Icons.wb_sunny_rounded,
        label: 'هواشناسی',
        type: 'weather',
        gradient: LinearGradient(colors: [Colors.orangeAccent, Colors.amber])),
    _InteractiveSticker(
        icon: Icons.calendar_month_rounded,
        label: 'تاریخ',
        type: 'date',
        gradient: LinearGradient(colors: [Colors.red, Colors.redAccent])),
  ];

  // ایموجی‌ها (لیست کامل‌تر)
  static const List<String> _emojis = [
    '😂',
    '❤️',
    '😍',
    '🔥',
    '👏',
    '😢',
    '😮',
    '🙌',
    '🤔',
    '🎉',
    '🤣',
    '🥰',
    '🥺',
    '👍',
    '😭',
    '🙏',
    '😘',
    '✨',
    '👀',
    '😎',
    '😊',
    '😁',
    '🤩',
    '💯',
    '💩',
    '🥳',
    '😡',
    '🤯',
    '👋',
    '🙈',
    '🤝',
    '💕',
    '💔',
    '😤',
    '🤤',
    '🫠',
    '🤧',
    '🤢',
    '🥵',
    '🥶',
    '🥴',
    '😵',
    '😷',
    '🤕',
    '🤑',
    '🤠',
    '😈',
    '👿',
    '👹',
    '👺',
    '💀',
    '👻',
    '👽',
    '👾',
    '🤖',
    '💩',
    '😺',
    '😸',
    '😹',
    '😻',
    '😼',
    '😽',
    '🙀',
    '😿',
    '😾',
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🐔',
    '🐧',
    '🐦',
    '🐤',
    '🐣',
    '🐥',
    '🦆',
    '🦅',
    '🦉',
    '🦇',
    '🐺',
    '🐗',
    '🐴',
    '🦄',
    '🐝',
    '🐛',
    '🦋',
    '🐌',
    '🐞',
    '🐜',
    '🦟',
    '🦗',
    '🕷️',
    '🕸️',
    '🦂',
    '🐢',
    '🐍',
    '🦎',
    '🦖',
    '🦕',
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Search Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'جستجو...',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.5),
                labelStyle: const TextStyle(
                    fontFamily: 'Vazir', fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'استیکرها'),
                  Tab(text: 'ایموجی'),
                ],
              ),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInteractiveStickersGrid(),
                    _buildEmojiGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStickersGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 items per row for prominence
        childAspectRatio: 2.5, // Wider aspect ratio
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _interactiveStickers.length,
      itemBuilder: (context, index) {
        final sticker = _interactiveStickers[index];
        return _buildStickerCard(sticker);
      },
    );
  }

  Widget _buildStickerCard(_InteractiveSticker sticker) {
    return GestureDetector(
      onTap: () => _onInteractiveStickerTap(sticker),
      child: Container(
        decoration: BoxDecoration(
          gradient: sticker.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: sticker.gradient.colors.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glass effect overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: 0,
                    sigmaY: 0), // Just structural for now, optional logic
                child: Container(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(sticker.icon, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text(
                  sticker.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _emojis.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            widget.onStickerSelected(_emojis[index]);
            Navigator.pop(context);
          },
          child: Center(
            child: Text(
              _emojis[index],
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }

  void _onInteractiveStickerTap(_InteractiveSticker sticker) {
    final sheetsWithOwnNavigation = [
      'location',
      'mention',
      'hashtag',
      'link',
      'poll',
      'questions',
      'countdown',
      'weather'
    ];

    if (!sheetsWithOwnNavigation.contains(sticker.type)) {
      Navigator.pop(context);
    }

    switch (sticker.type) {
      case 'location':
        _showLocationPicker();
        break;
      case 'mention':
        _showMentionDialog();
        break;
      case 'hashtag':
        _showHashtagDialog();
        break;
      case 'link':
        _showLinkDialog();
        break;
      case 'poll':
        _showPollDialog();
        break;
      case 'questions':
        _showQuestionsDialog();
        break;
      case 'countdown':
        _showCountdownDialog();
        break;
      case 'date':
        _addDateSticker();
        break;
      case 'weather':
        _addWeatherSticker();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sticker.label} - به زودی...')),
        );
    }
  }

  // Wrapper methods for dialogs (kept from original logic)
  void _showLocationPicker(
      {StoryInteractionType targetType = StoryInteractionType.location}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerSheet(
        onLocationSelected: (locationName, lat, lng) async {
          int? temperature;
          int? weatherCode;

          if (targetType == StoryInteractionType.weather) {
            try {
              final weatherData =
                  await WeatherService().getCurrentTemperature(lat, lng);
              if (weatherData != null) {
                temperature = weatherData['temperature'] as int?;
                weatherCode = weatherData['weathercode'] as int?;
              }
            } catch (e) {
              debugPrint('Error fetching weather: $e');
            }
          }

          if (!mounted) return;

          if (widget.onInteractiveStickerSelected != null) {
            widget.onInteractiveStickerSelected!(
              targetType,
              {
                'city': locationName,
                'latitude': lat,
                'longitude': lng,
                'temperature': temperature ?? 24,
                'weathercode': weatherCode,
              },
            );
          } else {
            widget.onStickerSelected(
                '📍 $locationName ${temperature != null ? "$temperature°" : ""}');
          }
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showMentionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MentionInputSheet(
        onMentionCreated: (type, data) =>
            _handleStickerData(type, data, '@${data['username']}'),
      ),
    );
  }

  void _showHashtagDialog() {
    // Re-implementing visually improved hashtag dialog inline or reusing component if extracted
    // For brevity, reusing the logic from previous implementation but cleaned up
    final TextEditingController hashtagController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هشتگ',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: hashtagController,
                autofocus: true,
                style: const TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '# ',
                  prefixStyle: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                  hintText: 'متن هشتگ...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onSubmitted: (value) => _submitHashtag(value, ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitHashtag(String value, BuildContext ctx) {
    if (value.trim().isEmpty) return;
    final tag = value.trim().replaceAll('#', '');
    _handleStickerData(StoryInteractionType.hashtag, {'hashtag': tag}, '#$tag');
    Navigator.pop(ctx);
    Navigator.pop(context);
  }

  void _showLinkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LinkInputSheet(
        onLinkCreated: (type, data) =>
            _handleStickerData(type, data, '🔗 ${data['url']}'),
      ),
    );
  }

  void _showPollDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PollInputSheet(
        onPollCreated: (type, data) =>
            _handleStickerData(type, data, '📊 ${data['question']}'),
      ),
    );
  }

  void _showQuestionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuestionsInputSheet(
        onQuestionCreated: (type, data) =>
            _handleStickerData(type, data, '❓ ${data['question']}'),
      ),
    );
  }

  void _showCountdownDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CountdownInputSheet(
        onCountdownCreated: (type, data) =>
            _handleStickerData(type, data, '⏱️ ${data['title']}'),
      ),
    );
  }

  void _addDateSticker() {
    final now = DateTime.now();
    widget.onStickerSelected('📅 ${now.year}/${now.month}/${now.day}');
  }

  void _addWeatherSticker() {
    _showLocationPicker(targetType: StoryInteractionType.weather);
  }

  void _handleStickerData(StoryInteractionType type, Map<String, dynamic> data,
      String fallbackText) {
    if (widget.onInteractiveStickerSelected != null) {
      widget.onInteractiveStickerSelected!(type, data);
    } else {
      widget.onStickerSelected(fallbackText);
    }
  }
}

class _InteractiveSticker {
  final IconData icon;
  final String label;
  final String type;
  final Gradient gradient;

  const _InteractiveSticker({
    required this.icon,
    required this.label,
    required this.type,
    required this.gradient,
  });
}
