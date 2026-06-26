import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';
import 'glass_layer.dart';

/// Premium Poll Input Sheet (Social-style)
class PollInputSheet extends StatefulWidget {
  final Function(StoryInteractionType, Map<String, dynamic>) onPollCreated;

  const PollInputSheet({super.key, required this.onPollCreated});

  @override
  State<PollInputSheet> createState() => _PollInputSheetState();
}

class _PollInputSheetState extends State<PollInputSheet> {
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController(text: 'بله');
  final _option2Controller = TextEditingController(text: 'خیر');
  int _selectedStyle = 0;

  @override
  void dispose() {
    _questionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                  'نظرسنجی',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _canSubmit() ? _submit : null,
                  child: Text(
                    'تایید',
                    style: TextStyle(
                      color: _canSubmit() ? Colors.blue : Colors.grey,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildLivePreview(),
                  const SizedBox(height: 30),

                  // Input Fields
                  _buildInputSection(),
                ],
              ),
            ),
          ),

          // Style Selector
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: bottomPadding + 20,
              top: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: _buildStyleSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final question = _questionController.text.isEmpty
        ? 'سوال شما؟'
        : _questionController.text;
    final option1 =
        _option1Controller.text.isEmpty ? 'گزینه ۱' : _option1Controller.text;
    final option2 =
        _option2Controller.text.isEmpty ? 'گزینه ۲' : _option2Controller.text;

    switch (_selectedStyle) {
      case 1: // Dark Neon
        return _buildDarkNeonPreview(question, option1, option2);
      case 2: // Minimal
        return _buildMinimalPreview(question, option1, option2);
      case 0: // Standard White
      default:
        return _buildStandardPreview(question, option1, option2);
    }
  }

  Widget _buildStandardPreview(
      String question, String option1, String option2) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Vazirmatn',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildOptionButton(option1, Colors.grey[100]!, Colors.black),
          const SizedBox(height: 10),
          _buildOptionButton(option2, Colors.grey[100]!, Colors.black),
        ],
      ),
    );
  }

  Widget _buildDarkNeonPreview(
      String question, String option1, String option2) {
    return GlassLayer(
      borderRadius: BorderRadius.circular(20),
      blur: 15,
      opacity: 0.7,
      baseColor: Colors.black,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 260,
        child: Column(
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Vazirmatn',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildOptionButton(
                option1, Colors.purple.withValues(alpha: 0.3), Colors.white),
            const SizedBox(height: 10),
            _buildOptionButton(
                option2, Colors.cyan.withValues(alpha: 0.3), Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalPreview(String question, String option1, String option2) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              fontFamily: 'Vazirmatn',
            ),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    option1,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey),
              Expanded(
                child: Center(
                  child: Text(
                    option2,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String text, Color bgColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Vazirmatn',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question Input
        Text(
          'سوال',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _questionController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'سوال خود را بنویسید...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.poll, color: Colors.orange),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 20),

        // Options
        Text(
          'گزینه‌ها',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _option1Controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'گزینه ۱',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _option2Controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'گزینه ۲',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _styleButton(0, 'سفید', Icons.wb_sunny),
        _styleButton(1, 'نئون', Icons.nightlight_round),
        _styleButton(2, 'مینیمال', Icons.crop_square),
      ],
    );
  }

  Widget _styleButton(int index, String label, IconData icon) {
    final isSelected = _selectedStyle == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    return _questionController.text.isNotEmpty &&
        _option1Controller.text.isNotEmpty &&
        _option2Controller.text.isNotEmpty;
  }

  void _submit() {
    widget.onPollCreated(
      StoryInteractionType.poll,
      {
        'question': _questionController.text,
        'option1': _option1Controller.text,
        'option2': _option2Controller.text,
        'style': _selectedStyle,
      },
    );
    // Pop this sheet
    Navigator.pop(context);
    // Pop the parent sticker sheet
    Navigator.pop(context);
  }
}
