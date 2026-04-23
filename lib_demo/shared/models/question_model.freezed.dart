// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'question_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Question _$QuestionFromJson(Map<String, dynamic> json) {
  return _Question.fromJson(json);
}

/// @nodoc
mixin _$Question {
  String get id => throw _privateConstructorUsedError;
  QuestionType get type => throw _privateConstructorUsedError;
  SkillArea get skill => throw _privateConstructorUsedError;
  Difficulty get difficulty => throw _privateConstructorUsedError;
  String? get introText =>
      throw _privateConstructorUsedError; // context shown above the prompt
  String? get introImageUrl =>
      throw _privateConstructorUsedError; // image shown above the prompt
  String get prompt =>
      throw _privateConstructorUsedError; // question text (may contain {blank})
  String? get audioUrl =>
      throw _privateConstructorUsedError; // for listening questions
  String? get imageUrl =>
      throw _privateConstructorUsedError; // for question-level image (inline)
  String? get passageText =>
      throw _privateConstructorUsedError; // long-form reading passage
  List<QuestionOption> get options =>
      throw _privateConstructorUsedError; // MCQ options
  List<MatchPair> get matchPairs =>
      throw _privateConstructorUsedError; // matching pairs
  List<String> get orderItems =>
      throw _privateConstructorUsedError; // ordering items
  String? get correctAnswer =>
      throw _privateConstructorUsedError; // fill-blank / speaking rubric
  List<String> get acceptedAnswers =>
      throw _privateConstructorUsedError; // normalized alternative answers
  String get explanation =>
      throw _privateConstructorUsedError; // shown post-answer
  int get points => throw _privateConstructorUsedError;

  /// Serializes this Question to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionCopyWith<Question> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionCopyWith<$Res> {
  factory $QuestionCopyWith(Question value, $Res Function(Question) then) =
      _$QuestionCopyWithImpl<$Res, Question>;
  @useResult
  $Res call(
      {String id,
      QuestionType type,
      SkillArea skill,
      Difficulty difficulty,
      String? introText,
      String? introImageUrl,
      String prompt,
      String? audioUrl,
      String? imageUrl,
      String? passageText,
      List<QuestionOption> options,
      List<MatchPair> matchPairs,
      List<String> orderItems,
      String? correctAnswer,
      List<String> acceptedAnswers,
      String explanation,
      int points});
}

/// @nodoc
class _$QuestionCopyWithImpl<$Res, $Val extends Question>
    implements $QuestionCopyWith<$Res> {
  _$QuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? skill = null,
    Object? difficulty = null,
    Object? introText = freezed,
    Object? introImageUrl = freezed,
    Object? prompt = null,
    Object? audioUrl = freezed,
    Object? imageUrl = freezed,
    Object? passageText = freezed,
    Object? options = null,
    Object? matchPairs = null,
    Object? orderItems = null,
    Object? correctAnswer = freezed,
    Object? acceptedAnswers = null,
    Object? explanation = null,
    Object? points = null,
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
      introText: freezed == introText
          ? _value.introText
          : introText // ignore: cast_nullable_to_non_nullable
              as String?,
      introImageUrl: freezed == introImageUrl
          ? _value.introImageUrl
          : introImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      prompt: null == prompt
          ? _value.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      audioUrl: freezed == audioUrl
          ? _value.audioUrl
          : audioUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      passageText: freezed == passageText
          ? _value.passageText
          : passageText // ignore: cast_nullable_to_non_nullable
              as String?,
      options: null == options
          ? _value.options
          : options // ignore: cast_nullable_to_non_nullable
              as List<QuestionOption>,
      matchPairs: null == matchPairs
          ? _value.matchPairs
          : matchPairs // ignore: cast_nullable_to_non_nullable
              as List<MatchPair>,
      orderItems: null == orderItems
          ? _value.orderItems
          : orderItems // ignore: cast_nullable_to_non_nullable
              as List<String>,
      correctAnswer: freezed == correctAnswer
          ? _value.correctAnswer
          : correctAnswer // ignore: cast_nullable_to_non_nullable
              as String?,
      acceptedAnswers: null == acceptedAnswers
          ? _value.acceptedAnswers
          : acceptedAnswers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
      points: null == points
          ? _value.points
          : points // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestionImplCopyWith<$Res>
    implements $QuestionCopyWith<$Res> {
  factory _$$QuestionImplCopyWith(
          _$QuestionImpl value, $Res Function(_$QuestionImpl) then) =
      __$$QuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      QuestionType type,
      SkillArea skill,
      Difficulty difficulty,
      String? introText,
      String? introImageUrl,
      String prompt,
      String? audioUrl,
      String? imageUrl,
      String? passageText,
      List<QuestionOption> options,
      List<MatchPair> matchPairs,
      List<String> orderItems,
      String? correctAnswer,
      List<String> acceptedAnswers,
      String explanation,
      int points});
}

