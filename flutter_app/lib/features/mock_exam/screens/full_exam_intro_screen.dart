import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../exercise/screens/listening_exercise_screen.dart';
import '../../exercise/screens/reading_exercise_screen.dart';
import '../../exercise/screens/writing_exercise_screen.dart';
import 'full_exam_result_screen.dart';

/// Intro + orchestration screen for písemná (reading+writing+listening) mock tests.
///
/// Flow:
///   1. Show exam structure (sections, max points, pass threshold).
///   2. Learner completes each section individually → attempt_id recorded.
///   3. When all sections done: submit → FullExamResultScreen.
class FullExamIntroScreen extends StatefulWidget {
  const FullExamIntroScreen({super.key, required this.client, required this.test});

  final ApiClient client;
  final MockTest test;

  @override
  State<FullExamIntroScreen> createState() => _FullExamIntroScreenState();
}

class _FullExamIntroScreenState extends State<FullExamIntroScreen> {
  final Map<int, String> _attemptIds = {}; // sequenceNo → attemptId
  bool _submitting = false;
  String? _error;

  bool get _allDone => widget.test.sections.every(
      (s) => _attemptIds.containsKey(s.sequenceNo));

  Future<void> _openSection(MockTestSection section) async {
    final rawExercise = await widget.client.getExercise(section.exerciseId);
    if (!mounted) return;
    final detail = ExerciseDetail.fromJson(rawExercise);
    if (!mounted) return;

    String? attemptId;
    void onComplete(String id) { attemptId = id; }

    if (detail.isCteni) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReadingExerciseScreen(
          client: widget.client,
          detail: detail,
          onAttemptCompleted: onComplete,
        ),
      ));
    } else if (detail.isPsani1 || detail.isPsani2) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WritingExerciseScreen(
          client: widget.client,
          detail: detail,
          onAttemptCompleted: onComplete,
        ),
      ));
    } else if (detail.isPoslech) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ListeningExerciseScreen(
          client: widget.client,
          detail: detail,
          onAttemptCompleted: onComplete,
        ),
      ));
    }
    if (mounted) {
      setState(() => _attemptIds[section.sequenceNo] = attemptId ?? 'done-${section.sequenceNo}');
    }
  }

  Future<void> _submit() async {
    if (!_allDone || _submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      // Real attempt IDs from exercise screens; fallback placeholder starts with 'done-'.
      final attemptIds = widget.test.sections
          .map((s) => _attemptIds[s.sequenceNo] ?? '')
          .where((id) => id.isNotEmpty && !id.startsWith('done-'))
          .toList();
      // Note: if some sections used placeholder IDs (e.g. no scoring backend), they
      // are excluded from the list and their score defaults to 0.
      final maxPts = widget.test.sections.map((s) => s.maxPoints).toList();
      final raw = await widget.client.createFullExam(
        mockTestId: widget.test.id,
        pisemnaAttemptIds: attemptIds,
        sectionMaxPoints: maxPts,
      );
      if (!mounted) return;
      final session = FullExamSessionView.fromJson(raw);
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => FullExamResultScreen(session: session, test: widget.test),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    final maxPts = test.isPisemna ? 70 : 40;
    final passThreshold = test.isPisemna ? 42 : 24;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text(AppLocalizations.of(context).fullExamScreenTitle, style: AppTypography.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            // Header
            Text(test.title, style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.x2),
            if (test.description.isNotEmpty)
              Text(test.description, style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.x4),

            // Stats
            Row(children: [
              _StatChip(label: AppLocalizations.of(context).fullExamDurationLabel, value: AppLocalizations.of(context).fullExamMinDuration(test.estimatedDurationMinutes)),
              const SizedBox(width: AppSpacing.x3),
              _StatChip(label: AppLocalizations.of(context).fullExamMaxPtsLabel, value: AppLocalizations.of(context).fullExamPts(maxPts)),
              const SizedBox(width: AppSpacing.x3),
              _StatChip(label: AppLocalizations.of(context).fullExamPassLabel, value: AppLocalizations.of(context).fullExamPassSymbol(passThreshold)),
            ]),
            const SizedBox(height: AppSpacing.x6),

            // Sections
            Text(AppLocalizations.of(context).fullExamSectionsTitle, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.x3),
            ...test.sections.map((sec) {
              final done = _attemptIds.containsKey(sec.sequenceNo);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
                  tileColor: done ? AppColors.successContainer : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: done ? AppColors.success : AppColors.outlineVariant),
                  ),
                  leading: Icon(
                    done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: done ? AppColors.success : AppColors.outline,
                  ),
                  title: Text(sec.exerciseType.replaceAll('_', ' ').toUpperCase(), style: AppTypography.labelMedium),
                  trailing: Text('${sec.maxPoints}đ', style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
                  onTap: () => _openSection(sec),
                ),
              );
            }),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x3),
              Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            ],

            const SizedBox(height: AppSpacing.x6),
            FilledButton(
              onPressed: (_allDone && !_submitting) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _allDone ? AppLocalizations.of(context).fullExamSubmitCta : AppLocalizations.of(context).fullExamSubmitHint,
                      style: AppTypography.labelLarge.copyWith(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.onPrimaryContainer)),
          Text(value, style: AppTypography.labelLarge.copyWith(color: AppColors.onPrimaryContainer, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
