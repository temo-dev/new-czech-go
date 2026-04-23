// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$examSessionNotifierHash() =>
    r'86c360eb63ed453544312b0d8b86141607b3f0e8';

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

abstract class _$ExamSessionNotifier
    extends BuildlessAutoDisposeAsyncNotifier<ExamSessionState> {
  late final String attemptId;

  FutureOr<ExamSessionState> build(
    String attemptId,
  );
}

/// See also [ExamSessionNotifier].
@ProviderFor(ExamSessionNotifier)
const examSessionNotifierProvider = ExamSessionNotifierFamily();

/// See also [ExamSessionNotifier].
class ExamSessionNotifierFamily extends Family<AsyncValue<ExamSessionState>> {
  /// See also [ExamSessionNotifier].
  const ExamSessionNotifierFamily();

  /// See also [ExamSessionNotifier].
  ExamSessionNotifierProvider call(
    String attemptId,
  ) {
    return ExamSessionNotifierProvider(
      attemptId,
    );
  }

  @override
  ExamSessionNotifierProvider getProviderOverride(
    covariant ExamSessionNotifierProvider provider,
  ) {
    return call(
      provider.attemptId,
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
  String? get name => r'examSessionNotifierProvider';
}

/// See also [ExamSessionNotifier].
class ExamSessionNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    ExamSessionNotifier, ExamSessionState> {
  /// See also [ExamSessionNotifier].
  ExamSessionNotifierProvider(
    String attemptId,
  ) : this._internal(
          () => ExamSessionNotifier()..attemptId = attemptId,
          from: examSessionNotifierProvider,
          name: r'examSessionNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$examSessionNotifierHash,
          dependencies: ExamSessionNotifierFamily._dependencies,
          allTransitiveDependencies:
              ExamSessionNotifierFamily._allTransitiveDependencies,
          attemptId: attemptId,
        );

  ExamSessionNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.attemptId,
  }) : super.internal();

  final String attemptId;

  @override
  FutureOr<ExamSessionState> runNotifierBuild(
    covariant ExamSessionNotifier notifier,
  ) {
    return notifier.build(
      attemptId,
    );
  }

  @override
  Override overrideWith(ExamSessionNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ExamSessionNotifierProvider._internal(
        () => create()..attemptId = attemptId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        attemptId: attemptId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ExamSessionNotifier, ExamSessionState>
      createElement() {
    return _ExamSessionNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExamSessionNotifierProvider && other.attemptId == attemptId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, attemptId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExamSessionNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<ExamSessionState> {
  /// The parameter `attemptId` of this provider.
  String get attemptId;
}

class _ExamSessionNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ExamSessionNotifier,
        ExamSessionState> with ExamSessionNotifierRef {
  _ExamSessionNotifierProviderElement(super.provider);

  @override
  String get attemptId => (origin as ExamSessionNotifierProvider).attemptId;
}

String _$examTimerNotifierHash() => r'13fb6c0d7eaedfad9132e9f8404a1a4850f46067';

abstract class _$ExamTimerNotifier extends BuildlessAutoDisposeNotifier<int> {
  late final int initialSeconds;

  int build(
    int initialSeconds,
  );
}

/// See also [ExamTimerNotifier].
@ProviderFor(ExamTimerNotifier)
const examTimerNotifierProvider = ExamTimerNotifierFamily();

/// See also [ExamTimerNotifier].
class ExamTimerNotifierFamily extends Family<int> {
  /// See also [ExamTimerNotifier].
  const ExamTimerNotifierFamily();

  /// See also [ExamTimerNotifier].
  ExamTimerNotifierProvider call(
    int initialSeconds,
  ) {
    return ExamTimerNotifierProvider(
      initialSeconds,
    );
  }

  @override
  ExamTimerNotifierProvider getProviderOverride(
    covariant ExamTimerNotifierProvider provider,
  ) {
    return call(
      provider.initialSeconds,
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
  String? get name => r'examTimerNotifierProvider';
}

/// See also [ExamTimerNotifier].
class ExamTimerNotifierProvider
    extends AutoDisposeNotifierProviderImpl<ExamTimerNotifier, int> {
  /// See also [ExamTimerNotifier].
  ExamTimerNotifierProvider(
    int initialSeconds,
  ) : this._internal(
          () => ExamTimerNotifier()..initialSeconds = initialSeconds,
          from: examTimerNotifierProvider,
          name: r'examTimerNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$examTimerNotifierHash,
          dependencies: ExamTimerNotifierFamily._dependencies,
          allTransitiveDependencies:
              ExamTimerNotifierFamily._allTransitiveDependencies,
          initialSeconds: initialSeconds,
        );

  ExamTimerNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.initialSeconds,
  }) : super.internal();

  final int initialSeconds;

  @override
  int runNotifierBuild(
    covariant ExamTimerNotifier notifier,
  ) {
    return notifier.build(
      initialSeconds,
    );
  }

  @override
  Override overrideWith(ExamTimerNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ExamTimerNotifierProvider._internal(
        () => create()..initialSeconds = initialSeconds,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        initialSeconds: initialSeconds,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ExamTimerNotifier, int> createElement() {
    return _ExamTimerNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExamTimerNotifierProvider &&
        other.initialSeconds == initialSeconds;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, initialSeconds.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExamTimerNotifierRef on AutoDisposeNotifierProviderRef<int> {
  /// The parameter `initialSeconds` of this provider.
  int get initialSeconds;
}

class _ExamTimerNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<ExamTimerNotifier, int>
    with ExamTimerNotifierRef {
  _ExamTimerNotifierProviderElement(super.provider);

  @override
  int get initialSeconds =>
      (origin as ExamTimerNotifierProvider).initialSeconds;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
