import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/models.dart';

void main() {
  test('ExerciseDetail parses Uloha 2 scenario fields', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'exercise-uloha2-cinema',
      'title': 'Kino vecer',
      'exercise_type': 'uloha_2_dialogue_questions',
      'learner_instruction': 'Zeptejte se na chybejici informace.',
      'detail': {
        'scenario_title': 'Navsteva kina',
        'scenario_prompt':
            'Chcete jit do kina a potrebujete zjistit dulezite informace.',
        'required_info_slots': [
          {
            'slot_key': 'start_time',
            'label': 'Cas zacatku',
            'sample_question': 'V kolik hodin film zacina?',
          },
          {
            'slot_key': 'price',
            'label': 'Cena listku',
            'sample_question': 'Kolik stoji jeden listek?',
          },
        ],
        'custom_question_hint': 'Zeptejte se jeste na sal nebo titulky.',
      },
    });

    expect(detail.exerciseType, 'uloha_2_dialogue_questions');
    expect(detail.scenarioTitle, 'Navsteva kina');
    expect(detail.requiredInfoSlots, hasLength(2));
    expect(
      detail.requiredInfoSlots.first.sampleQuestion,
      'V kolik hodin film zacina?',
    );
    expect(detail.customQuestionHint, 'Zeptejte se jeste na sal nebo titulky.');
  });

  test('ExerciseDetail parses Uloha 3 story fields', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'exercise-uloha3-tv',
      'title': 'Nakup televize',
      'exercise_type': 'uloha_3_story_narration',
      'learner_instruction': 'Vypravejte pribeh podle 4 obrazku.',
      'assets': [
        {
          'id': 'asset-tv-1',
          'asset_kind': 'image',
          'storage_key': 'exercise-assets/exercise-uloha3-tv/asset-tv-1.png',
          'mime_type': 'image/png',
          'sequence_no': 1,
        },
        {
          'id': 'asset-tv-2',
          'asset_kind': 'image',
          'storage_key': 'exercise-assets/exercise-uloha3-tv/asset-tv-2.png',
          'mime_type': 'image/png',
          'sequence_no': 2,
        },
      ],
      'detail': {
        'story_title': 'Nakup televize',
        'image_asset_ids': [
          'asset-tv-1',
          'asset-tv-2',
          'asset-tv-3',
          'asset-tv-4',
        ],
        'narrative_checkpoints': [
          'Otec a syn sli do obchodu.',
          'Divali se na televize.',
          'Vybrali jednu televizi.',
          'Odvezli ji domu.',
        ],
        'grammar_focus': ['past_tense'],
      },
    });

    expect(detail.exerciseType, 'uloha_3_story_narration');
    expect(detail.storyTitle, 'Nakup televize');
    expect(detail.imageAssetIds, hasLength(4));
    expect(detail.narrativeCheckpoints, hasLength(4));
    expect(detail.grammarFocus, ['past_tense']);
    expect(detail.assets, hasLength(2));
    expect(detail.storyImageAssets, hasLength(2));
    expect(detail.storyImageAssets.first.id, 'asset-tv-1');
  });

  test('ExerciseDetail parses Uloha 4 choice fields', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'exercise-uloha4-flat',
      'title': 'Bydleni v Praze',
      'exercise_type': 'uloha_4_choice_reasoning',
      'learner_instruction': 'Vyberte jednu moznost a vysvetlete proc.',
      'detail': {
        'scenario_prompt': 'Ktery byt si vyberete a proc?',
        'options': [
          {
            'option_key': 'flat_a',
            'label': 'Byt A',
            'description': 'Levnejsi, ale daleko od centra.',
            'image_asset_id': 'asset-flat-a',
          },
          {
            'option_key': 'flat_b',
            'label': 'Byt B',
            'description': 'Blizko centra, ale mensi.',
          },
          {
            'option_key': 'flat_c',
            'label': 'Byt C',
            'description': 'Vetsi a klidny, ale drazsi.',
          },
        ],
        'expected_reasoning_axes': ['price', 'location', 'space'],
      },
    });

    expect(detail.exerciseType, 'uloha_4_choice_reasoning');
    expect(detail.choiceScenarioPrompt, 'Ktery byt si vyberete a proc?');
    expect(detail.choiceOptions, hasLength(3));
    expect(detail.choiceOptions.first.label, 'Byt A');
    expect(detail.choiceOptions.first.imageAssetId, 'asset-flat-a');
    expect(detail.expectedReasoningAxes, ['price', 'location', 'space']);
  });

  test('AttemptResult parses transcript provenance fields', () {
    final attempt = AttemptResult.fromJson({
      'id': 'attempt-1',
      'exercise_id': 'exercise-uloha1-weather',
      'status': 'completed',
      'started_at': '2026-04-22T12:00:00Z',
      'transcript': {
        'full_text': 'Mam rad teple pocasi.',
        'provider': 'dev_stub',
        'is_synthetic': true,
      },
      'feedback': {
        'readiness_level': 'almost_ready',
        'overall_summary': 'Ban dang di dung huong.',
        'strengths': const [],
        'improvements': const [],
        'retry_advice': const [],
        'sample_answer_text': '',
      },
      'review_artifact': {
        'status': 'ready',
        'generated_at': '2026-04-23T12:00:00Z',
        'repair_provider': 'task_aware_repair_v1',
      },
    });

    expect(attempt.transcript, 'Mam rad teple pocasi.');
    expect(attempt.transcriptProvider, 'dev_stub');
    expect(attempt.transcriptIsSynthetic, isTrue);
    expect(attempt.reviewArtifact?.status, 'ready');
    expect(attempt.reviewArtifact?.repairProvider, 'task_aware_repair_v1');
  });

  test('AttemptFeedbackView parses criteria_results from task_completion', () {
    final feedback = AttemptFeedbackView.fromJson({
      'readiness_level': 'almost_ready',
      'overall_summary': 'Kha tot.',
      'strengths': ['Phat am ro rang'],
      'improvements': ['Can them chi tiet'],
      'retry_advice': [],
      'sample_answer_text': '',
      'task_completion': {
        'score_band': 'almost',
        'criteria_results': [
          {
            'criterion_key': 'answered_question',
            'label': 'Tra loi dung cau hoi',
            'met': true,
            'comment': '',
          },
          {
            'criterion_key': 'gave_supporting_detail',
            'label': 'Co chi tiet ho tro',
            'met': false,
            'comment': 'Can them vi du cu the',
          },
        ],
      },
    });

    expect(feedback.criteriaResults, hasLength(2));
    expect(feedback.criteriaResults.first.criterionKey, 'answered_question');
    expect(feedback.criteriaResults.first.met, isTrue);
    expect(feedback.criteriaResults.last.criterionKey, 'gave_supporting_detail');
    expect(feedback.criteriaResults.last.met, isFalse);
    expect(feedback.criteriaResults.last.comment, 'Can them vi du cu the');
  });

  test('AttemptFeedbackView handles missing task_completion gracefully', () {
    final feedback = AttemptFeedbackView.fromJson({
      'readiness_level': 'needs_work',
      'overall_summary': '',
      'strengths': [],
      'improvements': [],
      'retry_advice': [],
    });

    expect(feedback.criteriaResults, isEmpty);
  });

  test('AttemptReviewArtifact parses full review payload', () {
    final artifact = AttemptReviewArtifactView.fromJson({
      'attempt_id': 'attempt-123',
      'status': 'ready',
      'source_transcript_text': 'dobry den ja mam rad pocasi',
      'source_transcript_provider': 'amazon_transcribe',
      'corrected_transcript_text': 'Dobry den, mam rad pocasi.',
      'model_answer_text': 'Mam rad teple pocasi, protoze muzu byt venku.',
      'speaking_focus_items': [
        {
          'focus_key': 'supporting_detail',
          'label': 'Them ly do ngan',
          'issue_type': 'missing_detail',
          'comment_vi': 'Them mot ly do ngan sau protoze.',
          'learner_fragment': 'mam rad pocasi',
          'target_fragment': 'mam rad teple pocasi, protoze...',
        },
      ],
      'diff_chunks': [
        {
          'kind': 'replaced',
          'source_text': 'ja mam rad pocasi',
          'target_text': 'Mam rad pocasi.',
        },
      ],
      'tts_audio': {
        'storage_key': 'attempt-review/attempt-123/model-answer.wav',
        'mime_type': 'audio/wav',
        'duration_ms': 4200,
      },
      'repair_provider': 'task_aware_repair_v1',
      'generated_at': '2026-04-23T12:00:00Z',
    });

    expect(artifact.attemptId, 'attempt-123');
    expect(artifact.isReady, isTrue);
    expect(artifact.speakingFocusItems, hasLength(1));
    expect(artifact.diffChunks.first.kind, 'replaced');
    expect(artifact.ttsAudio?.mimeType, 'audio/wav');
    expect(artifact.ttsAudio?.durationMs, 4200);
  });

  test('MockTest parses sections and totalMaxPoints', () {
    final test = MockTest.fromJson({
      'id': 'mock-test-1',
      'title': 'Mock Test 01',
      'description': 'Bản thân & nhà ở',
      'estimated_duration_minutes': 12,
      'status': 'published',
      'sections': [
        {'sequence_no': 1, 'exercise_id': 'ex-1', 'exercise_type': 'uloha_1_topic_answers', 'max_points': 8},
        {'sequence_no': 2, 'exercise_id': 'ex-2', 'exercise_type': 'uloha_2_dialogue_questions', 'max_points': 12},
        {'sequence_no': 3, 'exercise_id': 'ex-3', 'exercise_type': 'uloha_3_story_narration', 'max_points': 10},
        {'sequence_no': 4, 'exercise_id': 'ex-4', 'exercise_type': 'uloha_4_choice_reasoning', 'max_points': 7},
      ],
    });

    expect(test.id, 'mock-test-1');
    expect(test.estimatedDurationMinutes, 12);
    expect(test.sections.length, 4);
    expect(test.totalMaxPoints, 37); // 8+12+10+7
    expect(test.sections.first.maxPoints, 8);
    expect(test.sections.last.exerciseType, 'uloha_4_choice_reasoning');
  });

  test('ModuleSummary parses status field', () {
    final module = ModuleSummary.fromJson({
      'id': 'module-1',
      'course_id': 'course-a2',
      'title': 'Tuần 1 · Giới thiệu',
      'description': 'Chủ đề tuần đầu',
      'status': 'published',
      'sequence_no': 1,
      'module_kind': 'daily_practice',
    });

    expect(module.id, 'module-1');
    expect(module.status, 'published');
    expect(module.sequenceNo, 1);

    final locked = ModuleSummary.fromJson({
      'id': 'module-2',
      'course_id': 'course-a2',
      'title': 'Tuần 2',
      'description': '',
      'status': 'locked',
      'sequence_no': 2,
      'module_kind': 'daily_practice',
    });
    expect(locked.status, 'locked');
  });

  test('CriterionCheckView.fromJson parses met and comment', () {
    final c = CriterionCheckView.fromJson({
      'criterion_key': 'gave_supporting_detail',
      'label': 'Có chi tiết hỗ trợ',
      'met': false,
      'comment': 'Cần thêm ví dụ cụ thể',
    });

    expect(c.criterionKey, 'gave_supporting_detail');
    expect(c.label, 'Có chi tiết hỗ trợ');
    expect(c.met, isFalse);
    expect(c.comment, 'Cần thêm ví dụ cụ thể');

    final met = CriterionCheckView.fromJson({
      'criterion_key': 'answered_question',
      'label': 'Trả lời đúng câu hỏi',
      'met': true,
    });
    expect(met.met, isTrue);
    expect(met.comment, isEmpty);
  });
}