/// @nodoc
class __$$QuestionImplCopyWithImpl<$Res>
    extends _$QuestionCopyWithImpl<$Res, _$QuestionImpl>
    implements _$$QuestionImplCopyWith<$Res> {
  __$$QuestionImplCopyWithImpl(
      _$QuestionImpl _value, $Res Function(_$QuestionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? skill = null,
    Object? difficulty = null,
    Object? introText = freezed,
    Object? introImageUrl = freezed,
    Object? prompt = null,
    Object? audioUrl = freezed,
    Object? imageUrl = freezed,
    Object? passageText = freezed,
    Object? options = null,
    Object? matchPairs = null,
    Object? orderItems = null,
    Object? correctAnswer = freezed,
    Object? acceptedAnswers = null,
    Object? explanation = null,
    Object? points = null,
  }) {
    return _then(_$QuestionImpl(
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
      introText: freezed == introText
          ? _value.introText
          : introText // ignore: cast_nullable_to_non_nullable
              as String?,
      introImageUrl: freezed == introImageUrl
          ? _value.introImageUrl
          : introImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      prompt: null == prompt
          ? _value.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      audioUrl: freezed == audioUrl
          ? _value.audioUrl
          : audioUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      passageText: freezed == passageText
          ? _value.passageText
          : passageText // ignore: cast_nullable_to_non_nullable
              as String?,
      options: null == options
          ? _value._options
          : options // ignore: cast_nullable_to_non_nullable
              as List<QuestionOption>,
      matchPairs: null == matchPairs
          ? _value._matchPairs
          : matchPairs // ignore: cast_nullable_to_non_nullable
              as List<MatchPair>,
      orderItems: null == orderItems
          ? _value._orderItems
          : orderItems // ignore: cast_nullable_to_non_nullable
              as List<String>,
      correctAnswer: freezed == correctAnswer
          ? _value.correctAnswer
          : correctAnswer // ignore: cast_nullable_to_non_nullable
              as String?,
      acceptedAnswers: null == acceptedAnswers
          ? _value._acceptedAnswers
          : acceptedAnswers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      explanation: null == explanation
          ? _value.explanation
          : explanation // ignore: cast_nullable_to_non_nullable
              as String,
      points: null == points
          ? _value.points
          : points // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestionImpl implements _Question {
  const _$QuestionImpl(
      {required this.id,
      required this.type,
      required this.skill,
      required this.difficulty,
      this.introText,
      this.introImageUrl,
      required this.prompt,
      this.audioUrl,
      this.imageUrl,
      this.passageText,
      final List<QuestionOption> options = const [],
      final List<MatchPair> matchPairs = const [],
      final List<String> orderItems = const [],
      this.correctAnswer,
      final List<String> acceptedAnswers = const [],
      required this.explanation,
      this.points = 0})
      : _options = options,
        _matchPairs = matchPairs,
        _orderItems = orderItems,
        _acceptedAnswers = acceptedAnswers;

  factory _$QuestionImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestionImplFromJson(json);

  @override
  final String id;
  @override
  final QuestionType type;
  @override
  final SkillArea skill;
  @override
  final Difficulty difficulty;
  @override
  final String? introText;
// context shown above the prompt
  @override
  final String? introImageUrl;
// image shown above the prompt
  @override
  final String prompt;
// question text (may contain {blank})
  @override
  final String? audioUrl;
// for listening questions
  @override
  final String? imageUrl;
// for question-level image (inline)
  @override
  final String? passageText;
// long-form reading passage
  final List<QuestionOption> _options;
// long-form reading passage
  @override
  @JsonKey()
  List<QuestionOption> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

// MCQ options
  final List<MatchPair> _matchPairs;
// MCQ options
  @override
  @JsonKey()
  List<MatchPair> get matchPairs {
    if (_matchPairs is EqualUnmodifiableListView) return _matchPairs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_matchPairs);
  }

// matching pairs
  final List<String> _orderItems;
// matching pairs
  @override
  @JsonKey()
  List<String> get orderItems {
    if (_orderItems is EqualUnmodifiableListView) return _orderItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_orderItems);
  }

// ordering items
  @override
  final String? correctAnswer;
// fill-blank / speaking rubric
  final List<String> _acceptedAnswers;
// fill-blank / speaking rubric
  @override
  @JsonKey()
  List<String> get acceptedAnswers {
    if (_acceptedAnswers is EqualUnmodifiableListView) return _acceptedAnswers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_acceptedAnswers);
  }

// normalized alternative answers
  @override
  final String explanation;
// shown post-answer
  @override
  @JsonKey()
  final int points;

  @override
  String toString() {
    return 'Question(id: $id, type: $type, skill: $skill, difficulty: $difficulty, introText: $introText, introImageUrl: $introImageUrl, prompt: $prompt, audioUrl: $audioUrl, imageUrl: $imageUrl, passageText: $passageText, options: $options, matchPairs: $matchPairs, orderItems: $orderItems, correctAnswer: $correctAnswer, acceptedAnswers: $acceptedAnswers, explanation: $explanation, points: $points)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.skill, skill) || other.skill == skill) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.introText, introText) ||
                other.introText == introText) &&
            (identical(other.introImageUrl, introImageUrl) ||
                other.introImageUrl == introImageUrl) &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            (identical(other.audioUrl, audioUrl) ||
                other.audioUrl == audioUrl) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.passageText, passageText) ||
                other.passageText == passageText) &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            const DeepCollectionEquality()
                .equals(other._matchPairs, _matchPairs) &&
            const DeepCollectionEquality()
                .equals(other._orderItems, _orderItems) &&
            (identical(other.correctAnswer, correctAnswer) ||
                other.correctAnswer == correctAnswer) &&
            const DeepCollectionEquality()
                .equals(other._acceptedAnswers, _acceptedAnswers) &&
            (identical(other.explanation, explanation) ||
                other.explanation == explanation) &&
            (identical(other.points, points) || other.points == points));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      skill,
      difficulty,
      introText,
      introImageUrl,
      prompt,
      audioUrl,
      imageUrl,
      passageText,
      const DeepCollectionEquality().hash(_options),
      const DeepCollectionEquality().hash(_matchPairs),
      const DeepCollectionEquality().hash(_orderItems),
      correctAnswer,
      const DeepCollectionEquality().hash(_acceptedAnswers),
      explanation,
      points);

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionImplCopyWith<_$QuestionImpl> get copyWith =>
      __$$QuestionImplCopyWithImpl<_$QuestionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestionImplToJson(
      this,
    );
  }
}

