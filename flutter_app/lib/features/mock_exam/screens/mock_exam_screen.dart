import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';
import '../../exercise/screens/exercise_screen.dart' as exercise_feature;

/// Sequential mock oral exam: one exercise per Uloha type, aggregate result.
class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key, required this.client});

  final ApiClient client;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  MockExamSessionView? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await widget.client.createMockExam();
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

  Future<void> _runSection(MockExamSection section) async {
    final navigator = Navigator.of(context);
    try {
      final beforeAttemptIds = await _knownAttemptIds(section.exerciseId);
      final detail = ExerciseDetail.fromJson(
        await widget.client.getExercise(section.exerciseId),
      );
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => exercise_feature.ExerciseScreen(
            client: widget.client,
            detail: detail,
          ),
        ),
      );
      if (!mounted) return;

      final newAttemptId = await _findNewAttempt(
        section.exerciseId,
        beforeAttemptIds,
      );
      if (newAttemptId == null) {
        setState(() => _error = 'No attempt submitted for this section.');
        return;
      }

      final payload = await widget.client.advanceMockExam(
        _session!.id,
        attemptId: newAttemptId,
      );
      if (!mounted) return;
      setState(() => _session = MockExamSessionView.fromJson(payload));

      if (_session!.nextPending == null) {
        await _finalize();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  Future<Set<String>> _knownAttemptIds(String exerciseId) async {
    final payload = await widget.client.getAttempts();
    return payload
        .map((item) => AttemptResult.fromJson(item as Map<String, dynamic>))
        .where((a) => a.exerciseId == exerciseId)
        .map((a) => a.id)
        .toSet();
  }

  Future<String?> _findNewAttempt(
    String exerciseId,
    Set<String> before,
  ) async {
    final payload = await widget.client.getAttempts();
    final attempts = payload
        .map((item) => AttemptResult.fromJson(item as Map<String, dynamic>))
        .where((a) => a.exerciseId == exerciseId && !before.contains(a.id))
        .toList();
    if (attempts.isEmpty) return null;
    return attempts.first.id;
  }

  Future<void> _finalize() async {
    try {
      final payload = await widget.client.completeMockExam(_session!.id);
      if (!mounted) return;
      setState(() => _session = MockExamSessionView.fromJson(payload));
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.mockExamTitle)),
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
    final session = _session!;
    if (session.isCompleted) {
      return _MockExamResultView(session: session);
    }
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        Text(l.mockExamIntroTitle, style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.x2),
        Text(
          l.mockExamIntroBody,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.x5),
        for (final section in session.sections) ...[
          _SectionTile(
            section: section,
            onStart: () => _runSection(section),
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (err != null) ...[
          const SizedBox(height: AppSpacing.x3),
          Text(err, style: AppTypography.bodySmall.copyWith(color: Colors.red)),
        ],
      ],
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
    final tone = section.isCompleted
        ? PillTone.info
        : (section.isPending ? PillTone.primary : PillTone.neutral);
    final label = section.isCompleted
        ? l.mockExamStatusDone
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
                  section.exerciseType.toUpperCase(),
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
  const _MockExamResultView({required this.session});

  final MockExamSessionView session;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: [
        Text(l.mockExamResultTitle, style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.x3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.x5),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: AppRadius.lgAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoPill(
                label: session.overallReadinessLevel.toUpperCase(),
                tone: PillTone.primary,
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                l.mockExamOverallTitle,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                session.overallSummary,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        for (final section in session.sections)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.x4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.mdAll,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.mockExamSectionLabel(section.sequenceNo),
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          section.exerciseType.toUpperCase(),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InfoPill(
                    label: l.mockExamStatusDone,
                    tone: PillTone.info,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.x3),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.mockExamBackHome),
        ),
      ],
    );
  }
}
