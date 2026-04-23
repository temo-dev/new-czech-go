// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_session_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ExamSessionState {
  ExamAttempt get attempt => throw _privateConstructorUsedError;
  ExamMeta get meta => throw _privateConstructorUsedError;
  ExamSessionStatus get status => throw _privateConstructorUsedError;
  Map<String, ExamQuestionAnswer> get currentAnswers =>
      throw _privateConstructorUsedError;
  int get currentSectionIndex => throw _privateConstructorUsedError;
  int get currentQuestionIndex => throw _privateConstructorUsedError;
  bool get showSectionTransition => throw _privateConstructorUsedError;
  AutosaveStatus get autosaveStatus => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Create a copy of ExamSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExamSessionStateCopyWith<ExamSessionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExamSessionStateCopyWith<$Res> {
  factory $ExamSessionStateCopyWith(
          ExamSessionState value, $Res Function(ExamSessionState) then) =
      _$ExamSessionStateCopyWithImpl<$Res, ExamSessionState>;
  @useResult
  $Res call(
      {ExamAttempt attempt,
      ExamMeta meta,
      ExamSessionStatus status,
      Map<String, ExamQuestionAnswer> currentAnswers,
      int currentSectionIndex,
      int currentQuestionIndex,
      bool showSectionTransition,
      AutosaveStatus autosaveStatus,
      String? errorMessage});

  $ExamAttemptCopyWith<$Res> get attempt;
  $ExamMetaCopyWith<$Res> get meta;
}

