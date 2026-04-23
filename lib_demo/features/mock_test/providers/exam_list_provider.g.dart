// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$examListHash() => r'2f0306f863c0bc29acb080a4b36c37db54910c0c';

/// Fetches all active exams for the catalog (no sections — catalog view only).
///
/// Copied from [examList].
@ProviderFor(examList)
final examListProvider = AutoDisposeFutureProvider<List<ExamMeta>>.internal(
  examList,
  name: r'examListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$examListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExamListRef = AutoDisposeFutureProviderRef<List<ExamMeta>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
