// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mock_test_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SectionResult _$SectionResultFromJson(Map<String, dynamic> json) {
  return _SectionResult.fromJson(json);
}

/// @nodoc
mixin _$SectionResult {
  int get score => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

  /// Serializes this SectionResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SectionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SectionResultCopyWith<SectionResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SectionResultCopyWith<$Res> {
  factory $SectionResultCopyWith(
          SectionResult value, $Res Function(SectionResult) then) =
      _$SectionResultCopyWithImpl<$Res, SectionResult>;
  @useResult
  $Res call({int score, int total});
}

/// @nodoc
class _$SectionResultCopyWithImpl<$Res, $Val extends SectionResult>
    implements $SectionResultCopyWith<$Res> {
  _$SectionResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SectionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? score = null,
    Object? total = null,
  }) {
    return _then(_value.copyWith(
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SectionResultImplCopyWith<$Res>
    implements $SectionResultCopyWith<$Res> {
  factory _$$SectionResultImplCopyWith(
          _$SectionResultImpl value, $Res Function(_$SectionResultImpl) then) =
      __$$SectionResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int score, int total});
}

/// @nodoc
class __$$SectionResultImplCopyWithImpl<$Res>
    extends _$SectionResultCopyWithImpl<$Res, _$SectionResultImpl>
    implements _$$SectionResultImplCopyWith<$Res> {
  __$$SectionResultImplCopyWithImpl(
      _$SectionResultImpl _value, $Res Function(_$SectionResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of SectionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? score = null,
    Object? total = null,
  }) {
    return _then(_$SectionResultImpl(
      score: null == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SectionResultImpl implements _SectionResult {
  const _$SectionResultImpl({required this.score, required this.total});

  factory _$SectionResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$SectionResultImplFromJson(json);

  @override
  final int score;
  @override
  final int total;

  @override
  String toString() {
    return 'SectionResult(score: $score, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SectionResultImpl &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.total, total) || other.total == total));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, score, total);

  /// Create a copy of SectionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SectionResultImplCopyWith<_$SectionResultImpl> get copyWith =>
      __$$SectionResultImplCopyWithImpl<_$SectionResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SectionResultImplToJson(
      this,
    );
  }
}

abstract class _SectionResult implements SectionResult {
  const factory _SectionResult(
      {required final int score,
      required final int total}) = _$SectionResultImpl;

  factory _SectionResult.fromJson(Map<String, dynamic> json) =
      _$SectionResultImpl.fromJson;

  @override
  int get score;
  @override
  int get total;

  /// Create a copy of SectionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SectionResultImplCopyWith<_$SectionResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MockTestResult _$MockTestResultFromJson(Map<String, dynamic> json) {
  return _MockTestResult.fromJson(json);
}

/// @nodoc
mixin _$MockTestResult {
  String get id => throw _privateConstructorUsedError;
  String get attemptId => throw _privateConstructorUsedError;
  String? get userId => throw _privateConstructorUsedError;
  int get totalScore => throw _privateConstructorUsedError; // 0–100
  int get passThreshold => throw _privateConstructorUsedError;
  Map<String, SectionResult> get sectionScores =>
      throw _privateConstructorUsedError;
  List<String> get weakSkills => throw _privateConstructorUsedError;
  bool get passed => throw _privateConstructorUsedError;
  int get writtenScore => throw _privateConstructorUsedError;
  int get writtenTotal => throw _privateConstructorUsedError;
  int get writtenPassThreshold => throw _privateConstructorUsedError;
  int get speakingScore => throw _privateConstructorUsedError;
  int get speakingTotal => throw _privateConstructorUsedError;
  int get speakingPassThreshold => throw _privateConstructorUsedError;
  bool get aiGradingPending => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this MockTestResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MockTestResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MockTestResultCopyWith<MockTestResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MockTestResultCopyWith<$Res> {
  factory $MockTestResultCopyWith(
          MockTestResult value, $Res Function(MockTestResult) then) =
      _$MockTestResultCopyWithImpl<$Res, MockTestResult>;
  @useResult
  $Res call(
      {String id,
      String attemptId,
      String? userId,
      int totalScore,
      int passThreshold,
      Map<String, SectionResult> sectionScores,
      List<String> weakSkills,
      bool passed,
      int writtenScore,
      int writtenTotal,
      int writtenPassThreshold,
      int speakingScore,
      int speakingTotal,
      int speakingPassThreshold,
      bool aiGradingPending,
      DateTime createdAt});
}

/// @nodoc
class _$MockTestResultCopyWithImpl<$Res, $Val extends MockTestResult>
    implements $MockTestResultCopyWith<$Res> {
  _$MockTestResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MockTestResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? attemptId = null,
    Object? userId = freezed,
    Object? totalScore = null,
    Object? passThreshold = null,
    Object? sectionScores = null,
    Object? weakSkills = null,
    Object? passed = null,
    Object? writtenScore = null,
    Object? writtenTotal = null,
    Object? writtenPassThreshold = null,
    Object? speakingScore = null,
    Object? speakingTotal = null,
    Object? speakingPassThreshold = null,
    Object? aiGradingPending = null,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      attemptId: null == attemptId
          ? _value.attemptId
          : attemptId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      totalScore: null == totalScore
          ? _value.totalScore
          : totalScore // ignore: cast_nullable_to_non_nullable
              as int,
      passThreshold: null == passThreshold
          ? _value.passThreshold
          : passThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      sectionScores: null == sectionScores
          ? _value.sectionScores
          : sectionScores // ignore: cast_nullable_to_non_nullable
              as Map<String, SectionResult>,
      weakSkills: null == weakSkills
          ? _value.weakSkills
          : weakSkills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      passed: null == passed
          ? _value.passed
          : passed // ignore: cast_nullable_to_non_nullable
              as bool,
      writtenScore: null == writtenScore
          ? _value.writtenScore
          : writtenScore // ignore: cast_nullable_to_non_nullable
              as int,
      writtenTotal: null == writtenTotal
          ? _value.writtenTotal
          : writtenTotal // ignore: cast_nullable_to_non_nullable
              as int,
      writtenPassThreshold: null == writtenPassThreshold
          ? _value.writtenPassThreshold
          : writtenPassThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      speakingScore: null == speakingScore
          ? _value.speakingScore
          : speakingScore // ignore: cast_nullable_to_non_nullable
              as int,
      speakingTotal: null == speakingTotal
          ? _value.speakingTotal
          : speakingTotal // ignore: cast_nullable_to_non_nullable
              as int,
      speakingPassThreshold: null == speakingPassThreshold
          ? _value.speakingPassThreshold
          : speakingPassThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      aiGradingPending: null == aiGradingPending
          ? _value.aiGradingPending
          : aiGradingPending // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MockTestResultImplCopyWith<$Res>
    implements $MockTestResultCopyWith<$Res> {
  factory _$$MockTestResultImplCopyWith(_$MockTestResultImpl value,
          $Res Function(_$MockTestResultImpl) then) =
      __$$MockTestResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String attemptId,
      String? userId,
      int totalScore,
      int passThreshold,
      Map<String, SectionResult> sectionScores,
      List<String> weakSkills,
      bool passed,
      int writtenScore,
      int writtenTotal,
      int writtenPassThreshold,
      int speakingScore,
      int speakingTotal,
      int speakingPassThreshold,
      bool aiGradingPending,
      DateTime createdAt});
}

/// @nodoc
class __$$MockTestResultImplCopyWithImpl<$Res>
    extends _$MockTestResultCopyWithImpl<$Res, _$MockTestResultImpl>
    implements _$$MockTestResultImplCopyWith<$Res> {
  __$$MockTestResultImplCopyWithImpl(
      _$MockTestResultImpl _value, $Res Function(_$MockTestResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of MockTestResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? attemptId = null,
    Object? userId = freezed,
    Object? totalScore = null,
    Object? passThreshold = null,
    Object? sectionScores = null,
    Object? weakSkills = null,
    Object? passed = null,
    Object? writtenScore = null,
    Object? writtenTotal = null,
    Object? writtenPassThreshold = null,
    Object? speakingScore = null,
    Object? speakingTotal = null,
    Object? speakingPassThreshold = null,
    Object? aiGradingPending = null,
    Object? createdAt = null,
  }) {
    return _then(_$MockTestResultImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      attemptId: null == attemptId
          ? _value.attemptId
          : attemptId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      totalScore: null == totalScore
          ? _value.totalScore
          : totalScore // ignore: cast_nullable_to_non_nullable
              as int,
      passThreshold: null == passThreshold
          ? _value.passThreshold
          : passThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      sectionScores: null == sectionScores
          ? _value._sectionScores
          : sectionScores // ignore: cast_nullable_to_non_nullable
              as Map<String, SectionResult>,
      weakSkills: null == weakSkills
          ? _value._weakSkills
          : weakSkills // ignore: cast_nullable_to_non_nullable
              as List<String>,
      passed: null == passed
          ? _value.passed
          : passed // ignore: cast_nullable_to_non_nullable
              as bool,
      writtenScore: null == writtenScore
          ? _value.writtenScore
          : writtenScore // ignore: cast_nullable_to_non_nullable
              as int,
      writtenTotal: null == writtenTotal
          ? _value.writtenTotal
          : writtenTotal // ignore: cast_nullable_to_non_nullable
              as int,
      writtenPassThreshold: null == writtenPassThreshold
          ? _value.writtenPassThreshold
          : writtenPassThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      speakingScore: null == speakingScore
          ? _value.speakingScore
          : speakingScore // ignore: cast_nullable_to_non_nullable
              as int,
      speakingTotal: null == speakingTotal
          ? _value.speakingTotal
          : speakingTotal // ignore: cast_nullable_to_non_nullable
              as int,
      speakingPassThreshold: null == speakingPassThreshold
          ? _value.speakingPassThreshold
          : speakingPassThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      aiGradingPending: null == aiGradingPending
          ? _value.aiGradingPending
          : aiGradingPending // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MockTestResultImpl implements _MockTestResult {
  const _$MockTestResultImpl(
      {required this.id,
      required this.attemptId,
      this.userId,
      required this.totalScore,
      required this.passThreshold,
      final Map<String, SectionResult> sectionScores = const {},
      final List<String> weakSkills = const [],
      this.passed = false,
      this.writtenScore = 0,
      this.writtenTotal = 70,
      this.writtenPassThreshold = 42,
      this.speakingScore = 0,
      this.speakingTotal = 40,
      this.speakingPassThreshold = 24,
      this.aiGradingPending = false,
      required this.createdAt})
      : _sectionScores = sectionScores,
        _weakSkills = weakSkills;

  factory _$MockTestResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$MockTestResultImplFromJson(json);

  @override
  final String id;
  @override
  final String attemptId;
  @override
  final String? userId;
  @override
  final int totalScore;
// 0–100
  @override
  final int passThreshold;
  final Map<String, SectionResult> _sectionScores;
  @override
  @JsonKey()
  Map<String, SectionResult> get sectionScores {
    if (_sectionScores is EqualUnmodifiableMapView) return _sectionScores;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_sectionScores);
  }

  final List<String> _weakSkills;
  @override
  @JsonKey()
  List<String> get weakSkills {
    if (_weakSkills is EqualUnmodifiableListView) return _weakSkills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weakSkills);
  }

  @override
  @JsonKey()
  final bool passed;
  @override
  @JsonKey()
  final int writtenScore;
  @override
  @JsonKey()
  final int writtenTotal;
  @override
  @JsonKey()
  final int writtenPassThreshold;
  @override
  @JsonKey()
  final int speakingScore;
  @override
  @JsonKey()
  final int speakingTotal;
  @override
  @JsonKey()
  final int speakingPassThreshold;
  @override
  @JsonKey()
  final bool aiGradingPending;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'MockTestResult(id: $id, attemptId: $attemptId, userId: $userId, totalScore: $totalScore, passThreshold: $passThreshold, sectionScores: $sectionScores, weakSkills: $weakSkills, passed: $passed, writtenScore: $writtenScore, writtenTotal: $writtenTotal, writtenPassThreshold: $writtenPassThreshold, speakingScore: $speakingScore, speakingTotal: $speakingTotal, speakingPassThreshold: $speakingPassThreshold, aiGradingPending: $aiGradingPending, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MockTestResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.attemptId, attemptId) ||
                other.attemptId == attemptId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.totalScore, totalScore) ||
                other.totalScore == totalScore) &&
            (identical(other.passThreshold, passThreshold) ||
                other.passThreshold == passThreshold) &&
            const DeepCollectionEquality()
                .equals(other._sectionScores, _sectionScores) &&
            const DeepCollectionEquality()
                .equals(other._weakSkills, _weakSkills) &&
            (identical(other.passed, passed) || other.passed == passed) &&
            (identical(other.writtenScore, writtenScore) ||
                other.writtenScore == writtenScore) &&
            (identical(other.writtenTotal, writtenTotal) ||
                other.writtenTotal == writtenTotal) &&
            (identical(other.writtenPassThreshold, writtenPassThreshold) ||
                other.writtenPassThreshold == writtenPassThreshold) &&
            (identical(other.speakingScore, speakingScore) ||
                other.speakingScore == speakingScore) &&
            (identical(other.speakingTotal, speakingTotal) ||
                other.speakingTotal == speakingTotal) &&
            (identical(other.speakingPassThreshold, speakingPassThreshold) ||
                other.speakingPassThreshold == speakingPassThreshold) &&
            (identical(other.aiGradingPending, aiGradingPending) ||
                other.aiGradingPending == aiGradingPending) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      attemptId,
      userId,
      totalScore,
      passThreshold,
      const DeepCollectionEquality().hash(_sectionScores),
      const DeepCollectionEquality().hash(_weakSkills),
      passed,
      writtenScore,
      writtenTotal,
      writtenPassThreshold,
      speakingScore,
      speakingTotal,
      speakingPassThreshold,
      aiGradingPending,
      createdAt);

  /// Create a copy of MockTestResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MockTestResultImplCopyWith<_$MockTestResultImpl> get copyWith =>
      __$$MockTestResultImplCopyWithImpl<_$MockTestResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MockTestResultImplToJson(
      this,
    );
  }
}

abstract class _MockTestResult implements MockTestResult {
  const factory _MockTestResult(
      {required final String id,
      required final String attemptId,
      final String? userId,
      required final int totalScore,
      required final int passThreshold,
      final Map<String, SectionResult> sectionScores,
      final List<String> weakSkills,
      final bool passed,
      final int writtenScore,
      final int writtenTotal,
      final int writtenPassThreshold,
      final int speakingScore,
      final int speakingTotal,
      final int speakingPassThreshold,
      final bool aiGradingPending,
      required final DateTime createdAt}) = _$MockTestResultImpl;

  factory _MockTestResult.fromJson(Map<String, dynamic> json) =
      _$MockTestResultImpl.fromJson;

  @override
  String get id;
  @override
  String get attemptId;
  @override
  String? get userId;
  @override
  int get totalScore; // 0–100
  @override
  int get passThreshold;
  @override
  Map<String, SectionResult> get sectionScores;
  @override
  List<String> get weakSkills;
  @override
  bool get passed;
  @override
  int get writtenScore;
  @override
  int get writtenTotal;
  @override
  int get writtenPassThreshold;
  @override
  int get speakingScore;
  @override
  int get speakingTotal;
  @override
  int get speakingPassThreshold;
  @override
  bool get aiGradingPending;
  @override
  DateTime get createdAt;

  /// Create a copy of MockTestResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MockTestResultImplCopyWith<_$MockTestResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
