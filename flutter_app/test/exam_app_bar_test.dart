import 'package:flutter/material.dart';
import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/mock_exam/controllers/exam_session_controller.dart';
import 'package:flutter_app/features/mock_exam/widgets/exam_app_bar.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentApi extends ApiClient {
  _SilentApi() : super(baseUrl: 'http://fake');
}

MockExamSessionView _session({
  required DateTime startedAt,
  int durationSec = 5400,
  List<Map<String, dynamic>>? sectionsOverride,
}) {
  final sections =
      sectionsOverride ??
      [
        {
          'sequence_no': 1,
          'skill_kind': 'doc',
          'exercise_id': 'ex-1',
          'exercise_type': 'cteni_1',
          'max_points': 5,
          'attempt_id': '',
          'section_score': 0,
          'status': 'pending',
          'display_order': 1,
        },
        {
          'sequence_no': 2,
          'skill_kind': 'noi',
          'exercise_id': 'ex-2',
          'exercise_type': 'uloha_1_topic_answers',
          'max_points': 8,
          'attempt_id': '',
          'section_score': 0,
          'status': 'pending',
          'display_order': 2,
        },
      ];
  return MockExamSessionView.fromJson(<String, dynamic>{
    'id': 's1',
    'status': 'in_progress',
    'mock_test_id': 'mt-1',
    'overall_score': 0,
    'passed': false,
    'pass_threshold_percent': 60,
    'overall_readiness_level': '',
    'overall_summary': '',
    'sections': sections,
    'started_at': startedAt.toIso8601String(),
    'duration_sec': durationSec,
    'expires_at': startedAt
        .add(Duration(seconds: durationSec))
        .toIso8601String(),
  });
}

Widget _wrap(ExamSessionController c) => MaterialApp(
  home: Scaffold(appBar: ExamAppBar(controller: c)),
);

void main() {
  group('ExamAppBar', () {
    testWidgets('renders timer formatted MM:SS', (tester) async {
      final clock = DateTime.utc(2026, 5, 12, 12, 30, 0);
      final c = ExamSessionController(
        client: _SilentApi(),
        initial: _session(startedAt: DateTime.utc(2026, 5, 12, 12, 0, 0)),
        clock: () => clock,
      );
      await tester.pumpWidget(_wrap(c));
      // 90 min - 30 min = 60 min remaining → "60:00".
      expect(find.text('60:00'), findsOneWidget);
    });

    testWidgets('shows current section progress + points', (tester) async {
      final clock = DateTime.utc(2026, 5, 12, 12, 0, 0);
      final c = ExamSessionController(
        client: _SilentApi(),
        initial: _session(startedAt: clock),
        clock: () => clock,
      );
      await tester.pumpWidget(_wrap(c));
      // First actionable section: display_order=1, max_points=5.
      expect(find.text('1/2 · 5đ'), findsOneWidget);
    });

    testWidgets('sheet button invokes onSheetTap', (tester) async {
      final clock = DateTime.utc(2026, 5, 12, 12, 0, 0);
      final c = ExamSessionController(
        client: _SilentApi(),
        initial: _session(startedAt: clock),
        clock: () => clock,
      );
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ExamAppBar(
              controller: c,
              onSheetTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('overflow Nộp bài ngay fires onSubmitAllTap', (tester) async {
      final clock = DateTime.utc(2026, 5, 12, 12, 0, 0);
      final c = ExamSessionController(
        client: _SilentApi(),
        initial: _session(startedAt: clock),
        clock: () => clock,
      );
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ExamAppBar(
              controller: c,
              onSubmitAllTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nộp bài ngay'));
      expect(tapped, isTrue);
    });
  });
}
