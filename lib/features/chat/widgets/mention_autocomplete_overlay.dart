// lib/features/chat/widgets/mention_autocomplete_overlay.dart
//
// Overlay for displaying mention (@user) and hashtag (#tag) suggestions
//

import 'package:flutter/material.dart';
import '../../../model/ProfileModel.dart';

/// A suggestion item for autocomplete
class AutocompleteSuggestion {
  final String value; // The actual value to insert (@username or #tag)
  final String displayName;
  final String? avatarUrl;
  final String type; // '@' or '#'

  const AutocompleteSuggestion({
    required this.value,
    required this.displayName,
    this.avatarUrl,
    required this.type,
  });

  factory AutocompleteSuggestion.fromProfile(ProfileModel profile) {
    return AutocompleteSuggestion(
      value: '@${profile.username}',
      displayName:
          profile.fullName.isNotEmpty ? profile.fullName : profile.username,
      avatarUrl: profile.avatarUrl,
      type: '@',
    );
  }

  factory AutocompleteSuggestion.hashtag(String tag) {
    return AutocompleteSuggestion(
      value: '#$tag',
      displayName: tag,
      type: '#',
    );
  }
}

/// Overlay widget for displaying autocomplete suggestions
class MentionAutocompleteOverlay extends StatelessWidget {
  final List<AutocompleteSuggestion> suggestions;
  final Function(AutocompleteSuggestion) onSelect;
  final bool isLoading;

  const MentionAutocompleteOverlay({
    super.key,
    required this.suggestions,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return _buildSuggestionTile(suggestion, textColor, isDark);
              },
            ),
    );
  }

  Widget _buildSuggestionTile(
      AutocompleteSuggestion suggestion, Color textColor, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(suggestion),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Avatar or icon
              if (suggestion.type == '@')
                CircleAvatar(
                  radius: 18,
                  backgroundImage: suggestion.avatarUrl != null
                      ? NetworkImage(suggestion.avatarUrl!)
                      : null,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  child: suggestion.avatarUrl == null
                      ? Icon(Icons.person, size: 18, color: textColor)
                      : null,
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tag, size: 18, color: Colors.blue),
                ),
              const SizedBox(width: 12),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.displayName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (suggestion.type == '@')
                      Text(
                        suggestion.value,
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
