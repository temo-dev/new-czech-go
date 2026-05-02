import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'interview_intro_screen.dart';

class InterviewListScreen extends StatefulWidget {
  const InterviewListScreen({
    super.key,
    required this.client,
    required this.moduleId,
  });

  final ApiClient client;
  final String moduleId;

  @override
  State<InterviewListScreen> createState() => _InterviewListScreenState();
}

class _InterviewListScreenState extends State<InterviewListScreen> {
  List<ExerciseSummary> _exercises = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.listModuleExercises(
        widget.moduleId,
        skillKind: 'interview',
      );
      if (!mounted) return;
      setState(() {
        _exercises = raw
            .map((e) => ExerciseSummary.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        title: Text(l.interviewSkillLabel, style: AppTypography.titleMedium.copyWith(color: AppColors.onSecondary)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _exercises.isEmpty
                  ? _EmptyView(l: l)
                  : _ExerciseList(
                      exercises: _exercises,
                      client: widget.client,
                      moduleId: widget.moduleId,
                      h: h,
                      l: l,
                    ),
    );
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({
    required this.exercises,
    required this.client,
    required this.moduleId,
    required this.h,
    required this.l,
  });

  final List<ExerciseSummary> exercises;
  final ApiClient client;
  final String moduleId;
  final double h;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // Group by exerciseType
    final conv = exercises.where((e) => e.exerciseType == 'interview_conversation').toList();
    final choice = exercises.where((e) => e.exerciseType == 'interview_choice_explain').toList();

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x3),
      children: [
        if (conv.isNotEmpty) ...[
          _GroupHeader(label: 'Hội thoại theo chủ đề'),
          ...conv.map((e) => _ExerciseItem(exercise: e, client: client, moduleId: moduleId, l: l)),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (choice.isNotEmpty) ...[
          _GroupHeader(label: 'Chọn phương án + giải thích'),
          ...choice.map((e) => _ExerciseItem(exercise: e, client: client, moduleId: moduleId, l: l)),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ExerciseItem extends StatelessWidget {
  const _ExerciseItem({
    required this.exercise,
    required this.client,
    required this.moduleId,
    required this.l,
  });

  final ExerciseSummary exercise;
  final ApiClient client;
  final String moduleId;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isConv = exercise.exerciseType == 'interview_conversation';
    final typeLabel = isConv ? 'Hội thoại' : 'Chọn & giải thích';
    final icon = isConv ? Icons.chat_bubble_outline : Icons.check_circle_outline;
    final iconBg = isConv ? AppColors.primaryContainer : AppColors.secondaryContainer;
    final iconColor = isConv ? AppColors.onPrimaryContainer : AppColors.onSecondaryContainer;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InterviewIntroScreen(
              exerciseId: exercise.id,
              client: client,
              moduleId: moduleId,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconBg.withAlpha(180),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(typeLabel, style: AppTypography.labelSmall.copyWith(color: iconColor, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error),
          const SizedBox(height: AppSpacing.x3),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(l.emptyExerciseList, style: AppTypography.bodyMedium));
  }
}
