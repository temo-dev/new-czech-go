// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exam_analysis.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MatchingAnalysisFeedbackItem _$MatchingAnalysisFeedbackItemFromJson(
    Map<String, dynamic> json) {
  return _MatchingAnalysisFeedbackItem.fromJson(json);
}

/// @nodoc
mixin _$MatchingAnalysisFeedbackItem {
  String get item => throw _privateConstructorUsedError;
  String get issue => throw _privateConstructorUsedError;

  /// Serializes this MatchingAnalysisFeedbackItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchingAnalysisFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchingAnalysisFeedbackItemCopyWith<MatchingAnalysisFeedbackItem>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchingAnalysisFeedbackItemCopyWith<$Res> {
  factory $MatchingAnalysisFeedbackItemCopyWith(
          MatchingAnalysisFeedbackItem value,
          $Res Function(MatchingAnalysisFeedbackItem) then) =
      _$MatchingAnalysisFeedbackItemCopyWithImpl<$Res,
          MatchingAnalysisFeedbackItem>;
  @useResult
  $Res call({String item, String issue});
}

/// @nodoc
class _$MatchingAnalysisFeedbackItemCopyWithImpl<$Res,
        $Val extends MatchingAnalysisFeedbackItem>
    implements $MatchingAnalysisFeedbackItemCopyWith<$Res> {
  _$MatchingAnalysisFeedbackItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchingAnalysisFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? item = null,
    Object? issue = null,
  }) {
    return _then(_value.copyWith(
      item: null == item
          ? _value.item
          : item // ignore: cast_nullable_to_non_nullable
              as String,
      issue: null == issue
          ? _value.issue
          : issue // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MatchingAnalysisFeedbackItemImplCopyWith<$Res>
    implements $MatchingAnalysisFeedbackItemCopyWith<$Res> {
  factory _$$MatchingAnalysisFeedbackItemImplCopyWith(
          _$MatchingAnalysisFeedbackItemImpl value,
          $Res Function(_$MatchingAnalysisFeedbackItemImpl) then) =
      __$$MatchingAnalysisFeedbackItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String item, String issue});
}

/// @nodoc
class __$$MatchingAnalysisFeedbackItemImplCopyWithImpl<$Res>
    extends _$MatchingAnalysisFeedbackItemCopyWithImpl<$Res,
        _$MatchingAnalysisFeedbackItemImpl>
    implements _$$MatchingAnalysisFeedbackItemImplCopyWith<$Res> {
  __$$MatchingAnalysisFeedbackItemImplCopyWithImpl(
      _$MatchingAnalysisFeedbackItemImpl _value,
      $Res Function(_$MatchingAnalysisFeedbackItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of MatchingAnalysisFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? item = null,
    Object? issue = null,
  }) {
    return _then(_$MatchingAnalysisFeedbackItemImpl(
      item: null == item
          ? _value.item
          : item // ignore: cast_nullable_to_non_nullable
              as String,
      issue: null == issue
          ? _value.issue
          : issue // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MatchingAnalysisFeedbackItemImpl
    implements _MatchingAnalysisFeedbackItem {
  const _$MatchingAnalysisFeedbackItemImpl({this.item = '', this.issue = ''});

  factory _$MatchingAnalysisFeedbackItemImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$MatchingAnalysisFeedbackItemImplFromJson(json);

  @override
  @JsonKey()
  final String item;
  @override
  @JsonKey()
  final String issue;

  @override
  String toString() {
    return 'MatchingAnalysisFeedbackItem(item: $item, issue: $issue)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchingAnalysisFeedbackItemImpl &&
            (identical(other.item, item) || other.item == item) &&
            (identical(other.issue, issue) || other.issue == issue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, item, issue);

  /// Create a copy of MatchingAnalysisFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchingAnalysisFeedbackItemImplCopyWith<
          _$MatchingAnalysisFeedbackItemImpl>
      get copyWith => __$$MatchingAnalysisFeedbackItemImplCopyWithImpl<
          _$MatchingAnalysisFeedbackItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchingAnalysisFeedbackItemImplToJson(
      this,
    );
  }
}

abstract class _MatchingAnalysisFeedbackItem
    implements MatchingAnalysisFeedbackItem {
  const factory _MatchingAnalysisFeedbackItem(
      {final String item,
      final String issue}) = _$MatchingAnalysisFeedbackItemImpl;

  factory _MatchingAnalysisFeedbackItem.fromJson(Map<String, dynamic> json) =
      _$MatchingAnalysisFeedbackItemImpl.fromJson;

  @override
  String get item;
  @override
  String get issue;

  /// Create a copy of MatchingAnalysisFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchingAnalysisFeedbackItemImplCopyWith<
          _$MatchingAnalysisFeedbackItemImpl>
      get copyWith => throw _privateConstructorUsedError;
}

QuestionAnalysisCriterion _$QuestionAnalysisCriterionFromJson(
    Map<String, dynamic> json) {
  return _QuestionAnalysisCriterion.fromJson(json);
}

/// @nodoc
mixin _$QuestionAnalysisCriterion {
  String get label => throw _privateConstructorUsedError;
  double? get score => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_score')
  double? get maxScore => throw _privateConstructorUsedError;
  String get feedback => throw _privateConstructorUsedError;
  String get tip => throw _privateConstructorUsedError;

  /// Serializes this QuestionAnalysisCriterion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuestionAnalysisCriterion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionAnalysisCriterionCopyWith<QuestionAnalysisCriterion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionAnalysisCriterionCopyWith<$Res> {
  factory $QuestionAnalysisCriterionCopyWith(QuestionAnalysisCriterion value,
          $Res Function(QuestionAnalysisCriterion) then) =
      _$QuestionAnalysisCriterionCopyWithImpl<$Res, QuestionAnalysisCriterion>;
  @useResult
  $Res call(
      {String label,
      double? score,
      @JsonKey(name: 'max_score') double? maxScore,
      String feedback,
      String tip});
}

/// @nodoc
class _$QuestionAnalysisCriterionCopyWithImpl<$Res,
        $Val extends QuestionAnalysisCriterion>
    implements $QuestionAnalysisCriterionCopyWith<$Res> {
  _$QuestionAnalysisCriterionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionAnalysisCriterion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? score = freezed,
    Object? maxScore = freezed,
    Object? feedback = null,
    Object? tip = null,
  }) {
    return _then(_value.copyWith(
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double?,
      maxScore: freezed == maxScore
          ? _value.maxScore
          : maxScore // ignore: cast_nullable_to_non_nullable
              as double?,
      feedback: null == feedback
          ? _value.feedback
          : feedback // ignore: cast_nullable_to_non_nullable
              as String,
      tip: null == tip
          ? _value.tip
          : tip // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestionAnalysisCriterionImplCopyWith<$Res>
    implements $QuestionAnalysisCriterionCopyWith<$Res> {
  factory _$$QuestionAnalysisCriterionImplCopyWith(
          _$QuestionAnalysisCriterionImpl value,
          $Res Function(_$QuestionAnalysisCriterionImpl) then) =
      __$$QuestionAnalysisCriterionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String label,
      double? score,
      @JsonKey(name: 'max_score') double? maxScore,
      String feedback,
      String tip});
}

/// @nodoc
class __$$QuestionAnalysisCriterionImplCopyWithImpl<$Res>
    extends _$QuestionAnalysisCriterionCopyWithImpl<$Res,
        _$QuestionAnalysisCriterionImpl>
    implements _$$QuestionAnalysisCriterionImplCopyWith<$Res> {
  __$$QuestionAnalysisCriterionImplCopyWithImpl(
      _$QuestionAnalysisCriterionImpl _value,
      $Res Function(_$QuestionAnalysisCriterionImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionAnalysisCriterion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? score = freezed,
    Object? maxScore = freezed,
    Object? feedback = null,
    Object? tip = null,
  }) {
    return _then(_$QuestionAnalysisCriterionImpl(
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double?,
      maxScore: freezed == maxScore
          ? _value.maxScore
          : maxScore // ignore: cast_nullable_to_non_nullable
              as double?,
      feedback: null == feedback
          ? _value.feedback
          : feedback // ignore: cast_nullable_to_non_nullable
              as String,
      tip: null == tip
          ? _value.tip
          : tip // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestionAnalysisCriterionImpl implements _QuestionAnalysisCriterion {
  const _$QuestionAnalysisCriterionImpl(
      {this.label = '',
      this.score,
      @JsonKey(name: 'max_score') this.maxScore,
      this.feedback = '',
      this.tip = ''});

  factory _$QuestionAnalysisCriterionImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestionAnalysisCriterionImplFromJson(json);

  @override
  @JsonKey()
  final String label;
  @override
  final double? score;
  @override
  @JsonKey(name: 'max_score')
  final double? maxScore;
  @override
  @JsonKey()
  final String feedback;
  @override
  @JsonKey()
  final String tip;

  @override
  String toString() {
    return 'QuestionAnalysisCriterion(label: $label, score: $score, maxScore: $maxScore, feedback: $feedback, tip: $tip)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionAnalysisCriterionImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.maxScore, maxScore) ||
                other.maxScore == maxScore) &&
            (identical(other.feedback, feedback) ||
                other.feedback == feedback) &&
            (identical(other.tip, tip) || other.tip == tip));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, label, score, maxScore, feedback, tip);

  /// Create a copy of QuestionAnalysisCriterion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionAnalysisCriterionImplCopyWith<_$QuestionAnalysisCriterionImpl>
      get copyWith => __$$QuestionAnalysisCriterionImplCopyWithImpl<
          _$QuestionAnalysisCriterionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestionAnalysisCriterionImplToJson(
      this,
    );
  }
}

abstract class _QuestionAnalysisCriterion implements QuestionAnalysisCriterion {
  const factory _QuestionAnalysisCriterion(
      {final String label,
      final double? score,
      @JsonKey(name: 'max_score') final double? maxScore,
      final String feedback,
      final String tip}) = _$QuestionAnalysisCriterionImpl;

  factory _QuestionAnalysisCriterion.fromJson(Map<String, dynamic> json) =
      _$QuestionAnalysisCriterionImpl.fromJson;

  @override
  String get label;
  @override
  double? get score;
  @override
  @JsonKey(name: 'max_score')
  double? get maxScore;
  @override
  String get feedback;
  @override
  String get tip;

  /// Create a copy of QuestionAnalysisCriterion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionAnalysisCriterionImplCopyWith<_$QuestionAnalysisCriterionImpl>
      get copyWith => throw _privateConstructorUsedError;
}

QuestionAnalysisFeedback _$QuestionAnalysisFeedbackFromJson(
    Map<String, dynamic> json) {
  return _QuestionAnalysisFeedback.fromJson(json);
}

/// @nodoc
mixin _$QuestionAnalysisFeedback {
  String get verdict => throw _privateConstructorUsedError;
  @JsonKey(name: 'error_analysis')
  String get errorAnalysis => throw _privateConstructorUsedError;
  @JsonKey(name: 'correct_explanation')
  String get correctExplanation => throw _privateConstructorUsedError;
  @JsonKey(name: 'short_tip')
  String get shortTip => throw _privateConstructorUsedError;
  @JsonKey(name: 'key_concept')
  String get keyConceptLabel => throw _privateConstructorUsedError;
  @JsonKey(name: 'matching_feedback')
  List<MatchingAnalysisFeedbackItem> get matchingFeedback =>
      throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  List<QuestionAnalysisCriterion> get criteria =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'short_tips')
  List<String> get shortTips => throw _privateConstructorUsedError;
  bool get skipped => throw _privateConstructorUsedError;

  /// Serializes this QuestionAnalysisFeedback to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuestionAnalysisFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionAnalysisFeedbackCopyWith<QuestionAnalysisFeedback> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionAnalysisFeedbackCopyWith<$Res> {
  factory $QuestionAnalysisFeedbackCopyWith(QuestionAnalysisFeedback value,
          $Res Function(QuestionAnalysisFeedback) then) =
      _$QuestionAnalysisFeedbackCopyWithImpl<$Res, QuestionAnalysisFeedback>;
  @useResult
  $Res call(
      {String verdict,
      @JsonKey(name: 'error_analysis') String errorAnalysis,
      @JsonKey(name: 'correct_explanation') String correctExplanation,
      @JsonKey(name: 'short_tip') String shortTip,
      @JsonKey(name: 'key_concept') String keyConceptLabel,
      @JsonKey(name: 'matching_feedback')
      List<MatchingAnalysisFeedbackItem> matchingFeedback,
      String summary,
      List<QuestionAnalysisCriterion> criteria,
      @JsonKey(name: 'short_tips') List<String> shortTips,
      bool skipped});
}

/// @nodoc
class _$QuestionAnalysisFeedbackCopyWithImpl<$Res,
        $Val extends QuestionAnalysisFeedback>
    implements $QuestionAnalysisFeedbackCopyWith<$Res> {
  _$QuestionAnalysisFeedbackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionAnalysisFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? verdict = null,
    Object? errorAnalysis = null,
    Object? correctExplanation = null,
    Object? shortTip = null,
    Object? keyConceptLabel = null,
    Object? matchingFeedback = null,
    Object? summary = null,
    Object? criteria = null,
    Object? shortTips = null,
    Object? skipped = null,
  }) {
    return _then(_value.copyWith(
      verdict: null == verdict
          ? _value.verdict
          : verdict // ignore: cast_nullable_to_non_nullable
              as String,
      errorAnalysis: null == errorAnalysis
          ? _value.errorAnalysis
          : errorAnalysis // ignore: cast_nullable_to_non_nullable
              as String,
      correctExplanation: null == correctExplanation
          ? _value.correctExplanation
          : correctExplanation // ignore: cast_nullable_to_non_nullable
              as String,
      shortTip: null == shortTip
          ? _value.shortTip
          : shortTip // ignore: cast_nullable_to_non_nullable
              as String,
      keyConceptLabel: null == keyConceptLabel
          ? _value.keyConceptLabel
          : keyConceptLabel // ignore: cast_nullable_to_non_nullable
              as String,
      matchingFeedback: null == matchingFeedback
          ? _value.matchingFeedback
          : matchingFeedback // ignore: cast_nullable_to_non_nullable
              as List<MatchingAnalysisFeedbackItem>,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      criteria: null == criteria
          ? _value.criteria
          : criteria // ignore: cast_nullable_to_non_nullable
              as List<QuestionAnalysisCriterion>,
      shortTips: null == shortTips
          ? _value.shortTips
          : shortTips // ignore: cast_nullable_to_non_nullable
              as List<String>,
      skipped: null == skipped
          ? _value.skipped
          : skipped // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestionAnalysisFeedbackImplCopyWith<$Res>
    implements $QuestionAnalysisFeedbackCopyWith<$Res> {
  factory _$$QuestionAnalysisFeedbackImplCopyWith(
          _$QuestionAnalysisFeedbackImpl value,
          $Res Function(_$QuestionAnalysisFeedbackImpl) then) =
      __$$QuestionAnalysisFeedbackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String verdict,
      @JsonKey(name: 'error_analysis') String errorAnalysis,
      @JsonKey(name: 'correct_explanation') String correctExplanation,
      @JsonKey(name: 'short_tip') String shortTip,
      @JsonKey(name: 'key_concept') String keyConceptLabel,
      @JsonKey(name: 'matching_feedback')
      List<MatchingAnalysisFeedbackItem> matchingFeedback,
      String summary,
      List<QuestionAnalysisCriterion> criteria,
      @JsonKey(name: 'short_tips') List<String> shortTips,
      bool skipped});
}

/// @nodoc
class __$$QuestionAnalysisFeedbackImplCopyWithImpl<$Res>
    extends _$QuestionAnalysisFeedbackCopyWithImpl<$Res,
        _$QuestionAnalysisFeedbackImpl>
    implements _$$QuestionAnalysisFeedbackImplCopyWith<$Res> {
  __$$QuestionAnalysisFeedbackImplCopyWithImpl(
      _$QuestionAnalysisFeedbackImpl _value,
      $Res Function(_$QuestionAnalysisFeedbackImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionAnalysisFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? verdict = null,
    Object? errorAnalysis = null,
    Object? correctExplanation = null,
    Object? shortTip = null,
    Object? keyConceptLabel = null,
    Object? matchingFeedback = null,
    Object? summary = null,
    Object? criteria = null,
    Object? shortTips = null,
    Object? skipped = null,
  }) {
    return _then(_$QuestionAnalysisFeedbackImpl(
      verdict: null == verdict
          ? _value.verdict
          : verdict // ignore: cast_nullable_to_non_nullable
              as String,
      errorAnalysis: null == errorAnalysis
          ? _value.errorAnalysis
          : errorAnalysis // ignore: cast_nullable_to_non_nullable
              as String,
      correctExplanation: null == correctExplanation
          ? _value.correctExplanation
          : correctExplanation // ignore: cast_nullable_to_non_nullable
              as String,
      shortTip: null == shortTip
          ? _value.shortTip
          : shortTip // ignore: cast_nullable_to_non_nullable
              as String,
      keyConceptLabel: null == keyConceptLabel
          ? _value.keyConceptLabel
          : keyConceptLabel // ignore: cast_nullable_to_non_nullable
              as String,
      matchingFeedback: null == matchingFeedback
          ? _value._matchingFeedback
          : matchingFeedback // ignore: cast_nullable_to_non_nullable
              as List<MatchingAnalysisFeedbackItem>,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      criteria: null == criteria
          ? _value._criteria
          : criteria // ignore: cast_nullable_to_non_nullable
              as List<QuestionAnalysisCriterion>,
      shortTips: null == shortTips
          ? _value._shortTips
          : shortTips // ignore: cast_nullable_to_non_nullable
              as List<String>,
      skipped: null == skipped
          ? _value.skipped
          : skipped // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestionAnalysisFeedbackImpl implements _QuestionAnalysisFeedback {
  const _$QuestionAnalysisFeedbackImpl(
      {this.verdict = 'incorrect',
      @JsonKey(name: 'error_analysis') this.errorAnalysis = '',
      @JsonKey(name: 'correct_explanation') this.correctExplanation = '',
      @JsonKey(name: 'short_tip') this.shortTip = '',
      @JsonKey(name: 'key_concept') this.keyConceptLabel = '',
      @JsonKey(name: 'matching_feedback')
      final List<MatchingAnalysisFeedbackItem> matchingFeedback = const [],
      this.summary = '',
      final List<QuestionAnalysisCriterion> criteria = const [],
      @JsonKey(name: 'short_tips') final List<String> shortTips = const [],
      this.skipped = false})
      : _matchingFeedback = matchingFeedback,
        _criteria = criteria,
        _shortTips = shortTips;

  factory _$QuestionAnalysisFeedbackImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestionAnalysisFeedbackImplFromJson(json);

  @override
  @JsonKey()
  final String verdict;
  @override
  @JsonKey(name: 'error_analysis')
  final String errorAnalysis;
  @override
  @JsonKey(name: 'correct_explanation')
  final String correctExplanation;
  @override
  @JsonKey(name: 'short_tip')
  final String shortTip;
  @override
  @JsonKey(name: 'key_concept')
  final String keyConceptLabel;
  final List<MatchingAnalysisFeedbackItem> _matchingFeedback;
  @override
  @JsonKey(name: 'matching_feedback')
  List<MatchingAnalysisFeedbackItem> get matchingFeedback {
    if (_matchingFeedback is EqualUnmodifiableListView)
      return _matchingFeedback;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_matchingFeedback);
  }

  @override
  @JsonKey()
  final String summary;
  final List<QuestionAnalysisCriterion> _criteria;
  @override
  @JsonKey()
  List<QuestionAnalysisCriterion> get criteria {
    if (_criteria is EqualUnmodifiableListView) return _criteria;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_criteria);
  }

  final List<String> _shortTips;
  @override
  @JsonKey(name: 'short_tips')
  List<String> get shortTips {
    if (_shortTips is EqualUnmodifiableListView) return _shortTips;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shortTips);
  }

  @override
  @JsonKey()
  final bool skipped;

  @override
  String toString() {
    return 'QuestionAnalysisFeedback(verdict: $verdict, errorAnalysis: $errorAnalysis, correctExplanation: $correctExplanation, shortTip: $shortTip, keyConceptLabel: $keyConceptLabel, matchingFeedback: $matchingFeedback, summary: $summary, criteria: $criteria, shortTips: $shortTips, skipped: $skipped)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionAnalysisFeedbackImpl &&
            (identical(other.verdict, verdict) || other.verdict == verdict) &&
            (identical(other.errorAnalysis, errorAnalysis) ||
                other.errorAnalysis == errorAnalysis) &&
            (identical(other.correctExplanation, correctExplanation) ||
                other.correctExplanation == correctExplanation) &&
            (identical(other.shortTip, shortTip) ||
                other.shortTip == shortTip) &&
            (identical(other.keyConceptLabel, keyConceptLabel) ||
                other.keyConceptLabel == keyConceptLabel) &&
            const DeepCollectionEquality()
                .equals(other._matchingFeedback, _matchingFeedback) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(other._criteria, _criteria) &&
            const DeepCollectionEquality()
                .equals(other._shortTips, _shortTips) &&
            (identical(other.skipped, skipped) || other.skipped == skipped));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      verdict,
      errorAnalysis,
      correctExplanation,
      shortTip,
      keyConceptLabel,
      const DeepCollectionEquality().hash(_matchingFeedback),
      summary,
      const DeepCollectionEquality().hash(_criteria),
      const DeepCollectionEquality().hash(_shortTips),
      skipped);

  /// Create a copy of QuestionAnalysisFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionAnalysisFeedbackImplCopyWith<_$QuestionAnalysisFeedbackImpl>
      get copyWith => __$$QuestionAnalysisFeedbackImplCopyWithImpl<
          _$QuestionAnalysisFeedbackImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestionAnalysisFeedbackImplToJson(
      this,
    );
  }
}

abstract class _QuestionAnalysisFeedback implements QuestionAnalysisFeedback {
  const factory _QuestionAnalysisFeedback(
      {final String verdict,
      @JsonKey(name: 'error_analysis') final String errorAnalysis,
      @JsonKey(name: 'correct_explanation') final String correctExplanation,
      @JsonKey(name: 'short_tip') final String shortTip,
      @JsonKey(name: 'key_concept') final String keyConceptLabel,
      @JsonKey(name: 'matching_feedback')
      final List<MatchingAnalysisFeedbackItem> matchingFeedback,
      final String summary,
      final List<QuestionAnalysisCriterion> criteria,
      @JsonKey(name: 'short_tips') final List<String> shortTips,
      final bool skipped}) = _$QuestionAnalysisFeedbackImpl;

  factory _QuestionAnalysisFeedback.fromJson(Map<String, dynamic> json) =
      _$QuestionAnalysisFeedbackImpl.fromJson;

  @override
  String get verdict;
  @override
  @JsonKey(name: 'error_analysis')
  String get errorAnalysis;
  @override
  @JsonKey(name: 'correct_explanation')
  String get correctExplanation;
  @override
  @JsonKey(name: 'short_tip')
  String get shortTip;
  @override
  @JsonKey(name: 'key_concept')
  String get keyConceptLabel;
  @override
  @JsonKey(name: 'matching_feedback')
  List<MatchingAnalysisFeedbackItem> get matchingFeedback;
  @override
  String get summary;
  @override
  List<QuestionAnalysisCriterion> get criteria;
  @override
  @JsonKey(name: 'short_tips')
  List<String> get shortTips;
  @override
  bool get skipped;

  /// Create a copy of QuestionAnalysisFeedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionAnalysisFeedbackImplCopyWith<_$QuestionAnalysisFeedbackImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SkillInsight _$SkillInsightFromJson(Map<String, dynamic> json) {
  return _SkillInsight.fromJson(json);
}

/// @nodoc
mixin _$SkillInsight {
  String get skill => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  @JsonKey(name: 'main_issue')
  String get mainIssue => throw _privateConstructorUsedError;

  /// Serializes this SkillInsight to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SkillInsight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SkillInsightCopyWith<SkillInsight> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SkillInsightCopyWith<$Res> {
  factory $SkillInsightCopyWith(
          SkillInsight value, $Res Function(SkillInsight) then) =
      _$SkillInsightCopyWithImpl<$Res, SkillInsight>;
  @useResult
  $Res call(
      {String skill,
      String summary,
      @JsonKey(name: 'main_issue') String mainIssue});
}

/// @nodoc
class _$SkillInsightCopyWithImpl<$Res, $Val extends SkillInsight>
    implements $SkillInsightCopyWith<$Res> {
  _$SkillInsightCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SkillInsight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? skill = null,
    Object? summary = null,
    Object? mainIssue = null,
  }) {
    return _then(_value.copyWith(
      skill: null == skill
          ? _value.skill
          : skill // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      mainIssue: null == mainIssue
          ? _value.mainIssue
          : mainIssue // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SkillInsightImplCopyWith<$Res>
    implements $SkillInsightCopyWith<$Res> {
  factory _$$SkillInsightImplCopyWith(
          _$SkillInsightImpl value, $Res Function(_$SkillInsightImpl) then) =
      __$$SkillInsightImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String skill,
      String summary,
      @JsonKey(name: 'main_issue') String mainIssue});
}

/// @nodoc
class __$$SkillInsightImplCopyWithImpl<$Res>
    extends _$SkillInsightCopyWithImpl<$Res, _$SkillInsightImpl>
    implements _$$SkillInsightImplCopyWith<$Res> {
  __$$SkillInsightImplCopyWithImpl(
      _$SkillInsightImpl _value, $Res Function(_$SkillInsightImpl) _then)
      : super(_value, _then);

  /// Create a copy of SkillInsight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? skill = null,
    Object? summary = null,
    Object? mainIssue = null,
  }) {
    return _then(_$SkillInsightImpl(
      skill: null == skill
          ? _value.skill
          : skill // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      mainIssue: null == mainIssue
          ? _value.mainIssue
          : mainIssue // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SkillInsightImpl implements _SkillInsight {
  const _$SkillInsightImpl(
      {required this.skill,
      this.summary = '',
      @JsonKey(name: 'main_issue') this.mainIssue = ''});

  factory _$SkillInsightImpl.fromJson(Map<String, dynamic> json) =>
      _$$SkillInsightImplFromJson(json);

  @override
  final String skill;
  @override
  @JsonKey()
  final String summary;
  @override
  @JsonKey(name: 'main_issue')
  final String mainIssue;

  @override
  String toString() {
    return 'SkillInsight(skill: $skill, summary: $summary, mainIssue: $mainIssue)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SkillInsightImpl &&
            (identical(other.skill, skill) || other.skill == skill) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.mainIssue, mainIssue) ||
                other.mainIssue == mainIssue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, skill, summary, mainIssue);

  /// Create a copy of SkillInsight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SkillInsightImplCopyWith<_$SkillInsightImpl> get copyWith =>
      __$$SkillInsightImplCopyWithImpl<_$SkillInsightImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SkillInsightImplToJson(
      this,
    );
  }
}

abstract class _SkillInsight implements SkillInsight {
  const factory _SkillInsight(
          {required final String skill,
          final String summary,
          @JsonKey(name: 'main_issue') final String mainIssue}) =
      _$SkillInsightImpl;

  factory _SkillInsight.fromJson(Map<String, dynamic> json) =
      _$SkillInsightImpl.fromJson;

  @override
  String get skill;
  @override
  String get summary;
  @override
  @JsonKey(name: 'main_issue')
  String get mainIssue;

  /// Create a copy of SkillInsight
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SkillInsightImplCopyWith<_$SkillInsightImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OverallRecommendation _$OverallRecommendationFromJson(
    Map<String, dynamic> json) {
  return _OverallRecommendation.fromJson(json);
}

/// @nodoc
mixin _$OverallRecommendation {
  String get title => throw _privateConstructorUsedError;
  String get detail => throw _privateConstructorUsedError;

  /// Serializes this OverallRecommendation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OverallRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OverallRecommendationCopyWith<OverallRecommendation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OverallRecommendationCopyWith<$Res> {
  factory $OverallRecommendationCopyWith(OverallRecommendation value,
          $Res Function(OverallRecommendation) then) =
      _$OverallRecommendationCopyWithImpl<$Res, OverallRecommendation>;
  @useResult
  $Res call({String title, String detail});
}

/// @nodoc
class _$OverallRecommendationCopyWithImpl<$Res,
        $Val extends OverallRecommendation>
    implements $OverallRecommendationCopyWith<$Res> {
  _$OverallRecommendationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OverallRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? detail = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      detail: null == detail
          ? _value.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OverallRecommendationImplCopyWith<$Res>
    implements $OverallRecommendationCopyWith<$Res> {
  factory _$$OverallRecommendationImplCopyWith(
          _$OverallRecommendationImpl value,
          $Res Function(_$OverallRecommendationImpl) then) =
      __$$OverallRecommendationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, String detail});
}

/// @nodoc
class __$$OverallRecommendationImplCopyWithImpl<$Res>
    extends _$OverallRecommendationCopyWithImpl<$Res,
        _$OverallRecommendationImpl>
    implements _$$OverallRecommendationImplCopyWith<$Res> {
  __$$OverallRecommendationImplCopyWithImpl(_$OverallRecommendationImpl _value,
      $Res Function(_$OverallRecommendationImpl) _then)
      : super(_value, _then);

  /// Create a copy of OverallRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? detail = null,
  }) {
    return _then(_$OverallRecommendationImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      detail: null == detail
          ? _value.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OverallRecommendationImpl implements _OverallRecommendation {
  const _$OverallRecommendationImpl({this.title = '', this.detail = ''});

  factory _$OverallRecommendationImpl.fromJson(Map<String, dynamic> json) =>
      _$$OverallRecommendationImplFromJson(json);

  @override
  @JsonKey()
  final String title;
  @override
  @JsonKey()
  final String detail;

  @override
  String toString() {
    return 'OverallRecommendation(title: $title, detail: $detail)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OverallRecommendationImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.detail, detail) || other.detail == detail));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, detail);

  /// Create a copy of OverallRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OverallRecommendationImplCopyWith<_$OverallRecommendationImpl>
      get copyWith => __$$OverallRecommendationImplCopyWithImpl<
          _$OverallRecommendationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OverallRecommendationImplToJson(
      this,
    );
  }
}

abstract class _OverallRecommendation implements OverallRecommendation {
  const factory _OverallRecommendation(
      {final String title, final String detail}) = _$OverallRecommendationImpl;

  factory _OverallRecommendation.fromJson(Map<String, dynamic> json) =
      _$OverallRecommendationImpl.fromJson;

  @override
  String get title;
  @override
  String get detail;

  /// Create a copy of OverallRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OverallRecommendationImplCopyWith<_$OverallRecommendationImpl>
      get copyWith => throw _privateConstructorUsedError;
}

ExamAnalysis _$ExamAnalysisFromJson(Map<String, dynamic> json) {
  return _ExamAnalysis.fromJson(json);
}

/// @nodoc
mixin _$ExamAnalysis {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'attempt_id')
  String get attemptId => throw _privateConstructorUsedError;
  ExamAnalysisStatus get status => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'question_feedbacks',
      fromJson: _questionFeedbacksFromJson,
      toJson: _questionFeedbacksToJson)
  Map<String, QuestionAnalysisFeedback> get questionFeedbacks =>
      throw _privateConstructorUsedError;
  @JsonKey(
      name: 'skill_insights',
      fromJson: _skillInsightsFromJson,
      toJson: _skillInsightsToJson)
  List<SkillInsight> get skillInsights => throw _privateConstructorUsedError;
  @JsonKey(name: 'overall_recommendations')
  List<OverallRecommendation> get overallRecommendations =>
      throw _privateConstructorUsedError;
  @JsonKey(
      name: 'teacher_reviews_by_question',
      fromJson: _teacherReviewsByQuestionFromJson,
      toJson: _teacherReviewsByQuestionToJson)
  Map<String, Map<String, dynamic>> get teacherReviewsByQuestion =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'error_message')
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Serializes this ExamAnalysis to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExamAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExamAnalysisCopyWith<ExamAnalysis> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExamAnalysisCopyWith<$Res> {
  factory $ExamAnalysisCopyWith(
          ExamAnalysis value, $Res Function(ExamAnalysis) then) =
      _$ExamAnalysisCopyWithImpl<$Res, ExamAnalysis>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'attempt_id') String attemptId,
      ExamAnalysisStatus status,
      @JsonKey(
          name: 'question_feedbacks',
          fromJson: _questionFeedbacksFromJson,
          toJson: _questionFeedbacksToJson)
      Map<String, QuestionAnalysisFeedback> questionFeedbacks,
      @JsonKey(
          name: 'skill_insights',
          fromJson: _skillInsightsFromJson,
          toJson: _skillInsightsToJson)
      List<SkillInsight> skillInsights,
      @JsonKey(name: 'overall_recommendations')
      List<OverallRecommendation> overallRecommendations,
      @JsonKey(
          name: 'teacher_reviews_by_question',
          fromJson: _teacherReviewsByQuestionFromJson,
          toJson: _teacherReviewsByQuestionToJson)
      Map<String, Map<String, dynamic>> teacherReviewsByQuestion,
      @JsonKey(name: 'error_message') String? errorMessage});
}

