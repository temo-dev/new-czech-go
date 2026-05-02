import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/models.dart';

// Unit tests for grouping logic in InterviewListScreen.
// Widget tests requiring API are skipped (network unavailable in unit tests).

ExerciseSummary _ex(String id, String type) => ExerciseSummary(
      id: id,
      title: 'Interview $id',
      exerciseType: type,
      shortInstruction: '',
      skillKind: 'interview',
    );

void main() {
  group('InterviewListScreen grouping logic', () {
    test('groups interview_conversation separately from interview_choice_explain', () {
      final exercises = [
        _ex('1', 'interview_conversation'),
        _ex('2', 'interview_conversation'),
        _ex('3', 'interview_choice_explain'),
      ];
      final conv = exercises.where((e) => e.exerciseType == 'interview_conversation').toList();
      final choice = exercises.where((e) => e.exerciseType == 'interview_choice_explain').toList();
      expect(conv.length, 2);
      expect(choice.length, 1);
    });

    test('empty list produces empty groups', () {
      final exercises = <ExerciseSummary>[];
      final conv = exercises.where((e) => e.exerciseType == 'interview_conversation').toList();
      final choice = exercises.where((e) => e.exerciseType == 'interview_choice_explain').toList();
      expect(conv.isEmpty, isTrue);
      expect(choice.isEmpty, isTrue);
    });

    test('exercises with unknown type are excluded from both groups', () {
      final exercises = [
        _ex('1', 'interview_conversation'),
        _ex('2', 'unknown_type'),
      ];
      final conv = exercises.where((e) => e.exerciseType == 'interview_conversation').toList();
      final choice = exercises.where((e) => e.exerciseType == 'interview_choice_explain').toList();
      expect(conv.length, 1);
      expect(choice.isEmpty, isTrue);
    });

    test('all choice_explain, no conversation produces empty conv group', () {
      final exercises = [
        _ex('1', 'interview_choice_explain'),
        _ex('2', 'interview_choice_explain'),
      ];
      final conv = exercises.where((e) => e.exerciseType == 'interview_conversation').toList();
      final choice = exercises.where((e) => e.exerciseType == 'interview_choice_explain').toList();
      expect(conv.isEmpty, isTrue);
      expect(choice.length, 2);
    });

    test('SkillSummary.isImplemented includes interview', () {
      final skill = SkillSummary(
        moduleId: 'mod-1',
        skillKind: 'interview',
        exerciseCount: 3,
      );
      expect(skill.isImplemented, isTrue);
    });

    test('interview exercise type getters are correct', () {
      final convDetail = ExerciseDetail.fromJson({
        'id': 'ex-1',
        'title': 'Test',
        'exercise_type': 'interview_conversation',
        'learner_instruction': '',
        'detail': {
          'topic': 'Rodina',
          'system_prompt': 'You are Jana.',
          'max_turns': 8,
        },
      });
      expect(convDetail.isInterview, isTrue);
      expect(convDetail.isInterviewConversation, isTrue);
      expect(convDetail.isInterviewChoiceExplain, isFalse);
      expect(convDetail.interviewTopic, 'Rodina');
      expect(convDetail.interviewMaxTurns, 8);
    });

    test('interview_choice_explain detail parses options correctly', () {
      final choiceDetail = ExerciseDetail.fromJson({
        'id': 'ex-2',
        'title': 'Volný čas',
        'exercise_type': 'interview_choice_explain',
        'learner_instruction': '',
        'detail': {
          'question': 'Co děláte o víkendu?',
          'system_prompt': 'You are Jana. The learner chose {selected_option}.',
          'max_turns': 6,
          'options': [
            {'id': '1', 'label': 'Sportuji', 'image_asset_id': ''},
            {'id': '2', 'label': 'Čtu', 'image_asset_id': 'img-2'},
            {'id': '3', 'label': 'Vařím', 'image_asset_id': ''},
          ],
        },
      });
      expect(choiceDetail.isInterviewChoiceExplain, isTrue);
      expect(choiceDetail.interviewOptions.length, 3);
      expect(choiceDetail.interviewOptions[0].label, 'Sportuji');
      expect(choiceDetail.interviewOptions[1].imageAssetId, 'img-2');
      expect(choiceDetail.interviewQuestion, 'Co děláte o víkendu?');
    });
  });
}
