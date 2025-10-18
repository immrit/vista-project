class CurrentChatTracker {
  CurrentChatTracker._internal();
  static final CurrentChatTracker instance = CurrentChatTracker._internal();

  String? _openConversationId;

  String? get openConversationId => _openConversationId;

  void setOpenConversation(String conversationId) {
    _openConversationId = conversationId;
  }

  void clearOpenConversation() {
    _openConversationId = null;
  }
}

