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
import '../../../../utils/user_friendly_error_utils.dart';

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

  void _closeStickerSheet() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  int? _toIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _onInteractiveStickerTap(_InteractiveSticker sticker) {
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
        _closeStickerSheet();
        break;
      case 'weather':
        _addWeatherSticker();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${sticker.label} \u062F\u0631 \u0627\u06CC\u0646 \u0646\u0633\u062E\u0647 \u0641\u0639\u0627\u0644 \u0646\u06CC\u0633\u062A.',
            ),
          ),
        );
    }
  }

  void _showLocationPicker(
      {StoryInteractionType targetType = StoryInteractionType.location}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        onLocationSelected: (locationName, lat, lng) async {
          int? temperature;
          int? weatherCode;

          if (targetType == StoryInteractionType.weather) {
            try {
              if (lat.isFinite && lng.isFinite) {
                final weatherData =
                    await WeatherService().getCurrentTemperature(lat, lng);
                temperature = _toIntOrNull(weatherData?['temperature']);
                weatherCode = _toIntOrNull(weatherData?['weathercode']);

                if (weatherData == null && mounted) {
                  UserFriendlyErrorUtils.showErrorSnackBar(
                    context,
                    '\u062F\u0631\u06CC\u0627\u0641\u062A \u0627\u0637\u0644\u0627\u0639\u0627\u062A \u0622\u0628\u200C\u0648\u0647\u0648\u0627 \u0645\u0645\u06A9\u0646 \u0646\u0634\u062F.',
                  );
                }
              } else if (mounted) {
                UserFriendlyErrorUtils.showErrorSnackBar(
                  context,
                  '\u0628\u0631\u0627\u06CC \u062F\u0631\u06CC\u0627\u0641\u062A \u0622\u0628\u200C\u0648\u0647\u0648\u0627 \u0646\u06CC\u0627\u0632 \u0628\u0647 \u062F\u0633\u062A\u0631\u0633\u06CC \u0645\u06A9\u0627\u0646 \u062F\u0627\u0631\u06CC\u062F.',
                );
              }
            } catch (e) {
              if (mounted) {
                UserFriendlyErrorUtils.showErrorSnackBar(context, e);
              }
            }
          }

          if (!mounted) return;

          final payload = <String, dynamic>{
            'city': locationName,
            'latitude': lat,
            'longitude': lng,
          };
          if (temperature != null) {
            payload['temperature'] = temperature;
          }
          if (weatherCode != null) {
            payload['weathercode'] = weatherCode;
          }

          final fallbackText = targetType == StoryInteractionType.weather
              ? '\u0622\u0628\u200C\u0648\u0647\u0648\u0627: $locationName'
              : locationName;

          _handleStickerData(
            targetType,
            payload,
            fallbackText: fallbackText,
            closeStickerSheet: true,
          );
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
        onMentionCreated: (type, data) => _handleStickerData(type, data,
            fallbackText: '@${data['username']}'),
      ),
    );
  }

  void _showHashtagDialog() {
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
              const Text('\u0647\u0634\u062A\u06AF',
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
                  hintText: '\u0645\u062A\u0646 \u0647\u0634\u062A\u06AF...',
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
    _handleStickerData(
      StoryInteractionType.hashtag,
      {'hashtag': tag},
      fallbackText: '#$tag',
    );
    Navigator.pop(ctx);
    _closeStickerSheet();
  }

  void _showLinkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LinkInputSheet(
        onLinkCreated: (type, data) => _handleStickerData(
          type,
          data,
          fallbackText: '\u0644\u06CC\u0646\u06A9: ${data['url']}',
        ),
      ),
    );
  }

  void _showPollDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PollInputSheet(
        onPollCreated: (type, data) => _handleStickerData(
          type,
          data,
          fallbackText:
              '\u0646\u0638\u0631\u0633\u0646\u062C\u06CC: ${data['question']}',
        ),
      ),
    );
  }

  void _showQuestionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuestionsInputSheet(
        onQuestionCreated: (type, data) => _handleStickerData(
          type,
          data,
          fallbackText: '\u0633\u0648\u0627\u0644: ${data['question']}',
        ),
      ),
    );
  }

  void _showCountdownDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CountdownInputSheet(
        onCountdownCreated: (type, data) => _handleStickerData(
          type,
          data,
          fallbackText:
              '\u0634\u0645\u0627\u0631\u0634\u06AF\u0631: ${data['title']}',
        ),
      ),
    );
  }

  void _addDateSticker() {
    final now = DateTime.now();
    widget.onStickerSelected('${now.year}/${now.month}/${now.day}');
  }

  void _addWeatherSticker() {
    _showLocationPicker(targetType: StoryInteractionType.weather);
  }

  void _handleStickerData(
    StoryInteractionType type,
    Map<String, dynamic> data, {
    required String fallbackText,
    bool closeStickerSheet = false,
  }) {
    if (widget.onInteractiveStickerSelected != null) {
      widget.onInteractiveStickerSelected!(type, data);
    } else {
      widget.onStickerSelected(fallbackText);
    }

    if (closeStickerSheet) {
      _closeStickerSheet();
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
