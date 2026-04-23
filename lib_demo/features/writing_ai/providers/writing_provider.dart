import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum WritingFeedbackStatus {
  idle,
  submitting,
  pending,
  scoring,
  completed,
  error
}

class WritingMetric {
  const WritingMetric({
    required this.label,
    required this.score,
    required this.maxScore,
    this.feedback,
  });

  final String label;
  final double score;
  final double maxScore;
  final String? feedback;

  double get fraction => maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0;
}

/// A span of annotated text — either clean or marked with an issue.
class AnnotatedSpan {
  const AnnotatedSpan({
    required this.text,
    this.issueType,
    this.correction,
    this.explanation,
    this.tip,
  });

  final String text;
  final String? issueType; // 'grammar' | 'vocabulary' | 'spelling' | null
  final String? correction;
  final String? explanation;
  final String? tip;

  bool get hasIssue => issueType != null;
}

class WritingFeedbackResult {
  const WritingFeedbackResult({
    required this.attemptId,
    required this.totalScore,
    required this.maxScore,
    required this.metrics,
    required this.originalText,
    required this.annotatedSpans,
    required this.correctedVersion,
    required this.overallFeedback,
    this.shortTips = const [],
  });

  final String attemptId;
  final double totalScore;
  final double maxScore;
  final List<WritingMetric> metrics;
  final String originalText;
  final List<AnnotatedSpan> annotatedSpans;
  final String correctedVersion;
  final String overallFeedback;
  final List<String> shortTips;

  double get fraction =>
      maxScore > 0 ? (totalScore / maxScore).clamp(0.0, 1.0) : 0;
}

class WritingSessionState {
  const WritingSessionState({
    this.status = WritingFeedbackStatus.idle,
    this.attemptId,
    this.result,
    this.errorMessage,
    this.pollCount = 0,
  });

  final WritingFeedbackStatus status;
  final String? attemptId;
  final WritingFeedbackResult? result;
  final String? errorMessage;
  final int pollCount;

  WritingSessionState copyWith({
    WritingFeedbackStatus? status,
    String? attemptId,
    WritingFeedbackResult? result,
    String? errorMessage,
    int? pollCount,
  }) =>
      WritingSessionState(
        status: status ?? this.status,
        attemptId: attemptId ?? this.attemptId,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        pollCount: pollCount ?? this.pollCount,
      );
}

