class CurrentChatTracker {
  CurrentChatTracker._internal();
  static final CurrentChatTracker instance = CurrentChatTracker._internal();

  String? _openConversationId;
  DateTime? _lastHeartbeatAt;

  String? get openConversationId => _openConversationId;

  void setOpenConversation(String conversationId) {
    if (conversationId.isEmpty) return;
    _openConversationId = conversationId;
    _lastHeartbeatAt = DateTime.now();
  }

  void heartbeat([String? conversationId]) {
    if (conversationId != null &&
        conversationId.isNotEmpty &&
        _openConversationId != conversationId) {
      _openConversationId = conversationId;
    }
    if (_openConversationId != null) {
      _lastHeartbeatAt = DateTime.now();
    }
  }

  bool isConversationActive(
    String conversationId, {
    Duration maxAge = const Duration(minutes: 2),
  }) {
    if (_openConversationId != conversationId) return false;
    if (_lastHeartbeatAt == null) return false;
    return DateTime.now().difference(_lastHeartbeatAt!) <= maxAge;
  }

  void clearOpenConversation() {
    _openConversationId = null;
    _lastHeartbeatAt = null;
  }
}
