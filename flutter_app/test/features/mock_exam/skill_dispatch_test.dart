import 'package:flutter/material.dart';
import 'package:flutter_app/features/mock_exam/screens/mock_exam_skill_dispatch.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

// V36 — verify the mock-exam skill_kind dispatcher recognises interview
// exercises so the runner can route to InterviewSessionScreen rather
// than the WritingExerciseScreen fallback.

void main() {
  group('skillKindForExerciseType', () {
    test('maps uloha_ prefix to noi', () {
      expect(skillKindForExerciseType('uloha_1_topic_answers'), 'noi');
      expect(skillKindForExerciseType('uloha_3_story_narration'), 'noi');
    });

    test('maps poslech_ prefix to nghe', () {
      expect(skillKindForExerciseType('poslech_4'), 'nghe');
    });

    test('maps cteni_ prefix to doc', () {
      expect(skillKindForExerciseType('cteni_2'), 'doc');
    });

    test('maps psani_ prefix to viet', () {
      expect(skillKindForExerciseType('psani_2_email'), 'viet');
    });

    test('maps interview_ prefix to interview (V36)', () {
      expect(skillKindForExerciseType('interview_conversation'), 'interview');
      expect(skillKindForExerciseType('interview_choice_explain'), 'interview');
    });

    test('falls back to noi for unknown prefix', () {
      expect(skillKindForExerciseType('mystery_99'), 'noi');
    });
  });

  group('sectionSkillKind', () {
    test('returns section.skillKind when explicitly set', () {
      const section = MockExamSection(
        sequenceNo: 1,
        skillKind: 'interview',
        exerciseId: 'iv-1',
        exerciseType: 'interview_conversation',
        maxPoints: 20,
        attemptId: '',
        sectionScore: 0,
        status: 'pending',
      );
      expect(sectionSkillKind(section), 'interview');
    });

    test('infers from exerciseType when skillKind empty', () {
      const section = MockExamSection(
        sequenceNo: 1,
        skillKind: '',
        exerciseId: 'iv-1',
        exerciseType: 'interview_conversation',
        maxPoints: 20,
        attemptId: '',
        sectionScore: 0,
        status: 'pending',
      );
      expect(sectionSkillKind(section), 'interview');
    });

    test('prefers exerciseType when skillKind contradicts', () {
      const section = MockExamSection(
        sequenceNo: 2,
        skillKind: 'noi',
        exerciseId: 'poslech-2',
        exerciseType: 'poslech_2',
        maxPoints: 5,
        attemptId: '',
        sectionScore: 0,
        status: 'pending',
      );
      expect(sectionSkillKind(section), 'nghe');
    });
  });

  group('skillLabel', () {
    late AppLocalizations l;
    setUp(() async {
      l = await AppLocalizations.delegate.load(const Locale('vi'));
    });

    test('returns localised label for known skills', () {
      expect(skillLabel(l, 'noi'), l.skillNoi);
      expect(skillLabel(l, 'nghe'), l.skillNghe);
      expect(skillLabel(l, 'doc'), l.skillDoc);
      expect(skillLabel(l, 'viet'), l.skillViet);
    });

    test('returns localised label for interview (V36)', () {
      expect(skillLabel(l, 'interview'), l.skillInterview);
    });

    test('falls back to uppercased skill_kind for unknown', () {
      expect(skillLabel(l, 'mystery'), 'MYSTERY');
    });
  });
}
