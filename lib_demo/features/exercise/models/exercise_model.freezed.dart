// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exercise_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Exercise _$ExerciseFromJson(Map<String, dynamic> json) {
  return _Exercise.fromJson(json);
}

/// @nodoc
mixin _$Exercise {
  String get id => throw _privateConstructorUsedError;
  QuestionType get type => throw _privateConstructorUsedError;
  SkillArea get skill => throw _privateConstructorUsedError;
  Difficulty get difficulty => throw _privateConstructorUsedError;
  String get contentJson =>
      throw _privateConstructorUsedError; // raw JSON stored in Supabase
  List<String> get assetUrls => throw _privateConstructorUsedError;
  int get xpReward => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Exercise to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExerciseCopyWith<Exercise> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExerciseCopyWith<$Res> {
  factory $ExerciseCopyWith(Exercise value, $Res Function(Exercise) then) =
      _$ExerciseCopyWithImpl<$Res, Exercise>;
  @useResult
  $Res call(
      {String id,
      QuestionType type,
      SkillArea skill,
      Difficulty difficulty,
      String contentJson,
      List<String> assetUrls,
      int xpReward,
      DateTime? createdAt});
}

/// @nodoc
class _$ExerciseCopyWithImpl<$Res, $Val extends Exercise>
    implements $ExerciseCopyWith<$Res> {
  _$ExerciseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? skill = null,
    Object? difficulty = null,
    Object? contentJson = null,
    Object? assetUrls = null,
    Object? xpReward = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as QuestionType,
      skill: null == skill
          ? _value.skill
          : skill // ignore: cast_nullable_to_non_nullable
              as SkillArea,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as Difficulty,
      contentJson: null == contentJson
          ? _value.contentJson
          : contentJson // ignore: cast_nullable_to_non_nullable
              as String,
      assetUrls: null == assetUrls
          ? _value.assetUrls
          : assetUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
      xpReward: null == xpReward
          ? _value.xpReward
          : xpReward // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExerciseImplCopyWith<$Res>
    implements $ExerciseCopyWith<$Res> {
  factory _$$ExerciseImplCopyWith(
          _$ExerciseImpl value, $Res Function(_$ExerciseImpl) then) =
      __$$ExerciseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      QuestionType type,
      SkillArea skill,
      Difficulty difficulty,
      String contentJson,
      List<String> assetUrls,
      int xpReward,
      DateTime? createdAt});
}

/// @nodoc
class __$$ExerciseImplCopyWithImpl<$Res>
    extends _$ExerciseCopyWithImpl<$Res, _$ExerciseImpl>
    implements _$$ExerciseImplCopyWith<$Res> {
  __$$ExerciseImplCopyWithImpl(
      _$ExerciseImpl _value, $Res Function(_$ExerciseImpl) _then)
      : super(_value, _then);

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? skill = null,
    Object? difficulty = null,
    Object? contentJson = null,
    Object? assetUrls = null,
    Object? xpReward = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$ExerciseImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as QuestionType,
      skill: null == skill
          ? _value.skill
          : skill // ignore: cast_nullable_to_non_nullable
              as SkillArea,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as Difficulty,
      contentJson: null == contentJson
          ? _value.contentJson
          : contentJson // ignore: cast_nullable_to_non_nullable
              as String,
      assetUrls: null == assetUrls
          ? _value._assetUrls
          : assetUrls // ignore: cast_nullable_to_non_nullable
              as List<String>,
      xpReward: null == xpReward
          ? _value.xpReward
          : xpReward // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExerciseImpl implements _Exercise {
  const _$ExerciseImpl(
      {required this.id,
      required this.type,
      required this.skill,
      required this.difficulty,
      required this.contentJson,
      final List<String> assetUrls = const [],
      this.xpReward = 10,
      this.createdAt})
      : _assetUrls = assetUrls;

  factory _$ExerciseImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExerciseImplFromJson(json);

  @override
  final String id;
  @override
  final QuestionType type;
  @override
  final SkillArea skill;
  @override
  final Difficulty difficulty;
  @override
  final String contentJson;
// raw JSON stored in Supabase
  final List<String> _assetUrls;
// raw JSON stored in Supabase
  @override
  @JsonKey()
  List<String> get assetUrls {
    if (_assetUrls is EqualUnmodifiableListView) return _assetUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assetUrls);
  }

  @override
  @JsonKey()
  final int xpReward;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'Exercise(id: $id, type: $type, skill: $skill, difficulty: $difficulty, contentJson: $contentJson, assetUrls: $assetUrls, xpReward: $xpReward, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExerciseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.skill, skill) || other.skill == skill) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.contentJson, contentJson) ||
                other.contentJson == contentJson) &&
            const DeepCollectionEquality()
                .equals(other._assetUrls, _assetUrls) &&
            (identical(other.xpReward, xpReward) ||
                other.xpReward == xpReward) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      skill,
      difficulty,
      contentJson,
      const DeepCollectionEquality().hash(_assetUrls),
      xpReward,
      createdAt);

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExerciseImplCopyWith<_$ExerciseImpl> get copyWith =>
      __$$ExerciseImplCopyWithImpl<_$ExerciseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExerciseImplToJson(
      this,
    );
  }
}

