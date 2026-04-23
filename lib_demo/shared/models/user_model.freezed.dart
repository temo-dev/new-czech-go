// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AppUser _$AppUserFromJson(Map<String, dynamic> json) {
  return _AppUser.fromJson(json);
}

/// @nodoc
mixin _$AppUser {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String get locale => throw _privateConstructorUsedError;
  DateTime? get examDate => throw _privateConstructorUsedError;
  int get dailyGoalMinutes => throw _privateConstructorUsedError;
  int get currentStreakDays => throw _privateConstructorUsedError;
  int get totalXp => throw _privateConstructorUsedError;
  int get weeklyXp => throw _privateConstructorUsedError;
  DateTime? get lastActivityDate => throw _privateConstructorUsedError;
  SubscriptionTier get subscriptionTier => throw _privateConstructorUsedError;
  DateTime? get subscriptionExpiresAt => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this AppUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUserCopyWith<AppUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserCopyWith<$Res> {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) then) =
      _$AppUserCopyWithImpl<$Res, AppUser>;
  @useResult
  $Res call(
      {String id,
      String email,
      String? displayName,
      String? avatarUrl,
      String locale,
      DateTime? examDate,
      int dailyGoalMinutes,
      int currentStreakDays,
      int totalXp,
      int weeklyXp,
      DateTime? lastActivityDate,
      SubscriptionTier subscriptionTier,
      DateTime? subscriptionExpiresAt,
      DateTime? createdAt});
}

/// @nodoc
class _$AppUserCopyWithImpl<$Res, $Val extends AppUser>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? displayName = freezed,
    Object? avatarUrl = freezed,
    Object? locale = null,
    Object? examDate = freezed,
    Object? dailyGoalMinutes = null,
    Object? currentStreakDays = null,
    Object? totalXp = null,
    Object? weeklyXp = null,
    Object? lastActivityDate = freezed,
    Object? subscriptionTier = null,
    Object? subscriptionExpiresAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      examDate: freezed == examDate
          ? _value.examDate
          : examDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      dailyGoalMinutes: null == dailyGoalMinutes
          ? _value.dailyGoalMinutes
          : dailyGoalMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      currentStreakDays: null == currentStreakDays
          ? _value.currentStreakDays
          : currentStreakDays // ignore: cast_nullable_to_non_nullable
              as int,
      totalXp: null == totalXp
          ? _value.totalXp
          : totalXp // ignore: cast_nullable_to_non_nullable
              as int,
      weeklyXp: null == weeklyXp
          ? _value.weeklyXp
          : weeklyXp // ignore: cast_nullable_to_non_nullable
              as int,
      lastActivityDate: freezed == lastActivityDate
          ? _value.lastActivityDate
          : lastActivityDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      subscriptionTier: null == subscriptionTier
          ? _value.subscriptionTier
          : subscriptionTier // ignore: cast_nullable_to_non_nullable
              as SubscriptionTier,
      subscriptionExpiresAt: freezed == subscriptionExpiresAt
          ? _value.subscriptionExpiresAt
          : subscriptionExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppUserImplCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$$AppUserImplCopyWith(
          _$AppUserImpl value, $Res Function(_$AppUserImpl) then) =
      __$$AppUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String email,
      String? displayName,
      String? avatarUrl,
      String locale,
      DateTime? examDate,
      int dailyGoalMinutes,
      int currentStreakDays,
      int totalXp,
      int weeklyXp,
      DateTime? lastActivityDate,
      SubscriptionTier subscriptionTier,
      DateTime? subscriptionExpiresAt,
      DateTime? createdAt});
}

