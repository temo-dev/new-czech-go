// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_analysis_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$examAnalysisHash() => r'28ec0878827d2b900e5e9a6d1a3849c1af871ffe';

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

/// See also [examAnalysis].
@ProviderFor(examAnalysis)
const examAnalysisProvider = ExamAnalysisFamily();

/// See also [examAnalysis].
class ExamAnalysisFamily extends Family<AsyncValue<ExamAnalysis?>> {
  /// See also [examAnalysis].
  const ExamAnalysisFamily();

  /// See also [examAnalysis].
  ExamAnalysisProvider call(
    String attemptId,
  ) {
    return ExamAnalysisProvider(
      attemptId,
    );
  }

  @override
  ExamAnalysisProvider getProviderOverride(
    covariant ExamAnalysisProvider provider,
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
  String? get name => r'examAnalysisProvider';
}

/// See also [examAnalysis].
class ExamAnalysisProvider extends AutoDisposeFutureProvider<ExamAnalysis?> {
  /// See also [examAnalysis].
  ExamAnalysisProvider(
    String attemptId,
  ) : this._internal(
          (ref) => examAnalysis(
            ref as ExamAnalysisRef,
            attemptId,
          ),
          from: examAnalysisProvider,
          name: r'examAnalysisProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$examAnalysisHash,
          dependencies: ExamAnalysisFamily._dependencies,
          allTransitiveDependencies:
              ExamAnalysisFamily._allTransitiveDependencies,
          attemptId: attemptId,
        );

  ExamAnalysisProvider._internal(
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
    FutureOr<ExamAnalysis?> Function(ExamAnalysisRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExamAnalysisProvider._internal(
        (ref) => create(ref as ExamAnalysisRef),
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
  AutoDisposeFutureProviderElement<ExamAnalysis?> createElement() {
    return _ExamAnalysisProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExamAnalysisProvider && other.attemptId == attemptId;
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
mixin ExamAnalysisRef on AutoDisposeFutureProviderRef<ExamAnalysis?> {
  /// The parameter `attemptId` of this provider.
  String get attemptId;
}

class _ExamAnalysisProviderElement
    extends AutoDisposeFutureProviderElement<ExamAnalysis?>
    with ExamAnalysisRef {
  _ExamAnalysisProviderElement(super.provider);

  @override
  String get attemptId => (origin as ExamAnalysisProvider).attemptId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
