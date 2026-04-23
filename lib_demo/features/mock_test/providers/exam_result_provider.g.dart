// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_result_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$examResultHash() => r'b09c34c0db683d409bc709b3559893fb60fc214d';

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

/// See also [examResult].
@ProviderFor(examResult)
const examResultProvider = ExamResultFamily();

/// See also [examResult].
class ExamResultFamily extends Family<AsyncValue<MockTestResult>> {
  /// See also [examResult].
  const ExamResultFamily();

  /// See also [examResult].
  ExamResultProvider call(
    String attemptId,
  ) {
    return ExamResultProvider(
      attemptId,
    );
  }

  @override
  ExamResultProvider getProviderOverride(
    covariant ExamResultProvider provider,
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
  String? get name => r'examResultProvider';
}

/// See also [examResult].
class ExamResultProvider extends AutoDisposeFutureProvider<MockTestResult> {
  /// See also [examResult].
  ExamResultProvider(
    String attemptId,
  ) : this._internal(
          (ref) => examResult(
            ref as ExamResultRef,
            attemptId,
          ),
          from: examResultProvider,
          name: r'examResultProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$examResultHash,
          dependencies: ExamResultFamily._dependencies,
          allTransitiveDependencies:
              ExamResultFamily._allTransitiveDependencies,
          attemptId: attemptId,
        );

  ExamResultProvider._internal(
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
  Override overrideWith(
    FutureOr<MockTestResult> Function(ExamResultRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExamResultProvider._internal(
        (ref) => create(ref as ExamResultRef),
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
  AutoDisposeFutureProviderElement<MockTestResult> createElement() {
    return _ExamResultProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExamResultProvider && other.attemptId == attemptId;
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
mixin ExamResultRef on AutoDisposeFutureProviderRef<MockTestResult> {
  /// The parameter `attemptId` of this provider.
  String get attemptId;
}

class _ExamResultProviderElement
    extends AutoDisposeFutureProviderElement<MockTestResult>
    with ExamResultRef {
  _ExamResultProviderElement(super.provider);

  @override
  String get attemptId => (origin as ExamResultProvider).attemptId;
}

String _$examReviewHash() => r'e8bbd04bba50051b7f92e9f1ffadd72f70ec2d8c';

/// See also [examReview].
@ProviderFor(examReview)
const examReviewProvider = ExamReviewFamily();

/// See also [examReview].
class ExamReviewFamily extends Family<AsyncValue<List<QuestionReviewItem>>> {
  /// See also [examReview].
  const ExamReviewFamily();

  /// See also [examReview].
  ExamReviewProvider call(
    String attemptId,
  ) {
    return ExamReviewProvider(
      attemptId,
    );
  }

  @override
  ExamReviewProvider getProviderOverride(
    covariant ExamReviewProvider provider,
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
  String? get name => r'examReviewProvider';
}

/// See also [examReview].
class ExamReviewProvider
    extends AutoDisposeFutureProvider<List<QuestionReviewItem>> {
  /// See also [examReview].
  ExamReviewProvider(
    String attemptId,
  ) : this._internal(
          (ref) => examReview(
            ref as ExamReviewRef,
            attemptId,
          ),
          from: examReviewProvider,
          name: r'examReviewProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$examReviewHash,
          dependencies: ExamReviewFamily._dependencies,
          allTransitiveDependencies:
              ExamReviewFamily._allTransitiveDependencies,
          attemptId: attemptId,
        );

  ExamReviewProvider._internal(
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
  Override overrideWith(
    FutureOr<List<QuestionReviewItem>> Function(ExamReviewRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExamReviewProvider._internal(
        (ref) => create(ref as ExamReviewRef),
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
  AutoDisposeFutureProviderElement<List<QuestionReviewItem>> createElement() {
    return _ExamReviewProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExamReviewProvider && other.attemptId == attemptId;
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
mixin ExamReviewRef on AutoDisposeFutureProviderRef<List<QuestionReviewItem>> {
  /// The parameter `attemptId` of this provider.
  String get attemptId;
}

class _ExamReviewProviderElement
    extends AutoDisposeFutureProviderElement<List<QuestionReviewItem>>
    with ExamReviewRef {
  _ExamReviewProviderElement(super.provider);

  @override
  String get attemptId => (origin as ExamReviewProvider).attemptId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
