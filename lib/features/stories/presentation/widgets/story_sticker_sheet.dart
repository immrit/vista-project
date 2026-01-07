import 'package:flutter/material.dart';
import '../../../../services/weather_service.dart';
import 'location_picker_sheet.dart';
import 'link_input_sheet.dart';
import 'poll_input_sheet.dart';
import 'mention_input_sheet.dart';
import 'countdown_input_sheet.dart';
import 'questions_input_sheet.dart';
import '../../domain/entities/story_editor_models.dart';

/// Bottom Sheet استیکرهای تعاملی (مشابه اینستاگرام)
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

class _StoryStickerSheetState extends State<StoryStickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  // استیکرهای تعاملی
  static const List<_InteractiveSticker> _interactiveStickers = [
    _InteractiveSticker(
        icon: Icons.location_on,
        label: 'لوکیشن',
        type: 'location',
        color: Colors.red),
    _InteractiveSticker(
        icon: Icons.alternate_email,
        label: 'منشن',
        type: 'mention',
        color: Colors.purple),
    _InteractiveSticker(
        icon: Icons.tag, label: 'هشتگ', type: 'hashtag', color: Colors.blue),
    _InteractiveSticker(
        icon: Icons.link, label: 'لینک', type: 'link', color: Colors.green),
    _InteractiveSticker(
        icon: Icons.poll, label: 'نظرسنجی', type: 'poll', color: Colors.orange),
    _InteractiveSticker(
        icon: Icons.help_outline,
        label: 'سوالات',
        type: 'questions',
        color: Colors.pink),
    _InteractiveSticker(
        icon: Icons.timer,
        label: 'شمارش معکوس',
        type: 'countdown',
        color: Colors.teal),
    _InteractiveSticker(
        icon: Icons.music_note,
        label: 'موزیک',
        type: 'music',
        color: Colors.deepPurple),
    _InteractiveSticker(
        icon: Icons.gif_box, label: 'GIF', type: 'gif', color: Colors.cyan),
    _InteractiveSticker(
        icon: Icons.photo, label: 'عکس', type: 'photo', color: Colors.indigo),
    _InteractiveSticker(
        icon: Icons.thermostat,
        label: 'آب و هوا',
        type: 'weather',
        color: Colors.amber),
    _InteractiveSticker(
        icon: Icons.calendar_today,
        label: 'تاریخ',
        type: 'date',
        color: Colors.brown),
  ];

  // ایموجی‌ها
  static const List<String> _emojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
    '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '☺️', '😚',
    '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
    '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
    '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
    // قلب‌ها
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
    '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '♥️',
    // دست‌ها
    '👍', '👎', '👊', '✊', '🤛', '🤜', '🤞', '✌️', '🤟', '🤘',
    '👌', '🤌', '🤏', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚',
    '🖐️', '🖖', '👋', '🤙', '💪', '🦾', '🙏', '✍️', '👏', '🙌',
    // طبیعت
    '🌸', '🌹', '🌺', '🌻', '🌼', '🌷', '🌱', '🪴', '🌲', '🌳',
    '🌴', '🍀', '🍁', '🍂', '🍃', '🌿', '☘️', '🪻', '🌵', '🪵',
    // غذا
    '🍕', '🍔', '🌭', '🍟', '🍿', '🧆', '🌯', '🥗', '🍣', '🍱',
    '🍜', '🍝', '🍲', '🥘', '🧁', '🍰', '🎂', '🍩', '🍪', '☕',
    // حیوانات
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
    '🦁', '🐮', '🐷', '🐸', '🐵', '🙈', '🙉', '🙊', '🐔', '🐧',
    // اشیا
    '⭐', '🌟', '✨', '💫', '⚡', '🔥', '💥', '❄️', '🌈', '☀️',
    '🌙', '⭕', '❌', '✅', '❓', '❗', '💯', '🎉', '🎊', '🎁',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onInteractiveStickerTap(_InteractiveSticker sticker) {
    // Premium input sheets handle their own navigation - don't pre-pop
    // Only pop immediately for simple stickers like date
    final sheetsWithOwnNavigation = [
      'location',
      'mention',
      'hashtag',
      'link',
      'poll',
      'questions',
      'countdown',
      'weather', // Uses location picker which handles its own navigation
    ];

    if (!sheetsWithOwnNavigation.contains(sticker.type)) {
      Navigator.pop(context);
    }

    // نمایش دیالوگ مناسب برای هر نوع استیکر
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

  /// نمایش صفحه انتخاب لوکیشن با GPS
  void _showLocationPicker(
      {StoryInteractionType targetType = StoryInteractionType.location}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerSheet(
        onLocationSelected: (locationName, lat, lng) async {
          // شیت انتخاب لوکیشن خودش بسته می‌شود، نیازی به pop مجدد نیست

          int? temperature;
          int? weatherCode;

          // Only fetch weather if needed (for Weather widget)
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

          // Call parent immediately
          if (widget.onInteractiveStickerSelected != null) {
            debugPrint(
                'Adding sticker: $targetType, City: $locationName, Temp: $temperature');
            widget.onInteractiveStickerSelected!(
              targetType,
              {
                'city': locationName,
                'latitude': lat,
                'longitude': lng,
                'temperature': temperature ?? 24, // Fallback
                'weathercode': weatherCode,
              },
            );
          } else {
            widget.onStickerSelected(
                '📍 $locationName ${temperature != null ? "$temperature°" : ""}');
          }

          // بستن شیت اصلی استیکرها
          if (mounted) {
            Navigator.of(context).pop();
          }
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
        onMentionCreated: (type, data) {
          if (widget.onInteractiveStickerSelected != null) {
            widget.onInteractiveStickerSelected!(type, data);
          } else {
            widget.onStickerSelected('@${data['username']}');
          }
        },
      ),
    );
  }

  void _showHashtagDialog() {
    final TextEditingController hashtagController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const Text(
                  'هشتگ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    String value = hashtagController.text.trim();
                    if (value.isNotEmpty) {
                      // Remove # if user added it, we'll add it in the widget
                      if (value.startsWith('#')) {
                        value = value.substring(1);
                      }
                      if (widget.onInteractiveStickerSelected != null) {
                        widget.onInteractiveStickerSelected!(
                          StoryInteractionType.hashtag,
                          {'hashtag': value},
                        );
                      } else {
                        widget.onStickerSelected('#$value');
                      }
                      Navigator.pop(ctx);
                      // Pop the parent sticker sheet
                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'تایید',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Input Field with # prefix
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Row(
                children: [
                  const Text(
                    '#',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: hashtagController,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'هشتگ خود را وارد کنید...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) {
                        value = value.trim();
                        if (value.isNotEmpty) {
                          if (value.startsWith('#')) {
                            value = value.substring(1);
                          }
                          if (widget.onInteractiveStickerSelected != null) {
                            widget.onInteractiveStickerSelected!(
                              StoryInteractionType.hashtag,
                              {'hashtag': value},
                            );
                          } else {
                            widget.onStickerSelected('#$value');
                          }
                          Navigator.pop(ctx);
                          // Pop the parent sticker sheet
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Hint text
            Text(
              'روی استیکر ضربه بزنید تا استایل تغییر کند',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LinkInputSheet(
        onLinkCreated: (type, data) {
          if (widget.onInteractiveStickerSelected != null) {
            widget.onInteractiveStickerSelected!(type, data);
          } else {
            widget.onStickerSelected('🔗 ${data['url']}');
          }
        },
      ),
    );
  }

  void _showPollDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PollInputSheet(
        onPollCreated: (type, data) {
          if (widget.onInteractiveStickerSelected != null) {
            widget.onInteractiveStickerSelected!(type, data);
          } else {
            widget.onStickerSelected(
                '📊 ${data['question']}\n• ${data['option1']}\n• ${data['option2']}');
          }
        },
      ),
    );
  }

  void _showQuestionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuestionsInputSheet(
        onQuestionCreated: (type, data) {
          if (widget.onInteractiveStickerSelected != null) {
            widget.onInteractiveStickerSelected!(type, data);
          } else {
            widget.onStickerSelected('❓ ${data['question']}');
          }
        },
      ),
    );
  }

  void _showCountdownDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CountdownInputSheet(
        onCountdownCreated: (type, data) {
          if (widget.onInteractiveStickerSelected != null) {
            widget.onInteractiveStickerSelected!(type, data);
          } else {
            widget.onStickerSelected('⏱️ ${data['title']}');
          }
        },
      ),
    );
  }

  void _addDateSticker() {
    final now = DateTime.now();
    final persianDate = '${now.year}/${now.month}/${now.day}';
    widget.onStickerSelected('📅 $persianDate');
  }

  void _addWeatherSticker() {
    _showLocationPicker(targetType: StoryInteractionType.weather);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'جستجو',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // استیکرهای تعاملی
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interactiveStickers.map((sticker) {
                      return GestureDetector(
                        onTap: () => _onInteractiveStickerTap(sticker),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sticker.icon,
                                  size: 18, color: sticker.color),
                              const SizedBox(width: 6),
                              Text(
                                sticker.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // عنوان ایموجی‌ها
                  Text(
                    'استیکرهای شما',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grid ایموجی‌ها
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
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
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// مدل استیکر تعاملی
class _InteractiveSticker {
  final IconData icon;
  final String label;
  final String type;
  final Color color;

  const _InteractiveSticker({
    required this.icon,
    required this.label,
    required this.type,
    required this.color,
  });
}
