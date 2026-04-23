import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:app_czech/core/storage/prefs_storage.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/features/mock_test/models/exam_attempt.dart';
import 'package:app_czech/features/mock_test/models/exam_meta.dart';
import 'package:app_czech/features/mock_test/models/exam_question_answer.dart';
import 'package:app_czech/features/mock_test/providers/exam_questions_provider.dart';
import 'package:app_czech/features/writing_ai/providers/writing_provider.dart';
import 'package:app_czech/shared/models/question_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exam_session_notifier.freezed.dart';
part 'exam_session_notifier.g.dart';

Map<String, dynamic> _mapExamJson(Map<String, dynamic> e) => {
      'id': e['id'],
      'title': e['title'],
      'durationMinutes': e['duration_minutes'] ?? e['durationMinutes'] ?? 0,
    };

Map<String, dynamic> _mapSectionJson(Map<String, dynamic> s) => {
      'id': s['id'],
      'skill': s['skill'],
      'label': s['label'],
      'questionCount': s['question_count'] ?? s['questionCount'] ?? 0,
      'sectionDurationMinutes':
          s['section_duration_minutes'] ?? s['sectionDurationMinutes'],
      'orderIndex': s['order_index'] ?? s['orderIndex'] ?? 0,
    };

Map<String, dynamic> _mapAttemptJson(Map<String, dynamic> a) => {
      'id': a['id'],
      'examId': a['exam_id'] ?? a['examId'],
      'userId': a['user_id'] ?? a['userId'],
      'status': a['status'] ?? 'in_progress',
      'answers': a['answers'] ?? {},
      'remainingSeconds': a['remaining_seconds'] ?? a['remainingSeconds'],
      'startedAt': a['started_at'] ?? a['startedAt'],
      'submittedAt': a['submitted_at'] ?? a['submittedAt'],
    };

enum ExamSessionStatus {
  initializing,
  ready,
  autosaving,
  autosaveFailed,
  submitting,
  submitted,
}

enum AutosaveStatus { idle, saving, saved, failed }

@freezed
class ExamSessionState with _$ExamSessionState {
  const factory ExamSessionState({
    required ExamAttempt attempt,
    required ExamMeta meta,
    @Default(ExamSessionStatus.ready) ExamSessionStatus status,
    @Default({}) Map<String, ExamQuestionAnswer> currentAnswers,
    @Default(0) int currentSectionIndex,
    @Default(0) int currentQuestionIndex,
    @Default(false) bool showSectionTransition,
    @Default(AutosaveStatus.idle) AutosaveStatus autosaveStatus,
    String? errorMessage,
  }) = _ExamSessionState;
}

extension ExamSessionStateX on ExamSessionState {
  SectionMeta get currentSection => meta.sections[currentSectionIndex];

  bool get usesSectionTimers =>
      meta.sections.isNotEmpty &&
      meta.sections.every(
        (section) => (section.sectionDurationMinutes ?? 0) > 0,
      );

  int get totalExamSeconds => usesSectionTimers
      ? meta.sections.fold<int>(
          0,
          (sum, section) => sum + ((section.sectionDurationMinutes ?? 0) * 60),
        )
      : meta.durationMinutes * 60;

  int totalRemainingSeconds([int? override]) =>
      override ?? attempt.remainingSeconds ?? totalExamSeconds;

  int sectionIndexForRemainingSeconds([int? override]) {
    if (!usesSectionTimers) return currentSectionIndex;
    final remaining = totalRemainingSeconds(override);
    for (var index = 0; index < meta.sections.length; index++) {
      final futureSeconds = meta.sections.skip(index + 1).fold<int>(
            0,
            (sum, section) =>
                sum + ((section.sectionDurationMinutes ?? 0) * 60),
          );
      if (remaining > futureSeconds) {
        return index;
      }
    }
    return meta.sections.length - 1;
  }

  int sectionRemainingSeconds([int? override]) {
    if (!usesSectionTimers) return totalRemainingSeconds(override);
    final remaining = totalRemainingSeconds(override);
    final index = sectionIndexForRemainingSeconds(override);
    final futureSeconds = meta.sections.skip(index + 1).fold<int>(
          0,
          (sum, section) => sum + ((section.sectionDurationMinutes ?? 0) * 60),
        );
    return (remaining - futureSeconds).clamp(0, 1 << 31).toInt();
  }

