import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'interview_session_screen.dart';

/// Entry point when navigating from InterviewListScreen.
/// Loads exercise detail from API and delegates to [_InterviewIntroBody].
class InterviewIntroScreen extends StatefulWidget {
  const InterviewIntroScreen({
    super.key,
    required this.exerciseId,
    required this.client,
    required this.moduleId,
  }) : _preloadedDetail = null;

  /// Test-only constructor: pre-loaded detail skips the API call.
  // ignore: prefer_const_constructors_in_immutables
  InterviewIntroScreen.withDetail({
    super.key,
    required ExerciseDetail detail,
    required this.client,
    required this.moduleId,
  })  : _preloadedDetail = detail,
        exerciseId = detail.id;

  final String exerciseId;
  final ApiClient client;
  final String moduleId;
  final ExerciseDetail? _preloadedDetail;

  @override
  State<InterviewIntroScreen> createState() => _InterviewIntroScreenState();
}

class _InterviewIntroScreenState extends State<InterviewIntroScreen> {
  ExerciseDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget._preloadedDetail != null) {
      _detail = widget._preloadedDetail;
      _loading = false;
    } else {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.getExercise(widget.exerciseId);
      if (!mounted) return;
      setState(() {
        _detail = ExerciseDetail.fromJson(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unnecessary_non_null_assertion
    final l = AppLocalizations.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              FilledButton(onPressed: _loadDetail, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    return _InterviewIntroBody(
      detail: _detail!,
      client: widget.client,
      l: l,
    );
  }
}

/// Stateful body that handles option selection and navigation.
class _InterviewIntroBody extends StatefulWidget {
  const _InterviewIntroBody({
    required this.detail,
    required this.client,
    required this.l,
  });

  final ExerciseDetail detail;
  final ApiClient client;
  final AppLocalizations l;

  @override
  State<_InterviewIntroBody> createState() => _InterviewIntroBodyState();
}

class _InterviewIntroBodyState extends State<_InterviewIntroBody> {
  String? _selectedOptionLabel;
  bool _starting = false;

  ExerciseDetail get detail => widget.detail;

  Future<void> _startSession() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final attemptRaw = await widget.client.createAttempt(detail.id);
      final attemptId = attemptRaw['id'] as String;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InterviewSessionScreen(
            client: widget.client,
            exerciseId: detail.id,
            attemptId: attemptId,
            detail: detail,
            selectedOption: _selectedOptionLabel,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final isChoice = detail.isInterviewChoiceExplain;
    final canStart = !isChoice || _selectedOptionLabel != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      // Start button is sticky — never scrolls out of view.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePaddingH(context), AppSpacing.x2,
            AppSpacing.pagePaddingH(context), AppSpacing.x3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isChoice && _selectedOptionLabel != null)
                Row(
                  children: [
                    Text('${l.interviewSelectedLabel} ', style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                    Text(_selectedOptionLabel!, style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selectedOptionLabel = null),
                      child: Text('Chọn lại', style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  ],
                ),
              FilledButton(
                onPressed: canStart && !_starting ? _startSession : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _starting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        isChoice ? l.interviewStartWithChoice : l.interviewStartBtn,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.onSecondary,
            pinned: false,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroSection(detail: detail, l: l),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingH(context), AppSpacing.x4,
                AppSpacing.pagePaddingH(context), AppSpacing.x8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isChoice)
                    _ChoiceOptionGrid(
                      options: detail.interviewOptions,
                      selected: _selectedOptionLabel,
                      onSelect: (label) => setState(() => _selectedOptionLabel = label),
                      l: l,
                    )
                  else ...[
                    if (detail.interviewTips.isNotEmpty) ...[
                      _TipsCard(tips: detail.interviewTips, l: l),
                      const SizedBox(height: AppSpacing.x3),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.detail, required this.l});
  final ExerciseDetail detail;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isChoice = detail.isInterviewChoiceExplain;
    return Container(
      color: AppColors.secondary,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isChoice ? l.interviewChoiceLabel : l.interviewTopicLabel,
            style: AppTypography.labelSmall.copyWith(color: AppColors.onSecondary.withAlpha(160), letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            isChoice ? (detail.interviewQuestion.isNotEmpty ? detail.interviewQuestion : detail.title) : detail.title,
            style: AppTypography.titleLarge.copyWith(color: AppColors.onSecondary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.tips, required this.l});
  final List<String> tips;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.interviewTipsTitle, style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x2),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                Expanded(child: Text(tip, style: AppTypography.bodySmall)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

/// 2×2 grid of selectable options for interview_choice_explain.
class _ChoiceOptionGrid extends StatelessWidget {
  const _ChoiceOptionGrid({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.l,
  });

  final List<InterviewOptionView> options;
  final String? selected;
  final void Function(String label) onSelect;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.interviewChoiceInstruction, style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.x3),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.x2,
          mainAxisSpacing: AppSpacing.x2,
          childAspectRatio: 1.2,
          children: options.map((opt) {
            final isSelected = selected == opt.label;
            return GestureDetector(
              onTap: () => onSelect(opt.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      opt.label,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        // Selected label + reset row is now in bottomNavigationBar for
        // test reliability (always visible, never scrolls off-screen).
      ],
    );
  }
}
