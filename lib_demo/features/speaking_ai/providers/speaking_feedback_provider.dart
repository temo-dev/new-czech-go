import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum SpeakingFeedbackStatus { pending, scoring, completed, error }

class SpeakingMetric {
  const SpeakingMetric({
    required this.label,
    required this.score,
    required this.maxScore,
    this.feedback,
    this.tip,
  });

  final String label;
  final double score;
  final double maxScore;
  final String? feedback;
  final String? tip;

  double get fraction => maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0;
}

class TranscriptWord {
  const TranscriptWord({
    required this.word,
    this.issue, // null = correct, non-null = issue type
    this.suggestion,
  });

  final String word;
  final String? issue; // 'pronunciation' | 'grammar' | 'vocabulary'
  final String? suggestion;
}

class SpeakingFeedbackResult {
  const SpeakingFeedbackResult({
    required this.attemptId,
    required this.totalScore,
    required this.maxScore,
    required this.metrics,
    required this.transcript,
    required this.transcriptWords,
    required this.overallFeedback,
    required this.corrections,
    this.correctedAnswer = '',
    this.shortTips = const [],
    this.reviewMode = 'exercise',
    this.scoringMode = 'transcript_fallback',
  });

  final String attemptId;
  final double totalScore;
  final double maxScore;
  final List<SpeakingMetric> metrics;
  final String transcript;
  final List<TranscriptWord> transcriptWords;
  final String overallFeedback;
  final List<String> corrections;
  final String correctedAnswer;
  final List<String> shortTips;
  final String reviewMode;
  final String scoringMode;

  double get fraction =>
      maxScore > 0 ? (totalScore / maxScore).clamp(0.0, 1.0) : 0;
}

class SpeakingFeedbackState {
  const SpeakingFeedbackState({
    this.status = SpeakingFeedbackStatus.pending,
    this.result,
    this.errorMessage,
    this.pollCount = 0,
  });

  final SpeakingFeedbackStatus status;
  final SpeakingFeedbackResult? result;
  final String? errorMessage;
  final int pollCount;

