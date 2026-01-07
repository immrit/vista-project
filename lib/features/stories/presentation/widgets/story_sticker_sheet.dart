import 'package:flutter/material.dart';
import 'location_picker_sheet.dart';

/// Bottom Sheet استیکرهای تعاملی (مشابه اینستاگرام)
class StoryStickerSheet extends StatefulWidget {
  final Function(String content) onStickerSelected;

  const StoryStickerSheet({super.key, required this.onStickerSelected});

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
    Navigator.pop(context);
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
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerSheet(
        onLocationSelected: (locationName, lat, lng) {
          widget.onStickerSelected('📍 $locationName');
        },
      ),
    );
  }

  void _showMentionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('منشن کاربر'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'نام کاربری را وارد کنید',
            prefixIcon: Icon(Icons.alternate_email),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onStickerSelected('@$value');
              Navigator.pop(ctx);
            }
          },
        ),
      ),
    );
  }

  void _showHashtagDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هشتگ'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'هشتگ را وارد کنید',
            prefixIcon: Icon(Icons.tag),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onStickerSelected('#$value');
              Navigator.pop(ctx);
            }
          },
        ),
      ),
    );
  }

  void _showLinkDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('لینک'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'آدرس لینک را وارد کنید',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onStickerSelected('🔗 $value');
              Navigator.pop(ctx);
            }
          },
        ),
      ),
    );
  }

  void _showPollDialog() {
    String question = '';
    String option1 = '';
    String option2 = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نظرسنجی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'سوال نظرسنجی'),
              onChanged: (v) => question = v,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(hintText: 'گزینه ۱'),
              onChanged: (v) => option1 = v,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(hintText: 'گزینه ۲'),
              onChanged: (v) => option2 = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (question.isNotEmpty &&
                  option1.isNotEmpty &&
                  option2.isNotEmpty) {
                widget
                    .onStickerSelected('📊 $question\n• $option1\n• $option2');
                Navigator.pop(ctx);
              }
            },
            child: const Text('اضافه کن'),
          ),
        ],
      ),
    );
  }

  void _showQuestionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سوالات'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'سوال خود را بنویسید',
            prefixIcon: Icon(Icons.help_outline),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onStickerSelected('❓ $value');
              Navigator.pop(ctx);
            }
          },
        ),
      ),
    );
  }

  void _showCountdownDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شمارش معکوس'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'نام رویداد',
            prefixIcon: Icon(Icons.timer),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onStickerSelected('⏱️ $value');
              Navigator.pop(ctx);
            }
          },
        ),
      ),
    );
  }

  void _addDateSticker() {
    final now = DateTime.now();
    final persianDate = '${now.year}/${now.month}/${now.day}';
    widget.onStickerSelected('📅 $persianDate');
  }

  void _addWeatherSticker() {
    widget.onStickerSelected('🌤️ تهران 12°C');
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
