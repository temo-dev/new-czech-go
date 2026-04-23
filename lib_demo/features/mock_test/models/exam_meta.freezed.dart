// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_meta.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ExamMeta _$ExamMetaFromJson(Map<String, dynamic> json) {
  return _ExamMeta.fromJson(json);
}

/// @nodoc
mixin _$ExamMeta {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get durationMinutes => throw _privateConstructorUsedError;
  List<SectionMeta> get sections => throw _privateConstructorUsedError;

  /// Serializes this ExamMeta to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExamMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExamMetaCopyWith<ExamMeta> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExamMetaCopyWith<$Res> {
  factory $ExamMetaCopyWith(ExamMeta value, $Res Function(ExamMeta) then) =
      _$ExamMetaCopyWithImpl<$Res, ExamMeta>;
  @useResult
  $Res call(
      {String id,
      String title,
      int durationMinutes,
      List<SectionMeta> sections});
}

/// @nodoc
class _$ExamMetaCopyWithImpl<$Res, $Val extends ExamMeta>
    implements $ExamMetaCopyWith<$Res> {
  _$ExamMetaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExamMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? durationMinutes = null,
    Object? sections = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      durationMinutes: null == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      sections: null == sections
          ? _value.sections
          : sections // ignore: cast_nullable_to_non_nullable
              as List<SectionMeta>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExamMetaImplCopyWith<$Res>
    implements $ExamMetaCopyWith<$Res> {
  factory _$$ExamMetaImplCopyWith(
          _$ExamMetaImpl value, $Res Function(_$ExamMetaImpl) then) =
      __$$ExamMetaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      int durationMinutes,
      List<SectionMeta> sections});
}

/// @nodoc
class __$$ExamMetaImplCopyWithImpl<$Res>
    extends _$ExamMetaCopyWithImpl<$Res, _$ExamMetaImpl>
    implements _$$ExamMetaImplCopyWith<$Res> {
  __$$ExamMetaImplCopyWithImpl(
      _$ExamMetaImpl _value, $Res Function(_$ExamMetaImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExamMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? durationMinutes = null,
    Object? sections = null,
  }) {
    return _then(_$ExamMetaImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      durationMinutes: null == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      sections: null == sections
          ? _value._sections
          : sections // ignore: cast_nullable_to_non_nullable
              as List<SectionMeta>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExamMetaImpl implements _ExamMeta {
  const _$ExamMetaImpl(
      {required this.id,
      required this.title,
      required this.durationMinutes,
      final List<SectionMeta> sections = const []})
      : _sections = sections;

  factory _$ExamMetaImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExamMetaImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final int durationMinutes;
  final List<SectionMeta> _sections;
  @override
  @JsonKey()
  List<SectionMeta> get sections {
    if (_sections is EqualUnmodifiableListView) return _sections;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sections);
  }

  @override
  String toString() {
    return 'ExamMeta(id: $id, title: $title, durationMinutes: $durationMinutes, sections: $sections)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExamMetaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.durationMinutes, durationMinutes) ||
                other.durationMinutes == durationMinutes) &&
            const DeepCollectionEquality().equals(other._sections, _sections));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, durationMinutes,
      const DeepCollectionEquality().hash(_sections));

  /// Create a copy of ExamMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExamMetaImplCopyWith<_$ExamMetaImpl> get copyWith =>
      __$$ExamMetaImplCopyWithImpl<_$ExamMetaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExamMetaImplToJson(
      this,
    );
  }
}

abstract class _ExamMeta implements ExamMeta {
  const factory _ExamMeta(
      {required final String id,
      required final String title,
      required final int durationMinutes,
      final List<SectionMeta> sections}) = _$ExamMetaImpl;

  factory _ExamMeta.fromJson(Map<String, dynamic> json) =
      _$ExamMetaImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  int get durationMinutes;
  @override
  List<SectionMeta> get sections;

  /// Create a copy of ExamMeta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExamMetaImplCopyWith<_$ExamMetaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SectionMeta _$SectionMetaFromJson(Map<String, dynamic> json) {
  return _SectionMeta.fromJson(json);
}

/// @nodoc
mixin _$SectionMeta {
  String get id => throw _privateConstructorUsedError;
  String get skill =>
      throw _privateConstructorUsedError; // 'reading' | 'listening' | 'writing' | 'speaking'
  String get label => throw _privateConstructorUsedError;
  int get questionCount => throw _privateConstructorUsedError;
  int? get sectionDurationMinutes =>
      throw _privateConstructorUsedError; // null = uses global exam timer
  int get orderIndex => throw _privateConstructorUsedError;

  /// Serializes this SectionMeta to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SectionMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SectionMetaCopyWith<SectionMeta> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SectionMetaCopyWith<$Res> {
  factory $SectionMetaCopyWith(
          SectionMeta value, $Res Function(SectionMeta) then) =
      _$SectionMetaCopyWithImpl<$Res, SectionMeta>;
  @useResult
  $Res call(
      {String id,
      String skill,
      String label,
      int questionCount,
      int? sectionDurationMinutes,
      int orderIndex});
}

