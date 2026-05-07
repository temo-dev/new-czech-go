import 'package:flutter/material.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';
import 'package:flutter_app/features/mock_exam/screens/mock_exam_screen.dart';
import 'package:flutter_app/models/models.dart';
import 'pre_exam_screen.dart';
import 'promotion_result_screen.dart';

/// PromotionExamFlow orchestrates the V21.3 promotion exam sequence:
///
///   1. PreExamScreen (rules + confirm CTA)
///   2. createPromotionAttempt → getMockExam → MockExamScreen
///   3. onCompleted → getMockExam (completed session) → PromotionResultScreen
///
/// [onFinished] is called when the learner taps "Về trang chủ" on either
/// result branch, or taps "Để sau" on the pre-exam screen. Callers refresh
/// their level-progress state on [onFinished].
class PromotionExamFlow extends StatefulWidget {
  const PromotionExamFlow({
    super.key,
    required this.levelApi,
    required this.client,
    required this.targetLevel,
    required this.promotionTestId,
    required this.onFinished,
  });

  final LevelApi levelApi;
  final ApiClient client;
  final CefrLevel targetLevel;
  final String promotionTestId;
  final VoidCallback onFinished;

  @override
  State<PromotionExamFlow> createState() => _PromotionExamFlowState();
}

class _PromotionExamFlowState extends State<PromotionExamFlow> {
  _FlowPhase _phase = _FlowPhase.preExam;
  Future<MockExamSessionView>? _sessionFuture;
  String? _error;

  Future<void> _onConfirm() async {
    setState(() {
      _phase = _FlowPhase.loadingExam;
      _error = null;
    });
    try {
      final attempt = await widget.levelApi.createPromotionAttempt(
        widget.promotionTestId,
      );
      final raw = await widget.client.getMockExam(attempt.fullSessionId);
      final session = MockExamSessionView.fromJson(raw);
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.exam;
        _sessionFuture = Future.value(session);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _onExamCompleted(String sessionId) async {
    try {
      final raw = await widget.client.getMockExam(sessionId);
      final session = MockExamSessionView.fromJson(raw);
      if (!mounted) return;
      final perSkill = <String, double>{
        for (final s in session.sections)
          if (s.skillKind.isNotEmpty)
            s.skillKind: s.maxPoints > 0
                ? (s.sectionScore / s.maxPoints * 100)
                : 0.0,
      };
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder:
              (_) => PromotionResultScreen(
                passed: session.passed,
                targetLevel: widget.targetLevel,
                scorePct:
                    session.passThresholdPercent > 0
                        ? (session.overallScore /
                                session.passThresholdPercent *
                                100)
                            .clamp(0, 100)
                        : 0,
                perSkillPct: perSkill,
                cooldownUntil: null,
                thresholdPct: session.passThresholdPercent.toDouble(),
                onExplore: widget.onFinished,
                onHome: widget.onFinished,
                onPracticeWeakSkill: (_) => widget.onFinished(),
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _FlowPhase.preExam:
        return PreExamScreen(
          targetLevel: widget.targetLevel,
          durationMinutes: 45,
          passThresholdPct: 70,
          cooldownHours: 24,
          onConfirm: _onConfirm,
          onCancel: widget.onFinished,
        );

      case _FlowPhase.loadingExam:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              key: Key('promotion_exam_loading'),
            ),
          ),
        );

      case _FlowPhase.error:
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    key: const Key('promotion_exam_error'),
                    _error ?? 'Error',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  OutlinedButton(
                    key: const Key('promotion_exam_retry'),
                    onPressed: () {
                      setState(() {
                        _phase = _FlowPhase.preExam;
                        _error = null;
                      });
                    },
                    child: const Text('Thử lại'),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  TextButton(
                    onPressed: widget.onFinished,
                    child: const Text('Về trang chủ'),
                  ),
                ],
              ),
            ),
          ),
        );

      case _FlowPhase.exam:
        return FutureBuilder<MockExamSessionView>(
          future: _sessionFuture,
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    key: Key('promotion_exam_loading'),
                  ),
                ),
              );
            }
            return KeyedSubtree(
              key: const Key('promotion_exam_runner'),
              child: MockExamScreen(
                client: widget.client,
                initialSession: snap.data!,
                onCompleted: _onExamCompleted,
              ),
            );
          },
        );
    }
  }
}

enum _FlowPhase { preExam, loadingExam, exam, error }
