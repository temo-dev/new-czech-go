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
    required this.questions,
  });

  final String id;
  final String title;
  final String exerciseType;
  final String learnerInstruction;
  final List<String> questions;

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    final prompt = json['prompt'] as Map<String, dynamic>? ?? const {};
    final questionPrompts =
        (prompt['question_prompts'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    return ExerciseDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      exerciseType: json['exercise_type'] as String,
      learnerInstruction: json['learner_instruction'] as String? ?? '',
      questions: questionPrompts,
    );
  }
}

class AttemptResult {
  const AttemptResult({
    required this.id,
    required this.status,
    this.audio,
    this.transcript,
    this.feedback,
  });

  final String id;
  final String status;
  final AttemptAudioView? audio;
  final String? transcript;
  final AttemptFeedbackView? feedback;

  factory AttemptResult.fromJson(Map<String, dynamic> json) {
    return AttemptResult(
      id: json['id'] as String,
      status: json['status'] as String,
      audio:
          json['audio'] == null
              ? null
              : AttemptAudioView.fromJson(
                json['audio'] as Map<String, dynamic>,
              ),
      transcript:
          (json['transcript'] as Map<String, dynamic>?)?['full_text']
              as String?,
      feedback:
          json['feedback'] == null
              ? null
              : AttemptFeedbackView.fromJson(
                json['feedback'] as Map<String, dynamic>,
              ),
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