/// @nodoc
class _$ExamSessionStateCopyWithImpl<$Res, $Val extends ExamSessionState>
    implements $ExamSessionStateCopyWith<$Res> {
  _$ExamSessionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExamSessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attempt = null,
    Object? meta = null,
    Object? status = null,
    Object? currentAnswers = null,
    Object? currentSectionIndex = null,
    Object? currentQuestionIndex = null,
    Object? showSectionTransition = null,
    Object? autosaveStatus = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      attempt: null == attempt
          ? _value.attempt
          : attempt // ignore: cast_nullable_to_non_nullable
              as ExamAttempt,
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as ExamMeta,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ExamSessionStatus,
      currentAnswers: null == currentAnswers
          ? _value.currentAnswers
          : currentAnswers // ignore: cast_nullable_to_non_nullable
              as Map<String, ExamQuestionAnswer>,
      currentSectionIndex: null == currentSectionIndex
          ? _value.currentSectionIndex
          : currentSectionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      currentQuestionIndex: null == currentQuestionIndex
          ? _value.currentQuestionIndex
          : currentQuestionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      showSectionTransition: null == showSectionTransition
          ? _value.showSectionTransition
          : showSectionTransition // ignore: cast_nullable_to_non_nullable
              as bool,
      autosaveStatus: null == autosaveStatus
          ? _value.autosaveStatus
          : autosaveStatus // ignore: cast_nullable_to_non_nullable
              as AutosaveStatus,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of ExamSessionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExamAttemptCopyWith<$Res> get attempt {
    return $ExamAttemptCopyWith<$Res>(_value.attempt, (value) {
      return _then(_value.copyWith(attempt: value) as $Val);
    });
  }

  /// Create a copy of ExamSessionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExamMetaCopyWith<$Res> get meta {
    return $ExamMetaCopyWith<$Res>(_value.meta, (value) {
      return _then(_value.copyWith(meta: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ExamSessionStateImplCopyWith<$Res>
    implements $ExamSessionStateCopyWith<$Res> {
  factory _$$ExamSessionStateImplCopyWith(_$ExamSessionStateImpl value,
          $Res Function(_$ExamSessionStateImpl) then) =
      __$$ExamSessionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ExamAttempt attempt,
      ExamMeta meta,
      ExamSessionStatus status,
      Map<String, ExamQuestionAnswer> currentAnswers,
      int currentSectionIndex,
      int currentQuestionIndex,
      bool showSectionTransition,
      AutosaveStatus autosaveStatus,
      String? errorMessage});

  @override
  $ExamAttemptCopyWith<$Res> get attempt;
  @override
  $ExamMetaCopyWith<$Res> get meta;
}

/// @nodoc
class __$$ExamSessionStateImplCopyWithImpl<$Res>
    extends _$ExamSessionStateCopyWithImpl<$Res, _$ExamSessionStateImpl>
    implements _$$ExamSessionStateImplCopyWith<$Res> {
  __$$ExamSessionStateImplCopyWithImpl(_$ExamSessionStateImpl _value,
      $Res Function(_$ExamSessionStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExamSessionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? attempt = null,
    Object? meta = null,
    Object? status = null,
    Object? currentAnswers = null,
    Object? currentSectionIndex = null,
    Object? currentQuestionIndex = null,
    Object? showSectionTransition = null,
    Object? autosaveStatus = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$ExamSessionStateImpl(
      attempt: null == attempt
          ? _value.attempt
          : attempt // ignore: cast_nullable_to_non_nullable
              as ExamAttempt,
      meta: null == meta
          ? _value.meta
          : meta // ignore: cast_nullable_to_non_nullable
              as ExamMeta,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ExamSessionStatus,
      currentAnswers: null == currentAnswers
          ? _value._currentAnswers
          : currentAnswers // ignore: cast_nullable_to_non_nullable
              as Map<String, ExamQuestionAnswer>,
      currentSectionIndex: null == currentSectionIndex
          ? _value.currentSectionIndex
          : currentSectionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      currentQuestionIndex: null == currentQuestionIndex
          ? _value.currentQuestionIndex
          : currentQuestionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      showSectionTransition: null == showSectionTransition
          ? _value.showSectionTransition
          : showSectionTransition // ignore: cast_nullable_to_non_nullable
              as bool,
      autosaveStatus: null == autosaveStatus
          ? _value.autosaveStatus
          : autosaveStatus // ignore: cast_nullable_to_non_nullable
              as AutosaveStatus,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ExamSessionStateImpl
    with DiagnosticableTreeMixin
    implements _ExamSessionState {
  const _$ExamSessionStateImpl(
      {required this.attempt,
      required this.meta,
      this.status = ExamSessionStatus.ready,
      final Map<String, ExamQuestionAnswer> currentAnswers = const {},
      this.currentSectionIndex = 0,
      this.currentQuestionIndex = 0,
      this.showSectionTransition = false,
      this.autosaveStatus = AutosaveStatus.idle,
      this.errorMessage})
      : _currentAnswers = currentAnswers;

  @override
  final ExamAttempt attempt;
  @override
  final ExamMeta meta;
  @override
  @JsonKey()
  final ExamSessionStatus status;
  final Map<String, ExamQuestionAnswer> _currentAnswers;
  @override
  @JsonKey()
  Map<String, ExamQuestionAnswer> get currentAnswers {
    if (_currentAnswers is EqualUnmodifiableMapView) return _currentAnswers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_currentAnswers);
  }

  @override
  @JsonKey()
  final int currentSectionIndex;
  @override
  @JsonKey()
  final int currentQuestionIndex;
  @override
  @JsonKey()
  final bool showSectionTransition;
  @override
  @JsonKey()
  final AutosaveStatus autosaveStatus;
  @override
  final String? errorMessage;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ExamSessionState(attempt: $attempt, meta: $meta, status: $status, currentAnswers: $currentAnswers, currentSectionIndex: $currentSectionIndex, currentQuestionIndex: $currentQuestionIndex, showSectionTransition: $showSectionTransition, autosaveStatus: $autosaveStatus, errorMessage: $errorMessage)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ExamSessionState'))
      ..add(DiagnosticsProperty('attempt', attempt))
      ..add(DiagnosticsProperty('meta', meta))
      ..add(DiagnosticsProperty('status', status))
      ..add(DiagnosticsProperty('currentAnswers', currentAnswers))
      ..add(DiagnosticsProperty('currentSectionIndex', currentSectionIndex))
      ..add(DiagnosticsProperty('currentQuestionIndex', currentQuestionIndex))
      ..add(DiagnosticsProperty('showSectionTransition', showSectionTransition))
      ..add(DiagnosticsProperty('autosaveStatus', autosaveStatus))
      ..add(DiagnosticsProperty('errorMessage', errorMessage));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExamSessionStateImpl &&
            (identical(other.attempt, attempt) || other.attempt == attempt) &&
            (identical(other.meta, meta) || other.meta == meta) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._currentAnswers, _currentAnswers) &&
            (identical(other.currentSectionIndex, currentSectionIndex) ||
                other.currentSectionIndex == currentSectionIndex) &&
            (identical(other.currentQuestionIndex, currentQuestionIndex) ||
                other.currentQuestionIndex == currentQuestionIndex) &&
            (identical(other.showSectionTransition, showSectionTransition) ||
                other.showSectionTransition == showSectionTransition) &&
            (identical(other.autosaveStatus, autosaveStatus) ||
                other.autosaveStatus == autosaveStatus) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      attempt,
      meta,
      status,
      const DeepCollectionEquality().hash(_currentAnswers),
      currentSectionIndex,
      currentQuestionIndex,
      showSectionTransition,
      autosaveStatus,
      errorMessage);

  /// Create a copy of ExamSessionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExamSessionStateImplCopyWith<_$ExamSessionStateImpl> get copyWith =>
      __$$ExamSessionStateImplCopyWithImpl<_$ExamSessionStateImpl>(
          this, _$identity);
}

abstract class _ExamSessionState implements ExamSessionState {
  const factory _ExamSessionState(
      {required final ExamAttempt attempt,
      required final ExamMeta meta,
      final ExamSessionStatus status,
      final Map<String, ExamQuestionAnswer> currentAnswers,
      final int currentSectionIndex,
      final int currentQuestionIndex,
      final bool showSectionTransition,
      final AutosaveStatus autosaveStatus,
      final String? errorMessage}) = _$ExamSessionStateImpl;

  @override
  ExamAttempt get attempt;
  @override
  ExamMeta get meta;
  @override
  ExamSessionStatus get status;
  @override
  Map<String, ExamQuestionAnswer> get currentAnswers;
  @override
  int get currentSectionIndex;
  @override
  int get currentQuestionIndex;
  @override
  bool get showSectionTransition;
  @override
  AutosaveStatus get autosaveStatus;
  @override
  String? get errorMessage;

  /// Create a copy of ExamSessionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExamSessionStateImplCopyWith<_$ExamSessionStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