  int get globalQuestionIndex {
    var offset = 0;
    for (var i = 0; i < currentSectionIndex; i++) {
      offset += meta.sections[i].questionCount;
    }
    return offset + currentQuestionIndex;
  }

  int get totalQuestions => meta.totalQuestions;

  int get answeredCount =>
      currentAnswers.values.where((answer) => answer.isAnswered).length;

  int get unansweredCount => totalQuestions - answeredCount;
}

@riverpod
class ExamSessionNotifier extends _$ExamSessionNotifier {
  Timer? _autosaveTimer;
  var _disposed = false;
  var _autosaveEnabled = true;

  static const _autosaveDebounce = Duration(seconds: 30);
  static const _resultWait = Duration(seconds: 45);
  static const _resultPollInterval = Duration(seconds: 2);
  static const _prefsPrefix = 'exam_answers_';

  @override
  Future<ExamSessionState> build(String attemptId) async {
    ref.onDispose(() {
      _disposed = true;
      _autosaveEnabled = false;
      _autosaveTimer?.cancel();
    });

    final attemptData = await supabase
        .from('exam_attempts')
        .select()
        .eq('id', attemptId)
        .single();
    final attempt = ExamAttempt.fromJson(_mapAttemptJson(attemptData));

    final examData =
        await supabase.from('exams').select().eq('id', attempt.examId).single();

    final sectionsData = await supabase
        .from('exam_sections')
        .select()
        .eq('exam_id', attempt.examId)
        .order('order_index');

    final rawSections = (sectionsData as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    final sectionIds =
        rawSections.map((section) => section['id'] as String).toList();
    final questionCountRows = sectionIds.isEmpty
        ? const <dynamic>[]
        : await supabase
            .from('questions')
            .select('id, section_id')
            .inFilter('section_id', sectionIds);
    final actualCountBySection = <String, int>{};
    for (final row in questionCountRows) {
      final sectionId = (row as Map)['section_id'] as String?;
      if (sectionId == null) continue;
      actualCountBySection.update(sectionId, (value) => value + 1,
          ifAbsent: () => 1);
    }

    final sections = rawSections
        .map((section) =>
            SectionMeta.fromJson(_mapSectionJson(section)).copyWith(
              questionCount: actualCountBySection[section['id'] as String] ??
                  ((section['question_count'] as num?)?.toInt() ?? 0),
            ))
        .toList();

    final meta = ExamMeta.fromJson({
      ..._mapExamJson(examData),
      'sections': sections.map((section) => section.toJson()).toList(),
    });

    final questions =
        await ref.read(examQuestionsProvider(attempt.examId).future);
    final buffered = _loadBufferedAnswers(attemptId);
    final currentAnswers = buffered.isNotEmpty
        ? buffered
        : _restoreStoredAnswers(attempt.answers, questions);
    final seededState = ExamSessionState(
      attempt: attempt,
      meta: meta,
      currentAnswers: currentAnswers,
    );
    final derivedSectionIndex = seededState.sectionIndexForRemainingSeconds();
    final derivedQuestionIndex = _firstQuestionIndexForSection(
      sectionIndex: derivedSectionIndex,
      questions: questions,
      sections: sections,
      answers: currentAnswers,
    );

    return seededState.copyWith(
      currentSectionIndex: derivedSectionIndex,
      currentQuestionIndex: derivedQuestionIndex,
    );
  }

  void answerQuestion({
    required Question question,
    required QuestionAnswer answer,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!_autosaveEnabled || current.status == ExamSessionStatus.submitting) {
      return;
    }

    final previous = current.currentAnswers[question.id];
    final normalized = ExamQuestionAnswer.fromQuestionAnswer(
      question: question,
      answer: answer,
      existingAiAttemptId: previous?.aiAttemptId,
    );

    final updated =
        Map<String, ExamQuestionAnswer>.from(current.currentAnswers);
    if (normalized.isAnswered) {
      updated[question.id] = normalized;
    } else {
      updated.remove(question.id);
    }

    state = AsyncData(current.copyWith(currentAnswers: updated));
    _scheduleAutosave(
      current.attempt.id,
      updated,
      current.attempt.remainingSeconds,
    );
  }

  void goToQuestion(int sectionIndex, int questionIndex) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        currentSectionIndex: sectionIndex,
        currentQuestionIndex: questionIndex,
        showSectionTransition: false,
      ),
    );
  }

  void nextQuestion() {
    final current = state.valueOrNull;
    if (current == null) return;

    final section = current.currentSection;
    final isLastInSection =
        current.currentQuestionIndex >= section.questionCount - 1;
    final isLastSection =
        current.currentSectionIndex >= current.meta.sections.length - 1;

    if (!isLastInSection) {
      state = AsyncData(
        current.copyWith(
          currentQuestionIndex: current.currentQuestionIndex + 1,
        ),
      );
    } else if (!isLastSection) {
      state = AsyncData(current.copyWith(showSectionTransition: true));
    }
  }

  void advanceSection() {
    final current = state.valueOrNull;
    if (current == null) return;
    final nextSectionIndex = current.currentSectionIndex + 1;
    final questions =
        ref.read(examQuestionsProvider(current.meta.id)).valueOrNull ??
            const <Question>[];
    state = AsyncData(
      current.copyWith(
        currentSectionIndex: nextSectionIndex,
        currentQuestionIndex: _firstQuestionIndexForSection(
          sectionIndex: nextSectionIndex,
          questions: questions,
          sections: current.meta.sections,
          answers: current.currentAnswers,
        ),
        showSectionTransition: false,
      ),
    );
  }

  void syncSectionFromRemainingSeconds(int remainingSeconds) {
    final current = state.valueOrNull;
    if (current == null || !current.usesSectionTimers) return;
    final derivedSectionIndex =
        current.sectionIndexForRemainingSeconds(remainingSeconds);
    if (derivedSectionIndex == current.currentSectionIndex) return;
    final questions =
        ref.read(examQuestionsProvider(current.meta.id)).valueOrNull ??
            const <Question>[];
    state = AsyncData(
      current.copyWith(
        currentSectionIndex: derivedSectionIndex,
        currentQuestionIndex: _firstQuestionIndexForSection(
          sectionIndex: derivedSectionIndex,
          questions: questions,
          sections: current.meta.sections,
          answers: current.currentAnswers,
        ),
        showSectionTransition: false,
      ),
    );
  }

  Future<String?> submit() async {
    final current = state.valueOrNull;
    if (current == null) return null;

    _autosaveEnabled = false;
    _autosaveTimer?.cancel();

    state = AsyncData(
      current.copyWith(
        status: ExamSessionStatus.submitting,
        errorMessage: null,
      ),
    );

    try {
      final questions =
          await ref.read(examQuestionsProvider(current.meta.id).future);
      final enrichedAnswers = await _ensureAiAttempts(
        attemptId: current.attempt.id,
        questions: questions,
        answers: current.currentAnswers,
      );

      final submittedAt = DateTime.now();
      final updatedAttempt = current.attempt.copyWith(
        remainingSeconds: 0,
        submittedAt: submittedAt,
        status: 'submitted',
      );

      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          attempt: updatedAttempt,
          currentAnswers: enrichedAnswers,
        ),
      );

      await _persistProgress(
        attemptId: current.attempt.id,
        answers: enrichedAnswers,
        remainingSeconds: 0,
        status: 'submitted',
        submittedAt: submittedAt,
      );

      unawaited(Future<void>(() async {
        try {
          await supabase.functions
              .invoke('grade-exam', body: {'attempt_id': current.attempt.id});
        } catch (e) {
          debugPrint('[grade-exam] invoke error: $e');
        }
      }));

      final hasResult = await _waitForResultRow(current.attempt.id);
      if (!hasResult) {
        throw Exception('Result row not ready after ${_resultWait.inSeconds}s');
      }

      _clearBufferedAnswers(current.attempt.id);
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          status: ExamSessionStatus.submitted,
          attempt: updatedAttempt,
        ),
      );
      return current.attempt.id;
    } catch (e, st) {
      debugPrint('[submit] failed: $e\n$st');
      _autosaveEnabled = true;
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          status: ExamSessionStatus.ready,
          errorMessage: 'Nộp bài thất bại. Vui lòng thử lại.',
        ),
      );
      return null;
    }
  }

  void updateRemainingSeconds(int seconds) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        attempt: current.attempt.copyWith(remainingSeconds: seconds),
      ),
    );
  }

  Future<void> syncProgress({
    int? remainingSeconds,
    bool showAutosave = false,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!_autosaveEnabled || current.status == ExamSessionStatus.submitting) {
      return;
    }

    final nextRemaining = remainingSeconds ?? current.attempt.remainingSeconds;
    if (nextRemaining != null &&
        current.attempt.remainingSeconds != nextRemaining) {
      state = AsyncData(
        current.copyWith(
          attempt: current.attempt.copyWith(remainingSeconds: nextRemaining),
        ),
      );
    }

    await _persistProgress(
      attemptId: current.attempt.id,
      answers: state.valueOrNull?.currentAnswers ?? current.currentAnswers,
      remainingSeconds: nextRemaining,
      showAutosave: showAutosave,
    );
  }

  void _scheduleAutosave(
    String attemptId,
    Map<String, ExamQuestionAnswer> answers,
    int? remainingSeconds,
  ) {
    if (!_autosaveEnabled || _disposed) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounce, () {
      if (!_autosaveEnabled || _disposed) return;
      _persistProgress(
        attemptId: attemptId,
        answers: answers,
        remainingSeconds: remainingSeconds,
        showAutosave: true,
      );
    });
  }

  Future<void> _persistProgress({
    required String attemptId,
    required Map<String, ExamQuestionAnswer> answers,
    int? remainingSeconds,
    bool showAutosave = false,
    String? status,
    DateTime? submittedAt,
  }) async {
    if (_disposed) return;
    if (showAutosave && !_autosaveEnabled) return;
    final current = state.valueOrNull;
    if (current == null) return;

    if (showAutosave) {
      _safeSetState(current.copyWith(autosaveStatus: AutosaveStatus.saving));
    }

    try {
      await supabase.from('exam_attempts').update({
        'answers': _serializeAnswers(answers),
        if (remainingSeconds != null) 'remaining_seconds': remainingSeconds,
        if (status != null) 'status': status,
        if (submittedAt != null) 'submitted_at': submittedAt.toIso8601String(),
      }).eq('id', attemptId);

      _clearBufferedAnswers(attemptId);

      if (showAutosave) {
        _safeSetState(
          (state.valueOrNull ?? current).copyWith(
            autosaveStatus: AutosaveStatus.saved,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        _safeSetState(
          (state.valueOrNull ?? current).copyWith(
            autosaveStatus: AutosaveStatus.idle,
          ),
        );
      }
    } catch (_) {
      _bufferAnswers(attemptId, answers);
      if (showAutosave) {
        _safeSetState(
          (state.valueOrNull ?? current).copyWith(
            autosaveStatus: AutosaveStatus.failed,
          ),
        );
      }
    }
  }

  void _safeSetState(ExamSessionState next) {
    if (_disposed) return;
    try {
      state = AsyncData(next);
    } catch (_) {
      // A deferred autosave callback can finish after the provider/widget tree
      // has already been torn down. In that case we silently ignore the update.
    }
  }

  Future<void> persistCheckpoint(int remainingSeconds) async {
    if (_disposed) return;
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      await supabase.from('exam_attempts').update({
        'answers': _serializeAnswers(current.currentAnswers),
        'remaining_seconds': remainingSeconds,
      }).eq('id', current.attempt.id);
    } catch (_) {
      _bufferAnswers(current.attempt.id, current.currentAnswers);
    }
  }

  Future<Map<String, ExamQuestionAnswer>> _ensureAiAttempts({
    required String attemptId,
    required List<Question> questions,
    required Map<String, ExamQuestionAnswer> answers,
  }) async {
    final updated = Map<String, ExamQuestionAnswer>.from(answers);

    for (final question in questions) {
      if (question.type != QuestionType.writing) continue;

      final existing = updated[question.id];
      final text = existing?.writtenAnswer;
      if (existing == null || text == null || text.isEmpty) continue;
      if (existing.aiAttemptId != null) continue;

      final aiAttemptId = await submitWritingAttempt(
        text: text,
        questionId: question.id,
        examAttemptId: attemptId,
      );
      if (aiAttemptId != null && aiAttemptId.isNotEmpty) {
        updated[question.id] = existing.copyWith(aiAttemptId: aiAttemptId);
      }
    }

    return updated;
  }

  Future<bool> _waitForResultRow(String attemptId) async {
    final deadline = DateTime.now().add(_resultWait);
    while (DateTime.now().isBefore(deadline)) {
      final row = await supabase
          .from('exam_results')
          .select('id')
          .eq('attempt_id', attemptId)
          .maybeSingle();
      if (row != null) return true;
      await Future.delayed(_resultPollInterval);
    }
    return false;
  }

  Map<String, ExamQuestionAnswer> _restoreStoredAnswers(
    Map<String, dynamic> rawAnswers,
    List<Question> questions,
  ) {
    if (rawAnswers.isEmpty) return {};

    final restored = <String, ExamQuestionAnswer>{};
    final isLegacy = rawAnswers.keys.any((key) => key.startsWith('q_'));

    if (isLegacy) {
      for (final entry in questions.asMap().entries) {
        final raw = rawAnswers['q_${entry.key}'];
        if (raw == null) continue;
        final value = raw.toString().trim();
        if (value.isEmpty) continue;

        final question = entry.value;
        restored[question.id] = switch (question.type) {
          QuestionType.mcq => ExamQuestionAnswer(
              questionId: question.id,
              selectedOptionId: value,
            ),
          QuestionType.speaking => ExamQuestionAnswer(
              questionId: question.id,
              aiAttemptId: _looksLikeUuid(value) ? value : null,
            ),
          _ => ExamQuestionAnswer(
              questionId: question.id,
              writtenAnswer: value,
            ),
        };
      }
      return restored;
    }

    for (final entry in rawAnswers.entries) {
      final answer = ExamQuestionAnswer.fromStoredJson(entry.key, entry.value);
      if (answer.isAnswered) {
        restored[entry.key] = answer;
      }
    }
    return restored;
  }

  Map<String, dynamic> _serializeAnswers(
    Map<String, ExamQuestionAnswer> answers,
  ) {
    return {
      for (final entry in answers.entries)
        if (entry.value.isAnswered) entry.key: entry.value.toJson(),
    };
  }

  Map<String, ExamQuestionAnswer> _loadBufferedAnswers(String attemptId) {
    try {
      final raw =
          PrefsStorage.instance.prefs.getString('$_prefsPrefix$attemptId');
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map<String, ExamQuestionAnswer>((key, value) {
        return MapEntry(
          key.toString(),
          ExamQuestionAnswer.fromStoredJson(key.toString(), value),
        );
      });
    } catch (_) {
      return {};
    }
  }

  void _bufferAnswers(
    String attemptId,
    Map<String, ExamQuestionAnswer> answers,
  ) {
    try {
      final encoded = jsonEncode(_serializeAnswers(answers));
      PrefsStorage.instance.prefs.setString('$_prefsPrefix$attemptId', encoded);
    } catch (_) {}
  }

  void _clearBufferedAnswers(String attemptId) {
    try {
      PrefsStorage.instance.prefs.remove('$_prefsPrefix$attemptId');
    } catch (_) {}
  }
}