abstract class _Question implements Question {
  const factory _Question(
      {required final String id,
      required final QuestionType type,
      required final SkillArea skill,
      required final Difficulty difficulty,
      final String? introText,
      final String? introImageUrl,
      required final String prompt,
      final String? audioUrl,
      final String? imageUrl,
      final String? passageText,
      final List<QuestionOption> options,
      final List<MatchPair> matchPairs,
      final List<String> orderItems,
      final String? correctAnswer,
      final List<String> acceptedAnswers,
      required final String explanation,
      final int points}) = _$QuestionImpl;

  factory _Question.fromJson(Map<String, dynamic> json) =
      _$QuestionImpl.fromJson;

  @override
  String get id;
  @override
  QuestionType get type;
  @override
  SkillArea get skill;
  @override
  Difficulty get difficulty;
  @override
  String? get introText; // context shown above the prompt
  @override
  String? get introImageUrl; // image shown above the prompt
  @override
  String get prompt; // question text (may contain {blank})
  @override
  String? get audioUrl; // for listening questions
  @override
  String? get imageUrl; // for question-level image (inline)
  @override
  String? get passageText; // long-form reading passage
  @override
  List<QuestionOption> get options; // MCQ options
  @override
  List<MatchPair> get matchPairs; // matching pairs
  @override
  List<String> get orderItems; // ordering items
  @override
  String? get correctAnswer; // fill-blank / speaking rubric
  @override
  List<String> get acceptedAnswers; // normalized alternative answers
  @override
  String get explanation; // shown post-answer
  @override
  int get points;

