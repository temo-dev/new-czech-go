// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_result_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ExamResult _$ExamResultFromJson(Map<String, dynamic> json) {
  return _ExamResult.fromJson(json);
}

/// @nodoc
mixin _$ExamResult {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  ExamType get type => throw _privateConstructorUsedError;
  int get totalScore => throw _privateConstructorUsedError; // 0–100
  int get totalQuestions => throw _privateConstructorUsedError;
  int get correctAnswers => throw _privateConstructorUsedError;
  Map<String, int> get sectionScores =>
      throw _privateConstructorUsedError; // skill → score
  Map<String, int> get sectionTotals => throw _privateConstructorUsedError;
  List<QuestionAnswer> get answers => throw _privateConstructorUsedError;
  DateTime get completedAt => throw _privateConstructorUsedError;
  int get passThreshold =>
      throw _privateConstructorUsedError; // minimum passing score
  List<String> get weakSkills =>
      throw _privateConstructorUsedError; // skills below threshold
  bool get passed => throw _privateConstructorUsedError;
  int get writtenScore => throw _privateConstructorUsedError;
  int get writtenTotal => throw _privateConstructorUsedError;
  int get writtenPassThreshold => throw _privateConstructorUsedError;
  int get speakingScore => throw _privateConstructorUsedError;
  int get speakingTotal => throw _privateConstructorUsedError;
  int get speakingPassThreshold => throw _privateConstructorUsedError;
  String? get recommendation =>
      throw _privateConstructorUsedError; // suggested next lesson/module
  int? get totalTimeSeconds => throw _privateConstructorUsedError;

  /// Serializes this ExamResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExamResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExamResultCopyWith<ExamResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExamResultCopyWith<$Res> {
  factory $ExamResultCopyWith(
          ExamResult value, $Res Function(ExamResult) then) =
      _$ExamResultCopyWithImpl<$Res, ExamResult>;
  @useResult
  $Res call(
      {String id,
      String userId,
      ExamType type,
      int totalScore,
      int totalQuestions,
      int correctAnswers,
      Map<String, int> sectionScores,
      Map<String, int> sectionTotals,
      List<QuestionAnswer> answers,
      DateTime completedAt,
      int passThreshold,
      List<String> weakSkills,
      bool passed,
      int writtenScore,
      int writtenTotal,
      int writtenPassThreshold,
      int speakingScore,
      int speakingTotal,
      int speakingPassThreshold,
      String? recommendation,
      int? totalTimeSeconds});
}

/// @nodoc
class _$ExamResultCopyWithImpl<$Res, $Val extends ExamResult>
    implements $ExamResultCopyWith<$Res> {
  _$ExamResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExamResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? type = null,
    Object? totalScore = null,
    Object? totalQuestions = null,
    Object? correctAnswers = null,
    Object? sectionScores = null,
    Object? sectionTotals = null,
    Object? answers = null,
    Object? completedAt = null,
    Object? passThreshold = null,
    Object? weakSkills = null,
    Object? passed = null,
    Object? writtenScore = null,
    Object? writtenTotal = null,
    Object? writtenPassThreshold = null,
    Object? speakingScore = null,
    Object? speakingTotal = null,
    Object? speakingPassThreshold = null,
    Object? recommendation = freezed,
    Object? totalTimeSeconds = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ExamType,
      totalScore: null == totalScore
          ? _value.totalScore
          : totalScore // ignore: cast_nullable_to_non_nullable
              as int,
      totalQuestions: null == totalQuestions
          ? _value.totalQuestions
          : totalQuestions // ignore: cast_nullable_to_non_nullable
              as int,
      correctAnswers: null == correctAnswers
          ? _value.correctAnswers
          : correctAnswers // ignore: cast_nullable_to_non_nullable
              as int,
      sectionScores: null == sectionScores
          ? _value.sectionScores
          : sectionScores // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      sectionTotals: null == sectionTotals
          ? _value.sectionTotals
          : sectionTotals // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      answers: null == answers
          ? _value.answers
          : answers // ignore: cast_nullable_to_non_nullable
              as List<QuestionAnswer>,
      completedAt: null == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      passThreshold: null == passThreshold
          ? _value.passThreshold
          : passThreshold // ignore: cast_nullable_to_non_nullable
              as int,
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
      recommendation: freezed == recommendation
          ? _value.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as String?,
      totalTimeSeconds: freezed == totalTimeSeconds
          ? _value.totalTimeSeconds
          : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExamResultImplCopyWith<$Res>
    implements $ExamResultCopyWith<$Res> {
  factory _$$ExamResultImplCopyWith(
          _$ExamResultImpl value, $Res Function(_$ExamResultImpl) then) =
      __$$ExamResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String userId,
      ExamType type,
      int totalScore,
      int totalQuestions,
      int correctAnswers,
      Map<String, int> sectionScores,
      Map<String, int> sectionTotals,
      List<QuestionAnswer> answers,
      DateTime completedAt,
      int passThreshold,
      List<String> weakSkills,
      bool passed,
      int writtenScore,
      int writtenTotal,
      int writtenPassThreshold,
      int speakingScore,
      int speakingTotal,
      int speakingPassThreshold,
      String? recommendation,
      int? totalTimeSeconds});
}

