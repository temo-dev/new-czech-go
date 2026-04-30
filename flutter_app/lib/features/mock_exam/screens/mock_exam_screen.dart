import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/voice/voice_preference_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';
import '../../exercise/screens/exercise_screen.dart' as exercise_feature;
import '../../exercise/screens/listening_exercise_screen.dart';
import '../../exercise/screens/reading_exercise_screen.dart';
import '../../exercise/screens/writing_exercise_screen.dart';
import 'mock_exam_section_detail_screen.dart';

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

String _skillKindForExerciseType(String exerciseType) {
  if (exerciseType.startsWith('uloha_')) return 'noi';
  if (exerciseType.startsWith('poslech_')) return 'nghe';
  if (exerciseType.startsWith('cteni_')) return 'doc';
  if (exerciseType.startsWith('psani_')) return 'viet';
  return 'noi';
}

String _sectionSkillKind(MockExamSection section) {
  return section.skillKind.isNotEmpty
      ? section.skillKind
      : _skillKindForExerciseType(section.exerciseType);
}

String _skillLabel(AppLocalizations l, String skillKind) => switch (skillKind) {
  'noi' => l.skillNoi,
  'nghe' => l.skillNghe,
  'doc' => l.skillDoc,
  'viet' => l.skillViet,
  _ => skillKind.toUpperCase(),
};

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

/// Sequential sprint mock exam. Speaking sections are recorded first and then
/// analysed together; objective/text sections score inside their own screens.
class MockExamScreen extends StatefulWidget {
  const MockExamScreen({
    super.key,
    required this.client,
    this.initialSession,
    this.mockTest,
  });

  final ApiClient client;

  /// Pre-created session from the intro screen. If null, a new session is created.
  final MockExamSessionView? initialSession;

  /// Template selected by the learner. Used for title/copy while a session is in progress.
  final MockTest? mockTest;

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Use pre-created session from intro screen if available
    final initial = widget.initialSession;
    if (initial != null) {
      setState(() {
        _session = initial;
        _loading = false;
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
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<void> _advanceSection(String attemptId) async {
    try {
      final payload = await widget.client.advanceMockExam(
        _session!.id,
        attemptId: attemptId,
      );
      if (!mounted) return;
      setState(() {
        _session = MockExamSessionView.fromJson(payload);
        _error = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  Future<void> _runSection(MockExamSection section) async {
    final navigator = Navigator.of(context);
    try {
      final detail = ExerciseDetail.fromJson(
        await widget.client.getExercise(section.exerciseId),
      );
      if (!mounted) return;

      final kind = _sectionSkillKind(section);

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

        final payload = await widget.client.advanceMockExam(
          _session!.id,
          attemptId: rec.attemptId,
        );
        if (!mounted) return;
        setState(() {
          _session = MockExamSessionView.fromJson(payload);
          _pendingAnalyses.add(rec);
          _error = null;
        });
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
                    await _advanceSection(id);
                  },
                );
              } else if (kind == 'doc') {
                return ReadingExerciseScreen(
                  client: widget.client,
                  detail: detail,
                  showResultOnCompletion: false,
                  onAttemptCompleted: (id) async {
                    await _advanceSection(id);
                  },
                );
              } else {
                return WritingExerciseScreen(
                  client: widget.client,
                  detail: detail,
                  showResultOnCompletion: false,
                  onAttemptCompleted: (id) async {
                    await _advanceSection(id);
                  },
                );
              }
            },
          ),
        );
        if (!mounted) return;
        // If user backed out without completing, _session remains unchanged (nextPending != null).
      }

      if (_session!.nextPending == null) {
        await _bulkAnalyze();
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mockTitle = widget.mockTest?.title.trim() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(mockTitle.isNotEmpty ? mockTitle : l.mockExamTitle),
      ),
      body: SafeArea(child: _buildBody(l)),
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
      (s) => _sectionSkillKind(s) == 'noi',
    );
    if (session.isCompleted) {
      return _MockExamResultView(
        client: widget.client,
        session: session,
        sectionReadiness: _sectionReadiness,
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
          _SectionTile(section: section, onStart: () => _runSection(section)),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (err != null) ...[
          const SizedBox(height: AppSpacing.x3),
          Text(err, style: AppTypography.bodySmall.copyWith(color: Colors.red)),
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
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              ...List.generate(_pendingAnalyses.length, (i) {
                // _analyzeProgress = k means section k-1 is currently processing.
                // Sections 0..k-2 are done; section k-1 is active; k..end are pending.
                final done = _analyzeProgress > 1 && i < _analyzeProgress - 1;
                final active = _analyzeProgress > 0 && i == _analyzeProgress - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: done
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
                          color: done
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

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.onStart});

  final MockExamSection section;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final skill = _skillLabel(l, _sectionSkillKind(section));
    final exercise = _exerciseTypeLabel(l, section.exerciseType);
    final tone =
        section.isCompleted
            ? PillTone.info
            : (section.isPending ? PillTone.primary : PillTone.neutral);
    final label =
        section.isCompleted
            ? l.mockExamStatusRecorded
            : l.mockExamStatusPending;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoPill(label: label, tone: tone),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  l.mockExamSectionLabel(section.sequenceNo),
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  section.maxPoints > 0
                      ? l.mockExamSectionMeta(
                        skill,
                        exercise,
                        section.maxPoints,
                      )
                      : '$skill · $exercise',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          FilledButton(
            onPressed: section.isPending ? onStart : null,
            child: Text(
              section.isCompleted
                  ? l.mockExamActionDone
                  : l.mockExamActionStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockExamResultView extends StatelessWidget {
  const _MockExamResultView({
    required this.client,
    required this.session,
    required this.sectionReadiness,
  });

  final ApiClient client;
  final MockExamSessionView session;
  final Map<String, String> sectionReadiness;

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final totalMax = session.totalScoreMax > 0 ? session.totalScoreMax : 40;
    final hasScore = session.overallScore > 0 || session.passed;
    final passColor = session.passed ? AppColors.success : AppColors.error;
    final passContainerColor =
        session.passed ? AppColors.successContainer : AppColors.errorContainer;

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

        // ── Section breakdown ─────────────────────────────────────────────────
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
                                    skillKind: _sectionSkillKind(section),
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
              () => Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.home_outlined, size: 18),
          label: Text(l.mockExamBackHome),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: AppSpacing.x6),
      ],
    );
  }
}