  /// Create a copy of Question
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionImplCopyWith<_$QuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

QuestionOption _$QuestionOptionFromJson(Map<String, dynamic> json) {
  return _QuestionOption.fromJson(json);
}

/// @nodoc
mixin _$QuestionOption {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  bool get isCorrect => throw _privateConstructorUsedError;

  /// Serializes this QuestionOption to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionOptionCopyWith<QuestionOption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionOptionCopyWith<$Res> {
  factory $QuestionOptionCopyWith(
          QuestionOption value, $Res Function(QuestionOption) then) =
      _$QuestionOptionCopyWithImpl<$Res, QuestionOption>;
  @useResult
  $Res call({String id, String text, String? imageUrl, bool isCorrect});
}

/// @nodoc
class _$QuestionOptionCopyWithImpl<$Res, $Val extends QuestionOption>
    implements $QuestionOptionCopyWith<$Res> {
  _$QuestionOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? imageUrl = freezed,
    Object? isCorrect = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestionOptionImplCopyWith<$Res>
    implements $QuestionOptionCopyWith<$Res> {
  factory _$$QuestionOptionImplCopyWith(_$QuestionOptionImpl value,
          $Res Function(_$QuestionOptionImpl) then) =
      __$$QuestionOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String text, String? imageUrl, bool isCorrect});
}

/// @nodoc
class __$$QuestionOptionImplCopyWithImpl<$Res>
    extends _$QuestionOptionCopyWithImpl<$Res, _$QuestionOptionImpl>
    implements _$$QuestionOptionImplCopyWith<$Res> {
  __$$QuestionOptionImplCopyWithImpl(
      _$QuestionOptionImpl _value, $Res Function(_$QuestionOptionImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? imageUrl = freezed,
    Object? isCorrect = null,
  }) {
    return _then(_$QuestionOptionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isCorrect: null == isCorrect
          ? _value.isCorrect
          : isCorrect // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestionOptionImpl implements _QuestionOption {
  const _$QuestionOptionImpl(
      {required this.id,
      required this.text,
      this.imageUrl,
      this.isCorrect = false});

  factory _$QuestionOptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestionOptionImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final String? imageUrl;
  @override
  @JsonKey()
  final bool isCorrect;

  @override
  String toString() {
    return 'QuestionOption(id: $id, text: $text, imageUrl: $imageUrl, isCorrect: $isCorrect)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionOptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.isCorrect, isCorrect) ||
                other.isCorrect == isCorrect));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, text, imageUrl, isCorrect);

  /// Create a copy of QuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionOptionImplCopyWith<_$QuestionOptionImpl> get copyWith =>
      __$$QuestionOptionImplCopyWithImpl<_$QuestionOptionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestionOptionImplToJson(
      this,
    );
  }
}

