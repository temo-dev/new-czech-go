// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mock_exam_meta_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mockExamMetaHash() => r'7a2e9e836261a5c3165a2dd646f6b15b64e3d0dc';

/// Fetches the active exam meta (first active exam + its sections).
/// Used by MockTestIntroScreen before an attempt is created.
///
/// Copied from [mockExamMeta].
@ProviderFor(mockExamMeta)
final mockExamMetaProvider = AutoDisposeFutureProvider<ExamMeta>.internal(
  mockExamMeta,
  name: r'mockExamMetaProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mockExamMetaHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MockExamMetaRef = AutoDisposeFutureProviderRef<ExamMeta>;
String _$examMetaHash() => r'9fe4498aaccd963108bd18fe2fcbf4977e7e86ae';

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

/// Fetches a specific exam by ID (or first active if examId is null),
/// including its sections. Used by MockTestIntroScreen when launched
/// from the authenticated ExamCatalogScreen with a known examId.
///
/// Copied from [examMeta].
@ProviderFor(examMeta)
const examMetaProvider = ExamMetaFamily();

/// Fetches a specific exam by ID (or first active if examId is null),
/// including its sections. Used by MockTestIntroScreen when launched
/// from the authenticated ExamCatalogScreen with a known examId.
///
/// Copied from [examMeta].
class ExamMetaFamily extends Family<AsyncValue<ExamMeta>> {
  /// Fetches a specific exam by ID (or first active if examId is null),
  /// including its sections. Used by MockTestIntroScreen when launched
  /// from the authenticated ExamCatalogScreen with a known examId.
  ///
  /// Copied from [examMeta].
  const ExamMetaFamily();

  /// Fetches a specific exam by ID (or first active if examId is null),
  /// including its sections. Used by MockTestIntroScreen when launched
  /// from the authenticated ExamCatalogScreen with a known examId.
  ///
  /// Copied from [examMeta].
  ExamMetaProvider call(
    String? examId,
  ) {
    return ExamMetaProvider(
      examId,
    );
  }

  @override
  ExamMetaProvider getProviderOverride(
    covariant ExamMetaProvider provider,
  ) {
    return call(
      provider.examId,
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
  String? get name => r'examMetaProvider';
}

/// Fetches a specific exam by ID (or first active if examId is null),
/// including its sections. Used by MockTestIntroScreen when launched
/// from the authenticated ExamCatalogScreen with a known examId.
///
/// Copied from [examMeta].
class ExamMetaProvider extends AutoDisposeFutureProvider<ExamMeta> {
  /// Fetches a specific exam by ID (or first active if examId is null),
  /// including its sections. Used by MockTestIntroScreen when launched
  /// from the authenticated ExamCatalogScreen with a known examId.
  ///
  /// Copied from [examMeta].
  ExamMetaProvider(
    String? examId,
  ) : this._internal(
          (ref) => examMeta(
            ref as ExamMetaRef,
            examId,
          ),
          from: examMetaProvider,
          name: r'examMetaProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$examMetaHash,
          dependencies: ExamMetaFamily._dependencies,
          allTransitiveDependencies: ExamMetaFamily._allTransitiveDependencies,
          examId: examId,
        );

  ExamMetaProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.examId,
  }) : super.internal();

  final String? examId;

  @override
  Override overrideWith(
    FutureOr<ExamMeta> Function(ExamMetaRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExamMetaProvider._internal(
        (ref) => create(ref as ExamMetaRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        examId: examId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ExamMeta> createElement() {
    return _ExamMetaProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExamMetaProvider && other.examId == examId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, examId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExamMetaRef on AutoDisposeFutureProviderRef<ExamMeta> {
  /// The parameter `examId` of this provider.
  String? get examId;
}

class _ExamMetaProviderElement
    extends AutoDisposeFutureProviderElement<ExamMeta> with ExamMetaRef {
  _ExamMetaProviderElement(super.provider);

  @override
  String? get examId => (origin as ExamMetaProvider).examId;
}

String _$examAttemptCreatorHash() =>
    r'28e8405212e7875849d752001961a8884b65588b';

/// Creates an exam attempt row and returns its ID.
/// Called when the user taps "Bắt đầu" on MockTestIntroScreen.
///
/// Copied from [ExamAttemptCreator].
@ProviderFor(ExamAttemptCreator)
final examAttemptCreatorProvider = AutoDisposeNotifierProvider<
    ExamAttemptCreator, AsyncValue<String?>>.internal(
  ExamAttemptCreator.new,
  name: r'examAttemptCreatorProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$examAttemptCreatorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ExamAttemptCreator = AutoDisposeNotifier<AsyncValue<String?>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
