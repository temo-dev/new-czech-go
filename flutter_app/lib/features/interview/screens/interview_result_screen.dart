import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

class InterviewResultScreen extends StatefulWidget {
  const InterviewResultScreen({
    super.key,
    required this.client,
    required this.attemptId,
    required this.turns,
  });

  final ApiClient client;
  final String attemptId;
  final List<InterviewTranscriptTurn> turns;

  @override
  State<InterviewResultScreen> createState() => _InterviewResultScreenState();
}

class _InterviewResultScreenState extends State<InterviewResultScreen> {
  AttemptResult? _result;
  bool _loading = true;
  String? _error;
  Timer? _poller;
  int _pollCount = 0;
  static const _maxPolls = 60; // 2 min @ 2s

  @override
  void initState() {
    super.initState();
    _poll();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _poll() {
    _poller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_pollCount++ > _maxPolls) {
        _poller?.cancel();
        if (mounted) setState(() { _loading = false; _error = 'Timeout'; });
        return;
      }
      try {
        final raw = await widget.client.getAttempt(widget.attemptId);
        final attempt = AttemptResult.fromJson(raw);
        if (attempt.status == 'completed' || attempt.status == 'failed') {
          _poller?.cancel();
          if (mounted) setState(() { _result = attempt; _loading = false; });
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading) return _LoadingView(l: l);
    if (_error != null || _result == null) {
      return _FallbackView(turns: widget.turns, l: l);
    }
    return _ResultView(result: _result!, turns: widget.turns, l: l);
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.l});
  final AppLocalizations? l;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.x3),
            Text(l?.interviewAnalyzing ?? 'Đang chấm điểm...', style: AppTypography.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _FallbackView extends StatelessWidget {
  const _FallbackView({required this.turns, required this.l});
  final List<InterviewTranscriptTurn> turns;
  final AppLocalizations? l;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        title: Text(l?.interviewResultTitle ?? 'Kết quả', style: AppTypography.titleMedium.copyWith(color: AppColors.onSecondary)),
      ),
      body: _TranscriptTab(turns: turns, l: l),
    );
  }
}

class _ResultView extends StatefulWidget {
  const _ResultView({required this.result, required this.turns, required this.l});
  final AttemptResult result;
  final List<InterviewTranscriptTurn> turns;
  final AppLocalizations? l;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final feedback = widget.result.feedback;
    final readiness = feedback?.readinessLevel ?? 'ok';
    final score = _readinessToScore(readiness);
    final l = widget.l;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        title: Text(l?.interviewResultTitle ?? 'Kết quả', style: AppTypography.titleMedium.copyWith(color: AppColors.onSecondary)),
      ),
      body: Column(
        children: [
          // Hero
          Container(
            color: AppColors.secondary,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2.5),
                    color: Colors.white12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                      const Text('/100', style: TextStyle(fontSize: 9, color: Colors.white54)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.result.exerciseType, style: AppTypography.bodySmall.copyWith(color: Colors.white54)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x26FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(_readinessLabel(readiness), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: AppColors.surfaceContainerLowest,
            child: Row(
              children: [
                _TabItem(label: l?.interviewTabFeedback ?? 'Nhận xét', active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                _TabItem(label: l?.interviewTabTranscript ?? 'Hội thoại', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
              ],
            ),
          ),

          // Tab body
          Expanded(
            child: _tab == 0
                ? _FeedbackTab(feedback: feedback, l: l)
                : _TranscriptTab(turns: widget.turns, l: l),
          ),
        ],
      ),
    );
  }

  static int _readinessToScore(String r) {
    return switch (r) { 'strong' => 85, 'ok' => 65, _ => 40 };
  }

  static String _readinessLabel(String r) {
    return switch (r) { 'strong' => 'Tốt · Sẵn sàng thi', 'ok' => 'Khá · Cần luyện thêm', _ => 'Yếu · Cần cố gắng hơn' };
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelMedium.copyWith(
              color: active ? AppColors.secondary : AppColors.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab({required this.feedback, required this.l});
  final AttemptFeedbackView? feedback;
  final AppLocalizations? l;

  @override
  Widget build(BuildContext context) {
    if (feedback == null) return const Center(child: Text('Không có phản hồi.'));
    final h = AppSpacing.pagePaddingH(context);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x3),
      children: [
        if (feedback!.overallSummary.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Text(feedback!.overallSummary, style: AppTypography.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (feedback!.strengths.isNotEmpty) ...[
          _FeedbackSection(title: 'Điểm mạnh', items: feedback!.strengths, color: AppColors.secondary),
          const SizedBox(height: AppSpacing.x2),
        ],
        if (feedback!.improvements.isNotEmpty)
          _FeedbackSection(title: 'Cần cải thiện', items: feedback!.improvements, color: AppColors.tertiary),
      ],
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({required this.title, required this.items, required this.color});
  final String title;
  final List<String> items;
  final Color color;

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
          Text(title, style: AppTypography.labelMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x2),
          ...items.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                Expanded(child: Text(s, style: AppTypography.bodySmall)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _TranscriptTab extends StatelessWidget {
  const _TranscriptTab({required this.turns, required this.l});
  final List<InterviewTranscriptTurn> turns;
  final AppLocalizations? l;

  @override
  Widget build(BuildContext context) {
    final h = AppSpacing.pagePaddingH(context);
    if (turns.isEmpty) {
      return Center(child: Text(l?.emptyExerciseList ?? 'Không có hội thoại.'));
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x3),
      itemCount: turns.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x2),
      itemBuilder: (_, i) {
        final turn = turns[i];
        final isExaminer = turn.speaker == 'examiner';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isExaminer ? (l?.interviewExaminer ?? 'Examiner') : (l?.interviewYou ?? 'Bạn'),
              style: AppTypography.labelSmall.copyWith(
                color: isExaminer ? AppColors.secondary : AppColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isExaminer ? AppColors.surfaceContainerLowest : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(turn.text, style: AppTypography.bodySmall),
            ),
          ],
        );
      },
    );
  }
}