abstract class _Exercise implements Exercise {
  const factory _Exercise(
      {required final String id,
      required final QuestionType type,
      required final SkillArea skill,
      required final Difficulty difficulty,
      required final String contentJson,
      final List<String> assetUrls,
      final int xpReward,
      final DateTime? createdAt}) = _$ExerciseImpl;

  factory _Exercise.fromJson(Map<String, dynamic> json) =
      _$ExerciseImpl.fromJson;

  @override
  String get id;
  @override
  QuestionType get type;
  @override
  SkillArea get skill;
  @override
  Difficulty get difficulty;
  @override
  String get contentJson; // raw JSON stored in Supabase
  @override
  List<String> get assetUrls;
  @override
  int get xpReward;
  @override
  DateTime? get createdAt;

  /// Create a copy of Exercise
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExerciseImplCopyWith<_$ExerciseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ExerciseAttempt _$ExerciseAttemptFromJson(Map<String, dynamic> json) {
  return _ExerciseAttempt.fromJson(json);
}

/// @nodoc
mixin _$ExerciseAttempt {
  String get id => throw _privateConstructorUsedError;
  String get exerciseId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  QuestionAnswer get answer => throw _privateConstructorUsedError;
  bool get isCorrect => throw _privateConstructorUsedError;
  int get xpAwarded => throw _privateConstructorUsedError;
  DateTime get attemptedAt => throw _privateConstructorUsedError;

  /// Serializes this ExerciseAttempt to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExerciseAttempt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExerciseAttemptCopyWith<ExerciseAttempt> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExerciseAttemptCopyWith<$Res> {
  factory $ExerciseAttemptCopyWith(
          ExerciseAttempt value, $Res Function(ExerciseAttempt) then) =
      _$ExerciseAttemptCopyWithImpl<$Res, ExerciseAttempt>;
  @useResult
  $Res call(
      {String id,
      String exerciseId,
      String userId,
      QuestionAnswer answer,
      bool isCorrect,
      int xpAwarded,
      DateTime attemptedAt});

  $QuestionAnswerCopyWith<$Res> get answer;
}

/// @nodoc
class _$ExerciseAttemptCopyWithImpl<$Res, $Val extends ExerciseAttempt>
    implements $ExerciseAttemptCopyWith<$Res> {
  _$ExerciseAttemptCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExerciseAttempt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? exerciseId = null,
    Object? userId = null,
    Object? answer = null,
    Object? isCorrect = null,
    Object? xpAwarded = null,
    Object? attemptedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _value.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as QuestionAnswer,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
      xpAwarded: null == xpAwarded
          ? _value.xpAwarded
          : xpAwarded // ignore: cast_nullable_to_non_nullable
              as int,
      attemptedAt: null == attemptedAt
          ? _value.attemptedAt
          : attemptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  /// Create a copy of ExerciseAttempt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuestionAnswerCopyWith<$Res> get answer {
    return $QuestionAnswerCopyWith<$Res>(_value.answer, (value) {
      return _then(_value.copyWith(answer: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ExerciseAttemptImplCopyWith<$Res>
    implements $ExerciseAttemptCopyWith<$Res> {
  factory _$$ExerciseAttemptImplCopyWith(_$ExerciseAttemptImpl value,
          $Res Function(_$ExerciseAttemptImpl) then) =
      __$$ExerciseAttemptImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String exerciseId,
      String userId,
      QuestionAnswer answer,
      bool isCorrect,
      int xpAwarded,
      DateTime attemptedAt});

  @override
  $QuestionAnswerCopyWith<$Res> get answer;
}

/// @nodoc
class __$$ExerciseAttemptImplCopyWithImpl<$Res>
    extends _$ExerciseAttemptCopyWithImpl<$Res, _$ExerciseAttemptImpl>
    implements _$$ExerciseAttemptImplCopyWith<$Res> {
  __$$ExerciseAttemptImplCopyWithImpl(
      _$ExerciseAttemptImpl _value, $Res Function(_$ExerciseAttemptImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExerciseAttempt
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? exerciseId = null,
    Object? userId = null,
    Object? answer = null,
    Object? isCorrect = null,
    Object? xpAwarded = null,
    Object? attemptedAt = null,
  }) {
    return _then(_$ExerciseAttemptImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseId: null == exerciseId
          ? _value.exerciseId
          : exerciseId // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      answer: null == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as QuestionAnswer,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
      xpAwarded: null == xpAwarded
          ? _value.xpAwarded
          : xpAwarded // ignore: cast_nullable_to_non_nullable
              as int,
      attemptedAt: null == attemptedAt
          ? _value.attemptedAt
          : attemptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExerciseAttemptImpl implements _ExerciseAttempt {
  const _$ExerciseAttemptImpl(
      {required this.id,
      required this.exerciseId,
      required this.userId,
      required this.answer,
      required this.isCorrect,
      this.xpAwarded = 0,
      required this.attemptedAt});

  factory _$ExerciseAttemptImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExerciseAttemptImplFromJson(json);

  @override
  final String id;
  @override
  final String exerciseId;
  @override
  final String userId;
  @override
  final QuestionAnswer answer;
  @override
  final bool isCorrect;
  @override
  @JsonKey()
  final int xpAwarded;
  @override
  final DateTime attemptedAt;

  @override
  String toString() {
    return 'ExerciseAttempt(id: $id, exerciseId: $exerciseId, userId: $userId, answer: $answer, isCorrect: $isCorrect, xpAwarded: $xpAwarded, attemptedAt: $attemptedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExerciseAttemptImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.exerciseId, exerciseId) ||
                other.exerciseId == exerciseId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.answer, answer) || other.answer == answer) &&
            (identical(other.isCorrect, isCorrect) ||
                other.isCorrect == isCorrect) &&
            (identical(other.xpAwarded, xpAwarded) ||
                other.xpAwarded == xpAwarded) &&
            (identical(other.attemptedAt, attemptedAt) ||
                other.attemptedAt == attemptedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, exerciseId, userId, answer,
      isCorrect, xpAwarded, attemptedAt);

  /// Create a copy of ExerciseAttempt
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExerciseAttemptImplCopyWith<_$ExerciseAttemptImpl> get copyWith =>
      __$$ExerciseAttemptImplCopyWithImpl<_$ExerciseAttemptImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExerciseAttemptImplToJson(
      this,
    );
  }
}

abstract class _ExerciseAttempt implements ExerciseAttempt {
  const factory _ExerciseAttempt(
      {required final String id,
      required final String exerciseId,
      required final String userId,
      required final QuestionAnswer answer,
      required final bool isCorrect,
      final int xpAwarded,
      required final DateTime attemptedAt}) = _$ExerciseAttemptImpl;

  factory _ExerciseAttempt.fromJson(Map<String, dynamic> json) =
      _$ExerciseAttemptImpl.fromJson;

  @override
  String get id;
  @override
  String get exerciseId;
  @override
  String get userId;
  @override
  QuestionAnswer get answer;
  @override
  bool get isCorrect;
  @override
  int get xpAwarded;
  @override
  DateTime get attemptedAt;

  /// Create a copy of ExerciseAttempt
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExerciseAttemptImplCopyWith<_$ExerciseAttemptImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
