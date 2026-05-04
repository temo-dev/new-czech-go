import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/models.dart';

void main() {
  group('V16 interview detail parsing', () {
    test('reads display_prompt from interview_conversation detail', () {
      final detail = ExerciseDetail.fromJson({
        'id': 'ex-iv-1',
        'title': 'Phỏng vấn công việc',
        'exercise_type': 'interview_conversation',
        'detail': {
          'topic': 'Công việc',
          'system_prompt': 'You are an examiner...',
          'display_prompt': 'Mô tả công việc bạn muốn làm.',
          'audio_buffer_timeout_ms': 1500,
          'max_turns': 6,
          'show_transcript': true,
        },
      });

      expect(detail.interviewDisplayPrompt, 'Mô tả công việc bạn muốn làm.');
      expect(detail.interviewAudioBufferTimeoutMs, 1500);
    });

    test('defaults audio_buffer_timeout_ms to 1500 when missing', () {
      final detail = ExerciseDetail.fromJson({
        'id': 'ex-iv-2',
        'title': 't',
        'exercise_type': 'interview_conversation',
        'detail': {
          'system_prompt': 'x',
        },
      });

      expect(detail.interviewAudioBufferTimeoutMs, 1500);
      expect(detail.interviewDisplayPrompt, '');
    });

    test('clamps audio_buffer_timeout_ms below 500 to 500', () {
      final detail = ExerciseDetail.fromJson({
        'id': 'ex-iv-3',
        'title': 't',
        'exercise_type': 'interview_conversation',
        'detail': {'audio_buffer_timeout_ms': 100},
      });

      expect(detail.interviewAudioBufferTimeoutMs, 500);
    });

    test('clamps audio_buffer_timeout_ms above 5000 to 5000', () {
      final detail = ExerciseDetail.fromJson({
        'id': 'ex-iv-4',
        'title': 't',
        'exercise_type': 'interview_conversation',
        'detail': {'audio_buffer_timeout_ms': 9999},
      });

      expect(detail.interviewAudioBufferTimeoutMs, 5000);
    });

    test('non-interview exercise still defaults timeout to 1500', () {
      final detail = ExerciseDetail.fromJson({
        'id': 'ex-noi-1',
        'title': 't',
        'exercise_type': 'uloha_1_topic_answers',
        'detail': null,
      });

      expect(detail.interviewAudioBufferTimeoutMs, 1500);
      expect(detail.interviewDisplayPrompt, '');
    });

    test('reads display_prompt from interview_choice_explain detail', () {
      final detail = ExerciseDetail.fromJson({
        'id': 'ex-iv-5',
        'title': 'Choice',
        'exercise_type': 'interview_choice_explain',
        'detail': {
          'question': 'Chọn một nghề và giải thích',
          'options': [
            {'id': 'A', 'label': 'Đầu bếp'},
          ],
          'system_prompt': 'You are...',
          'display_prompt': 'Vysvětlete, proč jste si vybral tu profesi.',
          'audio_buffer_timeout_ms': 2000,
        },
      });

      expect(detail.interviewDisplayPrompt, 'Vysvětlete, proč jste si vybral tu profesi.');
      expect(detail.interviewAudioBufferTimeoutMs, 2000);
    });
  });
}
