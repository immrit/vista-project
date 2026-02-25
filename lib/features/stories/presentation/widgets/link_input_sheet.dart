import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';
import 'glass_layer.dart';

/// Premium Link Input Sheet (Instagram-style)
class LinkInputSheet extends StatefulWidget {
  final Function(StoryInteractionType, Map<String, dynamic>) onLinkCreated;

  const LinkInputSheet({super.key, required this.onLinkCreated});

  @override
  State<LinkInputSheet> createState() => _LinkInputSheetState();
}

class _LinkInputSheetState extends State<LinkInputSheet> {
  final _urlController = TextEditingController();
  final _labelController = TextEditingController();
  int _selectedStyle = 0;

  static const List<Color> _colors = [
    Color(0xFF2196F3), // Blue
    Color(0xFFE91E63), // Pink
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF000000), // Black
    Color(0xFFFFFFFF), // White
  ];
  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _urlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const Spacer(),
                const Text(
                  'افزودن لینک',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _urlController.text.isNotEmpty ? _submit : null,
                  child: Text(
                    'تایید',
                    style: TextStyle(
                      color: _urlController.text.isNotEmpty
                          ? Colors.blue
                          : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.grey, height: 1),

          // Live Preview
          Expanded(
            child: Center(
              child: _buildLivePreview(),
            ),
          ),

          // Input Fields
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: bottomPadding + 20,
            ),
            child: Column(
              children: [
                // URL Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _urlController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'https://example.com',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.link, color: Colors.blue),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),

                // Label Input (CTA)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _labelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'متن دکمه (اختیاری): مثلاً "خرید کنید"',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon:
                          const Icon(Icons.text_fields, color: Colors.purple),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 20),

                // Style Selector
                _buildStyleSelector(),
                const SizedBox(height: 16),

                // Color Selector
                _buildColorSelector(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final url = _urlController.text.isEmpty
        ? 'example.com'
        : _urlController.text
            .replaceFirst('https://', '')
            .replaceFirst('http://', '');
    final label = _labelController.text.isEmpty ? url : _labelController.text;
    final color = _colors[_selectedColorIndex];

    switch (_selectedStyle) {
      case 1: // Glass
        return GlassLayer(
          borderRadius: BorderRadius.circular(20),
          blur: 15,
          opacity: 0.5,
          baseColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: 'Vazir',
                ),
              ),
            ],
          ),
        );
      case 2: // Pill/Light
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Vazir',
                ),
              ),
            ],
          ),
        );
      case 0: // Gradient (Default)
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Vazir',
                    ),
                  ),
                  Text(
                    'tap to visit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 14),
            ],
          ),
        );
    }
  }

  Widget _buildStyleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _styleButton(0, 'گرادینت', Icons.gradient),
        _styleButton(1, 'شیشه‌ای', Icons.blur_on),
        _styleButton(2, 'ساده', Icons.circle_outlined),
      ],
    );
  }

  Widget _styleButton(int index, String label, IconData icon) {
    final isSelected = _selectedStyle == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Vazir',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final color = _colors[index];
          final isSelected = _selectedColorIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedColorIndex = index),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _submit() {
    if (_urlController.text.isEmpty) return;

    widget.onLinkCreated(
      StoryInteractionType.link,
      {
        'url': _urlController.text,
        'label': _labelController.text.isEmpty ? null : _labelController.text,
        'style': _selectedStyle,
        'colorIndex': _selectedColorIndex,
      },
    );
    // Pop this sheet
    Navigator.pop(context);
    // Pop the parent sticker sheet
    Navigator.pop(context);
  }
}
