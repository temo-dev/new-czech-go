// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$conversationsHash() => r'22285d3d26ee1d6b470ba0fe83acaaaa6e147871';

/// See also [conversations].
@ProviderFor(conversations)
final conversationsProvider =
    AutoDisposeStreamProvider<List<DmConversation>>.internal(
  conversations,
  name: r'conversationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$conversationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConversationsRef = AutoDisposeStreamProviderRef<List<DmConversation>>;
String _$chatMessagesHash() => r'd540dde33136aa2ae3b2c6c218ea97b4a94d53ba';

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

/// See also [chatMessages].
@ProviderFor(chatMessages)
const chatMessagesProvider = ChatMessagesFamily();

/// See also [chatMessages].
class ChatMessagesFamily extends Family<AsyncValue<List<ChatMessage>>> {
  /// See also [chatMessages].
  const ChatMessagesFamily();

  /// See also [chatMessages].
  ChatMessagesProvider call(
    String roomId,
  ) {
    return ChatMessagesProvider(
      roomId,
    );
  }

  @override
  ChatMessagesProvider getProviderOverride(
    covariant ChatMessagesProvider provider,
  ) {
    return call(
      provider.roomId,
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

/// See also [chatMessages].
class ChatMessagesProvider
    extends AutoDisposeStreamProvider<List<ChatMessage>> {
  /// See also [chatMessages].
  ChatMessagesProvider(
    String roomId,
  ) : this._internal(
          (ref) => chatMessages(
            ref as ChatMessagesRef,
            roomId,
          ),
          from: chatMessagesProvider,
          name: r'chatMessagesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatMessagesHash,
          dependencies: ChatMessagesFamily._dependencies,
          allTransitiveDependencies:
              ChatMessagesFamily._allTransitiveDependencies,
          roomId: roomId,
        );

  ChatMessagesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  Override overrideWith(
    Stream<List<ChatMessage>> Function(ChatMessagesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChatMessagesProvider._internal(
        (ref) => create(ref as ChatMessagesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<ChatMessage>> createElement() {
    return _ChatMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessagesProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatMessagesRef on AutoDisposeStreamProviderRef<List<ChatMessage>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ChatMessagesProviderElement
    extends AutoDisposeStreamProviderElement<List<ChatMessage>>
    with ChatMessagesRef {
  _ChatMessagesProviderElement(super.provider);

  @override
  String get roomId => (origin as ChatMessagesProvider).roomId;
}

String _$unreadCountHash() => r'1a916cad5bb9d8f38ab920ed5dd136b6d99626e9';

/// See also [unreadCount].
@ProviderFor(unreadCount)
final unreadCountProvider = AutoDisposeProvider<int>.internal(
  unreadCount,
  name: r'unreadCountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$unreadCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadCountRef = AutoDisposeProviderRef<int>;
String _$chatNotifierHash() => r'20c90cc8ad47f230bc1fcfb32f410ed8cba64a5b';

abstract class _$ChatNotifier
    extends BuildlessAutoDisposeNotifier<AsyncValue<void>> {
  late final String roomId;

  AsyncValue<void> build(
    String roomId,
  );
}

/// See also [ChatNotifier].
@ProviderFor(ChatNotifier)
const chatNotifierProvider = ChatNotifierFamily();

/// See also [ChatNotifier].
class ChatNotifierFamily extends Family<AsyncValue<void>> {
  /// See also [ChatNotifier].
  const ChatNotifierFamily();

  /// See also [ChatNotifier].
  ChatNotifierProvider call(
    String roomId,
  ) {
    return ChatNotifierProvider(
      roomId,
    );
  }

  @override
  ChatNotifierProvider getProviderOverride(
    covariant ChatNotifierProvider provider,
  ) {
    return call(
      provider.roomId,
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
  String? get name => r'chatNotifierProvider';
}

/// See also [ChatNotifier].
class ChatNotifierProvider
    extends AutoDisposeNotifierProviderImpl<ChatNotifier, AsyncValue<void>> {
  /// See also [ChatNotifier].
  ChatNotifierProvider(
    String roomId,
  ) : this._internal(
          () => ChatNotifier()..roomId = roomId,
          from: chatNotifierProvider,
          name: r'chatNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatNotifierHash,
          dependencies: ChatNotifierFamily._dependencies,
          allTransitiveDependencies:
              ChatNotifierFamily._allTransitiveDependencies,
          roomId: roomId,
        );

  ChatNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  AsyncValue<void> runNotifierBuild(
    covariant ChatNotifier notifier,
  ) {
    return notifier.build(
      roomId,
    );
  }

  @override
  Override overrideWith(ChatNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatNotifierProvider._internal(
        () => create()..roomId = roomId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ChatNotifier, AsyncValue<void>>
      createElement() {
    return _ChatNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatNotifierProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChatNotifierRef on AutoDisposeNotifierProviderRef<AsyncValue<void>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ChatNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<ChatNotifier, AsyncValue<void>>
    with ChatNotifierRef {
  _ChatNotifierProviderElement(super.provider);

  @override
  String get roomId => (origin as ChatNotifierProvider).roomId;
}

String _$openDmNotifierHash() => r'6504e40b19d5de0a127a896405f47faacaff6cd9';

/// See also [OpenDmNotifier].
@ProviderFor(OpenDmNotifier)
final openDmNotifierProvider =
    AutoDisposeNotifierProvider<OpenDmNotifier, AsyncValue<String?>>.internal(
  OpenDmNotifier.new,
  name: r'openDmNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$openDmNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$OpenDmNotifier = AutoDisposeNotifier<AsyncValue<String?>>;
String _$attachmentUploadNotifierHash() =>
    r'88ee098b198d5f9ac1482604b7fc92f3892ac40e';

abstract class _$AttachmentUploadNotifier
    extends BuildlessAutoDisposeNotifier<AsyncValue<void>> {
  late final String roomId;

  AsyncValue<void> build(
    String roomId,
  );
}

/// See also [AttachmentUploadNotifier].
@ProviderFor(AttachmentUploadNotifier)
const attachmentUploadNotifierProvider = AttachmentUploadNotifierFamily();

/// See also [AttachmentUploadNotifier].
class AttachmentUploadNotifierFamily extends Family<AsyncValue<void>> {
  /// See also [AttachmentUploadNotifier].
  const AttachmentUploadNotifierFamily();

  /// See also [AttachmentUploadNotifier].
  AttachmentUploadNotifierProvider call(
    String roomId,
  ) {
    return AttachmentUploadNotifierProvider(
      roomId,
    );
  }

  @override
  AttachmentUploadNotifierProvider getProviderOverride(
    covariant AttachmentUploadNotifierProvider provider,
  ) {
    return call(
      provider.roomId,
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
  String? get name => r'attachmentUploadNotifierProvider';
}

/// See also [AttachmentUploadNotifier].
class AttachmentUploadNotifierProvider extends AutoDisposeNotifierProviderImpl<
    AttachmentUploadNotifier, AsyncValue<void>> {
  /// See also [AttachmentUploadNotifier].
  AttachmentUploadNotifierProvider(
    String roomId,
  ) : this._internal(
          () => AttachmentUploadNotifier()..roomId = roomId,
          from: attachmentUploadNotifierProvider,
          name: r'attachmentUploadNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$attachmentUploadNotifierHash,
          dependencies: AttachmentUploadNotifierFamily._dependencies,
          allTransitiveDependencies:
              AttachmentUploadNotifierFamily._allTransitiveDependencies,
          roomId: roomId,
        );

  AttachmentUploadNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  AsyncValue<void> runNotifierBuild(
    covariant AttachmentUploadNotifier notifier,
  ) {
    return notifier.build(
      roomId,
    );
  }

  @override
  Override overrideWith(AttachmentUploadNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: AttachmentUploadNotifierProvider._internal(
        () => create()..roomId = roomId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<AttachmentUploadNotifier, AsyncValue<void>>
      createElement() {
    return _AttachmentUploadNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AttachmentUploadNotifierProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AttachmentUploadNotifierRef
    on AutoDisposeNotifierProviderRef<AsyncValue<void>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _AttachmentUploadNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<AttachmentUploadNotifier,
        AsyncValue<void>> with AttachmentUploadNotifierRef {
  _AttachmentUploadNotifierProviderElement(super.provider);

  @override
  String get roomId => (origin as AttachmentUploadNotifierProvider).roomId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
