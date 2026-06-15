// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatMessageEntryHash() => r'2464b50fbccd59303860ac76d88fbef71f9496e5';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Watches a single message entry. Only rebuilds when that message changes.
///
/// Copied from [chatMessageEntry].
@ProviderFor(chatMessageEntry)
const chatMessageEntryProvider = ChatMessageEntryFamily();

/// Watches a single message entry. Only rebuilds when that message changes.
///
/// Copied from [chatMessageEntry].
class ChatMessageEntryFamily extends Family<MessageModel?> {
  /// Watches a single message entry. Only rebuilds when that message changes.
  ///
  /// Copied from [chatMessageEntry].
  const ChatMessageEntryFamily();

  /// Watches a single message entry. Only rebuilds when that message changes.
  ///
  /// Copied from [chatMessageEntry].
  ChatMessageEntryProvider call(
    String conversationId,
    String messageId,
  ) {
    return ChatMessageEntryProvider(
      conversationId,
      messageId,
    );
  }

  @override
  ChatMessageEntryProvider getProviderOverride(
    covariant ChatMessageEntryProvider provider,
  ) {
    return call(
      provider.conversationId,
      provider.messageId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatMessageEntryProvider';
}

/// Watches a single message entry. Only rebuilds when that message changes.
///
/// Copied from [chatMessageEntry].
class ChatMessageEntryProvider extends AutoDisposeProvider<MessageModel?> {
  /// Watches a single message entry. Only rebuilds when that message changes.
  ///
  /// Copied from [chatMessageEntry].
  ChatMessageEntryProvider(
    String conversationId,
    String messageId,
  ) : this._internal(
          (ref) => chatMessageEntry(
            ref as ChatMessageEntryRef,
            conversationId,
            messageId,
          ),
          from: chatMessageEntryProvider,
          name: r'chatMessageEntryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatMessageEntryHash,
          dependencies: ChatMessageEntryFamily._dependencies,
          allTransitiveDependencies:
              ChatMessageEntryFamily._allTransitiveDependencies,
          conversationId: conversationId,
          messageId: messageId,
        );

  ChatMessageEntryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
    required this.messageId,
  }) : super.internal();

  final String conversationId;
  final String messageId;

