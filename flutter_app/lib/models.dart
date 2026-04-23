class ModuleSummary {
  const ModuleSummary({
    required this.id,
    required this.title,
    required this.moduleKind,
  });

  final String id;
  final String title;
  final String moduleKind;

  factory ModuleSummary.fromJson(Map<String, dynamic> json) {
    return ModuleSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      moduleKind: json['module_kind'] as String,
    );
  }
}

class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.title,
    required this.exerciseType,
    required this.shortInstruction,
  });

  final String id;
  final String title;
  final String exerciseType;
  final String shortInstruction;

  factory ExerciseSummary.fromJson(Map<String, dynamic> json) {
    return ExerciseSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      exerciseType: json['exercise_type'] as String,
      shortInstruction: json['short_instruction'] as String? ?? '',
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

class AttemptResult {
  const AttemptResult({
    required this.id,
    required this.exerciseId,
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
              .map((item) => DiffChunkView.fromJson(item as Map<String, dynamic>))
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
  });

  final String storageKey;
  final String mimeType;

  factory ReviewArtifactAudioView.fromJson(Map<String, dynamic> json) {
    return ReviewArtifactAudioView(
      storageKey: json['storage_key'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
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

class AttemptFeedbackView {
  const AttemptFeedbackView({
    required this.readinessLevel,
    required this.overallSummary,
    required this.strengths,
    required this.improvements,
    required this.retryAdvice,
    required this.sampleAnswer,
  });

  final String readinessLevel;
  final String overallSummary;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> retryAdvice;
  final String sampleAnswer;

  factory AttemptFeedbackView.fromJson(Map<String, dynamic> json) {
    List<String> toStrings(dynamic value) {
      return (value as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();
    }

    return AttemptFeedbackView(
      readinessLevel: json['readiness_level'] as String? ?? 'needs_work',
      overallSummary: json['overall_summary'] as String? ?? '',
      strengths: toStrings(json['strengths']),
      improvements: toStrings(json['improvements']),
      retryAdvice: toStrings(json['retry_advice']),
      sampleAnswer: json['sample_answer_text'] as String? ?? '',
    );
  }
}
