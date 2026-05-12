import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/mock_exam/controllers/exam_session_controller.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://fake');

  Map<String, dynamic>? _skipResult;
  Map<String, dynamic>? _advanceResult;
  Map<String, dynamic>? _getResult;
  String? lastSkipSessionId;
  int? lastSkipDisplayOrder;
  String? lastAdvanceAttemptId;

  void stubSkip(Map<String, dynamic> r) => _skipResult = r;
  void stubAdvance(Map<String, dynamic> r) => _advanceResult = r;
  void stubGet(Map<String, dynamic> r) => _getResult = r;

  @override
  Future<Map<String, dynamic>> skipMockExamSection(
    String sessionId, {
    required int displayOrder,
  }) async {
    lastSkipSessionId = sessionId;
    lastSkipDisplayOrder = displayOrder;
    return _skipResult!;
  }

  @override
  Future<Map<String, dynamic>> advanceMockExam(
    String id, {
    required String attemptId,
    int? targetDisplayOrder,
  }) async {
    lastAdvanceAttemptId = attemptId;
    return _advanceResult!;
  }

  @override
  Future<Map<String, dynamic>> getMockExam(String id) async => _getResult!;
}

MockExamSessionView _session({
  required List<Map<String, dynamic>> sections,
  bool withTimer = true,
}) {
  final now = DateTime.utc(2026, 5, 12, 12, 0, 0);
  final raw = <String, dynamic>{
    'id': 's1',
    'status': 'in_progress',
    'mock_test_id': 'mt-1',
    'overall_score': 0,
    'passed': false,
    'pass_threshold_percent': 60,
    'overall_readiness_level': '',
    'overall_summary': '',
    'sections': sections,
  };
  if (withTimer) {
    raw['started_at'] = now.toIso8601String();
    raw['duration_sec'] = 5400;
    raw['expires_at'] = now.add(const Duration(seconds: 5400)).toIso8601String();
  }
  return MockExamSessionView.fromJson(raw);
}

Map<String, dynamic> _section({
  required int seq,
  required int disp,
  required int maxPts,
  String status = 'pending',
}) => {
  'sequence_no': seq,
  'skill_kind': 'doc',
  'exercise_id': 'ex-$seq',
  'exercise_type': 'cteni_1',
  'max_points': maxPts,
  'attempt_id': '',
  'section_score': 0,
  'status': status,
  'display_order': disp,
};

void main() {
  group('ExamSessionController', () {
    test('initial currentDisplayOrder is first actionable section', () {
      final c = ExamSessionController(
        client: _FakeApi(),
        initial: _session(
          sections: [
            _section(seq: 1, disp: 1, maxPts: 5, status: 'completed'),
            _section(seq: 2, disp: 2, maxPts: 8, status: 'pending'),
          ],
        ),
      );
      expect(c.currentDisplayOrder, 2);
    });

    test('resolvedCount counts done + skipped', () {
      final c = ExamSessionController(
        client: _FakeApi(),
        initial: _session(
          sections: [
            _section(seq: 1, disp: 1, maxPts: 5, status: 'completed'),
            _section(seq: 2, disp: 2, maxPts: 8, status: 'skipped'),
            _section(seq: 3, disp: 3, maxPts: 12, status: 'pending'),
          ],
        ),
      );
      expect(c.resolvedCount, 2);
    });

    test('remaining returns remaining time against a clock', () {
      final clock = DateTime.utc(2026, 5, 12, 12, 30, 0); // +30 min
      final c = ExamSessionController(
        client: _FakeApi(),
        initial: _session(
          sections: [_section(seq: 1, disp: 1, maxPts: 5)],
        ),
        clock: () => clock,
      );
      // 90 min total - 30 min elapsed = 60 min remaining.
      expect(c.remaining, const Duration(minutes: 60));
    });

    test('skipCurrent calls api + advances pointer to next actionable', () async {
      final api = _FakeApi();
      api.stubSkip(<String, dynamic>{
        'id': 's1',
        'status': 'in_progress',
        'mock_test_id': 'mt-1',
        'overall_score': 0,
        'passed': false,
        'pass_threshold_percent': 60,
        'overall_readiness_level': '',
        'overall_summary': '',
        'sections': [
          _section(seq: 1, disp: 1, maxPts: 5, status: 'skipped'),
          _section(seq: 2, disp: 2, maxPts: 8, status: 'pending'),
        ],
      });
      final c = ExamSessionController(
        client: api,
        initial: _session(
          sections: [
            _section(seq: 1, disp: 1, maxPts: 5, status: 'pending'),
            _section(seq: 2, disp: 2, maxPts: 8, status: 'pending'),
          ],
        ),
      );
      expect(c.currentDisplayOrder, 1);
      await c.skipCurrent();
      expect(api.lastSkipDisplayOrder, 1);
      expect(c.currentDisplayOrder, 2);
      expect(c.session.sections[0].status, 'skipped');
    });

    test('jumpTo moves pointer without hitting server', () {
      final c = ExamSessionController(
        client: _FakeApi(),
        initial: _session(
          sections: [
            _section(seq: 1, disp: 1, maxPts: 5),
            _section(seq: 2, disp: 2, maxPts: 8),
          ],
        ),
      );
      c.jumpTo(2);
      expect(c.currentDisplayOrder, 2);
    });
  });
}