/// @nodoc
class __$$AppUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$AppUserImpl>
    implements _$$AppUserImplCopyWith<$Res> {
  __$$AppUserImplCopyWithImpl(
      _$AppUserImpl _value, $Res Function(_$AppUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? displayName = freezed,
    Object? avatarUrl = freezed,
    Object? locale = null,
    Object? examDate = freezed,
    Object? dailyGoalMinutes = null,
    Object? currentStreakDays = null,
    Object? totalXp = null,
    Object? weeklyXp = null,
    Object? lastActivityDate = freezed,
    Object? subscriptionTier = null,
    Object? subscriptionExpiresAt = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$AppUserImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      examDate: freezed == examDate
          ? _value.examDate
          : examDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      dailyGoalMinutes: null == dailyGoalMinutes
          ? _value.dailyGoalMinutes
          : dailyGoalMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      currentStreakDays: null == currentStreakDays
          ? _value.currentStreakDays
          : currentStreakDays // ignore: cast_nullable_to_non_nullable
              as int,
      totalXp: null == totalXp
          ? _value.totalXp
          : totalXp // ignore: cast_nullable_to_non_nullable
              as int,
      weeklyXp: null == weeklyXp
          ? _value.weeklyXp
          : weeklyXp // ignore: cast_nullable_to_non_nullable
              as int,
      lastActivityDate: freezed == lastActivityDate
          ? _value.lastActivityDate
          : lastActivityDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      subscriptionTier: null == subscriptionTier
          ? _value.subscriptionTier
          : subscriptionTier // ignore: cast_nullable_to_non_nullable
              as SubscriptionTier,
      subscriptionExpiresAt: freezed == subscriptionExpiresAt
          ? _value.subscriptionExpiresAt
          : subscriptionExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _$AppUserImpl implements _AppUser {
  const _$AppUserImpl(
      {required this.id,
      required this.email,
      this.displayName,
      this.avatarUrl,
      this.locale = 'vi',
      this.examDate,
      this.dailyGoalMinutes = 0,
      this.currentStreakDays = 0,
      this.totalXp = 0,
      this.weeklyXp = 0,
      this.lastActivityDate,
      this.subscriptionTier = SubscriptionTier.free,
      this.subscriptionExpiresAt,
      this.createdAt});

  factory _$AppUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUserImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  final String? displayName;
  @override
  final String? avatarUrl;
  @override
  @JsonKey()
  final String locale;
  @override
  final DateTime? examDate;
  @override
  @JsonKey()
  final int dailyGoalMinutes;
  @override
  @JsonKey()
  final int currentStreakDays;
  @override
  @JsonKey()
  final int totalXp;
  @override
  @JsonKey()
  final int weeklyXp;
  @override
  final DateTime? lastActivityDate;
  @override
  @JsonKey()
  final SubscriptionTier subscriptionTier;
  @override
  final DateTime? subscriptionExpiresAt;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, displayName: $displayName, avatarUrl: $avatarUrl, locale: $locale, examDate: $examDate, dailyGoalMinutes: $dailyGoalMinutes, currentStreakDays: $currentStreakDays, totalXp: $totalXp, weeklyXp: $weeklyXp, lastActivityDate: $lastActivityDate, subscriptionTier: $subscriptionTier, subscriptionExpiresAt: $subscriptionExpiresAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.examDate, examDate) ||
                other.examDate == examDate) &&
            (identical(other.dailyGoalMinutes, dailyGoalMinutes) ||
                other.dailyGoalMinutes == dailyGoalMinutes) &&
            (identical(other.currentStreakDays, currentStreakDays) ||
                other.currentStreakDays == currentStreakDays) &&
            (identical(other.totalXp, totalXp) || other.totalXp == totalXp) &&
            (identical(other.weeklyXp, weeklyXp) ||
                other.weeklyXp == weeklyXp) &&
            (identical(other.lastActivityDate, lastActivityDate) ||
                other.lastActivityDate == lastActivityDate) &&
            (identical(other.subscriptionTier, subscriptionTier) ||
                other.subscriptionTier == subscriptionTier) &&
            (identical(other.subscriptionExpiresAt, subscriptionExpiresAt) ||
                other.subscriptionExpiresAt == subscriptionExpiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      email,
      displayName,
      avatarUrl,
      locale,
      examDate,
      dailyGoalMinutes,
      currentStreakDays,
      totalXp,
      weeklyXp,
      lastActivityDate,
      subscriptionTier,
      subscriptionExpiresAt,
      createdAt);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      __$$AppUserImplCopyWithImpl<_$AppUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppUserImplToJson(
      this,
    );
  }
}

abstract class _AppUser implements AppUser {
  const factory _AppUser(
      {required final String id,
      required final String email,
      final String? displayName,
      final String? avatarUrl,
      final String locale,
      final DateTime? examDate,
      final int dailyGoalMinutes,
      final int currentStreakDays,
      final int totalXp,
      final int weeklyXp,
      final DateTime? lastActivityDate,
      final SubscriptionTier subscriptionTier,
      final DateTime? subscriptionExpiresAt,
      final DateTime? createdAt}) = _$AppUserImpl;

  factory _AppUser.fromJson(Map<String, dynamic> json) = _$AppUserImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  String? get displayName;
  @override
  String? get avatarUrl;
  @override
  String get locale;
  @override
  DateTime? get examDate;
  @override
  int get dailyGoalMinutes;
  @override
  int get currentStreakDays;
  @override
  int get totalXp;
  @override
  int get weeklyXp;
  @override
  DateTime? get lastActivityDate;
  @override
  SubscriptionTier get subscriptionTier;
  @override
  DateTime? get subscriptionExpiresAt;
  @override
  DateTime? get createdAt;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
