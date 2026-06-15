// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_messages_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatMessagesHash() => r'ae476ea3280daf1c67724dcb6163c49e4a661dbf';

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

abstract class _$ChatMessages
    extends BuildlessAutoDisposeAsyncNotifier<List<MessageModel>> {
  late final String conversationId;

  FutureOr<List<MessageModel>> build(
    String conversationId,
  );
}

/// See also [ChatMessages].
@ProviderFor(ChatMessages)
const chatMessagesProvider = ChatMessagesFamily();

/// See also [ChatMessages].
class ChatMessagesFamily extends Family<AsyncValue<List<MessageModel>>> {
  /// See also [ChatMessages].
  const ChatMessagesFamily();

  /// See also [ChatMessages].
  ChatMessagesProvider call(
    String conversationId,
  ) {
    return ChatMessagesProvider(
      conversationId,
    );
  }

  @override
  ChatMessagesProvider getProviderOverride(
    covariant ChatMessagesProvider provider,
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
  String? get name => r'chatMessagesProvider';
}

/// See also [ChatMessages].
class ChatMessagesProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ChatMessages, List<MessageModel>> {
  /// See also [ChatMessages].
  ChatMessagesProvider(
    String conversationId,
  ) : this._internal(
          () => ChatMessages()..conversationId = conversationId,
          from: chatMessagesProvider,
          name: r'chatMessagesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatMessagesHash,
          dependencies: ChatMessagesFamily._dependencies,
          allTransitiveDependencies:
              ChatMessagesFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  ChatMessagesProvider._internal(
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
  FutureOr<List<MessageModel>> runNotifierBuild(
    covariant ChatMessages notifier,
  ) {
    return notifier.build(
      conversationId,
    );
  }

  @override
  Override overrideWith(ChatMessages Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatMessagesProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<ChatMessages, List<MessageModel>>
      createElement() {
    return _ChatMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ChatMessagesRef
    on AutoDisposeAsyncNotifierProviderRef<List<MessageModel>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ChatMessagesProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ChatMessages,
        List<MessageModel>> with ChatMessagesRef {
  _ChatMessagesProviderElement(super.provider);

  @override
  String get conversationId => (origin as ChatMessagesProvider).conversationId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
