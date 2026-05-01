import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../widgets/ano_ne_widget.dart';
import '../widgets/exercise_context_image.dart';
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
    this.showResultOnCompletion = true,
  });

  final ApiClient client;
  final ExerciseDetail detail;
  final FutureOr<void> Function(String attemptId)? onAttemptCompleted;
  final bool showResultOnCompletion;

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
    if (d.isCteni6) {
      return d.anoNeStatements.every(
        (s) => _answers[s.questionNo.toString()]?.isNotEmpty == true,
      );
    }
    if (d.isCteni5) {
      return d.cteniQuestions.every(
        (q) => _answers[q.questionNo.toString()]?.isNotEmpty == true,
      );
    }
    final count =
        d.cteniQuestions.isNotEmpty
            ? d.cteniQuestions.length
            : (d.cteniItems.isNotEmpty ? d.cteniItems.length : 5);
    return List.generate(
      count,
      (i) => (i + 1).toString(),
    ).every((k) => _answers[k]?.isNotEmpty == true);
  }

  Future<void> _submit() async {
    if (!_hasAllAnswers || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final attempt = await widget.client.createAttempt(
        widget.detail.id,
        locale: 'vi',
      );
      final attemptId = attempt['id'] as String;
      final raw = await widget.client.submitAnswers(attemptId, _answers);
      await widget.onAttemptCompleted?.call(attemptId);
      if (!mounted) return;
      if (!widget.showResultOnCompletion) {
        Navigator.of(context).pop();
        return;
      }
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
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Text(
            AppLocalizations.of(context).resultScreenTitle,
            style: AppTypography.titleMedium,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: ObjectiveResultCard(
              result: _result!,
              onRetry: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          d.exerciseType.replaceAll('_', ' ').toUpperCase(),
          style: AppTypography.titleMedium,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            ExerciseContextImage(detail: d, client: widget.client),

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
                child: SelectableText(
                  d.cteniText,
                  style: AppTypography.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
            ],

            // cteni_6: passage + AnoNe widget
            if (d.isCteni6) ...[
              ..._buildCteni6Layout(d),
            ]
            // cteni_1: combined item+answer layout (image/text per item + A-H select)
            else if (d.exerciseType == 'cteni_1') ...[
              ..._buildCteni1Layout(d),
            ]
            else ...[
              // Items display (cteni_3: text blocks)
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
            ],

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.x6),
            FilledButton(
              onPressed: (_hasAllAnswers && !_submitting) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  _submitting
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        AppLocalizations.of(context).submitAnswersCta,
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// cteni_6 layout: passage card + AnoNeWidget.
  List<Widget> _buildCteni6Layout(ExerciseDetail d) {
    return [
      if (d.anoNePassage.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: SelectableText(
            d.anoNePassage,
            style: AppTypography.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
      ],
      AnoNeWidget(
        statements: d.anoNeStatements,
        onAnswersChanged: (a) => setState(() {
          _answers
            ..clear()
            ..addAll(a);
        }),
        result: _result?.feedback?.objectiveResult,
        enabled: _result == null,
      ),
    ];
  }

  /// cteni_1 combined layout: each item shows its content (image or text) with
  /// an inline A-H selection directly below. Items are rendered top-to-bottom.
  List<Widget> _buildCteni1Layout(ExerciseDetail d) {
    final opts = d.cteniOptions.isNotEmpty ? d.cteniOptions : <PoslechOptionView>[];
    final items = d.cteniItems;
    if (items.isEmpty) return [];

    final widgets = <Widget>[];

    // A-H legend: show all option texts so learner knows what each letter means
    if (opts.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.x4),
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: opts.map((opt) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(opt.key,
                          style: AppTypography.labelMedium.copyWith(
                              color: AppColors.secondary, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(opt.text, style: AppTypography.bodyMedium),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      );
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>? ?? {};
      final assetId = item['asset_id'] as String? ?? '';
      final text = item['text'] as String? ?? '';
      final no = (item['item_no'] as num?)?.toInt() ?? (i + 1);
      final currentAnswer = _answers[no.toString()];

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: currentAnswer != null ? AppColors.primary : AppColors.outlineVariant,
                width: currentAnswer != null ? 2 : 1,
              ),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Item header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: currentAnswer != null ? AppColors.primary : AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (currentAnswer != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currentAnswer,
                            style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Item content: image or text
                if (assetId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.zero),
                    child: Image.network(
                      widget.client.exerciseAssetUri(d.id, assetId).toString(),
                      headers: widget.client.authHeaders,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        color: const Color(0xFFF5F0EA),
                        child: Center(child: Text('$no', style: AppTypography.titleLarge.copyWith(color: AppColors.onSurfaceVariant))),
                      ),
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(height: 160, color: const Color(0xFFF5F0EA)),
                    ),
                  ),
                ] else if (text.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(text, style: AppTypography.bodyMedium.copyWith(fontStyle: FontStyle.italic)),
                    ),
                  ),
                ] else ...[
                  // No content yet
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],

                // A-H option chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: opts.map((opt) {
                      final selected = currentAnswer == opt.key;
                      return GestureDetector(
                        onTap: () => setState(() => _answers[no.toString()] = opt.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            opt.key,
                            style: AppTypography.labelLarge.copyWith(
                              color: selected ? Colors.white : AppColors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$no',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
    final questionCount =
        d.cteniQuestions.isNotEmpty
            ? d.cteniQuestions.length
            : d.cteniItems.isNotEmpty
            ? d.cteniItems.length
            : 5;

    return List.generate(questionCount, (i) {
      final qno = i + 1;
      final opts = d.cteniOptions.isNotEmpty ? d.cteniOptions : _defaultABCD();
      final prompt =
          d.cteniQuestions.isNotEmpty && i < d.cteniQuestions.length
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
              mediaUri: widget.client.mediaUri,
              authHeaders: widget.client.authHeaders,
            ),
          ],
        ),
      );
    });
  }

  List<PoslechOptionView> _defaultABCD() => const [
    PoslechOptionView(key: 'A', text: 'A'),
    PoslechOptionView(key: 'B', text: 'B'),
    PoslechOptionView(key: 'C', text: 'C'),
    PoslechOptionView(key: 'D', text: 'D'),
  ];
}
