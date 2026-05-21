import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/voice/voice_preference_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/app_notification.dart';
import '../../../shared/widgets/info_pill.dart';
import '../../exercise/screens/dictation_exercise_screen.dart';
import '../../exercise/screens/exercise_screen.dart' as exercise_feature;
import '../../exercise/screens/listening_exercise_screen.dart';
import '../../exercise/screens/reading_exercise_screen.dart';
import '../../exercise/screens/writing_exercise_screen.dart';
import '../../interview/screens/interview_session_screen.dart';
import '../widgets/rerecord_confirm_dialog.dart';
import '../widgets/submit_now_confirm_dialog.dart';
import 'answer_sheet_screen.dart';
import 'mock_exam_section_detail_screen.dart';
import 'mock_exam_skill_dispatch.dart';

class _PendingAnalysis {
  const _PendingAnalysis({
    required this.attemptId,
    required this.audioPath,
    required this.fileSizeBytes,
    required this.durationMs,
  });

  final String attemptId;
  final String audioPath;
  final int fileSizeBytes;
  final int durationMs;
}

int? _exerciseTypeNumber(String exerciseType) {
  final match = RegExp(r'_(\d+)').firstMatch(exerciseType);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

String _exerciseTypeLabel(AppLocalizations l, String exerciseType) {
  final n = _exerciseTypeNumber(exerciseType);
  if (exerciseType.startsWith('uloha_') && n != null) {
    return l.mockExamTaskTypeUloha(n);
  }
  if (exerciseType.startsWith('poslech_') && n != null) {
    return l.mockExamTaskTypeListening(n);
  }
  if (exerciseType.startsWith('cteni_') && n != null) {
    return l.mockExamTaskTypeReading(n);
  }
  if (exerciseType == 'psani_1_formular') {
    return l.mockExamTaskTypeWritingForm;
  }
  if (exerciseType == 'psani_2_email') {
    return l.mockExamTaskTypeWritingEmail;
  }
  if (exerciseType.startsWith('psani_') && n != null) {
    return l.mockExamTaskTypeWriting(n);
  }
  return exerciseType.replaceAll('_', ' ');
}

/// V39 mock exam runner. Sections open in `display_order`; speaking attempts
/// are queued for bulk analysis after the last pending section resolves.
class MockExamScreen extends StatefulWidget {
  const MockExamScreen({
    super.key,
    required this.client,
    this.initialSession,
    this.mockTest,
    this.onCompleted,
    this.showResultAfterCompletionCallback = false,
    this.resultCtaLabel,
    this.onResultCta,
    this.autoStartFirstSection = true,
    this.showProminentSubmitAction = false,
  });

  final ApiClient client;

  /// Pre-created session from the intro screen. If null, a new session is created.
  final MockExamSessionView? initialSession;

  /// Template selected by the learner. Used for title/copy while a session is in progress.
  final MockTest? mockTest;

  /// Optional hook fired once after the session transitions to completed.
  /// When provided, the caller is responsible for rendering the result screen
  /// (e.g. PlacementTestScreen → PlacementResultScreen, PreExamScreen →
  /// PromotionResultScreen). Set [showResultAfterCompletionCallback] when the
  /// caller only needs a completion side-effect and this screen should still
  /// render the built-in [_MockExamResultView].
  final FutureOr<void> Function(String sessionId)? onCompleted;

  final bool showResultAfterCompletionCallback;
  final String? resultCtaLabel;
  final VoidCallback? onResultCta;

  /// V39 process-mode: start at the first question instead of landing on
  /// the fallback section overview. Tests that inspect the overview can
  /// disable this without changing production navigation.
  final bool autoStartFirstSection;

  /// Shows the final submit action directly in the AppBar instead of hiding it
  /// inside the overflow menu. Used by placement where early submit must be
  /// easy to discover.
  final bool showProminentSubmitAction;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  MockExamSessionView? _session;
  bool _loading = true;
  String? _error;
  Map<String, String> _sectionReadiness = {};

  final List<_PendingAnalysis> _pendingAnalyses = [];
  bool _analyzing = false;
  int _analyzeProgress = 0;

  /// V39 S7 — when set, the next `_advanceSection` call passes this
  /// `target_display_order` to the server so the attempt is attached to a
  /// specific section (jump-back from the answer sheet). Reset to null
  /// after consumption so the linear-advance path resumes.
  int? _jumpTarget;

  /// V39 — auto-launch the first pending section once after the session
  /// loads so the learner lands directly inside the exam (no section-list
  /// landing). Returning from a completed per-section screen continues to
  /// the next pending section; the overview is only a fallback if the
  /// learner backs out or an error interrupts the process.
  bool _autoLaunchedFirst = false;

  /// V39 — 1-second ticker driving the AppBar countdown. Active only while
  /// the session has a server-anchored timer (`duration_sec > 0`).
  Timer? _timerTicker;
  bool _timerAutoSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _timerTicker?.cancel();
    super.dispose();
  }

  // V39 — kick off the per-second ticker driving the AppBar countdown.
  // Safe to call multiple times; previous timer is cancelled.
  void _startTickerIfNeeded() {
    _timerTicker?.cancel();
    final session = _session;
    if (session == null || !session.hasTimer) return;
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = _session;
      if (current != null &&
          current.hasTimer &&
          !current.isCompleted &&
          current.remainingAt(DateTime.now()) == Duration.zero &&
          !_timerAutoSubmitting) {
        _timerAutoSubmitting = true;
        _submitNow(auto: true);
        return;
      }
      setState(() {}); // re-render the timer chip
    });
  }

  // V39 — auto-launch the first pending section once after the session
  // loads. Completed sections continue to the next pending section; the
  // overview stays available only when the learner backs out or an error
  // interrupts the flow.
  Future<void> _autoLaunchFirstPendingIfNeeded() async {
    if (!widget.autoStartFirstSection) return;
    if (_autoLaunchedFirst) return;
    final session = _session;
    if (session == null || session.isCompleted) return;
    final first = _firstPendingSection();
    if (first == null) return;
    _autoLaunchedFirst = true;
    await _runSection(first);
  }

  List<MockExamSection> _sectionsByDisplayOrder() {
    final session = _session;
    if (session == null) return const [];
    return [...session.sections]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  MockExamSection? _firstPendingSection() {
    for (final s in _sectionsByDisplayOrder()) {
      if (s.isPending) return s;
    }
    return null;
  }

  MockExamSection? _nextPendingAfter(int displayOrder) {
    for (final s in _sectionsByDisplayOrder()) {
      if (s.displayOrder > displayOrder && s.isPending) return s;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    // Use pre-created session from intro screen if available
    final initial = widget.initialSession;
    if (initial != null) {
      setState(() {
        _session = initial;
        _loading = false;
      });
      _startTickerIfNeeded();
      // V39 — dispatch first-pending after the current frame so
      // Navigator.push from initState-driven async path runs after the
      // widget tree settles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_autoLaunchFirstPendingIfNeeded());
        // Server-side timer sweeper can flip a session to 'completed'
        // without running scoring (ExpireMockExam by design skips the
        // rollup). When the learner returns and we load such a session,
        // run /complete to score it and let onCompleted fire.
        if (initial.isCompleted &&
            initial.overallScore == 0 &&
            !initial.passed) {
          unawaited(_finalize());
        }
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _pendingAnalyses.clear();
      _analyzing = false;
      _analyzeProgress = 0;
    });
    try {
      final mockTestId = widget.mockTest?.id.trim() ?? '';
      if (widget.mockTest != null && mockTestId.isEmpty) {
        throw Exception(AppLocalizations.of(context).mockTestMissingTemplateId);
      }
      final payload = await widget.client.createMockExam(
        mockTestId: mockTestId.isEmpty ? null : mockTestId,
      );
      final session = MockExamSessionView.fromJson(payload);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
      _startTickerIfNeeded();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoLaunchFirstPendingIfNeeded();
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _advanceSection(String attemptId) async {
    try {
      final target = _jumpTarget;
      final payload = await widget.client.advanceMockExam(
        _session!.id,
        attemptId: attemptId,
        targetDisplayOrder: target,
      );
      if (!mounted) return false;
      setState(() {
        _session = MockExamSessionView.fromJson(payload);
        _error = null;
        _jumpTarget = null; // consume the jump target on first advance.
      });
      return true;
    } catch (err) {
      if (!mounted) return false;
      setState(() => _error = err.toString());
      return false;
    }
  }

  Future<void> _continueAfterResolvedSection(int displayOrder) async {
    if (!mounted) return;
    final next = _nextPendingAfter(displayOrder) ?? _firstPendingSection();
    if (next != null) {
      await _runSection(next);
      return;
    }
    await _bulkAnalyze();
  }

  void _returnToExamRouteIfNeeded() {
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) return;
    Navigator.of(context).popUntil((candidate) => identical(candidate, route));
  }

  // V39 S9 — "Nộp bài ngay": if any section is still pending, show a
  // destructive confirm with the pending count; otherwise submit directly.
  // Server marks remaining pending sections as 'skipped' and flips the
  // session to 'completed' in one call.
  Future<void> _submitNow({bool auto = false}) async {
    final session = _session;
    if (session == null) return;
    if (auto) {
      _returnToExamRouteIfNeeded();
      setState(() {
        _analyzing = true;
        _error = null;
      });
    }
    final pending = session.sections.where((s) => s.isPending).length;
    final total = session.sections.length;
    if (!auto && pending > 0) {
      final ok = await SubmitNowConfirmDialog.show(
        context,
        unansweredCount: pending,
        totalCount: total,
      );
      if (!mounted || !ok) return;
    }
    try {
      // Speaking sections record locally and bulk-analyze later. If the
      // learner taps "Nộp bài ngay" before the bulk path runs, the speaking
      // attempts are still 'draft' (no audio uploaded). Upload them first
      // (without finalizing — pending sections still need to be skipped via
      // /expire before /complete can score).
      if (_pendingAnalyses.isNotEmpty) {
        setState(() {
          _analyzing = true;
          _analyzeProgress = 0;
        });
        final total = _pendingAnalyses.length;
        for (var i = 0; i < total; i++) {
          final pending = _pendingAnalyses[i];
          if (!mounted) return;
          setState(() => _analyzeProgress = i + 1);
          final voiceId = await VoicePreferenceService.readCurrent();
          await widget.client.submitRecordedAudio(
            pending.attemptId,
            audioPath: pending.audioPath,
            mimeType: 'audio/m4a',
            fileSizeBytes: pending.fileSizeBytes,
            durationMs: pending.durationMs,
            preferredVoiceId: voiceId.isNotEmpty ? voiceId : null,
          );
          await _pollUntilDone(pending.attemptId);
        }
        _pendingAnalyses.clear();
        if (!mounted) return;
      }
      final payload = await widget.client.expireMockExam(session.id);
      if (!mounted) return;
      setState(() {
        _session = MockExamSessionView.fromJson(payload);
        _error = null;
      });
      // /expire only flips pending→skipped + session.status='completed' —
      // it deliberately skips scoring rollup. Fire /complete next so the
      // attempted sections get scored and the result view has an overall
      // score (otherwise learner sees a finished exam with 0/0).
      await _finalize();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = err.toString();
      });
    }
  }

  // V39 — mark a pending section as 'skipped' so the learner can move past it.
  // The same display_order remains re-enterable via the answer sheet.
  Future<void> _skipSection(MockExamSection section) async {
    try {
      final payload = await widget.client.skipMockExamSection(
        _session!.id,
        displayOrder: section.displayOrder,
      );
      if (!mounted) return;
      setState(() {
        _session = MockExamSessionView.fromJson(payload);
        _error = null;
      });
      await _continueAfterResolvedSection(section.displayOrder);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  Future<void> _runSection(MockExamSection section) async {
    final navigator = Navigator.of(context);
    final resolvedDisplayOrder = section.displayOrder;
    var sectionResolved = false;
    try {
      final detail = ExerciseDetail.fromJson(
        await widget.client.getExercise(
          section.exerciseId,
          mockExamSessionId: _session?.id,
        ),
      );
      if (!mounted) return;

      final kind = sectionSkillKind(section);

      if (kind == 'noi') {
        // Speaking: collect recording, bulk-analyze after all sections done.
        _PendingAnalysis? recorded;
        await navigator.push(
          MaterialPageRoute(
            builder:
                (_) => exercise_feature.ExerciseScreen(
                  client: widget.client,
                  detail: detail,
                  onRecordingReady: (
                    attemptId,
                    audioPath,
                    fileSizeBytes,
                    durationMs,
                  ) {
                    recorded = _PendingAnalysis(
                      attemptId: attemptId,
                      audioPath: audioPath,
                      fileSizeBytes: fileSizeBytes,
                      durationMs: durationMs,
                    );
                  },
                ),
          ),
        );
        if (!mounted) return;

        final rec = recorded;
        if (rec == null) return; // user backed out

        final advanced = await _advanceSection(rec.attemptId);
        if (!advanced || !mounted) return;
        setState(() => _pendingAnalyses.add(rec));
        sectionResolved = true;
      } else if (kind == 'interview') {
        // V36 — interview attempts are created up-front (mirrors course
        // intro flow) and the session screen fires onSessionEnded after
        // submit-interview resolves; the runner advances on that callback.
        final attemptRaw = await widget.client.createAttempt(detail.id);
        final attemptId = attemptRaw['id'] as String;
        if (!mounted) return;
        await navigator.push(
          MaterialPageRoute(
            builder:
                (_) => InterviewSessionScreen(
                  client: widget.client,
                  exerciseId: detail.id,
                  attemptId: attemptId,
                  detail: detail,
                  onSessionEnded: (id) async {
                    sectionResolved = await _advanceSection(id);
                  },
                ),
          ),
        );
        if (!mounted) return;
      } else {
        // Non-speaking: route to correct screen; callback advances session in background.
        await navigator.push(
          MaterialPageRoute(
            builder: (_) {
              if (kind == 'nghe') {
                return ListeningExerciseScreen(
                  client: widget.client,
                  detail: detail,
                  showResultOnCompletion: false,
                  onAttemptCompleted: (id) async {
                    sectionResolved = await _advanceSection(id);
                  },
                );
              } else if (kind == 'doc') {
                return ReadingExerciseScreen(
                  client: widget.client,
                  detail: detail,
                  showResultOnCompletion: false,
                  onAttemptCompleted: (id) async {
                    sectionResolved = await _advanceSection(id);
                  },
                );
              } else if (detail.isPsani3) {
                // V38.x — psani_3_dictation uses the dedicated stepper screen
                // (course flow routes the same way). Without this, the writing
                // screen renders an empty body in exam mode because its
                // builders only handle psani_1/psani_2.
                return DictationExerciseScreen(
                  client: widget.client,
                  detail: detail,
                  showResultOnCompletion: false,
                  onAttemptCompleted: (id) async {
                    sectionResolved = await _advanceSection(id);
                  },
                );
              } else {
                return WritingExerciseScreen(
                  client: widget.client,
                  detail: detail,
                  showResultOnCompletion: false,
                  onAttemptCompleted: (id) async {
                    sectionResolved = await _advanceSection(id);
                  },
                );
              }
            },
          ),
        );
        if (!mounted) return;
        // If user backed out without completing, _session remains unchanged (nextPending != null).
      }

      if (sectionResolved) {
        await _continueAfterResolvedSection(resolvedDisplayOrder);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  Future<void> _bulkAnalyze() async {
    setState(() {
      _analyzing = true;
      _analyzeProgress = 0;
    });

    final total = _pendingAnalyses.length;
    for (var i = 0; i < total; i++) {
      final pending = _pendingAnalyses[i];
      if (!mounted) return;
      setState(() => _analyzeProgress = i + 1);
      try {
        final voiceId = await VoicePreferenceService.readCurrent();
        await widget.client.submitRecordedAudio(
          pending.attemptId,
          audioPath: pending.audioPath,
          mimeType: 'audio/m4a',
          fileSizeBytes: pending.fileSizeBytes,
          durationMs: pending.durationMs,
          preferredVoiceId: voiceId.isNotEmpty ? voiceId : null,
        );
        await _pollUntilDone(pending.attemptId);
      } catch (err) {
        if (!mounted) return;
        setState(() {
          _analyzing = false;
          _error = err.toString();
        });
        return;
      }
    }

    if (!mounted) return;
    await _finalize();
  }

  Future<void> _pollUntilDone(String attemptId) async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final attempt = AttemptResult.fromJson(
        await widget.client.getAttempt(attemptId),
      );
      if (attempt.status == 'completed' || attempt.status == 'failed') return;
    }
  }

  Future<void> _finalize() async {
    try {
      final payload = await widget.client.completeMockExam(_session!.id);
      if (!mounted) return;
      final completed = MockExamSessionView.fromJson(payload);
      final attemptIds =
          completed.sections
              .map((s) => s.attemptId)
              .where((id) => id.isNotEmpty)
              .toSet();
      final Map<String, String> readiness = {};
      if (attemptIds.isNotEmpty) {
        final all = await widget.client.getAttempts();
        for (final item in all) {
          final a = AttemptResult.fromJson(item as Map<String, dynamic>);
          if (attemptIds.contains(a.id) && a.readinessLevel.isNotEmpty) {
            readiness[a.id] = a.readinessLevel;
          }
        }
      }
      if (!mounted) return;
      final onCompleted = widget.onCompleted;
      if (onCompleted != null && completed.isCompleted) {
        if (widget.showResultAfterCompletionCallback) {
          await onCompleted(completed.id);
          if (!mounted) return;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(Future.sync(() => onCompleted(completed.id)));
          });
        }
      }
      setState(() {
        _session = completed;
        _sectionReadiness = readiness;
        _analyzing = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = err.toString();
      });
    }
  }

  // V39 — server-anchored countdown rendered in AppBar.title row. Falls
  // back to the plain title when the session hasn't loaded a timer yet
  // (pre-V39 sessions or the loading state).
  Widget _buildAppBarTitle(String mockTitle, AppLocalizations l) {
    final session = _session;
    final title = mockTitle.isNotEmpty ? mockTitle : l.mockExamTitle;
    final remaining =
        session != null && session.hasTimer
            ? session.remainingAt(DateTime.now())
            : null;
    if (remaining == null) {
      return Text(title);
    }
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    final timerStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final warning = remaining < const Duration(minutes: 5);
    final timerColor = warning ? AppColors.error : AppColors.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 18, color: timerColor),
        const SizedBox(width: 6),
        Text(
          timerStr,
          style: AppTypography.titleMedium.copyWith(
            color: timerColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mockTitle = widget.mockTest?.title.trim() ?? '';
    final session = _session;
    final canSubmit = session != null && !session.isCompleted;
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(mockTitle, l),
        actions: [
          // V39 — open the Answer Sheet. S7: tapping a chip pops with the
          // section's display_order, and we re-run that section with the
          // server's jump-back semantics (`target_display_order`).
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Danh sách câu',
            onPressed:
                session == null
                    ? null
                    : () async {
                      final picked = await Navigator.of(context).push<int>(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => AnswerSheetScreen(session: session),
                        ),
                      );
                      if (!context.mounted || picked == null) return;
                      MockExamSection? target;
                      for (final s in _session!.sections) {
                        if (s.displayOrder == picked) {
                          target = s;
                          break;
                        }
                      }
                      if (target == null) return;
                      // V39 S8 — speaking sections with an existing attempt
                      // require a destructive confirm before re-record. Old
                      // attempt audio becomes inert (new attempt linked via
                      // target_display_order from S7). Interview sections use
                      // a different lifecycle and skip the dialog.
                      final kind = sectionSkillKind(target);
                      final needsConfirm =
                          kind == 'noi' && target.attemptId.isNotEmpty;
                      if (needsConfirm) {
                        final ok = await RerecordConfirmDialog.show(context);
                        if (!context.mounted || !ok) return;
                      }
                      setState(() => _jumpTarget = picked);
                      await _runSection(target);
                    },
          ),
          if (widget.showProminentSubmitAction && canSubmit)
            _ProminentSubmitAction(onPressed: () => _submitNow())
          else
            // V39 S9 — overflow ⋮ "Nộp bài ngay". Disabled while loading or
            // after the session has already completed.
            PopupMenuButton<String>(
              tooltip: 'Tuỳ chọn',
              icon: const Icon(Icons.more_vert_rounded),
              enabled: canSubmit,
              onSelected: (key) {
                if (key == 'submit-now') {
                  _submitNow();
                }
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(
                      value: 'submit-now',
                      child: ListTile(
                        leading: Icon(Icons.flag_rounded),
                        title: Text('Nộp bài ngay'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(l)),
      bottomNavigationBar: _buildBottomSubmitBar(l),
    );
  }

  Widget? _buildBottomSubmitBar(AppLocalizations l) {
    final session = _session;
    if (widget.showProminentSubmitAction ||
        _loading ||
        _analyzing ||
        session == null ||
        session.isCompleted) {
      return null;
    }
    final pending = session.sections.where((s) => s.isPending).length;
    final total = session.sections.length;
    final hint =
        pending > 0
            ? l.mockExamSubmitNowPendingHint(pending, total)
            : l.mockExamSubmitNowReadyHint;
    return _BottomSubmitBar(
      hint: hint,
      ctaLabel: l.mockExamSubmitNowCta,
      onPressed: () => _submitNow(),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = _error;
    if (err != null && _session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.x3),
              FilledButton(onPressed: _bootstrap, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }
    if (_analyzing) {
      return _buildAnalyzingView(l);
    }
    final session = _session!;
    final hasSpeaking = session.sections.any(
      (s) => sectionSkillKind(s) == 'noi',
    );
    if (session.isCompleted) {
      if (widget.onCompleted != null &&
          !widget.showResultAfterCompletionCallback) {
        // Caller handles the result screen; show a brief spinner while the
        // postFrameCallback fires and the route transition completes.
        return const Center(child: CircularProgressIndicator());
      }
      return _MockExamResultView(
        client: widget.client,
        session: session,
        sectionReadiness: _sectionReadiness,
        ctaLabel: widget.resultCtaLabel,
        onCta: widget.onResultCta,
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        Text(
          l.mockExamProgressIntroTitle(session.sections.length),
          style: AppTypography.titleLarge,
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          hasSpeaking
              ? l.mockExamProgressIntroBodyWithSpeaking
              : l.mockExamProgressIntroBodyNoSpeaking,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.x5),
        for (final section in session.sections) ...[
          _SectionTile(
            section: section,
            onStart: () => _runSection(section),
            onSkip: section.isPending ? () => _skipSection(section) : null,
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (err != null) ...[
          const SizedBox(height: AppSpacing.x3),
          AppNotification.error(message: err),
        ],
      ],
    );
  }

  Widget _buildAnalyzingView(AppLocalizations l) {
    final total = _pendingAnalyses.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.mockExamAnalyzing,
              style: AppTypography.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x3),
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: _analyzeProgress / total,
                  minHeight: 6,
                  backgroundColor: AppColors.outlineVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              ...List.generate(_pendingAnalyses.length, (i) {
                // _analyzeProgress = k means section k-1 is currently processing.
                // Sections 0..k-2 are done; section k-1 is active; k..end are pending.
                final done = _analyzeProgress > 1 && i < _analyzeProgress - 1;
                final active =
                    _analyzeProgress > 0 && i == _analyzeProgress - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            done
                                ? const Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: AppColors.success,
                                )
                                : active
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                                : const Icon(
                                  Icons.radio_button_unchecked,
                                  size: 20,
                                  color: AppColors.outline,
                                ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(
                        l.mockExamSectionLabel(i + 1),
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              done
                                  ? AppColors.success
                                  : active
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProminentSubmitAction extends StatelessWidget {
  const _ProminentSubmitAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.x2),
      child: FilledButton.icon(
        key: const Key('mock_exam_prominent_submit'),
        onPressed: onPressed,
        icon: const Icon(Icons.flag_rounded, size: 18),
        label: Text(AppLocalizations.of(context).mockExamSubmitNowCta),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _BottomSubmitBar extends StatelessWidget {
  const _BottomSubmitBar({
    required this.hint,
    required this.ctaLabel,
    required this.onPressed,
  });

  final String hint;
  final String ctaLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pagePaddingH(context);
    return Material(
      color: AppColors.surfaceContainerLowest,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.outlineVariant, width: 0.8),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.x3,
              horizontal,
              AppSpacing.x3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        hint,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                FilledButton.icon(
                  key: const Key('mock_exam_bottom_submit'),
                  onPressed: onPressed,
                  icon: const Icon(Icons.flag_rounded, size: 20),
                  label: Text(ctaLabel),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.onStart,
    this.onSkip,
  });

  final MockExamSection section;
  final VoidCallback onStart;

  /// V39 — fires when the learner taps "Bỏ qua" on this tile. Null for
  /// sections that are already completed/skipped (button hidden).
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final skill = skillLabel(l, sectionSkillKind(section));
    final exerciseType = _exerciseTypeLabel(l, section.exerciseType);
    final exercise =
        section.exerciseTitle.isNotEmpty ? section.exerciseTitle : exerciseType;
    final PillTone tone;
    final String label;
    if (section.isCompleted) {
      tone = PillTone.info;
      label = l.mockExamStatusRecorded;
    } else if (section.isSkipped) {
      tone = PillTone.neutral;
      label = 'Đã bỏ qua';
    } else {
      tone = PillTone.primary;
      label = l.mockExamStatusPending;
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color:
            section.isSkipped
                ? AppColors.surfaceContainer
                : AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color:
              section.isSkipped ? AppColors.outline : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoPill(label: label, tone: tone),
                const SizedBox(height: AppSpacing.x2),
                Text(exercise, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  section.maxPoints > 0
                      ? l.mockExamSectionMeta(
                        l.mockExamSectionLabel(section.sequenceNo),
                        skill,
                        section.maxPoints,
                      )
                      : '${l.mockExamSectionLabel(section.sequenceNo)} · $skill',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: section.isPending ? onStart : null,
                child: Text(
                  section.isCompleted
                      ? l.mockExamActionDone
                      : section.isSkipped
                      ? 'Đã bỏ qua'
                      : l.mockExamActionStart,
                ),
              ),
              if (onSkip != null) ...[
                const SizedBox(height: AppSpacing.x1),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x3,
                      vertical: AppSpacing.x1,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Bỏ qua'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillResultBucket {
  int score = 0;
  int max = 0;
  int completed = 0;
  int skipped = 0;

  double get fraction => max > 0 ? score / max : 0;
}

class _SkillResultSummary {
  const _SkillResultSummary({
    required this.skillKind,
    required this.label,
    required this.score,
    required this.max,
    required this.completed,
    required this.skipped,
    required this.comment,
  });

  final String skillKind;
  final String label;
  final int score;
  final int max;
  final int completed;
  final int skipped;
  final String comment;

  double get fraction => max > 0 ? score / max : 0;
}

class _SkillSummaryTile extends StatelessWidget {
  const _SkillSummaryTile({required this.summary});

  final _SkillResultSummary summary;

  @override
  Widget build(BuildContext context) {
    final pct = summary.fraction.clamp(0.0, 1.0);
    final color =
        pct >= 0.8
            ? AppColors.success
            : pct >= 0.55
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_skillIcon(summary.skillKind), color: color, size: 20),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(summary.label, style: AppTypography.titleSmall),
              ),
              if (summary.max > 0)
                Text(
                  '${summary.score}/${summary.max}',
                  style: AppTypography.titleSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (summary.max > 0) ...[
            const SizedBox(height: AppSpacing.x2),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x2),
          Text(
            summary.comment,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _skillIcon(String kind) => switch (kind) {
  'noi' => Icons.mic_outlined,
  'nghe' => Icons.headphones_outlined,
  'doc' => Icons.menu_book_outlined,
  'viet' => Icons.edit_outlined,
  'interview' => Icons.forum_outlined,
  _ => Icons.quiz_outlined,
};

class _MockExamResultView extends StatelessWidget {
  const _MockExamResultView({
    required this.client,
    required this.session,
    required this.sectionReadiness,
    this.ctaLabel,
    this.onCta,
  });

  final ApiClient client;
  final MockExamSessionView session;
  final Map<String, String> sectionReadiness;
  final String? ctaLabel;
  final VoidCallback? onCta;

  // Helper so Builder callbacks inside build() can access client.
  ApiClient _client(BuildContext context) => client;

  IconData _sectionIcon(String exerciseType) => switch (exerciseType) {
    String t when t.startsWith('uloha_1') => Icons.person_outline_rounded,
    String t when t.startsWith('uloha_2') => Icons.image_outlined,
    String t when t.startsWith('uloha_3') => Icons.people_outline_rounded,
    String t when t.startsWith('uloha_4') => Icons.mic_none_rounded,
    String t when t.startsWith('poslech_') => Icons.headphones_outlined,
    String t when t.startsWith('cteni_') => Icons.menu_book_outlined,
    String t when t.startsWith('psani_') => Icons.edit_outlined,
    _ => Icons.school_outlined,
  };

  Color _sectionIconBg(String exerciseType) => switch (exerciseType) {
    String t when t.startsWith('uloha_1') => AppColors.primaryFixed,
    String t when t.startsWith('uloha_2') => AppColors.infoContainer,
    String t when t.startsWith('uloha_3') => AppColors.warningContainer,
    String t when t.startsWith('uloha_4') => AppColors.successContainer,
    String t when t.startsWith('poslech_') => AppColors.infoContainer,
    String t when t.startsWith('cteni_') => AppColors.tertiaryContainer,
    String t when t.startsWith('psani_') => AppColors.secondaryContainer,
    _ => AppColors.surfaceContainerHigh,
  };

  List<_SkillResultSummary> _skillSummaries(AppLocalizations l) {
    final bySkill = <String, _SkillResultBucket>{};
    for (final section in session.sections) {
      final skill = sectionSkillKind(section);
      final bucket = bySkill.putIfAbsent(skill, () => _SkillResultBucket());
      bucket.score += section.sectionScore;
      bucket.max += section.maxPoints;
      if (section.isCompleted) bucket.completed += 1;
      if (section.isSkipped) bucket.skipped += 1;
    }
    const order = ['noi', 'nghe', 'doc', 'viet', 'interview'];
    final skills =
        bySkill.keys.toList()..sort((a, b) {
          final ia = order.indexOf(a);
          final ib = order.indexOf(b);
          final ra = ia < 0 ? order.length : ia;
          final rb = ib < 0 ? order.length : ib;
          return ra == rb ? a.compareTo(b) : ra.compareTo(rb);
        });
    return [
      for (final skill in skills)
        _SkillResultSummary(
          skillKind: skill,
          label: skillLabel(l, skill),
          score: bySkill[skill]!.score,
          max: bySkill[skill]!.max,
          completed: bySkill[skill]!.completed,
          skipped: bySkill[skill]!.skipped,
          comment: _skillComment(l, skill, bySkill[skill]!.fraction),
        ),
    ];
  }

  String _skillComment(AppLocalizations l, String skillKind, double fraction) {
    final label = skillLabel(l, skillKind);
    if (fraction >= 0.8) {
      return l.mockExamSkillCommentStrong(label);
    }
    if (fraction >= 0.55) {
      return l.mockExamSkillCommentOk(label);
    }
    return l.mockExamSkillCommentNeedsWork(label);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final totalMax = session.totalScoreMax > 0 ? session.totalScoreMax : 40;
    final hasScore =
        session.isCompleted || session.overallScore > 0 || session.passed;
    final passColor = session.passed ? AppColors.success : AppColors.error;
    final passContainerColor =
        session.passed ? AppColors.successContainer : AppColors.errorContainer;
    final skillSummaries = _skillSummaries(l);

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        // ── Score hero ────────────────────────────────────────────────────────
        if (hasScore) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x6,
                vertical: AppSpacing.x5,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    'CELKOVÉ SKÓRE',
                    style: AppTypography.labelUppercase.copyWith(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  RichText(
                    text: TextSpan(
                      text: '${session.overallScore}',
                      style: AppTypography.scoreDisplay.copyWith(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: ' / $totalMax',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),

          // Pass/Fail badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: passContainerColor,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    session.passed
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: passColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.passed ? l.mockExamPassLabel : l.mockExamFailLabel,
                    style: AppTypography.labelUppercase.copyWith(
                      color: passColor,
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Center(
            child: Text(
              l.mockExamResultPassThreshold(session.passThresholdPercent),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          if (session.overallSummary.isNotEmpty)
            Center(
              child: Text(
                session.overallSummary,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.x5),
        ],

        if (skillSummaries.isNotEmpty) ...[
          Text(l.mockExamSkillSummaryTitle, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.x2),
          for (final summary in skillSummaries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: _SkillSummaryTile(summary: summary),
            ),
          const SizedBox(height: AppSpacing.x3),
        ],

        // ── Section breakdown ─────────────────────────────────────────────────
        Text(l.mockExamSectionBreakdownTitle, style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.x1),
        Text(
          l.mockExamTapSectionHint,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        for (final section in session.sections)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: Builder(
              builder: (context) {
                final hasMax = section.maxPoints > 0;
                final canTap = section.attemptId.isNotEmpty;
                final score = section.sectionScore;
                final maxPts = section.maxPoints;
                final pct = hasMax && maxPts > 0 ? score / maxPts : 0.0;
                final barColor =
                    pct >= 0.75
                        ? AppColors.success
                        : pct >= 0.5
                        ? AppColors.warning
                        : AppColors.error;

                return GestureDetector(
                  onTap:
                      canTap
                          ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => MockExamSectionDetailScreen(
                                    client: _client(context),
                                    attemptId: section.attemptId,
                                    sequenceNo: section.sequenceNo,
                                    skillKind: sectionSkillKind(section),
                                    maxPoints: section.maxPoints,
                                  ),
                            ),
                          )
                          : null,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l.mockExamSectionLabel(section.sequenceNo),
                              style: AppTypography.labelUppercase.copyWith(
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Spacer(),
                            if (canTap)
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: AppColors.onSurfaceVariant,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _sectionIconBg(section.exerciseType),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _sectionIcon(section.exerciseType),
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x3),
                            if (hasMax) ...[
                              Text(
                                '$score/$maxPts',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x3),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor:
                                        AppColors.surfaceContainerHigh,
                                    valueColor: AlwaysStoppedAnimation(
                                      barColor,
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              Text(
                                _exerciseTypeLabel(l, section.exerciseType),
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: AppSpacing.x3),

        // ── Readiness analysis card ───────────────────────────────────────────
        if (session.overallSummary.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.x5),
            decoration: BoxDecoration(
              color: AppColors.inverseSurfaceLight,
              borderRadius: AppRadius.lgAll,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.analytics_outlined,
                      color: AppColors.primaryFixed,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Text(
                      'Analýza připravenosti',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.primaryFixed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  session.overallSummary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inverseOnSurfaceLight.withAlpha(200),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.x5),

        // ── CTA ───────────────────────────────────────────────────────────────
        FilledButton.icon(
          onPressed:
              onCta ??
              () => Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.home_outlined, size: 18),
          label: Text(ctaLabel ?? l.mockExamBackHome),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: AppSpacing.x6),
      ],
    );
  }
}
