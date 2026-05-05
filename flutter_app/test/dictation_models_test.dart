import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/models.dart';

void main() {
  group('DictationSentenceView', () {
    test('parses idx, text, and audio_asset_id', () {
      final view = DictationSentenceView.fromJson(<String, dynamic>{
        'idx': 2,
        'text': 'Pavel jde do kavárny.',
        'audio_asset_id': 'audio/ex-1/sentence-2.mp3',
      });
      expect(view.idx, 2);
      expect(view.text, 'Pavel jde do kavárny.');
      expect(view.audioAssetId, 'audio/ex-1/sentence-2.mp3');
    });

    test('defaults missing fields gracefully', () {
      final view = DictationSentenceView.fromJson(<String, dynamic>{});
      expect(view.idx, 0);
      expect(view.text, '');
      expect(view.audioAssetId, '');
    });
  });

  group('ExerciseDetail psani_3_dictation parsing', () {
    test('parses dictation detail end-to-end', () {
      final detail = ExerciseDetail.fromJson(<String, dynamic>{
        'id': 'ex-1',
        'title': 'Trong quán cafe',
        'exercise_type': 'psani_3_dictation',
        'detail': <String, dynamic>{
          'topic': 'Trong quán cafe',
          'context_image_asset_id': 'img-cafe',
          'sentences': [
            {'idx': 0, 'text': 'Pavel jde do kavárny.', 'audio_asset_id': 'a-0'},
            {'idx': 1, 'text': 'Chce si dát čaj.', 'audio_asset_id': 'a-1'},
            {'idx': 2, 'text': 'Děkuji.', 'audio_asset_id': 'a-2'},
          ],
          'max_replays_per_sentence': 3,
          'voice_id': 'Tomas',
          'max_points': 10,
          'pass_threshold_percent': 60,
        },
      });
      expect(detail.isPsani3, isTrue);
      expect(detail.dictationTopic, 'Trong quán cafe');
      expect(detail.dictationContextImageAssetId, 'img-cafe');
      expect(detail.dictationSentences.length, 3);
      expect(detail.dictationSentences[1].text, 'Chce si dát čaj.');
      expect(detail.dictationMaxReplaysPerSentence, 3);
      expect(detail.dictationMaxPoints, 10);
      expect(detail.dictationPassThresholdPercent, 60);
    });

    test('isPsani3 returns false for other writing types', () {
      final p1 = ExerciseDetail.fromJson(<String, dynamic>{
        'id': 'ex-2',
        'title': 'Form',
        'exercise_type': 'psani_1_formular',
        'detail': <String, dynamic>{},
      });
      expect(p1.isPsani3, isFalse);
      expect(p1.dictationSentences, isEmpty);
    });

    test('parses submission_mode for V18.1 OCR exercises', () {
      for (final mode in ['type', 'ocr', 'both']) {
        final detail = ExerciseDetail.fromJson(<String, dynamic>{
          'id': 'ex-mode',
          'title': 't',
          'exercise_type': 'psani_3_dictation',
          'detail': <String, dynamic>{
            'topic': 'x',
            'sentences': const <Map<String, dynamic>>[],
            'submission_mode': mode,
          },
        });
        expect(detail.dictationSubmissionMode, mode, reason: 'mode=$mode');
      }
    });

    test('defaults submission_mode to "type" when missing (V18 backward-compat)', () {
      final detail = ExerciseDetail.fromJson(<String, dynamic>{
        'id': 'ex-legacy',
        'title': 't',
        'exercise_type': 'psani_3_dictation',
        'detail': <String, dynamic>{
          'topic': 'x',
          'sentences': const <Map<String, dynamic>>[],
        },
      });
      expect(detail.dictationSubmissionMode, 'type');
      expect(detail.dictationIsOCRMode, isFalse);
      expect(detail.dictationIsTypeMode, isTrue);
      expect(detail.dictationIsBothMode, isFalse);
    });

    test('coerces unknown submission_mode value back to "type"', () {
      final detail = ExerciseDetail.fromJson(<String, dynamic>{
        'id': 'ex-bogus',
        'title': 't',
        'exercise_type': 'psani_3_dictation',
        'detail': <String, dynamic>{
          'topic': 'x',
          'sentences': const <Map<String, dynamic>>[],
          'submission_mode': 'bogus',
        },
      });
      expect(detail.dictationSubmissionMode, 'type');
    });

    test('uses sane defaults when dictation fields are missing', () {
      final detail = ExerciseDetail.fromJson(<String, dynamic>{
        'id': 'ex-3',
        'title': 'X',
        'exercise_type': 'psani_3_dictation',
        'detail': <String, dynamic>{
          'topic': 'X',
          'sentences': const <Map<String, dynamic>>[],
        },
      });
      expect(detail.dictationMaxReplaysPerSentence, 3);
      expect(detail.dictationMaxPoints, 10);
      expect(detail.dictationPassThresholdPercent, 60);
    });
  });

  group('DictationResultView', () {
    test('parses overall + sentence scores from feedback payload', () {
      final json = <String, dynamic>{
        'overall_score': 8,
        'max_points': 10,
        'passed': true,
        'pass_threshold_percent': 60,
        'sentences': [
          {
            'idx': 0,
            'reference': 'Pavel jde do kavárny.',
            'learner': 'Pavel jde do kavarny.',
            'accuracy': 0.95,
            'audio_asset_id': 'a-0',
            'error_tags': ['missing_diacritic'],
            'feedback_vi': 'Bạn quên dấu trên á.',
            'feedback_en': 'Missing diacritic on á.',
            'diff_chunks': [
              {'kind': 'replaced', 'source_text': 'kavárny', 'target_text': 'kavarny'},
            ],
          },
        ],
      };
      final result = DictationResultView.fromJson(json);
      expect(result.overallScore, 8);
      expect(result.passed, isTrue);
      expect(result.sentences.length, 1);
      final s0 = result.sentences[0];
      expect(s0.accuracy, 0.95);
      expect(s0.errorTags, ['missing_diacritic']);
      expect(s0.feedbackVI, 'Bạn quên dấu trên á.');
      expect(s0.diffChunks.length, 1);
      expect(s0.diffChunks[0].kind, 'replaced');
    });
  });

  group('AttemptFeedbackView dictation_result wiring', () {
    test('feedback view exposes dictationResult when present', () {
      final feedback = AttemptFeedbackView.fromJson(<String, dynamic>{
        'readiness_level': 'ready_for_mock',
        'overall_summary': 'OK',
        'strengths': const <String>[],
        'improvements': const <String>[],
        'retry_advice': const <String>[],
        'dictation_result': {
          'overall_score': 7,
          'max_points': 10,
          'passed': true,
          'pass_threshold_percent': 60,
          'sentences': const <Map<String, dynamic>>[],
        },
      });
      expect(feedback.dictationResult, isNotNull);
      expect(feedback.dictationResult!.overallScore, 7);
      expect(feedback.objectiveResult, isNull);
    });

    test('dictationResult is null for non-dictation attempts', () {
      final feedback = AttemptFeedbackView.fromJson(<String, dynamic>{
        'readiness_level': 'almost_ready',
        'overall_summary': 'X',
      });
      expect(feedback.dictationResult, isNull);
    });
  });
}
