import 'package:flutter/material.dart';

import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/storage/cefr_prefs.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';
import 'package:flutter_app/models/models.dart';
import 'existing_level_confirm_dialog.dart';

/// V21.3 onboarding gate that sits between [AuthService.authenticated] and
/// [LearnerShell]. Fetches [LevelProgressResponse] and routes the learner to
/// the right first screen:
///
/// | placementTakenAt | currentLevel | promptShown | Outcome |
/// |------------------|--------------|-------------|---------|
/// | non-null         | any          | any         | child (LearnerShell) |
/// | null             | a0           | —           | welcomeScreen (placement intro) |
/// | null             | non-a0       | true        | child (treat as onboarded) |
/// | null             | non-a0       | false       | child + existing-level dialog |
///
/// [refresh] forces a re-fetch so the gate re-evaluates after placement is
/// completed, skipped, or the existing-level prompt is confirmed.
///
/// [onExistingRetest] is called when the learner chooses to retake the
/// placement test from the existing-level dialog. Callers use this hook to
/// push [PlacementTestScreen]. When null the gate just re-evaluates (the
/// child shows because [CefrPrefs.isExistingPromptShown] is now true).
class CefrAuthGate extends StatefulWidget {
  const CefrAuthGate({
    super.key,
    required this.levelApi,
    required this.child,
    required this.welcomeScreen,
    this.onExistingRetest,
  });

  final LevelApi levelApi;
  final Widget child;
  final Widget welcomeScreen;
  final VoidCallback? onExistingRetest;

  @override
  State<CefrAuthGate> createState() => CefrAuthGateState();
}

class CefrAuthGateState extends State<CefrAuthGate> {
  Future<_GateDecision>? _decision;
  bool _dialogScheduled = false;

  @override
  void initState() {
    super.initState();
    _decision = _evaluate();
  }

  void refresh() {
    setState(() {
      _decision = _evaluate();
      _dialogScheduled = false;
    });
  }

  Future<_GateDecision> _evaluate() async {
    final prefs = await CefrPrefs.create();
    final progress = await widget.levelApi.fetchLevelProgress();
    return _GateDecision(progress: progress, prefs: prefs);
  }

  void _scheduleExistingPrompt(BuildContext ctx, _GateDecision decision) {
    if (_dialogScheduled) return;
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showExistingPrompt(ctx, decision);
    });
  }

  Future<void> _showExistingPrompt(
    BuildContext ctx,
    _GateDecision decision,
  ) async {
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder:
          (_) => ExistingLevelConfirmDialog(
            level: decision.progress.currentLevel,
            onConfirm: () => _onConfirm(ctx, decision),
            onRetest: () => _onRetest(ctx, decision),
          ),
    );
  }

  void _onConfirm(BuildContext ctx, _GateDecision decision) {
    Navigator.pop(ctx);
    _handleConfirm(decision);
  }

  Future<void> _handleConfirm(_GateDecision decision) async {
    try {
      await widget.levelApi.skipPlacement();
    } catch (_) {
      // Best-effort: 409 means placement already recorded, which is fine.
    }
    await decision.prefs.markExistingPromptShown();
    if (mounted) refresh();
  }

  void _onRetest(BuildContext ctx, _GateDecision decision) {
    Navigator.pop(ctx);
    _handleRetest(decision);
  }

  Future<void> _handleRetest(_GateDecision decision) async {
    await decision.prefs.markExistingPromptShown();
    if (!mounted) return;
    final cb = widget.onExistingRetest;
    if (cb != null) {
      cb();
    } else {
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateDecision>(
      future: _decision,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      key: const Key('cefr_gate_error'),
                      snap.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    OutlinedButton(
                      key: const Key('cefr_gate_retry'),
                      onPressed: refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final decision = snap.data!;
        final progress = decision.progress;
        final prefs = decision.prefs;

        // Already onboarded: placement taken OR prompt already recorded.
        final alreadyOnboarded =
            progress.placementTakenAt != null || prefs.isExistingPromptShown;

        if (alreadyOnboarded) {
          return widget.child;
        }

        // Fresh A0 — placement not yet taken.
        if (progress.currentLevel == CefrLevel.a0) {
          return widget.welcomeScreen;
        }

        // Existing non-A0 user: show child underneath + dialog on top.
        _scheduleExistingPrompt(context, decision);
        return widget.child;
      },
    );
  }
}

class _GateDecision {
  const _GateDecision({required this.progress, required this.prefs});
  final LevelProgressResponse progress;
  final CefrPrefs prefs;
}