abstract class _QuestionOption implements QuestionOption {
  const factory _QuestionOption(
      {required final String id,
      required final String text,
      final String? imageUrl,
      final bool isCorrect}) = _$QuestionOptionImpl;

  factory _QuestionOption.fromJson(Map<String, dynamic> json) =
      _$QuestionOptionImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
  @override
  String? get imageUrl;
  @override
  bool get isCorrect;

  /// Create a copy of QuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionOptionImplCopyWith<_$QuestionOptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MatchPair _$MatchPairFromJson(Map<String, dynamic> json) {
  return _MatchPair.fromJson(json);
}

/// @nodoc
mixin _$MatchPair {
  String get leftId => throw _privateConstructorUsedError;
  String get leftText => throw _privateConstructorUsedError;
  String get rightId => throw _privateConstructorUsedError;
  String get rightText => throw _privateConstructorUsedError;

  /// Serializes this MatchPair to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchPair
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchPairCopyWith<MatchPair> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchPairCopyWith<$Res> {
  factory $MatchPairCopyWith(MatchPair value, $Res Function(MatchPair) then) =
      _$MatchPairCopyWithImpl<$Res, MatchPair>;
  @useResult
  $Res call({String leftId, String leftText, String rightId, String rightText});
}

/// @nodoc
class _$MatchPairCopyWithImpl<$Res, $Val extends MatchPair>
    implements $MatchPairCopyWith<$Res> {
  _$MatchPairCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchPair
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? leftId = null,
    Object? leftText = null,
    Object? rightId = null,
    Object? rightText = null,
  }) {
    return _then(_value.copyWith(
      leftId: null == leftId
          ? _value.leftId
          : leftId // ignore: cast_nullable_to_non_nullable
              as String,
      leftText: null == leftText
          ? _value.leftText
          : leftText // ignore: cast_nullable_to_non_nullable
              as String,
      rightId: null == rightId
          ? _value.rightId
          : rightId // ignore: cast_nullable_to_non_nullable
              as String,
      rightText: null == rightText
          ? _value.rightText
          : rightText // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MatchPairImplCopyWith<$Res>
    implements $MatchPairCopyWith<$Res> {
  factory _$$MatchPairImplCopyWith(
          _$MatchPairImpl value, $Res Function(_$MatchPairImpl) then) =
      __$$MatchPairImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String leftId, String leftText, String rightId, String rightText});
}

/// @nodoc
class __$$MatchPairImplCopyWithImpl<$Res>
    extends _$MatchPairCopyWithImpl<$Res, _$MatchPairImpl>
    implements _$$MatchPairImplCopyWith<$Res> {
  __$$MatchPairImplCopyWithImpl(
      _$MatchPairImpl _value, $Res Function(_$MatchPairImpl) _then)
      : super(_value, _then);

  /// Create a copy of MatchPair
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? leftId = null,
    Object? leftText = null,
    Object? rightId = null,
    Object? rightText = null,
  }) {
    return _then(_$MatchPairImpl(
      leftId: null == leftId
          ? _value.leftId
          : leftId // ignore: cast_nullable_to_non_nullable
              as String,
      leftText: null == leftText
          ? _value.leftText
          : leftText // ignore: cast_nullable_to_non_nullable
              as String,
      rightId: null == rightId
          ? _value.rightId
          : rightId // ignore: cast_nullable_to_non_nullable
              as String,
      rightText: null == rightText
          ? _value.rightText
          : rightText // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MatchPairImpl implements _MatchPair {
  const _$MatchPairImpl(
      {required this.leftId,
      required this.leftText,
      required this.rightId,
      required this.rightText});

  factory _$MatchPairImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchPairImplFromJson(json);

  @override
  final String leftId;
  @override
  final String leftText;
  @override
  final String rightId;
  @override
  final String rightText;

  @override
  String toString() {
    return 'MatchPair(leftId: $leftId, leftText: $leftText, rightId: $rightId, rightText: $rightText)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchPairImpl &&
            (identical(other.leftId, leftId) || other.leftId == leftId) &&
            (identical(other.leftText, leftText) ||
                other.leftText == leftText) &&
            (identical(other.rightId, rightId) || other.rightId == rightId) &&
            (identical(other.rightText, rightText) ||
                other.rightText == rightText));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, leftId, leftText, rightId, rightText);

  /// Create a copy of MatchPair
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchPairImplCopyWith<_$MatchPairImpl> get copyWith =>
      __$$MatchPairImplCopyWithImpl<_$MatchPairImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchPairImplToJson(
      this,
    );
  }
}

