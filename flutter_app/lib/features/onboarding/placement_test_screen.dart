import 'package:flutter/material.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';
import 'package:flutter_app/features/mock_exam/screens/mock_exam_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

/// PlacementTestScreen is a thin wrapper around [MockExamScreen] for the
/// V21.3 onboarding placement flow.
///
/// Lifecycle:
///   1. [initState] → [LevelApi.startPlacement] → {mockTestId, fullSessionId}
///   2. [ApiClient.getMockExam(fullSessionId)] → [MockExamSessionView]
///   3. Shows [MockExamScreen(initialSession, onCompleted)] — the runner
///      handles all section navigation without changes.
///   4. [MockExamScreen.onCompleted] fires → [LevelApi.completePlacement]
///      → placement result dialog with the assigned/current level.
///      Dismissing the dialog returns to MockExamScreen's built-in result view.
///   5. Learner taps "Bắt đầu học" on that result view → [onFinished] →
///      close this route → CefrAuthGate refreshes, LearnerShell mounts.
///
/// [LevelApi] and [ApiClient] are injected so tests can supply stubs
/// without a live server.
class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({
    super.key,
    required this.levelApi,
    required this.client,
    required this.onFinished,
  });

  final LevelApi levelApi;
  final ApiClient client;
  final VoidCallback onFinished;

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen> {
  _PlacementReady? _ready;
  String? _error;
  bool _placementResultDialogShown = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final started = await widget.levelApi.startPlacement();
      final raw = await widget.client.getMockExam(started.fullSessionId);
      final session = MockExamSessionView.fromJson(raw);
      if (!mounted) return;
      setState(() {
        _ready = _PlacementReady(session: session);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _onCompleted(String sessionId) async {
    if (_placementResultDialogShown) return;
    _placementResultDialogShown = true;
    try {
      final result = await widget.levelApi.completePlacement(sessionId);
      if (!mounted) return;
      await _showPlacementResultDialog(result);
    } catch (_) {
      _placementResultDialogShown = false;
      rethrow;
    }
  }

  Future<void> _showPlacementResultDialog(PlacementCompleteResult result) {
    final l = AppLocalizations.of(context);
    final currentLevel = cefrLevelLabel(result.currentLevel);
    final isPass =
        cefrLevelOrder(result.assignedLevel) > cefrLevelOrder(CefrLevel.a0);
    final score = result.scorePct.round();
    final color = isPass ? AppColors.success : AppColors.warning;
    final containerColor =
        isPass ? AppColors.successContainer : AppColors.warningContainer;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('placement_result_dialog'),
          icon: Icon(
            isPass ? Icons.celebration_outlined : Icons.school_outlined,
            color: color,
            size: 32,
          ),
          title: Text(
            isPass
                ? l.placementResultDialogPassTitle
                : l.placementResultDialogEncourageTitle,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: containerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  currentLevel,
                  style: TextStyle(
                    color:
                        isPass
                            ? AppColors.success
                            : AppColors.onTertiaryContainer,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                isPass
                    ? l.placementResultDialogPassBody(currentLevel, score)
                    : l.placementResultDialogEncourageBody(currentLevel, score),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.placementResultDialogCta),
            ),
          ],
        );
      },
    );
  }

  void _finishPlacementFlow() {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    widget.onFinished();
    if (route?.isCurrent == true && navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  key: const Key('placement_test_error'),
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.x4),
                OutlinedButton(
                  key: const Key('placement_test_retry'),
                  onPressed: () {
                    setState(() => _error = null);
                    _start();
                  },
                  child: const Text('Thử lại'),
                ),
                const SizedBox(height: AppSpacing.x2),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ready = _ready;
    if (ready == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('placement_test_loading')),
        ),
      );
    }

    return KeyedSubtree(
      key: const Key('placement_test_exam'),
      child: MockExamScreen(
        client: widget.client,
        initialSession: ready.session,
        onCompleted: (sessionId) => _onCompleted(sessionId),
        showResultAfterCompletionCallback: true,
        resultCtaLabel: AppLocalizations.of(context).placementStartLearningCta,
        onResultCta: _finishPlacementFlow,
        showProminentSubmitAction: true,
      ),
    );
  }
}

class _PlacementReady {
  const _PlacementReady({required this.session});
  final MockExamSessionView session;
}
