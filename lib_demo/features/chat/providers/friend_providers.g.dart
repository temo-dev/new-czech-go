// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendsHash() => r'961779e4be61ad8d690d7ea302f6588220bd6cbb';

/// See also [friends].
@ProviderFor(friends)
final friendsProvider = AutoDisposeStreamProvider<List<UserProfile>>.internal(
  friends,
  name: r'friendsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$friendsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendsRef = AutoDisposeStreamProviderRef<List<UserProfile>>;
String _$pendingRequestsHash() => r'3fafc26840988ececfb601a2506df46bef298eb5';

/// See also [pendingRequests].
@ProviderFor(pendingRequests)
final pendingRequestsProvider =
    AutoDisposeStreamProvider<List<UserProfile>>.internal(
  pendingRequests,
  name: r'pendingRequestsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingRequestsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingRequestsRef = AutoDisposeStreamProviderRef<List<UserProfile>>;
String _$searchUsersHash() => r'46710ee05217792401538cb4cd390e93c2df9805';

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

/// See also [searchUsers].
@ProviderFor(searchUsers)
const searchUsersProvider = SearchUsersFamily();

/// See also [searchUsers].
class SearchUsersFamily extends Family<AsyncValue<List<UserProfile>>> {
  /// See also [searchUsers].
  const SearchUsersFamily();

  /// See also [searchUsers].
  SearchUsersProvider call(
    String query,
  ) {
    return SearchUsersProvider(
      query,
    );
  }

  @override
  SearchUsersProvider getProviderOverride(
    covariant SearchUsersProvider provider,
  ) {
    return call(
      provider.query,
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
  String? get name => r'searchUsersProvider';
}

/// See also [searchUsers].
class SearchUsersProvider extends AutoDisposeFutureProvider<List<UserProfile>> {
  /// See also [searchUsers].
  SearchUsersProvider(
    String query,
  ) : this._internal(
          (ref) => searchUsers(
            ref as SearchUsersRef,
            query,
          ),
          from: searchUsersProvider,
          name: r'searchUsersProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$searchUsersHash,
          dependencies: SearchUsersFamily._dependencies,
          allTransitiveDependencies:
              SearchUsersFamily._allTransitiveDependencies,
          query: query,
        );

  SearchUsersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<List<UserProfile>> Function(SearchUsersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SearchUsersProvider._internal(
        (ref) => create(ref as SearchUsersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<UserProfile>> createElement() {
    return _SearchUsersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchUsersProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SearchUsersRef on AutoDisposeFutureProviderRef<List<UserProfile>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _SearchUsersProviderElement
    extends AutoDisposeFutureProviderElement<List<UserProfile>>
    with SearchUsersRef {
  _SearchUsersProviderElement(super.provider);

  @override
  String get query => (origin as SearchUsersProvider).query;
}

String _$friendshipNotifierHash() =>
    r'24b4458c1f930508cbed5bb285786115e9491c68';

/// See also [FriendshipNotifier].
@ProviderFor(FriendshipNotifier)
final friendshipNotifierProvider =
    AutoDisposeNotifierProvider<FriendshipNotifier, AsyncValue<void>>.internal(
  FriendshipNotifier.new,
  name: r'friendshipNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$friendshipNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FriendshipNotifier = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