/// @nodoc
class _$ExamAnalysisCopyWithImpl<$Res, $Val extends ExamAnalysis>
    implements $ExamAnalysisCopyWith<$Res> {
  _$ExamAnalysisCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExamAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? attemptId = null,
    Object? status = null,
    Object? questionFeedbacks = null,
    Object? skillInsights = null,
    Object? overallRecommendations = null,
    Object? teacherReviewsByQuestion = null,
    Object? errorMessage = freezed,
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
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ExamAnalysisStatus,
      questionFeedbacks: null == questionFeedbacks
          ? _value.questionFeedbacks
          : questionFeedbacks // ignore: cast_nullable_to_non_nullable
              as Map<String, QuestionAnalysisFeedback>,
      skillInsights: null == skillInsights
          ? _value.skillInsights
          : skillInsights // ignore: cast_nullable_to_non_nullable
              as List<SkillInsight>,
      overallRecommendations: null == overallRecommendations
          ? _value.overallRecommendations
          : overallRecommendations // ignore: cast_nullable_to_non_nullable
              as List<OverallRecommendation>,
      teacherReviewsByQuestion: null == teacherReviewsByQuestion
          ? _value.teacherReviewsByQuestion
          : teacherReviewsByQuestion // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, dynamic>>,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExamAnalysisImplCopyWith<$Res>
    implements $ExamAnalysisCopyWith<$Res> {
  factory _$$ExamAnalysisImplCopyWith(
          _$ExamAnalysisImpl value, $Res Function(_$ExamAnalysisImpl) then) =
      __$$ExamAnalysisImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'attempt_id') String attemptId,
      ExamAnalysisStatus status,
      @JsonKey(
          name: 'question_feedbacks',
          fromJson: _questionFeedbacksFromJson,
          toJson: _questionFeedbacksToJson)
      Map<String, QuestionAnalysisFeedback> questionFeedbacks,
      @JsonKey(
          name: 'skill_insights',
          fromJson: _skillInsightsFromJson,
          toJson: _skillInsightsToJson)
      List<SkillInsight> skillInsights,
      @JsonKey(name: 'overall_recommendations')
      List<OverallRecommendation> overallRecommendations,
      @JsonKey(
          name: 'teacher_reviews_by_question',
          fromJson: _teacherReviewsByQuestionFromJson,
          toJson: _teacherReviewsByQuestionToJson)
      Map<String, Map<String, dynamic>> teacherReviewsByQuestion,
      @JsonKey(name: 'error_message') String? errorMessage});
}

