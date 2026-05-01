import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';

/// Renders a list of Ano/Ne (true/false) statement rows for cteni_6 and poslech_6.
///
/// Before submit ([result] is null): each row shows ANO and NE buttons.
/// After submit ([result] is non-null): buttons are disabled; rows show
/// green (correct) or red (wrong) background with an inline hint.
class AnoNeWidget extends StatefulWidget {
  const AnoNeWidget({
    super.key,
    required this.statements,
    required this.onAnswersChanged,
    this.result,
    this.enabled = true,
  });

  final List<AnoNeStatementView> statements;
  final void Function(Map<String, String> answers) onAnswersChanged;
  final ObjectiveResult? result; // null before submit
  final bool enabled;

  @override
  State<AnoNeWidget> createState() => _AnoNeWidgetState();
}

class _AnoNeWidgetState extends State<AnoNeWidget> {
  // qno → "ANO" | "NE"
  final Map<String, String> _selected = {};

  void _select(int questionNo, String value) {
    if (!widget.enabled) return;
    setState(() => _selected[questionNo.toString()] = value);
    widget.onAnswersChanged(Map.unmodifiable(_selected));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stmt in widget.statements)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: _AnoNeRow(
              statement: stmt,
              selected: _selected[stmt.questionNo.toString()],
              result: widget.result,
              onSelect: (v) => _select(stmt.questionNo, v),
              enabled: widget.enabled,
            ),
          ),
      ],
    );
  }
}

class _AnoNeRow extends StatelessWidget {
  const _AnoNeRow({
    required this.statement,
    required this.selected,
    required this.result,
    required this.onSelect,
    required this.enabled,
  });

  final AnoNeStatementView statement;
  final String? selected;
  final ObjectiveResult? result;
  final void Function(String) onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    QuestionResult? questionResult;
    if (result != null) {
      for (final q in result!.breakdown) {
        if (q.questionNo == statement.questionNo) {
          questionResult = q;
          break;
        }
      }
    }

    final isCorrect = questionResult?.isCorrect;
    final correctAnswer = questionResult?.correctAnswer.toUpperCase();

    final rowBg = isCorrect == null
        ? AppColors.surface
        : isCorrect
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.error.withValues(alpha: 0.08);
    final rowBorder = isCorrect == null
        ? AppColors.outlineVariant
        : isCorrect
            ? AppColors.success.withValues(alpha: 0.35)
            : AppColors.error.withValues(alpha: 0.35);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: rowBorder, width: 1.5),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statement text
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_indexLabel(statement.questionNo)}) ',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Text(
                  statement.statement,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),

          // ANO / NE buttons
          Row(
            children: [
              _AnoNeButton(
                label: l.anoButton,
                answer: 'ANO',
                selected: selected,
                questionResult: questionResult,
                onTap: enabled ? () => onSelect('ANO') : null,
              ),
              const SizedBox(width: AppSpacing.x2),
              _AnoNeButton(
                label: l.neButton,
                answer: 'NE',
                selected: selected,
                questionResult: questionResult,
                onTap: enabled ? () => onSelect('NE') : null,
              ),
            ],
          ),

          // Post-submit hint
          if (questionResult != null && !questionResult.isCorrect && correctAnswer != null) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              l.anoNeWrongHint(correctAnswer),
              style: AppTypography.labelSmall.copyWith(color: AppColors.error),
            ),
          ] else if (questionResult != null && questionResult.isCorrect) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              l.anoNeCorrectHint,
              style: AppTypography.labelSmall.copyWith(color: AppColors.success),
            ),
          ],
        ],
      ),
    );
  }

  static String _indexLabel(int n) {
    const labels = ['A', 'B', 'C', 'D', 'E'];
    final i = n - 1;
    return (i >= 0 && i < labels.length) ? labels[i] : n.toString();
  }
}

class _AnoNeButton extends StatelessWidget {
  const _AnoNeButton({
    required this.label,
    required this.answer,
    required this.selected,
    required this.questionResult,
    required this.onTap,
  });

  final String label;
  final String answer; // "ANO" or "NE"
  final String? selected;
  final QuestionResult? questionResult;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected?.toUpperCase() == answer;
    final isCorrectAnswer = questionResult?.correctAnswer.toUpperCase() == answer;
    final isUserWrong = questionResult != null &&
        !questionResult!.isCorrect &&
        selected?.toUpperCase() == answer;

    Color bg;
    Color border;
    Color textColor;

    if (questionResult != null) {
      // Post-submit state
      if (isCorrectAnswer) {
        bg = answer == 'ANO' ? AppColors.success : AppColors.error;
        border = bg;
        textColor = Colors.white;
      } else if (isUserWrong) {
        bg = (answer == 'ANO' ? AppColors.success : AppColors.error).withValues(alpha: 0.12);
        border = answer == 'ANO' ? AppColors.success : AppColors.error;
        textColor = answer == 'ANO' ? AppColors.success : AppColors.error;
      } else {
        bg = AppColors.surface;
        border = AppColors.outlineVariant;
        textColor = AppColors.onSurfaceVariant.withValues(alpha: 0.4);
      }
    } else {
      // Pre-submit state
      if (isSelected) {
        bg = answer == 'ANO' ? AppColors.success : AppColors.error;
        border = bg;
        textColor = Colors.white;
      } else {
        bg = AppColors.surface;
        border = AppColors.outlineVariant;
        textColor = AppColors.onSurfaceVariant;
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: border, width: 1.5),
            boxShadow: isSelected && questionResult == null
                ? [BoxShadow(color: bg.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