abstract class _MatchPair implements MatchPair {
  const factory _MatchPair(
      {required final String leftId,
      required final String leftText,
      required final String rightId,
      required final String rightText}) = _$MatchPairImpl;

  factory _MatchPair.fromJson(Map<String, dynamic> json) =
      _$MatchPairImpl.fromJson;

  @override
  String get leftId;
  @override
  String get leftText;
  @override
  String get rightId;
  @override
  String get rightText;

  /// Create a copy of MatchPair
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchPairImplCopyWith<_$MatchPairImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

QuestionAnswer _$QuestionAnswerFromJson(Map<String, dynamic> json) {
  return _QuestionAnswer.fromJson(json);
}

/// @nodoc
mixin _$QuestionAnswer {
  String get questionId => throw _privateConstructorUsedError;
  String? get selectedOptionId => throw _privateConstructorUsedError;
  String? get writtenAnswer => throw _privateConstructorUsedError;
  String? get audioKey =>
      throw _privateConstructorUsedError; // S3 key for speaking upload
  List<String> get selectedOptionIds => throw _privateConstructorUsedError;
  List<String> get orderedIds => throw _privateConstructorUsedError;
  Map<String, String> get matchedPairs =>
      throw _privateConstructorUsedError; // leftId → rightId
  bool get isFlagged => throw _privateConstructorUsedError;
  int? get timeSpentSeconds => throw _privateConstructorUsedError;

  /// Serializes this QuestionAnswer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuestionAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuestionAnswerCopyWith<QuestionAnswer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuestionAnswerCopyWith<$Res> {
  factory $QuestionAnswerCopyWith(
          QuestionAnswer value, $Res Function(QuestionAnswer) then) =
      _$QuestionAnswerCopyWithImpl<$Res, QuestionAnswer>;
  @useResult
  $Res call(
      {String questionId,
      String? selectedOptionId,
      String? writtenAnswer,
      String? audioKey,
      List<String> selectedOptionIds,
      List<String> orderedIds,
      Map<String, String> matchedPairs,
      bool isFlagged,
      int? timeSpentSeconds});
}

/// @nodoc
class _$QuestionAnswerCopyWithImpl<$Res, $Val extends QuestionAnswer>
    implements $QuestionAnswerCopyWith<$Res> {
  _$QuestionAnswerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuestionAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? selectedOptionId = freezed,
    Object? writtenAnswer = freezed,
    Object? audioKey = freezed,
    Object? selectedOptionIds = null,
    Object? orderedIds = null,
    Object? matchedPairs = null,
    Object? isFlagged = null,
    Object? timeSpentSeconds = freezed,
  }) {
    return _then(_value.copyWith(
      questionId: null == questionId
          ? _value.questionId
          : questionId // ignore: cast_nullable_to_non_nullable
              as String,
      selectedOptionId: freezed == selectedOptionId
          ? _value.selectedOptionId
          : selectedOptionId // ignore: cast_nullable_to_non_nullable
              as String?,
      writtenAnswer: freezed == writtenAnswer
          ? _value.writtenAnswer
          : writtenAnswer // ignore: cast_nullable_to_non_nullable
              as String?,
      audioKey: freezed == audioKey
          ? _value.audioKey
          : audioKey // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedOptionIds: null == selectedOptionIds
          ? _value.selectedOptionIds
          : selectedOptionIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      orderedIds: null == orderedIds
          ? _value.orderedIds
          : orderedIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      matchedPairs: null == matchedPairs
          ? _value.matchedPairs
          : matchedPairs // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      isFlagged: null == isFlagged
          ? _value.isFlagged
          : isFlagged // ignore: cast_nullable_to_non_nullable
              as bool,
      timeSpentSeconds: freezed == timeSpentSeconds
          ? _value.timeSpentSeconds
          : timeSpentSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuestionAnswerImplCopyWith<$Res>
    implements $QuestionAnswerCopyWith<$Res> {
  factory _$$QuestionAnswerImplCopyWith(_$QuestionAnswerImpl value,
          $Res Function(_$QuestionAnswerImpl) then) =
      __$$QuestionAnswerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String questionId,
      String? selectedOptionId,
      String? writtenAnswer,
      String? audioKey,
      List<String> selectedOptionIds,
      List<String> orderedIds,
      Map<String, String> matchedPairs,
      bool isFlagged,
      int? timeSpentSeconds});
}

/// @nodoc
class __$$QuestionAnswerImplCopyWithImpl<$Res>
    extends _$QuestionAnswerCopyWithImpl<$Res, _$QuestionAnswerImpl>
    implements _$$QuestionAnswerImplCopyWith<$Res> {
  __$$QuestionAnswerImplCopyWithImpl(
      _$QuestionAnswerImpl _value, $Res Function(_$QuestionAnswerImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuestionAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? questionId = null,
    Object? selectedOptionId = freezed,
    Object? writtenAnswer = freezed,
    Object? audioKey = freezed,
    Object? selectedOptionIds = null,
    Object? orderedIds = null,
    Object? matchedPairs = null,
    Object? isFlagged = null,
    Object? timeSpentSeconds = freezed,
  }) {
    return _then(_$QuestionAnswerImpl(
      questionId: null == questionId
          ? _value.questionId
          : questionId // ignore: cast_nullable_to_non_nullable
              as String,
      selectedOptionId: freezed == selectedOptionId
          ? _value.selectedOptionId
          : selectedOptionId // ignore: cast_nullable_to_non_nullable
              as String?,
      writtenAnswer: freezed == writtenAnswer
          ? _value.writtenAnswer
          : writtenAnswer // ignore: cast_nullable_to_non_nullable
              as String?,
      audioKey: freezed == audioKey
          ? _value.audioKey
          : audioKey // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedOptionIds: null == selectedOptionIds
          ? _value._selectedOptionIds
          : selectedOptionIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      orderedIds: null == orderedIds
          ? _value._orderedIds
          : orderedIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      matchedPairs: null == matchedPairs
          ? _value._matchedPairs
          : matchedPairs // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      isFlagged: null == isFlagged
          ? _value.isFlagged
          : isFlagged // ignore: cast_nullable_to_non_nullable
              as bool,
      timeSpentSeconds: freezed == timeSpentSeconds
          ? _value.timeSpentSeconds
          : timeSpentSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuestionAnswerImpl implements _QuestionAnswer {
  const _$QuestionAnswerImpl(
      {required this.questionId,
      this.selectedOptionId,
      this.writtenAnswer,
      this.audioKey,
      final List<String> selectedOptionIds = const [],
      final List<String> orderedIds = const [],
      final Map<String, String> matchedPairs = const {},
      this.isFlagged = false,
      this.timeSpentSeconds})
      : _selectedOptionIds = selectedOptionIds,
        _orderedIds = orderedIds,
        _matchedPairs = matchedPairs;

  factory _$QuestionAnswerImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuestionAnswerImplFromJson(json);

  @override
  final String questionId;
  @override
  final String? selectedOptionId;
  @override
  final String? writtenAnswer;
  @override
  final String? audioKey;
// S3 key for speaking upload
  final List<String> _selectedOptionIds;
// S3 key for speaking upload
  @override
  @JsonKey()
  List<String> get selectedOptionIds {
    if (_selectedOptionIds is EqualUnmodifiableListView)
      return _selectedOptionIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedOptionIds);
  }

  final List<String> _orderedIds;
  @override
  @JsonKey()
  List<String> get orderedIds {
    if (_orderedIds is EqualUnmodifiableListView) return _orderedIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_orderedIds);
  }

  final Map<String, String> _matchedPairs;
  @override
  @JsonKey()
  Map<String, String> get matchedPairs {
    if (_matchedPairs is EqualUnmodifiableMapView) return _matchedPairs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_matchedPairs);
  }

// leftId → rightId
  @override
  @JsonKey()
  final bool isFlagged;
  @override
  final int? timeSpentSeconds;

  @override
  String toString() {
    return 'QuestionAnswer(questionId: $questionId, selectedOptionId: $selectedOptionId, writtenAnswer: $writtenAnswer, audioKey: $audioKey, selectedOptionIds: $selectedOptionIds, orderedIds: $orderedIds, matchedPairs: $matchedPairs, isFlagged: $isFlagged, timeSpentSeconds: $timeSpentSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuestionAnswerImpl &&
            (identical(other.questionId, questionId) ||
                other.questionId == questionId) &&
            (identical(other.selectedOptionId, selectedOptionId) ||
                other.selectedOptionId == selectedOptionId) &&
            (identical(other.writtenAnswer, writtenAnswer) ||
                other.writtenAnswer == writtenAnswer) &&
            (identical(other.audioKey, audioKey) ||
                other.audioKey == audioKey) &&
            const DeepCollectionEquality()
                .equals(other._selectedOptionIds, _selectedOptionIds) &&
            const DeepCollectionEquality()
                .equals(other._orderedIds, _orderedIds) &&
            const DeepCollectionEquality()
                .equals(other._matchedPairs, _matchedPairs) &&
            (identical(other.isFlagged, isFlagged) ||
                other.isFlagged == isFlagged) &&
            (identical(other.timeSpentSeconds, timeSpentSeconds) ||
                other.timeSpentSeconds == timeSpentSeconds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      questionId,
      selectedOptionId,
      writtenAnswer,
      audioKey,
      const DeepCollectionEquality().hash(_selectedOptionIds),
      const DeepCollectionEquality().hash(_orderedIds),
      const DeepCollectionEquality().hash(_matchedPairs),
      isFlagged,
      timeSpentSeconds);

  /// Create a copy of QuestionAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuestionAnswerImplCopyWith<_$QuestionAnswerImpl> get copyWith =>
      __$$QuestionAnswerImplCopyWithImpl<_$QuestionAnswerImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuestionAnswerImplToJson(
      this,
    );
  }
}

abstract class _QuestionAnswer implements QuestionAnswer {
  const factory _QuestionAnswer(
      {required final String questionId,
      final String? selectedOptionId,
      final String? writtenAnswer,
      final String? audioKey,
      final List<String> selectedOptionIds,
      final List<String> orderedIds,
      final Map<String, String> matchedPairs,
      final bool isFlagged,
      final int? timeSpentSeconds}) = _$QuestionAnswerImpl;

  factory _QuestionAnswer.fromJson(Map<String, dynamic> json) =
      _$QuestionAnswerImpl.fromJson;

  @override
  String get questionId;
  @override
  String? get selectedOptionId;
  @override
  String? get writtenAnswer;
  @override
  String? get audioKey; // S3 key for speaking upload
  @override
  List<String> get selectedOptionIds;
  @override
  List<String> get orderedIds;
  @override
  Map<String, String> get matchedPairs; // leftId → rightId
  @override
  bool get isFlagged;
  @override
  int? get timeSpentSeconds;

  /// Create a copy of QuestionAnswer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuestionAnswerImplCopyWith<_$QuestionAnswerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