/// @nodoc
class __$$ExamAnalysisImplCopyWithImpl<$Res>
    extends _$ExamAnalysisCopyWithImpl<$Res, _$ExamAnalysisImpl>
    implements _$$ExamAnalysisImplCopyWith<$Res> {
  __$$ExamAnalysisImplCopyWithImpl(
      _$ExamAnalysisImpl _value, $Res Function(_$ExamAnalysisImpl) _then)
      : super(_value, _then);

  /// Create a copy of ExamAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? attemptId = null,
    Object? status = null,
    Object? questionFeedbacks = null,
    Object? skillInsights = null,
    Object? overallRecommendations = null,
    Object? teacherReviewsByQuestion = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$ExamAnalysisImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      attemptId: null == attemptId
          ? _value.attemptId
          : attemptId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ExamAnalysisStatus,
      questionFeedbacks: null == questionFeedbacks
          ? _value._questionFeedbacks
          : questionFeedbacks // ignore: cast_nullable_to_non_nullable
              as Map<String, QuestionAnalysisFeedback>,
      skillInsights: null == skillInsights
          ? _value._skillInsights
          : skillInsights // ignore: cast_nullable_to_non_nullable
              as List<SkillInsight>,
      overallRecommendations: null == overallRecommendations
          ? _value._overallRecommendations
          : overallRecommendations // ignore: cast_nullable_to_non_nullable
              as List<OverallRecommendation>,
      teacherReviewsByQuestion: null == teacherReviewsByQuestion
          ? _value._teacherReviewsByQuestion
          : teacherReviewsByQuestion // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, dynamic>>,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ExamAnalysisImpl implements _ExamAnalysis {
  const _$ExamAnalysisImpl(
      {required this.id,
      @JsonKey(name: 'attempt_id') required this.attemptId,
      required this.status,
      @JsonKey(
          name: 'question_feedbacks',
          fromJson: _questionFeedbacksFromJson,
          toJson: _questionFeedbacksToJson)
      final Map<String, QuestionAnalysisFeedback> questionFeedbacks = const {},
      @JsonKey(
          name: 'skill_insights',
          fromJson: _skillInsightsFromJson,
          toJson: _skillInsightsToJson)
      final List<SkillInsight> skillInsights = const [],
      @JsonKey(name: 'overall_recommendations')
      final List<OverallRecommendation> overallRecommendations = const [],
      @JsonKey(
          name: 'teacher_reviews_by_question',
          fromJson: _teacherReviewsByQuestionFromJson,
          toJson: _teacherReviewsByQuestionToJson)
      final Map<String, Map<String, dynamic>> teacherReviewsByQuestion =
          const {},
      @JsonKey(name: 'error_message') this.errorMessage})
      : _questionFeedbacks = questionFeedbacks,
        _skillInsights = skillInsights,
        _overallRecommendations = overallRecommendations,
        _teacherReviewsByQuestion = teacherReviewsByQuestion;

  factory _$ExamAnalysisImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExamAnalysisImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'attempt_id')
  final String attemptId;
  @override
  final ExamAnalysisStatus status;
  final Map<String, QuestionAnalysisFeedback> _questionFeedbacks;
  @override
  @JsonKey(
      name: 'question_feedbacks',
      fromJson: _questionFeedbacksFromJson,
      toJson: _questionFeedbacksToJson)
  Map<String, QuestionAnalysisFeedback> get questionFeedbacks {
    if (_questionFeedbacks is EqualUnmodifiableMapView)
      return _questionFeedbacks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_questionFeedbacks);
  }

  final List<SkillInsight> _skillInsights;
  @override
  @JsonKey(
      name: 'skill_insights',
      fromJson: _skillInsightsFromJson,
      toJson: _skillInsightsToJson)
  List<SkillInsight> get skillInsights {
    if (_skillInsights is EqualUnmodifiableListView) return _skillInsights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_skillInsights);
  }

  final List<OverallRecommendation> _overallRecommendations;
  @override
  @JsonKey(name: 'overall_recommendations')
  List<OverallRecommendation> get overallRecommendations {
    if (_overallRecommendations is EqualUnmodifiableListView)
      return _overallRecommendations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_overallRecommendations);
  }

  final Map<String, Map<String, dynamic>> _teacherReviewsByQuestion;
  @override
  @JsonKey(
      name: 'teacher_reviews_by_question',
      fromJson: _teacherReviewsByQuestionFromJson,
      toJson: _teacherReviewsByQuestionToJson)
  Map<String, Map<String, dynamic>> get teacherReviewsByQuestion {
    if (_teacherReviewsByQuestion is EqualUnmodifiableMapView)
      return _teacherReviewsByQuestion;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_teacherReviewsByQuestion);
  }

  @override
  @JsonKey(name: 'error_message')
  final String? errorMessage;

  @override
  String toString() {
    return 'ExamAnalysis(id: $id, attemptId: $attemptId, status: $status, questionFeedbacks: $questionFeedbacks, skillInsights: $skillInsights, overallRecommendations: $overallRecommendations, teacherReviewsByQuestion: $teacherReviewsByQuestion, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExamAnalysisImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.attemptId, attemptId) ||
                other.attemptId == attemptId) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._questionFeedbacks, _questionFeedbacks) &&
            const DeepCollectionEquality()
                .equals(other._skillInsights, _skillInsights) &&
            const DeepCollectionEquality().equals(
                other._overallRecommendations, _overallRecommendations) &&
            const DeepCollectionEquality().equals(
                other._teacherReviewsByQuestion, _teacherReviewsByQuestion) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      attemptId,
      status,
      const DeepCollectionEquality().hash(_questionFeedbacks),
      const DeepCollectionEquality().hash(_skillInsights),
      const DeepCollectionEquality().hash(_overallRecommendations),
      const DeepCollectionEquality().hash(_teacherReviewsByQuestion),
      errorMessage);

  /// Create a copy of ExamAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExamAnalysisImplCopyWith<_$ExamAnalysisImpl> get copyWith =>
      __$$ExamAnalysisImplCopyWithImpl<_$ExamAnalysisImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExamAnalysisImplToJson(
      this,
    );
  }
}

