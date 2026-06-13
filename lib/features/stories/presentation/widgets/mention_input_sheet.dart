import 'package:flutter/material.dart';
import '../../domain/entities/story_editor_models.dart';

/// Premium Mention Input Sheet (Social-style)
class MentionInputSheet extends StatefulWidget {
  final Function(StoryInteractionType, Map<String, dynamic>) onMentionCreated;

  const MentionInputSheet({super.key, required this.onMentionCreated});

  @override
  State<MentionInputSheet> createState() => _MentionInputSheetState();
}

class _MentionInputSheetState extends State<MentionInputSheet> {
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: bottomPadding + 24,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              const Spacer(),
              const Text(
                'منشن کاربر',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Vazir',
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _usernameController.text.isNotEmpty ? _submit : null,
                child: Text(
                  'تایید',
                  style: TextStyle(
                    color: _usernameController.text.isNotEmpty
                        ? Colors.blue
                        : Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Live Preview
          Center(
            child: _buildLivePreview(),
          ),
          const SizedBox(height: 32),

          // Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF58529), Color(0xFFDD2A7B)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '@',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'نام کاربری...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_usernameController.text.isNotEmpty) _submit();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Hint
          Text(
            'روی استیکر ضربه بزنید تا استایل تغییر کند',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final username = _usernameController.text.isEmpty
        ? 'username'
        : _usernameController.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDD2A7B).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        '@$username',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
          fontFamily: 'Vazir',
        ),
      ),
    );
  }

  void _submit() {
    String username = _usernameController.text.trim();
    if (username.startsWith('@')) {
      username = username.substring(1);
    }

    widget.onMentionCreated(
      StoryInteractionType.mention,
      {
        'username': username,
        'style': 0,
      },
    );
    // Pop this sheet
    Navigator.pop(context);
    // Pop the parent sticker sheet
    Navigator.pop(context);
  }
}
