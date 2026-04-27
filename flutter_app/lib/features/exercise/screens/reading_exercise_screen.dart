import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';
import '../widgets/fill_in_widget.dart';
import '../widgets/multiple_choice_widget.dart';
import '../widgets/objective_result_card.dart';

/// Screen for all cteni_* (reading) exercise types.
///
/// Flow: show reading text/items → learner answers → submit (sync) → result.
class ReadingExerciseScreen extends StatefulWidget {
  const ReadingExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
    this.onAttemptCompleted,
  });

  final ApiClient client;
  final ExerciseDetail detail;
  final void Function(String attemptId)? onAttemptCompleted;

  @override
  State<ReadingExerciseScreen> createState() => _ReadingExerciseScreenState();
}

class _ReadingExerciseScreenState extends State<ReadingExerciseScreen> {
  final Map<String, String> _answers = {};
  bool _submitting = false;
  String? _error;
  AttemptResult? _result;

  bool get _hasAllAnswers {
    final d = widget.detail;
    if (d.isCteni5) {
      return d.cteniQuestions.every((q) => _answers[q.questionNo.toString()]?.isNotEmpty == true);
    }
    final count = d.cteniQuestions.isNotEmpty
        ? d.cteniQuestions.length
        : (d.cteniItems.isNotEmpty ? d.cteniItems.length : 5);
    return List.generate(count, (i) => (i + 1).toString())
        .every((k) => _answers[k]?.isNotEmpty == true);
  }

  Future<void> _submit() async {
    if (!_hasAllAnswers || _submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final attempt = await widget.client.createAttempt(widget.detail.id, locale: 'vi');
      final attemptId = attempt['id'] as String;
      final raw = await widget.client.submitAnswers(attemptId, _answers);
      widget.onAttemptCompleted?.call(attemptId);
      if (!mounted) return;
      setState(() => _result = AttemptResult.fromJson(raw));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;

    if (_result != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0,
          title: Text('Kết quả', style: AppTypography.titleMedium)),
        body: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: ObjectiveResultCard(result: _result!, onRetry: () => Navigator.of(context).pop()),
        )),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: Text(d.exerciseType.replaceAll('_', ' ').toUpperCase(), style: AppTypography.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            if (d.learnerInstruction.isNotEmpty) ...[
              Text(d.learnerInstruction, style: AppTypography.bodyMedium),
              const SizedBox(height: AppSpacing.x4),
            ],

            // Reading text (cteni_2/4/5)
            if (d.cteniText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.x4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: SelectableText(d.cteniText, style: AppTypography.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.x4),
            ],

            // Items display (cteni_1: images/messages, cteni_3: text blocks)
            if (d.cteniItems.isNotEmpty && d.cteniText.isEmpty) ...[
              ..._buildItems(d),
              const SizedBox(height: AppSpacing.x4),
            ],

            // Answer UI
            if (d.isCteni5)
              FillInWidget(
                questions: d.cteniQuestions,
                answers: _answers,
                onChanged: (k, v) => setState(() => _answers[k] = v),
              )
            else
              ..._buildAnswerWidgets(d),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.x6),
            FilledButton(
              onPressed: (_hasAllAnswers && !_submitting) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Nộp đáp án', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItems(ExerciseDetail d) {
    return d.cteniItems.asMap().entries.map((e) {
      final item = e.value as Map<String, dynamic>? ?? {};
      final text = item['text'] as String? ?? '';
      final no = (item['item_no'] as num?)?.toInt() ?? (e.key + 1);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                child: Center(child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: AppTypography.bodySmall)),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildAnswerWidgets(ExerciseDetail d) {
    // For cteni_1 (match image → option): one selection per item
    // For cteni_2/4 (multiple choice): one per question with options
    // For cteni_3 (match text → person): one per item with person options
    final questionCount = d.cteniQuestions.isNotEmpty ? d.cteniQuestions.length
        : d.cteniItems.isNotEmpty ? d.cteniItems.length
        : 5;

    return List.generate(questionCount, (i) {
      final qno = i + 1;
      final opts = d.cteniOptions.isNotEmpty ? d.cteniOptions : _defaultABCD();
      final prompt = d.cteniQuestions.isNotEmpty && i < d.cteniQuestions.length
          ? d.cteniQuestions[i].prompt
          : null;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null && prompt.isNotEmpty) ...[
              Text('$qno. $prompt', style: AppTypography.labelMedium),
              const SizedBox(height: 4),
            ],
            MultipleChoiceWidget(
              questionNo: prompt == null ? qno : 0,
              options: opts,
              selected: _answers[qno.toString()],
              onSelect: (k) => setState(() => _answers[qno.toString()] = k),
            ),
          ],
        ),
      );
    });
  }

  List<PoslechOptionView> _defaultABCD() => const [
    PoslechOptionView(key: 'A', text: 'A'), PoslechOptionView(key: 'B', text: 'B'),
    PoslechOptionView(key: 'C', text: 'C'), PoslechOptionView(key: 'D', text: 'D'),
  ];
}