Future<String?> submitWritingAttempt({
  required String text,
  required String questionId,
  String? exerciseId,
  String? lessonId,
  String? examAttemptId,
}) async {
  try {
    final response = await supabase.functions.invoke(
      'writing-submit',
      body: {
        'text': text,
        if (questionId.isNotEmpty) 'question_id': questionId,
        if (exerciseId != null && exerciseId.isNotEmpty)
          'exercise_id': exerciseId,
        if (lessonId != null && lessonId.isNotEmpty) 'lesson_id': lessonId,
        if (examAttemptId != null) 'exam_attempt_id': examAttemptId,
      },
    );
    final data = response.data as Map<String, dynamic>?;
    return data?['attempt_id'] as String?;
  } catch (_) {
    return null;
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class WritingSessionNotifier extends StateNotifier<WritingSessionState> {
  WritingSessionNotifier() : super(const WritingSessionState());

  static const _maxRetries = 10;
  static const _pollInterval = Duration(seconds: 3);

  Future<void> submitWriting({
    required String text,
    required String questionId,
    String? exerciseId,
    required String lessonId,
    String? examAttemptId,
  }) async {
    if (state.status == WritingFeedbackStatus.submitting) return;
    state = state.copyWith(status: WritingFeedbackStatus.submitting);

    try {
      String? attemptId;

      attemptId = await submitWritingAttempt(
        text: text,
        questionId: questionId,
        exerciseId: exerciseId,
        lessonId: lessonId,
        examAttemptId: examAttemptId,
      );

      if (attemptId == null) {
        // writing-submit failed — there's no backend scorer for a direct DB
        // insert, so show an error immediately instead of polling forever.
        state = state.copyWith(
          status: WritingFeedbackStatus.error,
          errorMessage: 'Không thể gửi bài lên AI. Vui lòng thử lại.',
        );
        return;
      }

      state = state.copyWith(
        status: WritingFeedbackStatus.pending,
        attemptId: attemptId,
      );

      _startPolling(attemptId, originalText: text);
    } catch (e) {
      state = state.copyWith(
        status: WritingFeedbackStatus.error,
        errorMessage: 'Không thể nộp bài viết. Vui lòng thử lại.',
      );
    }
  }

  void _startPolling(String attemptId, {required String originalText}) async {
    int count = 0;
    while (mounted && count < _maxRetries) {
      await Future.delayed(_pollInterval);
      if (!mounted) return;
      count++;

      state = state.copyWith(
        status: WritingFeedbackStatus.scoring,
        pollCount: count,
      );

      final result = await _poll(attemptId, originalText: originalText);
      if (result != null) {
        state = state.copyWith(
          status: WritingFeedbackStatus.completed,
          result: result,
        );
        return;
      }
    }

    if (mounted && state.status != WritingFeedbackStatus.completed) {
      state = state.copyWith(
        status: WritingFeedbackStatus.error,
        errorMessage: 'Hết thời gian chờ chấm điểm. Vui lòng thử lại.',
      );
    }
  }

  Future<WritingFeedbackResult?> _poll(String attemptId,
      {required String originalText}) async {
    // Try edge function
    try {
      final response = await supabase.functions
          .invoke('writing-result', body: {'attempt_id': attemptId});
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['status'] == 'pending') return null;
      if (data['status'] == 'error') {
        state = state.copyWith(
          status: WritingFeedbackStatus.error,
          errorMessage: data['message'] as String? ?? 'Lỗi chấm điểm.',
        );
        return null;
      }
      return _parseEdgeResponse(attemptId, data, originalText);
    } catch (_) {}

    // Fallback: read ai_writing_attempts directly (handles writing-result outage)
    try {
      final row = await supabase
          .from('ai_writing_attempts')
          .select()
          .eq('id', attemptId)
          .maybeSingle();
      if (row == null) return null;
      final rm = Map<String, dynamic>.from(row as Map);
      final status = rm['status'] as String? ?? 'processing';
      if (status == 'ready') return _parseAiRow(attemptId, rm, originalText);
      if (status == 'error') {
        state = state.copyWith(
          status: WritingFeedbackStatus.error,
          errorMessage:
              rm['error_message'] as String? ?? 'Không thể chấm điểm bài viết.',
        );
      }
    } catch (_) {}
    return null;
  }

  WritingFeedbackResult _parseAiRow(
      String attemptId, Map<String, dynamic> row, String originalText) {
    final metricsDb = (row['metrics'] as Map?)?.cast<String, dynamic>() ?? {};
    final spansRaw = (row['grammar_notes'] as List?) ?? [];
    final spans = spansRaw.isEmpty
        ? [AnnotatedSpan(text: originalText)]
        : spansRaw.map((s) {
            final sm = Map<String, dynamic>.from(s as Map);
            return AnnotatedSpan(
              text: sm['text'] as String? ?? '',
              issueType: sm['issue_type'] as String?,
              correction: sm['correction'] as String?,
              explanation: sm['explanation'] as String?,
              tip: sm['tip'] as String?,
            );
          }).toList();

    final shortTips =
        (metricsDb['short_tips'] as List?)?.map((t) => t as String).toList() ??
            [];

    return WritingFeedbackResult(
      attemptId: attemptId,
      totalScore: (row['overall_score'] as num?)?.toDouble() ?? 0,
      maxScore: 100,
      metrics: [
        if (metricsDb['grammar'] != null)
          WritingMetric(
            label: 'Ngữ pháp',
            score: (metricsDb['grammar'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['grammar_feedback'] as String?,
          ),
        if (metricsDb['vocabulary'] != null)
          WritingMetric(
            label: 'Từ vựng',
            score: (metricsDb['vocabulary'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['vocabulary_feedback'] as String?,
          ),
        if (metricsDb['coherence'] != null)
          WritingMetric(
            label: 'Mạch lạc & Hình thức',
            score: (metricsDb['coherence'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['format_feedback'] as String?,
          ),
        if (metricsDb['task_achievement'] != null)
          WritingMetric(
            label: 'Nội dung',
            score: (metricsDb['task_achievement'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['content_feedback'] as String?,
          ),
      ],
      originalText: originalText,
      annotatedSpans: spans,
      correctedVersion: row['corrected_essay'] as String? ?? '',
      overallFeedback: metricsDb['overall_feedback'] as String? ?? '',
      shortTips: shortTips,
    );
  }

  WritingFeedbackResult _parseEdgeResponse(
      String attemptId, Map<String, dynamic> data, String originalText) {
    final metricsRaw = data['metrics'] as List<dynamic>? ?? [];
    final metrics = metricsRaw.map((m) {
      final mm = Map<String, dynamic>.from(m as Map);
      return WritingMetric(
        label: mm['label'] as String? ?? '',
        score: (mm['score'] as num?)?.toDouble() ?? 0,
        maxScore: (mm['max_score'] as num?)?.toDouble() ?? 10,
        feedback: mm['feedback'] as String?,
      );
    }).toList();

    final spansRaw = data['annotated_spans'] as List<dynamic>? ?? [];
    final spans = spansRaw.isEmpty
        ? [AnnotatedSpan(text: originalText)]
        : spansRaw.map((s) {
            final sm = Map<String, dynamic>.from(s as Map);
            return AnnotatedSpan(
              text: sm['text'] as String? ?? '',
              issueType: sm['issue_type'] as String?,
              correction: sm['correction'] as String?,
              explanation: sm['explanation'] as String?,
              tip: sm['tip'] as String?,
            );
          }).toList();

    final shortTips = (data['short_tips'] as List<dynamic>? ?? [])
        .map((t) => t as String)
        .toList();

    return WritingFeedbackResult(
      attemptId: attemptId,
      totalScore: (data['total_score'] as num?)?.toDouble() ?? 0,
      maxScore: (data['max_score'] as num?)?.toDouble() ?? 100,
      metrics: metrics,
      originalText: originalText,
      annotatedSpans: spans,
      correctedVersion: data['corrected_version'] as String? ?? '',
      overallFeedback: data['overall_feedback'] as String? ?? '',
      shortTips: shortTips,
    );
  }

  void retry() => state = const WritingSessionState();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final writingSessionProvider = StateNotifierProvider.autoDispose<
    WritingSessionNotifier, WritingSessionState>(
  (_) => WritingSessionNotifier(),
);

// ── Review feedback (mock-test result screen) ─────────────────────────────────
//
// Family provider keyed by questionId. Auto-submits the user's written answer
// to the AI and stores the result for display in the review panel.

class WritingReviewNotifier extends StateNotifier<WritingSessionState> {
  WritingReviewNotifier() : super(const WritingSessionState());

  static const _maxRetries = 10;
  static const _pollInterval = Duration(seconds: 3);

  bool _submitted = false;

  Future<void> submit({
    required String text,
    required String questionId,
  }) async {
    if (_submitted || !mounted) return;
    _submitted = true;
    state = state.copyWith(status: WritingFeedbackStatus.submitting);

    try {
      String? attemptId;
      try {
        final res = await supabase.functions.invoke(
          'writing-submit',
          body: {'text': text, 'question_id': questionId},
        );
        final data = res.data as Map<String, dynamic>?;
        attemptId = data?['attempt_id'] as String?;
      } catch (_) {}

      if (!mounted) return;
      if (attemptId == null) {
        state = state.copyWith(
          status: WritingFeedbackStatus.error,
          errorMessage: 'Không thể gửi bài viết lên AI.',
        );
        return;
      }

      state = state.copyWith(
        status: WritingFeedbackStatus.pending,
        attemptId: attemptId,
      );

      // writing-submit returns the attempt id immediately and the backend
      // finishes scoring in the background, so review screens poll here too.
      int count = 0;
      while (mounted && count < _maxRetries) {
        await Future.delayed(_pollInterval);
        if (!mounted) return;
        count++;
        state = state.copyWith(
          status: WritingFeedbackStatus.scoring,
          pollCount: count,
        );
        final result = await _fetchResult(attemptId, originalText: text);
        if (result != null) {
          state = state.copyWith(
            status: WritingFeedbackStatus.completed,
            result: result,
          );
          return;
        }
      }

      if (mounted && state.status != WritingFeedbackStatus.completed) {
        state = state.copyWith(
          status: WritingFeedbackStatus.error,
          errorMessage: 'Hết thời gian chờ chấm điểm.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        status: WritingFeedbackStatus.error,
        errorMessage: 'Lỗi kết nối AI. Vui lòng thử lại.',
      );
    }
  }

  Future<WritingFeedbackResult?> _fetchResult(
    String attemptId, {
    required String originalText,
  }) async {
    try {
      final res = await supabase.functions
          .invoke('writing-result', body: {'attempt_id': attemptId});
      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['status'] == 'pending') return null;
      if (data['status'] == 'error') {
        if (mounted) {
          state = state.copyWith(
            status: WritingFeedbackStatus.error,
            errorMessage:
                data['message'] as String? ?? 'Lỗi chấm điểm bài viết.',
          );
        }
        return null;
      }
      return _parseEdgeResponse(attemptId, data, originalText);
    } catch (_) {}

    // Fallback: read ai_writing_attempts directly
    try {
      final row = await supabase
          .from('ai_writing_attempts')
          .select()
          .eq('id', attemptId)
          .maybeSingle();
      if (row == null) return null;
      final rm = Map<String, dynamic>.from(row as Map);
      final status = rm['status'] as String? ?? 'processing';
      if (status == 'ready') return _parseAiRow(attemptId, rm, originalText);
      if (status == 'error' && mounted) {
        state = state.copyWith(
          status: WritingFeedbackStatus.error,
          errorMessage:
              rm['error_message'] as String? ?? 'Không thể chấm điểm bài viết.',
        );
      }
    } catch (_) {}
    return null;
  }

  WritingFeedbackResult _parseAiRow(
    String attemptId,
    Map<String, dynamic> row,
    String originalText,
  ) {
    final metricsDb = (row['metrics'] as Map?)?.cast<String, dynamic>() ?? {};
    final spansRaw = (row['grammar_notes'] as List?) ?? [];
    final spans = spansRaw.isEmpty
        ? [AnnotatedSpan(text: originalText)]
        : spansRaw.map((s) {
            final sm = Map<String, dynamic>.from(s as Map);
            return AnnotatedSpan(
              text: sm['text'] as String? ?? '',
              issueType: sm['issue_type'] as String?,
              correction: sm['correction'] as String?,
              explanation: sm['explanation'] as String?,
              tip: sm['tip'] as String?,
            );
          }).toList();
    final shortTips =
        (metricsDb['short_tips'] as List?)?.map((t) => t as String).toList() ??
            [];
    return WritingFeedbackResult(
      attemptId: attemptId,
      totalScore: (row['overall_score'] as num?)?.toDouble() ?? 0,
      maxScore: 100,
      metrics: [
        if (metricsDb['grammar'] != null)
          WritingMetric(
            label: 'Ngữ pháp',
            score: (metricsDb['grammar'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['grammar_feedback'] as String?,
          ),
        if (metricsDb['vocabulary'] != null)
          WritingMetric(
            label: 'Từ vựng',
            score: (metricsDb['vocabulary'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['vocabulary_feedback'] as String?,
          ),
        if (metricsDb['coherence'] != null)
          WritingMetric(
            label: 'Mạch lạc & Hình thức',
            score: (metricsDb['coherence'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['format_feedback'] as String?,
          ),
        if (metricsDb['task_achievement'] != null)
          WritingMetric(
            label: 'Nội dung',
            score: (metricsDb['task_achievement'] as num).toDouble(),
            maxScore: 100,
            feedback: metricsDb['content_feedback'] as String?,
          ),
      ],
      originalText: originalText,
      annotatedSpans: spans,
      correctedVersion: row['corrected_essay'] as String? ?? '',
      overallFeedback: metricsDb['overall_feedback'] as String? ?? '',
      shortTips: shortTips,
    );
  }

  WritingFeedbackResult _parseEdgeResponse(
    String attemptId,
    Map<String, dynamic> data,
    String originalText,
  ) {
    final metricsRaw = data['metrics'] as List<dynamic>? ?? [];
    final metrics = metricsRaw.map((m) {
      final mm = Map<String, dynamic>.from(m as Map);
      return WritingMetric(
        label: mm['label'] as String? ?? '',
        score: (mm['score'] as num?)?.toDouble() ?? 0,
        maxScore: (mm['max_score'] as num?)?.toDouble() ?? 100,
        feedback: mm['feedback'] as String?,
      );
    }).toList();

    final spansRaw = data['annotated_spans'] as List<dynamic>? ?? [];
    final spans = spansRaw.isEmpty
        ? [AnnotatedSpan(text: originalText)]
        : spansRaw.map((s) {
            final sm = Map<String, dynamic>.from(s as Map);
            return AnnotatedSpan(
              text: sm['text'] as String? ?? '',
              issueType: sm['issue_type'] as String?,
              correction: sm['correction'] as String?,
              explanation: sm['explanation'] as String?,
              tip: sm['tip'] as String?,
            );
          }).toList();

    final shortTips = (data['short_tips'] as List<dynamic>? ?? [])
        .map((t) => t as String)
        .toList();

    return WritingFeedbackResult(
      attemptId: attemptId,
      totalScore: (data['total_score'] as num?)?.toDouble() ?? 0,
      maxScore: (data['max_score'] as num?)?.toDouble() ?? 100,
      metrics: metrics,
      originalText: originalText,
      annotatedSpans: spans,
      correctedVersion: data['corrected_version'] as String? ?? '',
      overallFeedback: data['overall_feedback'] as String? ?? '',
      shortTips: shortTips,
    );
  }
}

final writingReviewFeedbackProvider = StateNotifierProvider.autoDispose
    .family<WritingReviewNotifier, WritingSessionState, String>(
  (_, __) => WritingReviewNotifier(),
);

// ── Fetch a completed attempt by ID (used by WritingFeedbackScreen from review)

final writingAttemptResultProvider =
    FutureProvider.autoDispose.family<WritingFeedbackResult?, String>(
  (_, attemptId) async {
    try {
      final res = await supabase.functions
          .invoke('writing-result', body: {'attempt_id': attemptId});
      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['status'] == 'pending') return null;
      if (data['status'] == 'error') throw Exception(data['message']);
      final metricsRaw = data['metrics'] as List<dynamic>? ?? [];
      final metrics = metricsRaw.map((m) {
        final mm = Map<String, dynamic>.from(m as Map);
        return WritingMetric(
          label: mm['label'] as String? ?? '',
          score: (mm['score'] as num?)?.toDouble() ?? 0,
          maxScore: (mm['max_score'] as num?)?.toDouble() ?? 100,
          feedback: mm['feedback'] as String?,
        );
      }).toList();
      final spansRaw = data['annotated_spans'] as List<dynamic>? ?? [];
      final spans = spansRaw.isEmpty
          ? [const AnnotatedSpan(text: '')]
          : spansRaw.map((s) {
              final sm = Map<String, dynamic>.from(s as Map);
              return AnnotatedSpan(
                text: sm['text'] as String? ?? '',
                issueType: sm['issue_type'] as String?,
                correction: sm['correction'] as String?,
                explanation: sm['explanation'] as String?,
                tip: sm['tip'] as String?,
              );
            }).toList();
      final shortTips = (data['short_tips'] as List<dynamic>? ?? [])
          .map((t) => t as String)
          .toList();
      return WritingFeedbackResult(
        attemptId: attemptId,
        totalScore: (data['total_score'] as num?)?.toDouble() ?? 0,
        maxScore: (data['max_score'] as num?)?.toDouble() ?? 100,
        metrics: metrics,
        originalText: '',
        annotatedSpans: spans,
        correctedVersion: data['corrected_version'] as String? ?? '',
        overallFeedback: data['overall_feedback'] as String? ?? '',
        shortTips: shortTips,
      );
    } catch (_) {
      return null;
    }
  },
);