/// @nodoc
class _$SectionMetaCopyWithImpl<$Res, $Val extends SectionMeta>
    implements $SectionMetaCopyWith<$Res> {
  _$SectionMetaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SectionMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? skill = null,
    Object? label = null,
    Object? questionCount = null,
    Object? sectionDurationMinutes = freezed,
    Object? orderIndex = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      skill: null == skill
          ? _value.skill
          : skill // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      questionCount: null == questionCount
          ? _value.questionCount
          : questionCount // ignore: cast_nullable_to_non_nullable
              as int,
      sectionDurationMinutes: freezed == sectionDurationMinutes
          ? _value.sectionDurationMinutes
          : sectionDurationMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SectionMetaImplCopyWith<$Res>
    implements $SectionMetaCopyWith<$Res> {
  factory _$$SectionMetaImplCopyWith(
          _$SectionMetaImpl value, $Res Function(_$SectionMetaImpl) then) =
      __$$SectionMetaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String skill,
      String label,
      int questionCount,
      int? sectionDurationMinutes,
      int orderIndex});
}

/// @nodoc
class __$$SectionMetaImplCopyWithImpl<$Res>
    extends _$SectionMetaCopyWithImpl<$Res, _$SectionMetaImpl>
    implements _$$SectionMetaImplCopyWith<$Res> {
  __$$SectionMetaImplCopyWithImpl(
      _$SectionMetaImpl _value, $Res Function(_$SectionMetaImpl) _then)
      : super(_value, _then);

  /// Create a copy of SectionMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? skill = null,
    Object? label = null,
    Object? questionCount = null,
    Object? sectionDurationMinutes = freezed,
    Object? orderIndex = null,
  }) {
    return _then(_$SectionMetaImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      skill: null == skill
          ? _value.skill
          : skill // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      questionCount: null == questionCount
          ? _value.questionCount
          : questionCount // ignore: cast_nullable_to_non_nullable
              as int,
      sectionDurationMinutes: freezed == sectionDurationMinutes
          ? _value.sectionDurationMinutes
          : sectionDurationMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SectionMetaImpl implements _SectionMeta {
  const _$SectionMetaImpl(
      {required this.id,
      required this.skill,
      required this.label,
      required this.questionCount,
      this.sectionDurationMinutes,
      this.orderIndex = 0});

  factory _$SectionMetaImpl.fromJson(Map<String, dynamic> json) =>
      _$$SectionMetaImplFromJson(json);

  @override
  final String id;
  @override
  final String skill;
// 'reading' | 'listening' | 'writing' | 'speaking'
  @override
  final String label;
  @override
  final int questionCount;
  @override
  final int? sectionDurationMinutes;
// null = uses global exam timer
  @override
  @JsonKey()
  final int orderIndex;

  @override
  String toString() {
    return 'SectionMeta(id: $id, skill: $skill, label: $label, questionCount: $questionCount, sectionDurationMinutes: $sectionDurationMinutes, orderIndex: $orderIndex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SectionMetaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.skill, skill) || other.skill == skill) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.questionCount, questionCount) ||
                other.questionCount == questionCount) &&
            (identical(other.sectionDurationMinutes, sectionDurationMinutes) ||
                other.sectionDurationMinutes == sectionDurationMinutes) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, skill, label, questionCount,
      sectionDurationMinutes, orderIndex);

  /// Create a copy of SectionMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SectionMetaImplCopyWith<_$SectionMetaImpl> get copyWith =>
      __$$SectionMetaImplCopyWithImpl<_$SectionMetaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SectionMetaImplToJson(
      this,
    );
  }
}

abstract class _SectionMeta implements SectionMeta {
  const factory _SectionMeta(
      {required final String id,
      required final String skill,
      required final String label,
      required final int questionCount,
      final int? sectionDurationMinutes,
      final int orderIndex}) = _$SectionMetaImpl;

  factory _SectionMeta.fromJson(Map<String, dynamic> json) =
      _$SectionMetaImpl.fromJson;

  @override
  String get id;
  @override
  String get skill; // 'reading' | 'listening' | 'writing' | 'speaking'
  @override
  String get label;
  @override
  int get questionCount;
  @override
  int? get sectionDurationMinutes; // null = uses global exam timer
  @override
  int get orderIndex;

  /// Create a copy of SectionMeta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SectionMetaImplCopyWith<_$SectionMetaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