/// @nodoc
class __$$ExamResultImplCopyWithImpl<$Res>
    extends _$ExamResultCopyWithImpl<$Res, _$ExamResultImpl>
    implements _$$ExamResultImplCopyWith<$Res> {
  __$$ExamResultImplCopyWithImpl(
      _$ExamResultImpl _value, $Res Function(_$ExamResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExamResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? type = null,
    Object? totalScore = null,
    Object? totalQuestions = null,
    Object? correctAnswers = null,
    Object? sectionScores = null,
    Object? sectionTotals = null,
    Object? answers = null,
    Object? completedAt = null,
    Object? passThreshold = null,
    Object? weakSkills = null,
    Object? passed = null,
    Object? writtenScore = null,
    Object? writtenTotal = null,
    Object? writtenPassThreshold = null,
    Object? speakingScore = null,
    Object? speakingTotal = null,
    Object? speakingPassThreshold = null,
    Object? recommendation = freezed,
    Object? totalTimeSeconds = freezed,
  }) {
    return _then(_$ExamResultImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ExamType,
      totalScore: null == totalScore
          ? _value.totalScore
          : totalScore // ignore: cast_nullable_to_non_nullable
              as int,
      totalQuestions: null == totalQuestions
          ? _value.totalQuestions
          : totalQuestions // ignore: cast_nullable_to_non_nullable
              as int,
      correctAnswers: null == correctAnswers
          ? _value.correctAnswers
          : correctAnswers // ignore: cast_nullable_to_non_nullable
              as int,
      sectionScores: null == sectionScores
          ? _value._sectionScores
          : sectionScores // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      sectionTotals: null == sectionTotals
          ? _value._sectionTotals
          : sectionTotals // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      answers: null == answers
          ? _value._answers
          : answers // ignore: cast_nullable_to_non_nullable
              as List<QuestionAnswer>,
      completedAt: null == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      passThreshold: null == passThreshold
          ? _value.passThreshold
          : passThreshold // ignore: cast_nullable_to_non_nullable
              as int,
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
      recommendation: freezed == recommendation
          ? _value.recommendation
          : recommendation // ignore: cast_nullable_to_non_nullable
              as String?,
      totalTimeSeconds: freezed == totalTimeSeconds
          ? _value.totalTimeSeconds
          : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExamResultImpl implements _ExamResult {
  const _$ExamResultImpl(
      {required this.id,
      required this.userId,
      required this.type,
      required this.totalScore,
      required this.totalQuestions,
      required this.correctAnswers,
      required final Map<String, int> sectionScores,
      required final Map<String, int> sectionTotals,
      required final List<QuestionAnswer> answers,
      required this.completedAt,
      this.passThreshold = 60,
      final List<String> weakSkills = const [],
      this.passed = false,
      this.writtenScore = 0,
      this.writtenTotal = 70,
      this.writtenPassThreshold = 42,
      this.speakingScore = 0,
      this.speakingTotal = 40,
      this.speakingPassThreshold = 24,
      this.recommendation,
      this.totalTimeSeconds})
      : _sectionScores = sectionScores,
        _sectionTotals = sectionTotals,
        _answers = answers,
        _weakSkills = weakSkills;

  factory _$ExamResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExamResultImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final ExamType type;
  @override
  final int totalScore;
// 0–100
  @override
  final int totalQuestions;
  @override
  final int correctAnswers;
  final Map<String, int> _sectionScores;
  @override
  Map<String, int> get sectionScores {
    if (_sectionScores is EqualUnmodifiableMapView) return _sectionScores;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_sectionScores);
  }

// skill → score
  final Map<String, int> _sectionTotals;
// skill → score
  @override
  Map<String, int> get sectionTotals {
    if (_sectionTotals is EqualUnmodifiableMapView) return _sectionTotals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_sectionTotals);
  }

  final List<QuestionAnswer> _answers;
  @override
  List<QuestionAnswer> get answers {
    if (_answers is EqualUnmodifiableListView) return _answers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_answers);
  }

  @override
  final DateTime completedAt;
  @override
  @JsonKey()
  final int passThreshold;
// minimum passing score
  final List<String> _weakSkills;
// minimum passing score
  @override
  @JsonKey()
  List<String> get weakSkills {
    if (_weakSkills is EqualUnmodifiableListView) return _weakSkills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weakSkills);
  }