abstract class _ExamAnalysis implements ExamAnalysis {
  const factory _ExamAnalysis(
          {required final String id,
          @JsonKey(name: 'attempt_id') required final String attemptId,
          required final ExamAnalysisStatus status,
          @JsonKey(
              name: 'question_feedbacks',
              fromJson: _questionFeedbacksFromJson,
              toJson: _questionFeedbacksToJson)
          final Map<String, QuestionAnalysisFeedback> questionFeedbacks,
          @JsonKey(
              name: 'skill_insights',
              fromJson: _skillInsightsFromJson,
              toJson: _skillInsightsToJson)
          final List<SkillInsight> skillInsights,
          @JsonKey(name: 'overall_recommendations')
          final List<OverallRecommendation> overallRecommendations,
          @JsonKey(
              name: 'teacher_reviews_by_question',
              fromJson: _teacherReviewsByQuestionFromJson,
              toJson: _teacherReviewsByQuestionToJson)
          final Map<String, Map<String, dynamic>> teacherReviewsByQuestion,
          @JsonKey(name: 'error_message') final String? errorMessage}) =
      _$ExamAnalysisImpl;

  factory _ExamAnalysis.fromJson(Map<String, dynamic> json) =
      _$ExamAnalysisImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'attempt_id')
  String get attemptId;
  @override
  ExamAnalysisStatus get status;
  @override
  @JsonKey(
      name: 'question_feedbacks',
      fromJson: _questionFeedbacksFromJson,
      toJson: _questionFeedbacksToJson)
  Map<String, QuestionAnalysisFeedback> get questionFeedbacks;
  @override
  @JsonKey(
      name: 'skill_insights',
      fromJson: _skillInsightsFromJson,
      toJson: _skillInsightsToJson)
  List<SkillInsight> get skillInsights;
  @override
  @JsonKey(name: 'overall_recommendations')
  List<OverallRecommendation> get overallRecommendations;
  @override
  @JsonKey(
      name: 'teacher_reviews_by_question',
      fromJson: _teacherReviewsByQuestionFromJson,
      toJson: _teacherReviewsByQuestionToJson)
  Map<String, Map<String, dynamic>> get teacherReviewsByQuestion;
  @override
  @JsonKey(name: 'error_message')
  String? get errorMessage;

  /// Create a copy of ExamAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExamAnalysisImplCopyWith<_$ExamAnalysisImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