int _firstQuestionIndexForSection({
  required int sectionIndex,
  required List<Question> questions,
  required List<SectionMeta> sections,
  required Map<String, ExamQuestionAnswer> answers,
}) {
  if (sectionIndex < 0 || sectionIndex >= sections.length) return 0;

  var offset = 0;
  for (var index = 0; index < sectionIndex; index++) {
    offset += sections[index].questionCount;
  }

  final sectionLength = sections[sectionIndex].questionCount;
  for (var index = 0; index < sectionLength; index++) {
    final globalIndex = offset + index;
    if (globalIndex >= questions.length) break;
    final question = questions[globalIndex];
    if (!(answers[question.id]?.isAnswered ?? false)) {
      return index;
    }
  }

  return sectionLength == 0 ? 0 : sectionLength - 1;
}

@riverpod
class ExamTimerNotifier extends _$ExamTimerNotifier {
  Timer? _ticker;

  @override
  int build(int initialSeconds) {
    ref.onDispose(() => _ticker?.cancel());
    return initialSeconds;
  }

  void start(void Function() onExpired) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state > 0) {
        state = state - 1;
      } else {
        _ticker?.cancel();
        onExpired();
      }
    });
  }

  void pause() => _ticker?.cancel();

  void updateFromServer(int seconds) => state = seconds;
}

bool _looksLikeUuid(String value) {
  final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  return uuidPattern.hasMatch(value);
}
