// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_attempt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ExamAttempt _$ExamAttemptFromJson(Map<String, dynamic> json) {
  return _ExamAttempt.fromJson(json);
}

/// @nodoc
mixin _$ExamAttempt {
  String get id => throw _privateConstructorUsedError;
  String get examId => throw _privateConstructorUsedError;
  String? get userId =>
      throw _privateConstructorUsedError; // null = anonymous guest
  String get status =>
      throw _privateConstructorUsedError; // 'in_progress' | 'submitted'
  Map<String, dynamic> get answers => throw _privateConstructorUsedError;
  int? get remainingSeconds => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get submittedAt => throw _privateConstructorUsedError;

  /// Serializes this ExamAttempt to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExamAttempt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExamAttemptCopyWith<ExamAttempt> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExamAttemptCopyWith<$Res> {
  factory $ExamAttemptCopyWith(
          ExamAttempt value, $Res Function(ExamAttempt) then) =
      _$ExamAttemptCopyWithImpl<$Res, ExamAttempt>;
  @useResult
  $Res call(
      {String id,
      String examId,
      String? userId,
      String status,
      Map<String, dynamic> answers,
      int? remainingSeconds,
      DateTime? startedAt,
      DateTime? submittedAt});
}

/// @nodoc
class _$ExamAttemptCopyWithImpl<$Res, $Val extends ExamAttempt>
    implements $ExamAttemptCopyWith<$Res> {
  _$ExamAttemptCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExamAttempt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? examId = null,
    Object? userId = freezed,
    Object? status = null,
    Object? answers = null,
    Object? remainingSeconds = freezed,
    Object? startedAt = freezed,
    Object? submittedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      examId: null == examId
          ? _value.examId
          : examId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      answers: null == answers
          ? _value.answers
          : answers // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      remainingSeconds: freezed == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      submittedAt: freezed == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExamAttemptImplCopyWith<$Res>
    implements $ExamAttemptCopyWith<$Res> {
  factory _$$ExamAttemptImplCopyWith(
          _$ExamAttemptImpl value, $Res Function(_$ExamAttemptImpl) then) =
      __$$ExamAttemptImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String examId,
      String? userId,
      String status,
      Map<String, dynamic> answers,
      int? remainingSeconds,
      DateTime? startedAt,
      DateTime? submittedAt});
}

/// @nodoc
class __$$ExamAttemptImplCopyWithImpl<$Res>
    extends _$ExamAttemptCopyWithImpl<$Res, _$ExamAttemptImpl>
    implements _$$ExamAttemptImplCopyWith<$Res> {
  __$$ExamAttemptImplCopyWithImpl(
      _$ExamAttemptImpl _value, $Res Function(_$ExamAttemptImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExamAttempt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? examId = null,
    Object? userId = freezed,
    Object? status = null,
    Object? answers = null,
    Object? remainingSeconds = freezed,
    Object? startedAt = freezed,
    Object? submittedAt = freezed,
  }) {
    return _then(_$ExamAttemptImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      examId: null == examId
          ? _value.examId
          : examId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: freezed == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      answers: null == answers
          ? _value._answers
          : answers // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      remainingSeconds: freezed == remainingSeconds
          ? _value.remainingSeconds
          : remainingSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      submittedAt: freezed == submittedAt
          ? _value.submittedAt
          : submittedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExamAttemptImpl implements _ExamAttempt {
  const _$ExamAttemptImpl(
      {required this.id,
      required this.examId,
      this.userId,
      required this.status,
      final Map<String, dynamic> answers = const {},
      this.remainingSeconds,
      this.startedAt,
      this.submittedAt})
      : _answers = answers;

  factory _$ExamAttemptImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExamAttemptImplFromJson(json);

  @override
  final String id;
  @override
  final String examId;
  @override
  final String? userId;
// null = anonymous guest
  @override
  final String status;
// 'in_progress' | 'submitted'
  final Map<String, dynamic> _answers;
// 'in_progress' | 'submitted'
  @override
  @JsonKey()
  Map<String, dynamic> get answers {
    if (_answers is EqualUnmodifiableMapView) return _answers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_answers);
  }

  @override
  final int? remainingSeconds;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? submittedAt;

  @override
  String toString() {
    return 'ExamAttempt(id: $id, examId: $examId, userId: $userId, status: $status, answers: $answers, remainingSeconds: $remainingSeconds, startedAt: $startedAt, submittedAt: $submittedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExamAttemptImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.examId, examId) || other.examId == examId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._answers, _answers) &&
            (identical(other.remainingSeconds, remainingSeconds) ||
                other.remainingSeconds == remainingSeconds) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      examId,
      userId,
      status,
      const DeepCollectionEquality().hash(_answers),
      remainingSeconds,
      startedAt,
      submittedAt);

  /// Create a copy of ExamAttempt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExamAttemptImplCopyWith<_$ExamAttemptImpl> get copyWith =>
      __$$ExamAttemptImplCopyWithImpl<_$ExamAttemptImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExamAttemptImplToJson(
      this,
    );
  }
}

abstract class _ExamAttempt implements ExamAttempt {
  const factory _ExamAttempt(
      {required final String id,
      required final String examId,
      final String? userId,
      required final String status,
      final Map<String, dynamic> answers,
      final int? remainingSeconds,
      final DateTime? startedAt,
      final DateTime? submittedAt}) = _$ExamAttemptImpl;

  factory _ExamAttempt.fromJson(Map<String, dynamic> json) =
      _$ExamAttemptImpl.fromJson;

  @override
  String get id;
  @override
  String get examId;
  @override
  String? get userId; // null = anonymous guest
  @override
  String get status; // 'in_progress' | 'submitted'
  @override
  Map<String, dynamic> get answers;
  @override
  int? get remainingSeconds;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get submittedAt;

  /// Create a copy of ExamAttempt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExamAttemptImplCopyWith<_$ExamAttemptImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
