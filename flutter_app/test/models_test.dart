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

  // ── V6: Vocab & Grammar exercise model tests ─────────────────────────────

  test('ExerciseDetail parses quizcard_basic fields', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'ex-quizcard-1',
      'title': 'chodím',
      'exercise_type': 'quizcard_basic',
      'learner_instruction': 'Lật thẻ để xem nghĩa.',
      'detail': {
        'front_text': 'chodím',
        'back_text': 'đi bộ',
        'example_sentence': 'Já chodím do školy.',
        'example_translation': 'Tôi đi bộ đến trường.',
        'explanation': 'First person singular of chodít.',
        'correct_answers': {'1': 'known'},
      },
    });

    expect(detail.exerciseType, 'quizcard_basic');
    expect(detail.isQuizcard, isTrue);
    expect(detail.isVocabGrammar, isTrue);
    expect(detail.flashcardFront, 'chodím');
    expect(detail.flashcardBack, 'đi bộ');
    expect(detail.flashcardExample, 'Já chodím do školy.');
    expect(detail.flashcardExampleTranslation, 'Tôi đi bộ đến trường.');
    // fillBlankExplanation reads detail['explanation'] which quizcard also has
    expect(detail.fillBlankExplanation, 'First person singular of chodít.');
    expect(detail.isMatching, isFalse);
    expect(detail.isFillBlank, isFalse);
    expect(detail.isChoiceWord, isFalse);
  });

  test('ExerciseDetail parses matching fields', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'ex-matching-1',
      'title': 'Ghép từ',
      'exercise_type': 'matching',
      'learner_instruction': 'Ghép từ với nghĩa.',
      'detail': {
        'pairs': [
          {'left_id': '1', 'left': 'chodím', 'right_id': 'A', 'right': 'đi bộ'},
          {'left_id': '2', 'left': 'jedu', 'right_id': 'B', 'right': 'đi xe'},
          {'left_id': '3', 'left': 'letím', 'right_id': 'C', 'right': 'bay'},
          {'left_id': '4', 'left': 'běžím', 'right_id': 'D', 'right': 'chạy'},
        ],
        'explanation': 'Các động từ di chuyển.',
        'correct_answers': {'1': 'A', '2': 'B', '3': 'C', '4': 'D'},
      },
    });

    expect(detail.isMatching, isTrue);
    expect(detail.isVocabGrammar, isTrue);
    expect(detail.matchingPairs.length, 4);
    expect(detail.matchingPairs[0].leftId, '1');
    expect(detail.matchingPairs[0].left, 'chodím');
    expect(detail.matchingPairs[0].rightId, 'A');
    expect(detail.matchingPairs[0].right, 'đi bộ');
    expect(detail.matchingPairs[3].left, 'běžím');
  });

  test('ExerciseDetail parses fill_blank fields', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'ex-fill-1',
      'title': 'Điền từ',
      'exercise_type': 'fill_blank',
      'learner_instruction': 'Điền từ vào chỗ trống.',
      'detail': {
        'sentence': 'Já ___ do školy každý den.',
        'hint': 'Động từ di chuyển ngôi thứ 1',
        'explanation': "Ngôi thứ nhất số ít dùng 'chodím'.",
        'correct_answers': {'1': 'chodím'},
      },
    });

    expect(detail.isFillBlank, isTrue);
    expect(detail.isVocabGrammar, isTrue);
    expect(detail.fillBlankSentence, 'Já ___ do školy každý den.');
    expect(detail.fillBlankHint, 'Động từ di chuyển ngôi thứ 1');
    expect(detail.fillBlankExplanation, contains("chodím"));
    expect(detail.isQuizcard, isFalse);
  });

  test('ExerciseDetail parses choice_word fields', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'ex-choice-1',
      'title': 'Chọn từ',
      'exercise_type': 'choice_word',
      'learner_instruction': 'Chọn từ đúng.',
      'detail': {
        'stem': 'Kde ___ Pavel dnes?',
        'options': [
          {'key': 'A', 'text': 'je'},
          {'key': 'B', 'text': 'jsou'},
          {'key': 'C', 'text': 'jsem'},
          {'key': 'D', 'text': 'jste'},
        ],
        'grammar_note': 'Pavel là ngôi thứ 3 số ít.',
        'explanation': "Dùng 'je' cho ngôi thứ 3 số ít.",
        'correct_answers': {'1': 'A'},
      },
    });

    expect(detail.isChoiceWord, isTrue);
    expect(detail.isVocabGrammar, isTrue);
    expect(detail.choiceWordStem, 'Kde ___ Pavel dnes?');
    expect(detail.choiceWordGrammarNote, 'Pavel là ngôi thứ 3 số ít.');
    expect(detail.choiceWordExplanation, contains("je"));
    expect(detail.poslechOptions.length, 4);
    expect(detail.poslechOptions[0].key, 'A');
    expect(detail.poslechOptions[0].text, 'je');
  });

  test('Skill isImplemented includes tu_vung and ngu_phap', () {
    final tuVung = Skill(
      id: 'sk-1', moduleId: 'mod-1', skillKind: 'tu_vung',
      title: 'Từ vựng', sequenceNo: 1, status: 'published',
    );
    expect(tuVung.isImplemented, isTrue);

    final nguPhap = Skill(
      id: 'sk-2', moduleId: 'mod-1', skillKind: 'ngu_phap',
      title: 'Ngữ pháp', sequenceNo: 2, status: 'published',
    );
    expect(nguPhap.isImplemented, isTrue);

    final tuVung2 = Skill(
      id: 'sk-3', moduleId: 'mod-1', skillKind: 'tu_vung',
      title: 'Từ vựng', sequenceNo: 3, status: 'published',
    );
    expect(tuVung2.isImplemented, isTrue);
  });

  test('MatchingPairView parses fromJson correctly', () {
    final pair = MatchingPairView.fromJson({
      'left_id': '3',
      'left': 'letím',
      'right_id': 'C',
      'right': 'bay',
    });

    expect(pair.leftId, '3');
    expect(pair.left, 'letím');
    expect(pair.rightId, 'C');
    expect(pair.right, 'bay');
  });

  test('MatchingPairView handles missing fields gracefully', () {
    final pair = MatchingPairView.fromJson({});
    expect(pair.leftId, isEmpty);
    expect(pair.left, isEmpty);
    expect(pair.rightId, isEmpty);
    expect(pair.right, isEmpty);
  });

  test('ExerciseDetail V6 flags are false for non-vocab types', () {
    final detail = ExerciseDetail.fromJson({
      'id': 'ex-noi',
      'title': 'Nói',
      'exercise_type': 'uloha_1_topic_answers',
      'learner_instruction': '',
      'detail': <String, dynamic>{},
    });

    expect(detail.isVocabGrammar, isFalse);
    expect(detail.isQuizcard, isFalse);
    expect(detail.isMatching, isFalse);
    expect(detail.isFillBlank, isFalse);
    expect(detail.isChoiceWord, isFalse);
  });

  test('ExerciseDetail fromJson does not crash for psani_1_formular with string questions', () {
    // psani_1 detail['questions'] contains strings (form questions).
    // poslechQuestions parser must not cast them as Maps.
    final detail = ExerciseDetail.fromJson(<String, dynamic>{
      'id': 'psani1-test',
      'title': 'Formulář',
      'exercise_type': 'psani_1_formular',
      'detail': <String, dynamic>{
        'questions': ['Jak jste se dozvěděl/a?', 'Proč nakupujete?', 'Co vám chybí?'],
        'min_words': 10,
      },
    });
    expect(detail.isPsani1, isTrue);
    expect(detail.writingQuestions.length, 3);
    expect(detail.poslechQuestions, isEmpty);
  });

  test('ExerciseDetail writingMinWords defaults correctly per type', () {
    ExerciseDetail makeWriting(String type, {int? minWords}) {
      final detail = <String, dynamic>{};
      if (minWords != null) detail['min_words'] = minWords;
      return ExerciseDetail.fromJson(<String, dynamic>{
        'id': 'w1',
        'title': 'T',
        'exercise_type': type,
        'detail': detail,
      });
    }

    // explicit min_words overrides default for both types
    expect(makeWriting('psani_1_formular', minWords: 15).writingMinWords, 15);
    expect(makeWriting('psani_2_email', minWords: 40).writingMinWords, 40);

    // no min_words: psani_1 defaults to 10, psani_2 defaults to 35
    expect(makeWriting('psani_1_formular').writingMinWords, 10);
    expect(makeWriting('psani_2_email').writingMinWords, 35);
  });

  // ── _hasEnoughWords logic (pure function, tested via model layer) ──────────

  test('poslechQuestions fromJson handles empty questions list', () {
    final detail = ExerciseDetail.fromJson(<String, dynamic>{
      'id': 'p1',
      'title': 'Poslech',
      'exercise_type': 'poslech_1',
      'detail': <String, dynamic>{'questions': []},
    });
    expect(detail.poslechQuestions, isEmpty);
  });

  test('poslechQuestions fromJson parses well-formed map list', () {
    final detail = ExerciseDetail.fromJson(<String, dynamic>{
      'id': 'p2',
      'title': 'Poslech 2',
      'exercise_type': 'poslech_2',
      'detail': <String, dynamic>{
        'questions': [
          {'question_no': 1, 'prompt': 'Co říká muž?'},
          {'question_no': 2, 'prompt': 'Kde to je?'},
        ],
      },
    });
    expect(detail.poslechQuestions.length, 2);
    expect(detail.poslechQuestions[0].questionNo, 1);
    expect(detail.poslechQuestions[0].prompt, 'Co říká muž?');
    expect(detail.poslechQuestions[1].questionNo, 2);
  });

  test('cteniQuestions fromJson parses well-formed map list', () {
    final detail = ExerciseDetail.fromJson(<String, dynamic>{
      'id': 'c1',
      'title': 'Čtení 3',
      'exercise_type': 'cteni_3',
      'detail': <String, dynamic>{
        'questions': [
          {'question_no': 3, 'prompt': 'Kdo napsal?'},
        ],
      },
    });
    expect(detail.cteniQuestions.length, 1);
    expect(detail.cteniQuestions[0].questionNo, 3);
    expect(detail.cteniQuestions[0].prompt, 'Kdo napsal?');
  });

  test('FillQuestionView.fromJson handles missing fields gracefully', () {
    // question_no defaults to 0 (int), prompt defaults to empty string.
    final q = FillQuestionView.fromJson(<String, dynamic>{});
    expect(q.questionNo, 0);
    expect(q.prompt, '');
  });

  test('AttemptReviewArtifactView.diffChunks parses list of diff chunks', () {
    final artifact = AttemptReviewArtifactView.fromJson({
      'status': 'ready',
      'source_transcript_text': 'Já jít do školy.',
      'corrected_transcript_text': 'Já jdu do školy.',
      'model_answer_text': 'Já jdu do školy.',
      'diff_chunks': [
        {'kind': 'unchanged', 'source_text': 'Já ', 'target_text': 'Já '},
        {'kind': 'deleted', 'source_text': 'jít', 'target_text': ''},
        {'kind': 'inserted', 'source_text': '', 'target_text': 'jdu'},
        {'kind': 'unchanged', 'source_text': ' do školy.', 'target_text': ' do školy.'},
      ],
      'repair_provider': 'writing_scorer_v1',
      'generated_at': '2026-04-29T00:00:00Z',
    });
    expect(artifact.diffChunks.length, 4);
    expect(artifact.diffChunks[0].kind, 'unchanged');
    expect(artifact.diffChunks[1].kind, 'deleted');
    expect(artifact.diffChunks[1].sourceText, 'jít');
    expect(artifact.diffChunks[2].kind, 'inserted');
    expect(artifact.diffChunks[2].targetText, 'jdu');
  });

  test('AttemptReviewArtifactView.diffChunks defaults to empty list when absent', () {
    final artifact = AttemptReviewArtifactView.fromJson({
      'status': 'ready',
      'source_transcript_text': 'text',
      'corrected_transcript_text': 'text',
      'model_answer_text': '',
      'repair_provider': 'writing_scorer_v1',
      'generated_at': '2026-04-29T00:00:00Z',
    });
    expect(artifact.diffChunks, isEmpty);
  });
}