// skills below threshold
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
  final String? recommendation;
// suggested next lesson/module
  @override
  final int? totalTimeSeconds;

  @override
  String toString() {
    return 'ExamResult(id: $id, userId: $userId, type: $type, totalScore: $totalScore, totalQuestions: $totalQuestions, correctAnswers: $correctAnswers, sectionScores: $sectionScores, sectionTotals: $sectionTotals, answers: $answers, completedAt: $completedAt, passThreshold: $passThreshold, weakSkills: $weakSkills, passed: $passed, writtenScore: $writtenScore, writtenTotal: $writtenTotal, writtenPassThreshold: $writtenPassThreshold, speakingScore: $speakingScore, speakingTotal: $speakingTotal, speakingPassThreshold: $speakingPassThreshold, recommendation: $recommendation, totalTimeSeconds: $totalTimeSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExamResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.totalScore, totalScore) ||
                other.totalScore == totalScore) &&
            (identical(other.totalQuestions, totalQuestions) ||
                other.totalQuestions == totalQuestions) &&
            (identical(other.correctAnswers, correctAnswers) ||
                other.correctAnswers == correctAnswers) &&
            const DeepCollectionEquality()
                .equals(other._sectionScores, _sectionScores) &&
            const DeepCollectionEquality()
                .equals(other._sectionTotals, _sectionTotals) &&
            const DeepCollectionEquality().equals(other._answers, _answers) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.passThreshold, passThreshold) ||
                other.passThreshold == passThreshold) &&
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
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation) &&
            (identical(other.totalTimeSeconds, totalTimeSeconds) ||
                other.totalTimeSeconds == totalTimeSeconds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        userId,
        type,
        totalScore,
        totalQuestions,
        correctAnswers,
        const DeepCollectionEquality().hash(_sectionScores),
        const DeepCollectionEquality().hash(_sectionTotals),
        const DeepCollectionEquality().hash(_answers),
        completedAt,
        passThreshold,
        const DeepCollectionEquality().hash(_weakSkills),
        passed,
        writtenScore,
        writtenTotal,
        writtenPassThreshold,
        speakingScore,
        speakingTotal,
        speakingPassThreshold,
        recommendation,
        totalTimeSeconds
      ]);

  /// Create a copy of ExamResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExamResultImplCopyWith<_$ExamResultImpl> get copyWith =>
      __$$ExamResultImplCopyWithImpl<_$ExamResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExamResultImplToJson(
      this,
    );
  }
}

abstract class _ExamResult implements ExamResult {
  const factory _ExamResult(
      {required final String id,
      required final String userId,
      required final ExamType type,
      required final int totalScore,
      required final int totalQuestions,
      required final int correctAnswers,
      required final Map<String, int> sectionScores,
      required final Map<String, int> sectionTotals,
      required final List<QuestionAnswer> answers,
      required final DateTime completedAt,
      final int passThreshold,
      final List<String> weakSkills,
      final bool passed,
      final int writtenScore,
      final int writtenTotal,
      final int writtenPassThreshold,
      final int speakingScore,
      final int speakingTotal,
      final int speakingPassThreshold,
      final String? recommendation,
      final int? totalTimeSeconds}) = _$ExamResultImpl;

  factory _ExamResult.fromJson(Map<String, dynamic> json) =
      _$ExamResultImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  ExamType get type;
  @override
  int get totalScore; // 0–100
  @override
  int get totalQuestions;
  @override
  int get correctAnswers;
  @override
  Map<String, int> get sectionScores; // skill → score
  @override
  Map<String, int> get sectionTotals;
  @override
  List<QuestionAnswer> get answers;
  @override
  DateTime get completedAt;
  @override
  int get passThreshold; // minimum passing score
  @override
  List<String> get weakSkills; // skills below threshold
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
  String? get recommendation; // suggested next lesson/module
  @override
  int? get totalTimeSeconds;

  /// Create a copy of ExamResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExamResultImplCopyWith<_$ExamResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
