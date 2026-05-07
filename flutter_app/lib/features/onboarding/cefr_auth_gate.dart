import 'package:flutter/material.dart';

import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/storage/cefr_prefs.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';
import 'package:flutter_app/models/models.dart';

/// V21.3 onboarding gate that sits between [AuthService.authenticated] and
/// [LearnerShell]. Fetches [LevelProgressResponse] and routes the learner to
/// the right first screen:
///
/// | placementTakenAt | currentLevel | promptShown | Outcome |
/// |------------------|--------------|-------------|---------|
/// | non-null         | any          | any         | child (LearnerShell) |
/// | null             | a0           | —           | welcomeScreen (placement intro) |
/// | null             | non-a0       | true         | child (treat as onboarded) |
/// | null             | non-a0       | false       | child + Phase C dialog (added in C2) |
///
/// [refresh] forces a re-fetch so the gate re-evaluates after the learner
/// completes or skips placement. Call it from [PlacementResultScreen] or the
/// skip handler.
class CefrAuthGate extends StatefulWidget {
  const CefrAuthGate({
    super.key,
    required this.levelApi,
    required this.child,
    required this.welcomeScreen,
  });

  final LevelApi levelApi;
  final Widget child;
  final Widget welcomeScreen;

  @override
  State<CefrAuthGate> createState() => CefrAuthGateState();
}

class CefrAuthGateState extends State<CefrAuthGate> {
  Future<_GateDecision>? _decision;

  @override
  void initState() {
    super.initState();
    _decision = _evaluate();
  }

  void refresh() {
    setState(() {
      _decision = _evaluate();
    });
  }

  Future<_GateDecision> _evaluate() async {
    final prefs = await CefrPrefs.create();
    final progress = await widget.levelApi.fetchLevelProgress();
    return _GateDecision(progress: progress, prefs: prefs);
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
        final alreadyOnboarded = progress.placementTakenAt != null ||
            prefs.isExistingPromptShown;

        if (alreadyOnboarded) {
          return widget.child;
        }

        // Fresh A0 — placement not yet taken.
        if (progress.currentLevel == CefrLevel.a0) {
          return widget.welcomeScreen;
        }

        // Existing non-A0 user with placement_taken_at == null and prompt
        // not yet shown. Phase C will overlay the dialog; for Phase B just
        // show the child. Phase C (C2) adds the dialog overlay here.
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
