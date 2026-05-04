class Course {
  const Course({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.status,
    required this.sequenceNo,
    this.bannerImageId = '',
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String status;
  final int sequenceNo;
  final String bannerImageId;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'published',
      sequenceNo: (json['sequence_no'] as num?)?.toInt() ?? 0,
      bannerImageId: json['banner_image_id'] as String? ?? '',
    );
  }
}

// SkillSummary is computed from exercises grouped by skill_kind within a module.
// The skills table no longer exists; this is a derived aggregate from the API.
class SkillSummary {
  const SkillSummary({
    required this.moduleId,
    required this.skillKind,
    required this.exerciseCount,
  });

  final String moduleId;
  final String skillKind;
  final int exerciseCount;

  bool get isImplemented =>
      skillKind == 'noi' ||
      skillKind == 'viet' ||
      skillKind == 'nghe' ||
      skillKind == 'doc' ||
      skillKind == 'tu_vung' ||
      skillKind == 'ngu_phap' ||
      skillKind == 'interview';

  bool get isWriting => skillKind == 'viet';

  factory SkillSummary.fromJson(Map<String, dynamic> json, String moduleId) {
    return SkillSummary(
      moduleId: moduleId,
      skillKind: json['skill_kind'] as String? ?? '',
      exerciseCount: (json['exercise_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ModuleSummary {
  const ModuleSummary({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.moduleKind,
    required this.sequenceNo,
    required this.status,
  });

  final String id;
  final String courseId;
  final String title;
  final String description;
  final String moduleKind;
  final int sequenceNo;
  final String status;

  factory ModuleSummary.fromJson(Map<String, dynamic> json) {
    return ModuleSummary(
      id: json['id'] as String,
      courseId: json['course_id'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      moduleKind: json['module_kind'] as String? ?? 'daily_plan',
      sequenceNo: (json['sequence_no'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'published',
    );
  }
}

class PlanDay {
  const PlanDay({
    required this.day,
    required this.label,
    required this.description,
    required this.status,
    required this.moduleId,
    required this.moduleKind,
  });

  final int day;
  final String label;
  final String description;
  final String status;
  final String moduleId;
  final String moduleKind;

  bool get isDone => status == 'done';
  bool get isCurrent => status == 'current';
  bool get isMockExam => moduleKind == 'mock_exam';

  factory PlanDay.fromJson(Map<String, dynamic> json) {
    return PlanDay(
      day: (json['day'] as num).toInt(),
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'upcoming',
      moduleId: json['module_id'] as String? ?? '',
      moduleKind: json['module_kind'] as String? ?? 'daily_plan',
    );
  }
}

class MockTestSection {
  const MockTestSection({
    required this.sequenceNo,
    required this.skillKind,
    required this.exerciseId,
    required this.exerciseType,
    required this.maxPoints,
  });

  final int sequenceNo;
  final String skillKind; // noi | nghe | doc | viet
  final String exerciseId;
  final String exerciseType;
  final int maxPoints;

  factory MockTestSection.fromJson(Map<String, dynamic> json) {
    return MockTestSection(
      sequenceNo: (json['sequence_no'] as num).toInt(),
      skillKind: json['skill_kind'] as String? ?? '',
      exerciseId: json['exercise_id'] as String? ?? '',
      exerciseType: json['exercise_type'] as String? ?? '',
      maxPoints: (json['max_points'] as num?)?.toInt() ?? 0,
    );
  }
}

class MockTest {
  const MockTest({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedDurationMinutes,
    required this.status,
    required this.sections,
    this.examMode = '',
    this.passThresholdPercent = 60,
    this.bannerImageId = '',
  });

  final String id;
  final String title;
  final String description;
  final int estimatedDurationMinutes;
  final String status;
  final String examMode;
  final int passThresholdPercent;
  final String bannerImageId;
  final List<MockTestSection> sections;

  int get totalMaxPoints => sections.fold(0, (s, sec) => s + sec.maxPoints);
  bool get hasPronunciationBonus =>
      sections.length == 4 &&
      totalMaxPoints == 37 &&
      sections.every(
        (s) => s.skillKind == 'noi' || s.exerciseType.startsWith('uloha_'),
      );
  int get totalScoreMax => totalMaxPoints + (hasPronunciationBonus ? 3 : 0);

  factory MockTest.fromJson(Map<String, dynamic> json) {
    final raw = json['sections'] as List<dynamic>? ?? const [];
    return MockTest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      estimatedDurationMinutes:
          (json['estimated_duration_minutes'] as num?)?.toInt() ?? 15,
      status: json['status'] as String? ?? 'draft',
      examMode: json['exam_mode'] as String? ?? '',
      passThresholdPercent:
          (json['pass_threshold_percent'] as num?)?.toInt() ?? 60,
      bannerImageId: json['banner_image_id'] as String? ?? '',
      sections:
          raw
              .map((e) => MockTestSection.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class MockExamSection {
  const MockExamSection({
    required this.sequenceNo,
    required this.skillKind,
    required this.exerciseId,
    required this.exerciseType,
    required this.maxPoints,
    required this.attemptId,
    required this.sectionScore,
    required this.status,
  });

  final int sequenceNo;
  final String skillKind;
  final String exerciseId;
  final String exerciseType;
  final int maxPoints;
  final String attemptId;
  final int sectionScore;
  final String status;

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';

  factory MockExamSection.fromJson(Map<String, dynamic> json) {
    return MockExamSection(
      sequenceNo: (json['sequence_no'] as num).toInt(),
      skillKind: json['skill_kind'] as String? ?? '',
      exerciseId: json['exercise_id'] as String? ?? '',
      exerciseType: json['exercise_type'] as String? ?? '',
      maxPoints: (json['max_points'] as num?)?.toInt() ?? 0,
      attemptId: json['attempt_id'] as String? ?? '',
      sectionScore: (json['section_score'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class MockExamSessionView {
  const MockExamSessionView({
    required this.id,
    required this.status,
    required this.mockTestId,
    required this.overallScore,
    required this.passed,
    required this.passThresholdPercent,
    required this.overallReadinessLevel,
    required this.overallSummary,
    required this.sections,
  });

  final String id;
  final String status;
  final String mockTestId;
  final int overallScore;
  final bool passed;
  final int passThresholdPercent;
  final String overallReadinessLevel;
  final String overallSummary;
  final List<MockExamSection> sections;

  bool get isCompleted => status == 'completed';

  int get totalMaxPoints => sections.fold(0, (s, sec) => s + sec.maxPoints);
  bool get hasPronunciationBonus =>
      sections.length == 4 &&
      totalMaxPoints == 37 &&
      sections.every(
        (s) => s.skillKind == 'noi' || s.exerciseType.startsWith('uloha_'),
      );
  int get totalScoreMax => totalMaxPoints + (hasPronunciationBonus ? 3 : 0);

  MockExamSection? get nextPending {
    for (final s in sections) {
      if (s.isPending) return s;
    }
    return null;
  }

  factory MockExamSessionView.fromJson(Map<String, dynamic> json) {
    final raw = json['sections'] as List<dynamic>? ?? const [];
    return MockExamSessionView(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'created',
      mockTestId: json['mock_test_id'] as String? ?? '',
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      passed: json['passed'] as bool? ?? false,
      passThresholdPercent:
          (json['pass_threshold_percent'] as num?)?.toInt() ?? 60,
      overallReadinessLevel: json['overall_readiness_level'] as String? ?? '',
      overallSummary: json['overall_summary'] as String? ?? '',
      sections:
          raw
              .map((e) => MockExamSection.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class LearningPlanView {
  const LearningPlanView({
    required this.currentDay,
    required this.startDate,
    required this.status,
    required this.days,
  });

  final int currentDay;
  final String startDate;
  final String status;
  final List<PlanDay> days;

  factory LearningPlanView.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? const [];
    return LearningPlanView(
      currentDay: (json['current_day'] as num?)?.toInt() ?? 1,
      startDate: json['start_date'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      days:
          rawDays
              .map((item) => PlanDay.fromJson(item as Map<String, dynamic>))
              .toList(),
    );
  }
}

class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.title,
    required this.exerciseType,
    required this.shortInstruction,
    this.skillKind = '',
  });

  final String id;
  final String title;
  final String exerciseType;
  final String shortInstruction;
  final String skillKind;

  factory ExerciseSummary.fromJson(Map<String, dynamic> json) {
    return ExerciseSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      exerciseType: json['exercise_type'] as String,
      shortInstruction: json['short_instruction'] as String? ?? '',
      skillKind: json['skill_kind'] as String? ?? '',
    );
  }
}

class ExerciseDetail {
  const ExerciseDetail({
    required this.id,
    required this.title,
    required this.exerciseType,
    required this.learnerInstruction,
    required this.assets,
    required this.questions,
    required this.scenarioTitle,
    required this.scenarioPrompt,
    required this.requiredInfoSlots,
    required this.customQuestionHint,
    required this.storyTitle,
    required this.imageAssetIds,
    required this.narrativeCheckpoints,
    required this.grammarFocus,
    required this.choiceScenarioPrompt,
    required this.choiceOptions,
    required this.expectedReasoningAxes,
    this.writingQuestions = const [],
    this.writingMinWords = 10,
    this.emailPrompt = '',
    this.emailTopics = const [],
    // listening
    this.poslechItems = const [],
    this.poslechOptions = const [],
    this.poslechQuestions = const [],
    // reading
    this.cteniText = '',
    this.cteniItems = const [],
    this.cteniOptions = const [],
    this.cteniQuestions = const [],
    // V6: vocab & grammar
    this.flashcardFront = '',
    this.flashcardBack = '',
    this.flashcardExample = '',
    this.flashcardExampleTranslation = '',
    this.flashcardImageAssetId = '',
    this.matchingPairs = const [],
    this.fillBlankSentence = '',
    this.fillBlankHint = '',
    this.fillBlankExplanation = '',
    this.choiceWordStem = '',
    this.choiceWordExplanation = '',
    this.choiceWordGrammarNote = '',
    this.correctAnswers = const {},
    // V13: ano/ne
    this.anoNePassage = '',
    this.anoNeStatements = const [],
    // V14: interview
    this.interviewTopic = '',
    this.interviewTips = const [],
    this.interviewSystemPrompt = '',
    this.interviewMaxTurns = 8,
    this.interviewShowTranscript = false,
    this.interviewQuestion = '',
    this.interviewOptions = const [],
    // V16
    this.interviewDisplayPrompt = '',
    this.interviewAudioBufferTimeoutMs = 1500,
  });

  final String id;
  final String title;
  final String exerciseType;
  final String learnerInstruction;
  final List<PromptAssetView> assets;
  final List<String> questions;
  final String scenarioTitle;
  final String scenarioPrompt;
  final List<RequiredInfoSlotView> requiredInfoSlots;
  final String customQuestionHint;
  final String storyTitle;
  final List<String> imageAssetIds;
  final List<String> narrativeCheckpoints;
  final List<String> grammarFocus;
  final String choiceScenarioPrompt;
  final List<ChoiceOptionView> choiceOptions;
  final List<String> expectedReasoningAxes;
  final List<String> writingQuestions;
  final int writingMinWords;
  final String emailPrompt;
  final List<String> emailTopics;
  final List<PoslechItemView> poslechItems;
  final List<PoslechOptionView> poslechOptions;
  final List<FillQuestionView> poslechQuestions;
  final String cteniText;
  final List<dynamic> cteniItems; // ReadingItem or TextItem (raw maps)
  final List<PoslechOptionView> cteniOptions;
  final List<FillQuestionView> cteniQuestions;

  // V6: quizcard_basic
  final String flashcardFront;
  final String flashcardBack;
  final String flashcardExample;
  final String flashcardExampleTranslation;
  final String flashcardImageAssetId;

  // V6: matching
  final List<MatchingPairView> matchingPairs;

  // V6: fill_blank
  final String fillBlankSentence;
  final String fillBlankHint;
  final String fillBlankExplanation;

  // V6: choice_word
  final String choiceWordStem;
  final String choiceWordExplanation;
  final String choiceWordGrammarNote;
  final Map<String, String> correctAnswers;

  // V13: cteni_6 / poslech_6
  final String anoNePassage;
  final List<AnoNeStatementView> anoNeStatements;

  // V14: interview_conversation / interview_choice_explain
  final String interviewTopic;
  final List<String> interviewTips;
  final String interviewSystemPrompt;
  final int interviewMaxTurns;
  final bool interviewShowTranscript;
  final String interviewQuestion;
  final List<InterviewOptionView> interviewOptions;

  // V16: derived learner-facing prompt + Simli audio buffer fallback timeout
  final String interviewDisplayPrompt;
  final int interviewAudioBufferTimeoutMs;

  bool get isInterviewConversation => exerciseType == 'interview_conversation';
  bool get isInterviewChoiceExplain =>
      exerciseType == 'interview_choice_explain';
  bool get isInterview => exerciseType.startsWith('interview_');

  bool get isPsani1 => exerciseType == 'psani_1_formular';
  bool get isPsani2 => exerciseType == 'psani_2_email';
  bool get isPoslech => exerciseType.startsWith('poslech_');
  bool get isPoslech5 => exerciseType == 'poslech_5';
  bool get isCteni => exerciseType.startsWith('cteni_');
  bool get isCteni5 => exerciseType == 'cteni_5';
  bool get isCteni6 => exerciseType == 'cteni_6';
  bool get isPoslech6 => exerciseType == 'poslech_6';
  bool get isAnoNe => exerciseType == 'cteni_6' || exerciseType == 'poslech_6';

  // V6: Vocab & Grammar exercise types
  bool get isQuizcard => exerciseType == 'quizcard_basic';
  bool get isMatching => exerciseType == 'matching';
  bool get isFillBlank => exerciseType == 'fill_blank';
  bool get isChoiceWord => exerciseType == 'choice_word';
  bool get isVocabGrammar =>
      isQuizcard || isMatching || isFillBlank || isChoiceWord;

  PromptAssetView? assetById(String assetId) {
    for (final asset in assets) {
      if (asset.id == assetId) {
        return asset;
      }
    }
    return null;
  }

  List<PromptAssetView> get storyImageAssets =>
      imageAssetIds.map(assetById).whereType<PromptAssetView>().toList();

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    final prompt = json['prompt'] as Map<String, dynamic>? ?? const {};
    final detail = json['detail'] as Map<String, dynamic>? ?? const {};
    final assets =
        (json['assets'] as List<dynamic>? ?? const [])
            .map(
              (item) => PromptAssetView.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    final questionPrompts =
        (prompt['question_prompts'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final requiredInfoSlots =
        (detail['required_info_slots'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  RequiredInfoSlotView.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    final imageAssetIds =
        (detail['image_asset_ids'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final narrativeCheckpoints =
        (detail['narrative_checkpoints'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final grammarFocus =
        (detail['grammar_focus'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final choiceOptions =
        (detail['options'] as List<dynamic>? ?? const [])
            .map(
              (item) => ChoiceOptionView.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    final expectedReasoningAxes =
        (detail['expected_reasoning_axes'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final writingQuestions =
        (detail['questions'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final emailTopics =
        (detail['topics'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    return ExerciseDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      exerciseType: json['exercise_type'] as String,
      learnerInstruction: json['learner_instruction'] as String? ?? '',
      assets: assets,
      questions: questionPrompts,
      scenarioTitle: detail['scenario_title'] as String? ?? '',
      scenarioPrompt: detail['scenario_prompt'] as String? ?? '',
      requiredInfoSlots: requiredInfoSlots,
      customQuestionHint: detail['custom_question_hint'] as String? ?? '',
      storyTitle: detail['story_title'] as String? ?? '',
      imageAssetIds: imageAssetIds,
      narrativeCheckpoints: narrativeCheckpoints,
      grammarFocus: grammarFocus,
      choiceScenarioPrompt: detail['scenario_prompt'] as String? ?? '',
      choiceOptions: choiceOptions,
      expectedReasoningAxes: expectedReasoningAxes,
      writingQuestions: writingQuestions,
      writingMinWords:
          (detail['min_words'] as num?)?.toInt() ??
          (json['exercise_type'] == 'psani_2_email' ? 35 : 10),
      emailPrompt: detail['prompt'] as String? ?? '',
      emailTopics: emailTopics,
      poslechItems:
          (detail['items'] as List<dynamic>? ?? const [])
              .map((e) => PoslechItemView.fromJson(e as Map<String, dynamic>))
              .toList(),
      poslechOptions:
          (detail['options'] as List<dynamic>? ?? const [])
              .map((e) => PoslechOptionView.fromJson(e as Map<String, dynamic>))
              .toList(),
      poslechQuestions:
          (detail['questions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(FillQuestionView.fromJson)
              .toList(),
      cteniText: detail['text'] as String? ?? '',
      cteniItems:
          detail['items'] as List<dynamic>? ??
          detail['texts'] as List<dynamic>? ??
          const [],
      cteniOptions:
          (() {
            final opts = detail['options'] ?? detail['persons'];
            if (opts is List<dynamic>) {
              return opts
                  .map(
                    (e) =>
                        PoslechOptionView.fromJson(e as Map<String, dynamic>),
                  )
                  .toList();
            }
            return <PoslechOptionView>[];
          })(),
      cteniQuestions:
          (detail['questions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(FillQuestionView.fromJson)
              .toList(),
      // V6: quizcard_basic
      flashcardFront: detail['front_text'] as String? ?? '',
      flashcardBack: detail['back_text'] as String? ?? '',
      flashcardExample: detail['example_sentence'] as String? ?? '',
      flashcardExampleTranslation:
          detail['example_translation'] as String? ?? '',
      flashcardImageAssetId: detail['image_asset_id'] as String? ?? '',
      // V6: matching
      matchingPairs:
          (detail['pairs'] as List<dynamic>? ?? const [])
              .map((e) => MatchingPairView.fromJson(e as Map<String, dynamic>))
              .toList(),
      // V6: fill_blank
      fillBlankSentence: detail['sentence'] as String? ?? '',
      fillBlankHint: detail['hint'] as String? ?? '',
      fillBlankExplanation: detail['explanation'] as String? ?? '',
      // V6: choice_word
      choiceWordStem: detail['stem'] as String? ?? '',
      choiceWordExplanation: detail['explanation'] as String? ?? '',
      choiceWordGrammarNote: detail['grammar_note'] as String? ?? '',
      correctAnswers: (detail['correct_answers'] as Map<String, dynamic>? ??
              const {})
          .map((k, v) => MapEntry(k, v.toString())),
      // V13: ano/ne
      anoNePassage: detail['passage'] as String? ?? '',
      anoNeStatements:
          (detail['statements'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(AnoNeStatementView.fromJson)
              .toList(),
      // V14: interview
      interviewTopic: detail['topic'] as String? ?? '',
      interviewTips:
          (detail['tips'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      interviewSystemPrompt: detail['system_prompt'] as String? ?? '',
      interviewMaxTurns: (detail['max_turns'] as num?)?.toInt() ?? 8,
      interviewShowTranscript: detail['show_transcript'] as bool? ?? false,
      interviewQuestion: detail['question'] as String? ?? '',
      interviewOptions:
          (detail['options'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(InterviewOptionView.fromJson)
              .toList(),
      // V16
      interviewDisplayPrompt: detail['display_prompt'] as String? ?? '',
      interviewAudioBufferTimeoutMs: _clampAudioBufferTimeout(
        detail['audio_buffer_timeout_ms'],
      ),
    );
  }
}

int _clampAudioBufferTimeout(dynamic raw) {
  final n = (raw as num?)?.toInt() ?? 0;
  if (n <= 0) return 1500;
  if (n < 500) return 500;
  if (n > 5000) return 5000;
  return n;
}

// V13: One statement in a cteni_6 / poslech_6 exercise.
class AnoNeStatementView {
  const AnoNeStatementView({required this.questionNo, required this.statement});

  final int questionNo;
  final String statement;

  factory AnoNeStatementView.fromJson(Map<String, dynamic> json) {
    return AnoNeStatementView(
      questionNo: (json['question_no'] as num?)?.toInt() ?? 0,
      statement: json['statement'] as String? ?? '',
    );
  }
}

// V14: One selectable option in an interview_choice_explain exercise.
class InterviewOptionView {
  const InterviewOptionView({
    required this.id,
    required this.label,
    this.imageAssetId = '',
    this.tips = const [],
  });

  final String id;
  final String label;
  final String imageAssetId;
  final List<String> tips;

  factory InterviewOptionView.fromJson(Map<String, dynamic> json) {
    return InterviewOptionView(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      imageAssetId: json['image_asset_id'] as String? ?? '',
      tips:
          (json['tips'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

// V14: One turn in a completed interview session transcript.
class InterviewTranscriptTurn {
  const InterviewTranscriptTurn({
    required this.speaker,
    required this.text,
    this.atSec = 0,
  });

  final String speaker; // "examiner" | "learner"
  final String text;
  final int atSec;

  Map<String, dynamic> toJson() => {
    'speaker': speaker,
    'text': text,
    'at_sec': atSec,
  };
}

// V14: Signed session URL returned by POST /v1/interview-sessions/token.
class InterviewTokenResponse {
  const InterviewTokenResponse({
    required this.signedUrl,
    required this.expiresIn,
    this.voiceId = '',
  });

  final String signedUrl;
  final int expiresIn;
  final String voiceId;

  factory InterviewTokenResponse.fromJson(Map<String, dynamic> json) {
    return InterviewTokenResponse(
      signedUrl: json['signed_url'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 30,
      voiceId: json['voice_id'] as String? ?? '',
    );
  }
}

// V6: One pair in a matching exercise.
// leftId/rightId are the keys used for submission ("1","2"... / "A","B"...).
class MatchingPairView {
  const MatchingPairView({
    required this.leftId,
    required this.left,
    required this.rightId,
    required this.right,
    this.imageAssetId = '',
  });

  final String leftId;
  final String left; // Czech term (displayed in fixed order on left)
  final String rightId;
  final String right; // Vietnamese definition (shuffled by Flutter on right)
  final String imageAssetId; // V11: optional image for right-column card

  factory MatchingPairView.fromJson(Map<String, dynamic> json) {
    return MatchingPairView(
      leftId: json['left_id'] as String? ?? '',
      left: json['left'] as String? ?? '',
      rightId: json['right_id'] as String? ?? '',
      right: json['right'] as String? ?? '',
      imageAssetId: json['image_asset_id'] as String? ?? '',
    );
  }
}

class PromptAssetView {
  const PromptAssetView({
    required this.id,
    required this.assetKind,
    required this.storageKey,
    required this.mimeType,
    required this.sequenceNo,
  });

  final String id;
  final String assetKind;
  final String storageKey;
  final String mimeType;
  final int sequenceNo;

  bool get isImage => mimeType.startsWith('image/');

  factory PromptAssetView.fromJson(Map<String, dynamic> json) {
    return PromptAssetView(
      id: json['id'] as String? ?? '',
      assetKind: json['asset_kind'] as String? ?? '',
      storageKey: json['storage_key'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sequenceNo: json['sequence_no'] as int? ?? 0,
    );
  }
}

class RequiredInfoSlotView {
  const RequiredInfoSlotView({
    required this.slotKey,
    required this.label,
    required this.sampleQuestion,
  });

  final String slotKey;
  final String label;
  final String sampleQuestion;

  factory RequiredInfoSlotView.fromJson(Map<String, dynamic> json) {
    return RequiredInfoSlotView(
      slotKey: json['slot_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      sampleQuestion: json['sample_question'] as String? ?? '',
    );
  }
}

class ChoiceOptionView {
  const ChoiceOptionView({
    required this.optionKey,
    required this.label,
    required this.imageAssetId,
    required this.description,
  });

  final String optionKey;
  final String label;
  final String imageAssetId;
  final String description;

  factory ChoiceOptionView.fromJson(Map<String, dynamic> json) {
    return ChoiceOptionView(
      optionKey: json['option_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      imageAssetId: json['image_asset_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

// --- Listening (V3) model views ---

class PoslechOptionView {
  const PoslechOptionView({
    required this.key,
    this.text = '',
    this.label = '',
    this.assetId = '',
    this.imageAssetId = '',
  });
  final String key;
  final String text;
  final String label;
  final String
  assetId; // existing ImageOption asset (e.g. uploaded image for послech options)
  final String
  imageAssetId; // V11: MultipleChoiceOption.image_asset_id (vocabulary image)

  factory PoslechOptionView.fromJson(Map<String, dynamic> json) {
    return PoslechOptionView(
      key: json['key'] as String? ?? '',
      text: json['text'] as String? ?? '',
      label: json['label'] as String? ?? '',
      assetId: json['asset_id'] as String? ?? '',
      imageAssetId: json['image_asset_id'] as String? ?? '',
    );
  }
}

class PoslechItemView {
  const PoslechItemView({
    required this.questionNo,
    this.question = '',
    this.options = const [],
  });
  final int questionNo;
  final String question;
  final List<PoslechOptionView> options;

  factory PoslechItemView.fromJson(Map<String, dynamic> json) {
    return PoslechItemView(
      questionNo: (json['question_no'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      options:
          (json['options'] as List<dynamic>? ?? const [])
              .map((e) => PoslechOptionView.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class FillQuestionView {
  const FillQuestionView({required this.questionNo, required this.prompt});
  final int questionNo;
  final String prompt;

  factory FillQuestionView.fromJson(Map<String, dynamic> json) {
    return FillQuestionView(
      questionNo: (json['question_no'] as num?)?.toInt() ?? 0,
      prompt: json['prompt'] as String? ?? '',
    );
  }
}

class AttemptResult {
  const AttemptResult({
    required this.id,
    required this.exerciseId,
    required this.exerciseType,
    required this.status,
    required this.startedAt,
    required this.readinessLevel,
    required this.failureCode,
    this.audio,
    this.transcript,
    required this.transcriptProvider,
    required this.transcriptIsSynthetic,
    this.feedback,
    this.reviewArtifact,
  });

  final String id;
  final String exerciseId;
  final String exerciseType;
  final String status;
  final String startedAt;
  final String readinessLevel;
  final String failureCode;
  final AttemptAudioView? audio;
  final String? transcript;
  final String transcriptProvider;
  final bool transcriptIsSynthetic;
  final AttemptFeedbackView? feedback;
  final AttemptReviewArtifactSummaryView? reviewArtifact;

  String get transcriptPreview {
    final source = transcript?.trim() ?? '';
    if (source.isEmpty) {
      return '';
    }
    if (source.length <= 120) {
      return source;
    }
    return '${source.substring(0, 120)}...';
  }

  factory AttemptResult.fromJson(Map<String, dynamic> json) {
    final feedback =
        json['feedback'] == null
            ? null
            : AttemptFeedbackView.fromJson(
              json['feedback'] as Map<String, dynamic>,
            );
    return AttemptResult(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String? ?? '',
      exerciseType: json['exercise_type'] as String? ?? '',
      status: json['status'] as String,
      startedAt: json['started_at'] as String? ?? '',
      readinessLevel:
          json['readiness_level'] as String? ?? feedback?.readinessLevel ?? '',
      failureCode: json['failure_code'] as String? ?? '',
      audio:
          json['audio'] == null
              ? null
              : AttemptAudioView.fromJson(
                json['audio'] as Map<String, dynamic>,
              ),
      transcript:
          (json['transcript'] as Map<String, dynamic>?)?['full_text']
              as String?,
      transcriptProvider:
          (json['transcript'] as Map<String, dynamic>?)?['provider']
              as String? ??
          '',
      transcriptIsSynthetic:
          (json['transcript'] as Map<String, dynamic>?)?['is_synthetic']
              as bool? ??
          false,
      feedback: feedback,
      reviewArtifact:
          json['review_artifact'] == null
              ? null
              : AttemptReviewArtifactSummaryView.fromJson(
                json['review_artifact'] as Map<String, dynamic>,
              ),
    );
  }
}

class AttemptReviewArtifactSummaryView {
  const AttemptReviewArtifactSummaryView({
    required this.status,
    required this.failureCode,
    required this.generatedAt,
    required this.repairProvider,
  });

  final String status;
  final String failureCode;
  final String generatedAt;
  final String repairProvider;

  factory AttemptReviewArtifactSummaryView.fromJson(Map<String, dynamic> json) {
    return AttemptReviewArtifactSummaryView(
      status: json['status'] as String? ?? 'pending',
      failureCode: json['failure_code'] as String? ?? '',
      generatedAt: json['generated_at'] as String? ?? '',
      repairProvider: json['repair_provider'] as String? ?? '',
    );
  }
}

class AttemptReviewArtifactView {
  const AttemptReviewArtifactView({
    required this.attemptId,
    required this.status,
    required this.sourceTranscriptText,
    required this.sourceTranscriptProvider,
    required this.correctedTranscriptText,
    required this.modelAnswerText,
    required this.speakingFocusItems,
    required this.diffChunks,
    this.ttsAudio,
    required this.repairProvider,
    required this.generatedAt,
    required this.failedAt,
    required this.failureCode,
  });

  final String attemptId;
  final String status;
  final String sourceTranscriptText;
  final String sourceTranscriptProvider;
  final String correctedTranscriptText;
  final String modelAnswerText;
  final List<SpeakingFocusItemView> speakingFocusItems;
  final List<DiffChunkView> diffChunks;
  final ReviewArtifactAudioView? ttsAudio;
  final String repairProvider;
  final String generatedAt;
  final String failedAt;
  final String failureCode;

  bool get isPending => status == 'pending';
  bool get isReady => status == 'ready';
  bool get isFailed => status == 'failed';
  bool get isNotApplicable => status == 'not_applicable';

  factory AttemptReviewArtifactView.fromJson(Map<String, dynamic> json) {
    return AttemptReviewArtifactView(
      attemptId: json['attempt_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      sourceTranscriptText: json['source_transcript_text'] as String? ?? '',
      sourceTranscriptProvider:
          json['source_transcript_provider'] as String? ?? '',
      correctedTranscriptText:
          json['corrected_transcript_text'] as String? ?? '',
      modelAnswerText: json['model_answer_text'] as String? ?? '',
      speakingFocusItems:
          (json['speaking_focus_items'] as List<dynamic>? ?? const [])
              .map(
                (item) => SpeakingFocusItemView.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      diffChunks:
          (json['diff_chunks'] as List<dynamic>? ?? const [])
              .map(
                (item) => DiffChunkView.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      ttsAudio:
          json['tts_audio'] == null
              ? null
              : ReviewArtifactAudioView.fromJson(
                json['tts_audio'] as Map<String, dynamic>,
              ),
      repairProvider: json['repair_provider'] as String? ?? '',
      generatedAt: json['generated_at'] as String? ?? '',
      failedAt: json['failed_at'] as String? ?? '',
      failureCode: json['failure_code'] as String? ?? '',
    );
  }
}

class SpeakingFocusItemView {
  const SpeakingFocusItemView({
    required this.focusKey,
    required this.label,
    required this.learnerFragment,
    required this.targetFragment,
    required this.issueType,
    required this.commentVi,
    required this.confidenceBand,
  });

  final String focusKey;
  final String label;
  final String learnerFragment;
  final String targetFragment;
  final String issueType;
  final String commentVi;
  final String confidenceBand;

  factory SpeakingFocusItemView.fromJson(Map<String, dynamic> json) {
    return SpeakingFocusItemView(
      focusKey: json['focus_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      learnerFragment: json['learner_fragment'] as String? ?? '',
      targetFragment: json['target_fragment'] as String? ?? '',
      issueType: json['issue_type'] as String? ?? '',
      commentVi: json['comment_vi'] as String? ?? '',
      confidenceBand: json['confidence_band'] as String? ?? '',
    );
  }
}

class DiffChunkView {
  const DiffChunkView({
    required this.kind,
    required this.sourceText,
    required this.targetText,
  });

  final String kind;
  final String sourceText;
  final String targetText;

  factory DiffChunkView.fromJson(Map<String, dynamic> json) {
    return DiffChunkView(
      kind: json['kind'] as String? ?? '',
      sourceText: json['source_text'] as String? ?? '',
      targetText: json['target_text'] as String? ?? '',
    );
  }
}

class ReviewArtifactAudioView {
  const ReviewArtifactAudioView({
    required this.storageKey,
    required this.mimeType,
    required this.durationMs,
  });

  final String storageKey;
  final String mimeType;
  final int durationMs;

  factory ReviewArtifactAudioView.fromJson(Map<String, dynamic> json) {
    return ReviewArtifactAudioView(
      storageKey: json['storage_key'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? 0,
    );
  }
}

class AttemptAudioView {
  const AttemptAudioView({
    required this.storageKey,
    required this.mimeType,
    required this.durationMs,
    required this.fileSizeBytes,
  });

  final String storageKey;
  final String mimeType;
  final int durationMs;
  final int fileSizeBytes;

  factory AttemptAudioView.fromJson(Map<String, dynamic> json) {
    return AttemptAudioView(
      storageKey: json['storage_key'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      durationMs: json['duration_ms'] as int? ?? 0,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
    );
  }
}

class CriterionCheckView {
  const CriterionCheckView({
    required this.criterionKey,
    required this.label,
    required this.met,
    this.comment = '',
  });

  final String criterionKey;
  final String label;
  final bool met;
  final String comment;

  factory CriterionCheckView.fromJson(Map<String, dynamic> json) {
    return CriterionCheckView(
      criterionKey: json['criterion_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      met: json['met'] as bool? ?? false,
      comment: json['comment'] as String? ?? '',
    );
  }
}

// --- Objective scoring result (V3/V4) ---

class QuestionResult {
  const QuestionResult({
    required this.questionNo,
    this.questionText = '',
    required this.learnerAnswer,
    this.learnerAnswerText = '',
    required this.correctAnswer,
    this.correctAnswerText = '',
    required this.isCorrect,
  });
  final int questionNo;
  final String questionText;
  final String learnerAnswer;
  final String learnerAnswerText;
  final String correctAnswer;
  final String correctAnswerText;
  final bool isCorrect;

  factory QuestionResult.fromJson(Map<String, dynamic> json) {
    return QuestionResult(
      questionNo: (json['question_no'] as num?)?.toInt() ?? 0,
      questionText: json['question_text'] as String? ?? '',
      learnerAnswer: json['learner_answer'] as String? ?? '',
      learnerAnswerText: json['learner_answer_text'] as String? ?? '',
      correctAnswer: json['correct_answer'] as String? ?? '',
      correctAnswerText: json['correct_answer_text'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
    );
  }
}

class ObjectiveResult {
  const ObjectiveResult({
    required this.score,
    required this.maxScore,
    required this.breakdown,
  });
  final int score;
  final int maxScore;
  final List<QuestionResult> breakdown;

  factory ObjectiveResult.fromJson(Map<String, dynamic> json) {
    return ObjectiveResult(
      score: (json['score'] as num?)?.toInt() ?? 0,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 0,
      breakdown:
          (json['breakdown'] as List<dynamic>? ?? const [])
              .map((e) => QuestionResult.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class AttemptFeedbackView {
  const AttemptFeedbackView({
    required this.readinessLevel,
    required this.overallSummary,
    required this.strengths,
    required this.improvements,
    required this.retryAdvice,
    required this.sampleAnswer,
    this.criteriaResults = const [],
    this.objectiveResult,
  });

  final String readinessLevel;
  final String overallSummary;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> retryAdvice;
  final String sampleAnswer;
  final List<CriterionCheckView> criteriaResults;
  final ObjectiveResult? objectiveResult;

  factory AttemptFeedbackView.fromJson(Map<String, dynamic> json) {
    List<String> toStrings(dynamic value) {
      return (value as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();
    }

    final taskCompletion =
        json['task_completion'] as Map<String, dynamic>? ?? {};
    final rawCriteria =
        taskCompletion['criteria_results'] as List<dynamic>? ?? [];
    final criteria =
        rawCriteria
            .map((e) => CriterionCheckView.fromJson(e as Map<String, dynamic>))
            .toList();

    final objRaw = json['objective_result'] as Map<String, dynamic>?;

    return AttemptFeedbackView(
      readinessLevel: json['readiness_level'] as String? ?? 'needs_work',
      overallSummary: json['overall_summary'] as String? ?? '',
      strengths: toStrings(json['strengths']),
      improvements: toStrings(json['improvements']),
      retryAdvice: toStrings(json['retry_advice']),
      sampleAnswer: json['sample_answer_text'] as String? ?? '',
      criteriaResults: criteria,
      objectiveResult: objRaw != null ? ObjectiveResult.fromJson(objRaw) : null,
    );
  }
}
