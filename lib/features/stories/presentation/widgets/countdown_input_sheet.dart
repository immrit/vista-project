import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

/// Premium Countdown Input Sheet
class CountdownInputSheet extends StatefulWidget {
  final Function(StoryInteractionType, Map<String, dynamic>) onCountdownCreated;

  const CountdownInputSheet({super.key, required this.onCountdownCreated});

  @override
  State<CountdownInputSheet> createState() => _CountdownInputSheetState();
}

class _CountdownInputSheetState extends State<CountdownInputSheet> {
  final _titleController = TextEditingController(text: 'شمارش معکوس');
  DateTime _targetDate = DateTime.now().add(const Duration(days: 1));
  int _selectedStyle = 0;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  'شمارش معکوس',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _submit,
                  child: const Text(
                    'تایید',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.grey, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Live Preview
                  _buildLivePreview(),
                  const SizedBox(height: 30),

                  // Title Input
                  _buildTitleInput(),
                  const SizedBox(height: 20),

                  // Date Picker
                  _buildDatePicker(),
                  const SizedBox(height: 20),

                  // Style Selector
                  _buildStyleSelector(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final title =
        _titleController.text.isEmpty ? 'رویداد' : _titleController.text;
    final diff = _targetDate.difference(DateTime.now());
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    switch (_selectedStyle) {
      case 1: // Neon
        return _buildNeonPreview(title, days, hours, minutes);
      case 2: // Minimal
        return _buildMinimalPreview(title, days, hours, minutes);
      case 0: // Standard
      default:
        return _buildStandardPreview(title, days, hours, minutes);
    }
  }

  Widget _buildStandardPreview(String title, int days, int hours, int minutes) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BCD4), Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF009688).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazir',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeBox('$days', 'روز'),
              const SizedBox(width: 8),
              const Text(':',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(width: 8),
              _buildTimeBox('$hours', 'ساعت'),
              const SizedBox(width: 8),
              const Text(':',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(width: 8),
              _buildTimeBox('$minutes', 'دقیقه'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeonPreview(String title, int days, int hours, int minutes) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.3),
            blurRadius: 25,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazir',
              shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$days روز : $hours ساعت : $minutes دقیقه',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Vazir',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalPreview(String title, int days, int hours, int minutes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazir',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${days}d ${hours}h ${minutes}m',
            style: const TextStyle(
              color: Colors.teal,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'Vazir',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('عنوان رویداد',
            style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'مثلاً: تولد، سفر، ...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.event, color: Colors.teal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('تاریخ هدف',
            style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.teal),
                const SizedBox(width: 12),
                Text(
                  '${_targetDate.year}/${_targetDate.month}/${_targetDate.day}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('استایل', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _styleButton(0, 'استاندارد', Icons.timer),
            _styleButton(1, 'نئون', Icons.nightlight),
            _styleButton(2, 'مینیمال', Icons.crop_square),
          ],
        ),
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
          color: isSelected ? Colors.teal : Colors.grey[800],
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              surface: Color(0xFF303030),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _submit() {
    widget.onCountdownCreated(
      StoryInteractionType.countdown,
      {
        'title': _titleController.text,
        'targetDate': _targetDate.toIso8601String(),
        'style': _selectedStyle,
      },
    );
    // Pop this sheet
    Navigator.pop(context);
    // Pop the parent sticker sheet
    Navigator.pop(context);
  }
}
