import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

/// V21.3 one-time dialog for existing A2 learners who were backfilled via
/// migration 026. Shown exactly once: either the user confirms their level or
/// chooses to retake the placement test. The system back gesture is absorbed
/// (WillPopScope returning false) so the learner cannot dismiss without
/// making an explicit choice — ensuring CefrPrefs.isExistingPromptShown is
/// recorded only on a deliberate selection.
///
/// The dialog is shown by [CefrAuthGate] via [showDialog]; it calls
/// [onConfirm] or [onRetest] so the gate handles navigation + side effects.
class ExistingLevelConfirmDialog extends StatelessWidget {
  const ExistingLevelConfirmDialog({
    super.key,
    required this.level,
    required this.onConfirm,
    required this.onRetest,
  });

  final CefrLevel level;
  final VoidCallback onConfirm;
  final VoidCallback onRetest;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final levelLabel = cefrLevelLabel(level);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Semantics(
          header: true,
          child: Text(l.v213ExistingPromptTitle(levelLabel)),
        ),
        content: Text(l.v213ExistingPromptBody(levelLabel)),
        actions: [
          TextButton(
            key: const Key('existing_prompt_retest'),
            onPressed: onRetest,
            child: Text(l.v213ExistingPromptRetestCta),
          ),
          FilledButton(
            key: const Key('existing_prompt_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: onConfirm,
            child: Text(
              l.v213ExistingPromptConfirmCta(levelLabel),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.x3,
          0,
          AppSpacing.x3,
          AppSpacing.x3,
        ),
      ),
    );
  }
}