  SpeakingFeedbackState copyWith({
    SpeakingFeedbackStatus? status,
    SpeakingFeedbackResult? result,
    String? errorMessage,
    int? pollCount,
  }) =>
      SpeakingFeedbackState(
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        pollCount: pollCount ?? this.pollCount,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SpeakingFeedbackNotifier
    extends StateNotifier<SpeakingFeedbackState> {
  SpeakingFeedbackNotifier(this.attemptId)
      : super(const SpeakingFeedbackState()) {
    _startPolling();
  }

  final String attemptId;
  static const _maxRetries = 10;
  static const _pollInterval = Duration(seconds: 3);

  Future<void> _startPolling() async {
    while (mounted &&
        state.pollCount < _maxRetries &&
        state.status != SpeakingFeedbackStatus.completed &&
        state.status != SpeakingFeedbackStatus.error) {
      await Future.delayed(_pollInterval);
      if (!mounted) return;
      await _poll();
    }

    if (mounted && state.status != SpeakingFeedbackStatus.completed) {
      state = state.copyWith(
        status: SpeakingFeedbackStatus.error,
        errorMessage:
            'Hết thời gian chờ chấm điểm. Vui lòng thử lại.',
      );
    }
  }

  Future<void> _poll() async {
    state = state.copyWith(
      status: SpeakingFeedbackStatus.scoring,
      pollCount: state.pollCount + 1,
    );

    try {
      // Try edge function first
      final result = await _fetchFromEdgeFunction();
      if (result != null) {
        state = state.copyWith(
          status: SpeakingFeedbackStatus.completed,
          result: result,
        );
        return;
      }

      // Fallback: check ai_speaking_attempts table directly
      final row = await supabase
          .from('ai_speaking_attempts')
          .select()
          .eq('id', attemptId)
          .maybeSingle();

      if (row == null) return;

      final rm = Map<String, dynamic>.from(row as Map);
      final status = rm['status'] as String? ?? 'processing';

      if (status == 'ready') {
        state = state.copyWith(
          status: SpeakingFeedbackStatus.completed,
          result: _parseRow(rm),
        );
      } else if (status == 'error') {
        state = state.copyWith(
          status: SpeakingFeedbackStatus.error,
          errorMessage: 'Không thể chấm điểm bài nói. Vui lòng thử lại.',
        );
      }
      // else still processing — continue polling
    } catch (_) {
      // Network error — keep polling
    }
  }

  Future<SpeakingFeedbackResult?> _fetchFromEdgeFunction() async {
    try {
      final response = await supabase.functions
          .invoke('speaking-result', body: {'attempt_id': attemptId});
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['status'] == 'pending') return null;
      if (data['status'] == 'error') {
        state = state.copyWith(
          status: SpeakingFeedbackStatus.error,
          errorMessage: data['message'] as String? ??
              'Lỗi chấm điểm.',
        );
        return null;
      }
      return _parseEdgeResponse(data);
    } catch (_) {
      return null; // Edge function not deployed — fall through to DB check
    }
  }

  SpeakingFeedbackResult _parseEdgeResponse(
      Map<String, dynamic> data) {
    final metricsRaw =
        data['metrics'] as List<dynamic>? ?? [];
    final metrics = metricsRaw.map((m) {
      final mm = Map<String, dynamic>.from(m as Map);
      return SpeakingMetric(
        label: mm['label'] as String? ?? '',
        score: (mm['score'] as num?)?.toDouble() ?? 0,
        maxScore: (mm['max_score'] as num?)?.toDouble() ?? 10,
        feedback: mm['feedback'] as String?,
        tip: mm['tip'] as String?,
      );
    }).toList();

    final wordsRaw = data['transcript_words'] as List<dynamic>? ?? [];
    final words = wordsRaw.map((w) {
      final wm = Map<String, dynamic>.from(w as Map);
      return TranscriptWord(
        word: wm['word'] as String? ?? '',
        issue: wm['issue'] as String?,
        suggestion: wm['suggestion'] as String?,
      );
    }).toList();

    final corrections = (data['corrections'] as List<dynamic>? ?? [])
        .map((c) => c as String)
        .toList();
    final shortTips = (data['short_tips'] as List<dynamic>? ?? [])
        .map((t) => t as String)
        .toList();

    return SpeakingFeedbackResult(
      attemptId: attemptId,
      totalScore: (data['total_score'] as num?)?.toDouble() ?? 0,
      maxScore: (data['max_score'] as num?)?.toDouble() ?? 100,
      metrics: metrics,
      transcript: data['transcript'] as String? ?? '',
      transcriptWords: words,
      overallFeedback: data['overall_feedback'] as String? ?? '',
      corrections: corrections,
      correctedAnswer: data['corrected_answer'] as String? ?? '',
      shortTips: shortTips,
      reviewMode: data['review_mode'] as String? ?? 'exercise',
      scoringMode: data['scoring_mode'] as String? ?? 'transcript_fallback',
    );
  }

  SpeakingFeedbackResult _parseRow(Map<String, dynamic> row) {
    final scoreRaw = row['overall_score'] as num?;
    final transcript = row['transcript'] as String? ?? '';
    final metricsDb = (row['metrics'] as Map?)?.cast<String, dynamic>() ?? {};

    final metrics = [
      SpeakingMetric(
        label: 'Phát âm',
        score: (metricsDb['pronunciation'] as num?)?.toDouble() ?? 0,
        maxScore: 100,
        feedback: metricsDb['pronunciation_feedback'] as String?,
        tip: metricsDb['pronunciation_tip'] as String?,
      ),
      SpeakingMetric(
        label: 'Lưu loát',
        score: (metricsDb['fluency'] as num?)?.toDouble() ?? 0,
        maxScore: 100,
        feedback: (metricsDb['fluency_feedback'] ?? metricsDb['content_feedback']) as String?,
        tip: (metricsDb['fluency_tip'] ?? metricsDb['content_tip']) as String?,
      ),
      SpeakingMetric(
        label: 'Từ vựng',
        score: (metricsDb['vocabulary'] as num?)?.toDouble() ?? 0,
        maxScore: 100,
        feedback: metricsDb['vocabulary_feedback'] as String?,
        tip: metricsDb['vocabulary_tip'] as String?,
      ),
      SpeakingMetric(
        label: 'Ngữ pháp',
        score: (metricsDb['task_achievement'] as num?)?.toDouble() ?? 0,
        maxScore: 100,
        feedback: metricsDb['grammar_feedback'] as String?,
        tip: metricsDb['grammar_tip'] as String?,
      ),
    ];

    // Build transcript words from issues list
    final issuesRaw = (row['issues'] as List?)?.cast<Map>() ?? [];
    final issueMap = <String, Map>{};
    for (final issue in issuesRaw) {
      final word = (issue['word'] as String? ?? '').toLowerCase();
      if (word.isNotEmpty) issueMap[word] = Map<String, dynamic>.from(issue);
    }
    final transcriptWords = transcript.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((word) {
      final clean = word.replaceAll(RegExp(r'[.,!?;:"]+'), '').toLowerCase();
      final matched = issueMap[clean];
      return matched != null
          ? TranscriptWord(
              word: word,
              issue: matched['type'] as String? ?? 'pronunciation',
              suggestion: matched['suggestion'] as String?,
            )
          : TranscriptWord(word: word);
    }).toList();

    final shortTips = (metricsDb['short_tips'] as List?)?.map((t) => t as String).toList() ?? [];

    return SpeakingFeedbackResult(
      attemptId: attemptId,
      totalScore: scoreRaw?.toDouble() ?? 0,
      maxScore: 100,
      metrics: metrics,
      transcript: transcript,
      transcriptWords: transcriptWords,
      overallFeedback: metricsDb['overall_feedback'] as String? ?? '',
      corrections: [
        if ((row['corrected_answer'] as String?)?.isNotEmpty ?? false)
          row['corrected_answer'] as String,
      ],
      correctedAnswer: row['corrected_answer'] as String? ?? '',
      shortTips: shortTips,
      reviewMode: metricsDb['review_mode'] as String? ?? 'exercise',
      scoringMode: metricsDb['scoring_mode'] as String? ?? 'transcript_fallback',
    );
  }

  void retry() {
    state = const SpeakingFeedbackState();
    _startPolling();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final speakingFeedbackProvider = StateNotifierProvider
    .family<SpeakingFeedbackNotifier, SpeakingFeedbackState, String>(
  (_, attemptId) => SpeakingFeedbackNotifier(attemptId),
);
