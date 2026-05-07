import 'package:flutter/material.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';
import 'package:flutter_app/features/mock_exam/screens/mock_exam_screen.dart';
import 'package:flutter_app/models/models.dart';
import 'placement_result_screen.dart';

/// PlacementTestScreen is a thin wrapper around [MockExamScreen] for the
/// V21.3 onboarding placement flow.
///
/// Lifecycle:
///   1. [initState] → [LevelApi.startPlacement] → {mockTestId, fullSessionId}
///   2. [ApiClient.getMockExam(fullSessionId)] → [MockExamSessionView]
///   3. Shows [MockExamScreen(initialSession, onCompleted)] — the runner
///      handles all section navigation without changes.
///   4. [MockExamScreen.onCompleted] fires → [LevelApi.completePlacement]
///      → [PlacementResultScreen(assignedLevel, scorePct)]
///   5. Learner taps "Bắt đầu học" → [onFinished] → CefrAuthGate
///      refreshes, LearnerShell mounts.
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
        _ready = _PlacementReady(
          session: session,
          fullSessionId: started.fullSessionId,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _onCompleted(String sessionId) async {
    try {
      final result = await widget.levelApi.completePlacement(sessionId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder:
              (_) => PlacementResultScreen(
                assignedLevel: result.assignedLevel,
                scorePct: result.scorePct,
                onContinue: widget.onFinished,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Surface as a snackbar — the exam is done, don't block the user.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
          child: CircularProgressIndicator(
            key: Key('placement_test_loading'),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: const Key('placement_test_exam'),
      child: MockExamScreen(
        client: widget.client,
        initialSession: ready.session,
        onCompleted: (sessionId) => _onCompleted(sessionId),
      ),
    );
  }
}

class _PlacementReady {
  const _PlacementReady({required this.session, required this.fullSessionId});
  final MockExamSessionView session;
  final String fullSessionId;
}

