// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatRepositoryHash() => r'86af3b87c4fc6b41bdb61f51adfff0eebe1c8d4f';

/// See also [chatRepository].
@ProviderFor(chatRepository)
final chatRepositoryProvider = AutoDisposeProvider<ChatRepository>.internal(
  chatRepository,
  name: r'chatRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ChatRepositoryRef = AutoDisposeProviderRef<ChatRepository>;
String _$paginationStateHash() => r'b0f82b60262234e52d7e3ed7a1043ccfd32b93dc';

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

/// See also [paginationState].
@ProviderFor(paginationState)
const paginationStateProvider = PaginationStateFamily();

/// See also [paginationState].
class PaginationStateFamily extends Family<PaginationState> {
  /// See also [paginationState].
  const PaginationStateFamily();

  /// See also [paginationState].
  PaginationStateProvider call(
    String conversationId,
  ) {
    return PaginationStateProvider(
      conversationId,
    );
  }

  @override
  PaginationStateProvider getProviderOverride(
    covariant PaginationStateProvider provider,
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
  String? get name => r'paginationStateProvider';
}

/// See also [paginationState].
class PaginationStateProvider extends AutoDisposeProvider<PaginationState> {
  /// See also [paginationState].
  PaginationStateProvider(
    String conversationId,
  ) : this._internal(
          (ref) => paginationState(
            ref as PaginationStateRef,
            conversationId,
          ),
          from: paginationStateProvider,
          name: r'paginationStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$paginationStateHash,
          dependencies: PaginationStateFamily._dependencies,
          allTransitiveDependencies:
              PaginationStateFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  PaginationStateProvider._internal(
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
  Override overrideWith(
    PaginationState Function(PaginationStateRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PaginationStateProvider._internal(
        (ref) => create(ref as PaginationStateRef),
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
  AutoDisposeProviderElement<PaginationState> createElement() {
    return _PaginationStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PaginationStateProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PaginationStateRef on AutoDisposeProviderRef<PaginationState> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _PaginationStateProviderElement
    extends AutoDisposeProviderElement<PaginationState>
    with PaginationStateRef {
  _PaginationStateProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as PaginationStateProvider).conversationId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
