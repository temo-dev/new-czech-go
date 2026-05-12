import 'package:flutter_app/features/mock_exam/models/exam_section_state.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

MockExamSection _sec({
  int seq = 1,
  int displayOrder = 1,
  String status = 'pending',
}) {
  return MockExamSection(
    sequenceNo: seq,
    skillKind: 'noi',
    exerciseId: 'ex-$seq',
    exerciseType: 'uloha_1_topic_answers',
    maxPoints: 5,
    attemptId: '',
    sectionScore: 0,
    status: status,
    displayOrder: displayOrder,
  );
}

void main() {
  group('sectionStateFor', () {
    test('returns current when displayOrder matches pointer', () {
      final s = _sec(displayOrder: 3, status: 'pending');
      expect(sectionStateFor(s, currentDisplayOrder: 3), SectionState.current);
    });

    test('current overrides status (done section that is also current)', () {
      final s = _sec(displayOrder: 3, status: 'completed');
      expect(sectionStateFor(s, currentDisplayOrder: 3), SectionState.current);
    });

    test('returns done for completed section', () {
      final s = _sec(displayOrder: 2, status: 'completed');
      expect(sectionStateFor(s, currentDisplayOrder: 1), SectionState.done);
    });

    test('returns skipped for status="skipped"', () {
      final s = _sec(displayOrder: 2, status: 'skipped');
      expect(sectionStateFor(s, currentDisplayOrder: 1), SectionState.skipped);
    });

    test('returns empty for status="pending"', () {
      final s = _sec(displayOrder: 2, status: 'pending');
      expect(sectionStateFor(s, currentDisplayOrder: 1), SectionState.empty);
    });
  });
}