  @override
  Override overrideWith(
    MessageModel? Function(ChatMessageEntryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChatMessageEntryProvider._internal(
        (ref) => create(ref as ChatMessageEntryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
        messageId: messageId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<MessageModel?> createElement() {
    return _ChatMessageEntryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessageEntryProvider &&
        other.conversationId == conversationId &&
        other.messageId == messageId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);
    hash = _SystemHash.combine(hash, messageId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ChatMessageEntryRef on AutoDisposeProviderRef<MessageModel?> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;

  /// The parameter `messageId` of this provider.
  String get messageId;
}

class _ChatMessageEntryProviderElement
    extends AutoDisposeProviderElement<MessageModel?> with ChatMessageEntryRef {
  _ChatMessageEntryProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ChatMessageEntryProvider).conversationId;
  @override
  String get messageId => (origin as ChatMessageEntryProvider).messageId;
}

String _$chatMessageStoreHash() => r'67e55553552d8d0c33568c799482618b22ffd73c';

abstract class _$ChatMessageStore
    extends BuildlessAutoDisposeNotifier<ChatMessageStoreState> {
  late final String conversationId;

  ChatMessageStoreState build(
    String conversationId,
  );
}

/// See also [ChatMessageStore].
@ProviderFor(ChatMessageStore)
const chatMessageStoreProvider = ChatMessageStoreFamily();

/// See also [ChatMessageStore].
class ChatMessageStoreFamily extends Family<ChatMessageStoreState> {
  /// See also [ChatMessageStore].
  const ChatMessageStoreFamily();

  /// See also [ChatMessageStore].
  ChatMessageStoreProvider call(
    String conversationId,
  ) {
    return ChatMessageStoreProvider(
      conversationId,
    );
  }

  @override
  ChatMessageStoreProvider getProviderOverride(
    covariant ChatMessageStoreProvider provider,
  ) {
    return call(
      provider.conversationId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chatMessageStoreProvider';
}

/// See also [ChatMessageStore].
class ChatMessageStoreProvider extends AutoDisposeNotifierProviderImpl<
    ChatMessageStore, ChatMessageStoreState> {
  /// See also [ChatMessageStore].
  ChatMessageStoreProvider(
    String conversationId,
  ) : this._internal(
          () => ChatMessageStore()..conversationId = conversationId,
          from: chatMessageStoreProvider,
          name: r'chatMessageStoreProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatMessageStoreHash,
          dependencies: ChatMessageStoreFamily._dependencies,
          allTransitiveDependencies:
              ChatMessageStoreFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  ChatMessageStoreProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  ChatMessageStoreState runNotifierBuild(
    covariant ChatMessageStore notifier,
  ) {
    return notifier.build(
      conversationId,
    );
  }

  @override
  Override overrideWith(ChatMessageStore Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatMessageStoreProvider._internal(
        () => create()..conversationId = conversationId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ChatMessageStore, ChatMessageStoreState>
      createElement() {
    return _ChatMessageStoreProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessageStoreProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ChatMessageStoreRef
    on AutoDisposeNotifierProviderRef<ChatMessageStoreState> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ChatMessageStoreProviderElement
    extends AutoDisposeNotifierProviderElement<ChatMessageStore,
        ChatMessageStoreState> with ChatMessageStoreRef {
  _ChatMessageStoreProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ChatMessageStoreProvider).conversationId;
}

String _$conversationChatSelectionHash() =>
    r'87fa1741d830ca80a96e690eaed9228d7b6dc1a2';

abstract class _$ConversationChatSelection
    extends BuildlessAutoDisposeNotifier<ChatSelectionState> {
  late final String conversationId;

  ChatSelectionState build(
    String conversationId,
  );
}

/// See also [ConversationChatSelection].
@ProviderFor(ConversationChatSelection)
const conversationChatSelectionProvider = ConversationChatSelectionFamily();

/// See also [ConversationChatSelection].
class ConversationChatSelectionFamily extends Family<ChatSelectionState> {
  /// See also [ConversationChatSelection].
  const ConversationChatSelectionFamily();

  /// See also [ConversationChatSelection].
  ConversationChatSelectionProvider call(
    String conversationId,
  ) {
    return ConversationChatSelectionProvider(
      conversationId,
    );
  }

  @override
  ConversationChatSelectionProvider getProviderOverride(
    covariant ConversationChatSelectionProvider provider,
  ) {
    return call(
      provider.conversationId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'conversationChatSelectionProvider';
}

/// See also [ConversationChatSelection].
class ConversationChatSelectionProvider extends AutoDisposeNotifierProviderImpl<
    ConversationChatSelection, ChatSelectionState> {
  /// See also [ConversationChatSelection].
  ConversationChatSelectionProvider(
    String conversationId,
  ) : this._internal(
          () => ConversationChatSelection()..conversationId = conversationId,
          from: conversationChatSelectionProvider,
          name: r'conversationChatSelectionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$conversationChatSelectionHash,
          dependencies: ConversationChatSelectionFamily._dependencies,
          allTransitiveDependencies:
              ConversationChatSelectionFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  ConversationChatSelectionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  ChatSelectionState runNotifierBuild(
    covariant ConversationChatSelection notifier,
  ) {
    return notifier.build(
      conversationId,
    );
  }

  @override
  Override overrideWith(ConversationChatSelection Function() create) {
    return ProviderOverride(
      origin: this,
      override: ConversationChatSelectionProvider._internal(
        () => create()..conversationId = conversationId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ConversationChatSelection,
      ChatSelectionState> createElement() {
    return _ConversationChatSelectionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationChatSelectionProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ConversationChatSelectionRef
    on AutoDisposeNotifierProviderRef<ChatSelectionState> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationChatSelectionProviderElement
    extends AutoDisposeNotifierProviderElement<ConversationChatSelection,
        ChatSelectionState> with ConversationChatSelectionRef {
  _ConversationChatSelectionProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationChatSelectionProvider).conversationId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
