// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'A2 Mluvení Sprint';

  @override
  String get heroPill => 'FOCUSED SPEAKING PRACTICE';

  @override
  String heroGreeting(String name) {
    return 'Hi $name. Focus on clarity, calmness, and steady progress — like a patient coach, not a scary test.';
  }

  @override
  String get heroPillDays => '14 DAYS';

  @override
  String get heroPillTask => '1 TASK / SCREEN';

  @override
  String get heroPillFeedback => 'FEEDBACK AFTER EVERY ATTEMPT';

  @override
  String moduleExerciseCount(int count) {
    return '$count exercises';
  }

  @override
  String get planSectionTitle => '14-day plan';

  @override
  String get planSectionSubtitle => 'Go in order. Finish each day to unlock the mock exam.';

  @override
  String planDayLabel(int day) {
    return 'Day $day';
  }

  @override
  String get planStatusDone => 'DONE';

  @override
  String get planStatusCurrent => 'TODAY';

  @override
  String get planStatusUpcoming => 'UPCOMING';

  @override
  String get planMockExamLabel => 'MOCK EXAM';

  @override
  String get mockExamTitle => 'Mock oral exam';

  @override
  String get mockExamIntroTitle => 'Four sections, one attempt each';

  @override
  String get mockExamIntroBody => 'Record each Uloha in order. After all four sections, your answers are analysed together.';

  @override
  String mockExamProgressIntroTitle(int count) {
    return '$count sections, one attempt each';
  }

  @override
  String get mockExamProgressIntroBodyWithSpeaking => 'Complete each section in order. The exam score is calculated after the final section; speaking recordings are analysed together at the end.';

  @override
  String get mockExamProgressIntroBodyNoSpeaking => 'Complete each section in order. Your result is calculated after the final section.';

  @override
  String mockExamSectionLabel(int index) {
    return 'Section $index';
  }

  @override
  String get mockExamStatusDone => 'DONE';

  @override
  String get mockExamStatusPending => 'PENDING';

  @override
  String get mockExamStatusRecorded => 'RECORDED';

  @override
  String get mockExamAnalyzing => 'Analysing your exam...';

  @override
  String mockExamAnalyzingProgress(int n, int total) {
    return 'Analysing section $n of $total';
  }

  @override
  String get mockExamActionStart => 'Start';

  @override
  String get mockExamActionDone => 'Done';

  @override
  String mockExamSectionMeta(String skill, String exercise, int points) {
    return '$skill · $exercise · $points pts';
  }

  @override
  String mockExamTaskTypeUloha(int n) {
    return 'Úloha $n';
  }

  @override
  String mockExamTaskTypeListening(int n) {
    return 'Listening $n';
  }

  @override
  String mockExamTaskTypeReading(int n) {
    return 'Reading $n';
  }

  @override
  String mockExamTaskTypeWriting(int n) {
    return 'Writing $n';
  }

  @override
  String get mockExamTaskTypeWritingForm => 'Writing 1 - form';

  @override
  String get mockExamTaskTypeWritingEmail => 'Writing 2 - email';

  @override
  String get mockExamResultTitle => 'Mock exam result';

  @override
  String get mockExamOverallTitle => 'Overall readiness';

  @override
  String get mockExamBackHome => 'Back to home';

  @override
  String get mockExamCardPill => 'MOCK EXAM';

  @override
  String get mockExamCardTitle => 'A2 Mock Oral Exam';

  @override
  String get mockExamCardSubtitle => 'Run through all four speaking sections in sequence.';

  @override
  String get mockExamOpenCta => 'Open mock exam';

  @override
  String get courseListTitle => 'Courses';

  @override
  String get courseListEmpty => 'No courses available. Ask the admin to publish one.';

  @override
  String get moduleListTitle => 'Topics';

  @override
  String get skillListTitle => 'Skills';

  @override
  String get exerciseListTitle => 'Exercises';

  @override
  String get skillNoi => 'Speaking';

  @override
  String get skillNghe => 'Listening';

  @override
  String get skillDoc => 'Reading';

  @override
  String get skillViet => 'Writing';

  @override
  String get skillTuVung => 'Vocabulary';

  @override
  String get skillNguPhap => 'Grammar';

  @override
  String get skillComingSoon => 'Coming soon';

  @override
  String get mockTestListTitle => 'Choose exam';

  @override
  String get mockTestListEmpty => 'No mock tests available. Ask the admin to publish one.';

  @override
  String mockTestCardMinutes(int n) {
    return '$n min';
  }

  @override
  String mockTestCardSections(int n) {
    return '$n sections';
  }

  @override
  String get mockTestIntroStartCta => 'Start exam';

  @override
  String get mockTestMissingTemplateId => 'This mock test is missing its template ID. Please reload the exam list and try again.';

  @override
  String mockTestIntroPoints(int pts) {
    return '$pts points total';
  }

  @override
  String mockTestIntroPassThreshold(int pts) {
    return 'Pass: $pts points or more';
  }

  @override
  String get mockTestIntroSectionsTitle => 'Sections';

  @override
  String mockExamScoreLabel(int score, int max) {
    return '$score / $max';
  }

  @override
  String get mockExamPassLabel => 'PASS';

  @override
  String get mockExamFailLabel => 'FAIL';

  @override
  String mockExamResultPassThreshold(int pct) {
    return 'Pass threshold: $pct%';
  }

  @override
  String mockExamSectionScoreLabel(int n, int score, int max) {
    return 'Úloha $n: $score/$max pts';
  }

  @override
  String mockExamSectionDetail(int n) {
    return 'Section $n Analysis';
  }

  @override
  String get recentAttemptsTitle => 'Recent attempts';

  @override
  String get recentAttemptsSubtitle => 'Check the transcript and feedback to track your progress.';

  @override
  String get openExercise => 'Open exercise';

  @override
  String get retry => 'Retry';

  @override
  String get bottomNavHome => 'Home';

  @override
  String get bottomNavHistory => 'History';

  @override
  String get historyEmpty => 'No attempts yet. Open an exercise from the Home tab to begin.';

  @override
  String get historyLabel => 'HISTORY';

  @override
  String get historyTitle => 'Practice History';

  @override
  String get historySubtitle => 'Track your progress and submission results.';

  @override
  String get historyStatTotal => 'Total attempts';

  @override
  String get historyStatSuccess => 'Success rate';

  @override
  String get resultCoachTipLabel => 'COACH TIP';

  @override
  String get resultCriteriaLabel => 'EVALUATION CRITERIA';

  @override
  String get recordingCoachTip => 'Coach tip';

  @override
  String get pillSyntheticTranscript => 'SYNTHETIC TRANSCRIPT';

  @override
  String pillFailure(String code) {
    return 'FAILURE: $code';
  }

  @override
  String get pillReadinessReady => 'READY';

  @override
  String get pillReadinessAlmost => 'ALMOST READY';

  @override
  String get pillReadinessNeedsWork => 'NEEDS WORK';

  @override
  String get pillReadinessNotReady => 'NOT READY';

  @override
  String get pillFailed => 'FAILED';

  @override
  String get statusCopyStarting => 'Getting a new attempt ready.';

  @override
  String get statusCopyRecording => 'Focus on clarity and answering the main point.';

  @override
  String get statusCopyUploading => 'Packaging the recording for the pipeline.';

  @override
  String get statusCopyProcessing => 'Transcribing and building feedback.';

  @override
  String get statusCopyCompleted => 'Feedback is ready. Read the result and try again.';

  @override
  String get statusCopyFailed => 'This attempt failed. You can try again with a new recording.';

  @override
  String get statusCopyReady => 'Ready for a fresh attempt.';

  @override
  String get recordStatusReady => 'READY';

  @override
  String get recordStatusRecording => 'RECORDING';

  @override
  String get recordStatusUploading => 'UPLOADING';

  @override
  String get recordStatusProcessing => 'PROCESSING';

  @override
  String get recordStatusCompleted => 'COMPLETED';

  @override
  String get recordStatusFailed => 'FAILED';

  @override
  String get recordCtaStart => 'Start practice';

  @override
  String get recordCtaStop => 'Stop';

  @override
  String get recordCtaAnalyze => 'Analyze';

  @override
  String get recordCtaRerecord => 'Re-record';

  @override
  String get recordStatusStopped => 'STOPPED';

  @override
  String get recordHintTapToStart => 'TAP TO START';

  @override
  String get recordHintTapToStop => 'TAP TO STOP';

  @override
  String get historyBadgeReady => 'READY';

  @override
  String get historyBadgeAlmost => 'ALMOST';

  @override
  String get historyBadgeNeedsWork => 'NEEDS WORK';

  @override
  String get historyBadgeNotReady => 'NOT READY';

  @override
  String get historyBadgeFailed => 'FAILED';

  @override
  String get historyBadgeCreated => 'CREATED';

  @override
  String get historyCtaTitle => 'Keep up the pace!';

  @override
  String get historyCtaSubtitle => 'Practice one more topic to boost your Czech fluency.';

  @override
  String get historyCtaButton => 'Start training';

  @override
  String get recordHintStopped => 'Listen to your recording. Press \"Analyze\" when ready.';

  @override
  String get analysisScreenTitle => 'Analyzing';

  @override
  String get analysisUploading => 'Uploading the recording...';

  @override
  String get analysisProcessing => 'AI is listening and grading...';

  @override
  String get analysisFailedTitle => 'Analysis failed';

  @override
  String get analysisRetryCta => 'Back to re-record';

  @override
  String get recordHintReady => 'Press \"Start practice\" when ready.';

  @override
  String get recordHintRecording => 'Focus on clarity and answering the main point.';

  @override
  String get recordHintUploading => 'Packaging the recording for the pipeline.';

  @override
  String get recordHintProcessing => 'Transcribing and building feedback.';

  @override
  String get recordHintCompleted => 'Feedback is ready. Read the result and try again.';

  @override
  String get recordHintFailed => 'This attempt failed. Try again with a new recording.';

  @override
  String get playbackTitle => 'Listen to your recording';

  @override
  String playbackErrorPrefix(String message) {
    return 'Playback error: $message';
  }

  @override
  String get playbackOpenError => 'Could not open the recording for playback.';

  @override
  String get attemptAudioTitle => 'Listen to your submitted recording';

  @override
  String get attemptAudioLoadError => 'Could not load the audio.';

  @override
  String attemptAudioOpenError(String message) {
    return 'Could not open the audio: $message';
  }

  @override
  String get reviewAudioTitle => 'Listen to the model answer to shadow';

  @override
  String get reviewAudioLoadError => 'Could not load the model audio.';

  @override
  String reviewAudioOpenError(String message) {
    return 'Could not open the model audio: $message';
  }

  @override
  String get resultTitle => 'Result';

  @override
  String get resultTranscriptTitle => 'Your transcript';

  @override
  String get resultStrengthsTitle => 'Strengths';

  @override
  String get resultImprovementsTitle => 'To improve';

  @override
  String get resultRetryAdviceTitle => 'Advice for next time';

  @override
  String get resultSampleAnswerTitle => 'Sample answer';

  @override
  String get resultRetryCta => 'Retry this exercise';

  @override
  String get resultNextExerciseCta => 'Next exercise';

  @override
  String get resultTabFeedback => 'Feedback';

  @override
  String get resultTabTranscript => 'Transcript';

  @override
  String get resultTabSample => 'Sample';

  @override
  String get resultNoFeedback => 'No feedback available.';

  @override
  String get resultNoTranscript => 'No transcript available.';

  @override
  String get resultNoSample => 'No sample answer available.';

  @override
  String get reviewArtifactTitle => 'Corrections & shadowing';

  @override
  String get reviewArtifactSubtitle => 'Your original, the corrected version, and a model to shadow.';

  @override
  String get reviewLoadError => 'Could not load the review';

  @override
  String get reviewNotApplicableTitle => 'Corrections are not yet available for this task type';

  @override
  String get reviewNotApplicableBody => 'Corrections & shadowing will be available for Úloha 3 and Úloha 4 soon.';

  @override
  String get reviewFailedTitle => 'Review artifact failed';

  @override
  String get reviewFailedBodyUnknown => 'Backend could not generate the correction.';

  @override
  String reviewFailedBodyCode(String code) {
    return 'failure_code: $code';
  }

  @override
  String get reviewPendingTitle => 'Generating the correction and model audio...';

  @override
  String get reviewPendingBody => 'You can read the feedback above while you wait.';

  @override
  String get reviewSourceTitle => 'Your transcript';

  @override
  String get reviewCorrectedTitle => 'What you should say';

  @override
  String get reviewModelTitle => 'Model to shadow';

  @override
  String get reviewSourceFallback => 'Transcript not ready yet.';

  @override
  String get exerciseUloha1Label => 'ÚLOHA 1 · TOPIC ANSWERS';

  @override
  String get exerciseUloha2Label => 'ÚLOHA 2 · DIALOGUE';

  @override
  String get exerciseUloha3Label => 'ÚLOHA 3 · STORY';

  @override
  String get exerciseUloha4Label => 'ÚLOHA 4 · CHOICE & REASONING';

  @override
  String get coachNoteTitle => 'Coach note';

  @override
  String get coachNoteUloha1 => 'Keep it short and clear. Use simple sentences first. Answering the task matters more than sounding complex.';

  @override
  String get coachNoteUloha2 => 'Ask for every piece of info in the scenario. Use simple, clear questions.';

  @override
  String get coachNoteUloha3 => 'Tell it in order: nejdřív, pak, nakonec. Sentences don\'t need to be perfect — hit the key beats.';

  @override
  String get coachNoteUloha4 => 'Pick one option and explain why. Use \"protože\" or \"protože mi líbí\".';

  @override
  String get promptRequiredInfoTitle => 'Info you need to ask for';

  @override
  String promptHintPrefix(String text) {
    return 'Hint: $text';
  }

  @override
  String promptCustomQuestion(String text) {
    return 'Extra question: $text';
  }

  @override
  String promptStoryImageLabel(int index) {
    return 'Image $index';
  }

  @override
  String get promptStoryNoImages => 'No images yet — you can still practice from the text checkpoints.';

  @override
  String promptStoryImagesLoaded(int loaded, int total) {
    return 'Loaded $loaded/$total images.';
  }

  @override
  String get promptStoryHintOrder => 'Tell the story in order: nejdřív, pak, nakonec.';

  @override
  String promptStoryHintByImages(int count) {
    return 'Tell the story across the $count images.';
  }

  @override
  String get promptStoryCheckpointsTitle => 'Beats to mention';

  @override
  String promptStoryGrammarFocus(String list) {
    return 'Grammar to emphasize: $list';
  }

  @override
  String get promptChoiceOptionsTitle => 'Options';

  @override
  String promptChoiceReasoningHint(String list) {
    return 'Reasoning hints: $list';
  }

  @override
  String get bottomNavTests => 'Tests';

  @override
  String get bottomNavProfile => 'Profile';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileLanguageSection => 'Language';

  @override
  String get profileAboutSection => 'About';

  @override
  String get profileAppName => 'A2 Mluvení Sprint';

  @override
  String get profileAppTagline => 'Czech A2 oral exam prep for Vietnamese learners';

  @override
  String profileVersion(String version) {
    return 'Version $version';
  }

  @override
  String get profileVoiceSection => 'Model answer voice';

  @override
  String get profileVoicePreview => 'Preview';

  @override
  String get profileVoiceFemale => 'Female';

  @override
  String get profileVoiceMale => 'Male';

  @override
  String get profileVoiceProviderPolly => 'AWS Polly';

  @override
  String get profileVoiceProviderElevenLabs => 'ElevenLabs';

  @override
  String get profileVoicePreviewError => 'Could not preview this voice';

  @override
  String get submitAnswersCta => 'Submit answers';

  @override
  String get submitWritingCta => 'Submit';

  @override
  String get scoringInProgress => 'Scoring…';

  @override
  String get scoringTimeout => 'Scoring timed out. Please try again.';

  @override
  String get resultScreenTitle => 'Result';

  @override
  String get retryCta => 'Try again';

  @override
  String get writingTopicsLabel => 'Write about these topics:';

  @override
  String get writingEmailHint => 'Ahoj Lído, …';

  @override
  String writingWordCountBadge(int count, int min) {
    return '$count/$min words';
  }

  @override
  String writingQuestionFallback(int no) {
    return 'Question $no';
  }

  @override
  String get audioLoading => 'Loading audio…';

  @override
  String get audioError => 'Audio unavailable';

  @override
  String get audioHint => 'Listening audio — play twice';

  @override
  String get objectiveBreakdownTitle => 'Question breakdown';

  @override
  String objectiveQuestionLabel(int no) {
    return 'Q$no:';
  }

  @override
  String get objectivePassBadge => 'PASS';

  @override
  String get objectiveFailBadge => 'FAIL';

  @override
  String get objectiveNoAnswer => '(no answer)';

  @override
  String get objectiveYourAnswer => 'Your answer:';

  @override
  String get objectiveCorrectAnswer => 'Correct answer:';

  @override
  String get viewPassage => 'View reading text';

  @override
  String get hidePassage => 'Hide reading text';

  @override
  String objectiveScoreDisplay(int score, int max) {
    return '$score/$max';
  }

  @override
  String get fullExamScreenTitle => 'Mock exam';

  @override
  String get fullExamDurationLabel => 'Duration';

  @override
  String get fullExamMaxPtsLabel => 'Total pts';

  @override
  String get fullExamPassLabel => 'Pass';

  @override
  String get fullExamSectionsTitle => 'Sections';

  @override
  String get fullExamSubmitCta => 'Submit písemná';

  @override
  String get fullExamSubmitHint => 'Complete all sections to submit';

  @override
  String get fullExamResultTitle => 'Exam result';

  @override
  String get fullExamPisemnaLabel => 'Written part (Písemná)';

  @override
  String get fullExamUstniLabel => 'Oral part (Ústní)';

  @override
  String get fullExamPassedBadge => 'PASS';

  @override
  String get fullExamFailedBadge => 'FAIL';

  @override
  String get fullExamOverallPassed => 'PASSED';

  @override
  String get fullExamOverallFailed => 'NOT PASSED';

  @override
  String get fullExamUstniPending => 'Oral part not completed. Take the speaking mock test to get the overall result.';

  @override
  String get fullExamGoHome => 'Go home';

  @override
  String get fullExamPisemnaPassHint => 'Písemná passed — complete the oral part';

  @override
  String fullExamScoreNeed(int pass) {
    return 'need ≥$pass';
  }

  @override
  String fullExamMinDuration(int min) {
    return '$min min';
  }

  @override
  String fullExamPts(int pts) {
    return '$pts pts';
  }

  @override
  String fullExamPassSymbol(int pass) {
    return '≥$pass';
  }

  @override
  String get skillModulesLabel => 'SKILLS';

  @override
  String get skillModulesTitle => 'Develop your skills';

  @override
  String get skillModulesSubtitle => 'Choose the skill you want to practice today.';

  @override
  String get exerciseListProgressLink => 'Speaking Progress';

  @override
  String get exerciseListFlowBadge => 'FLOW';

  @override
  String get exerciseListSubtitle => 'Focus on fluency and correct pronunciation in real situations.';

  @override
  String get exerciseListDailySprintLabel => 'RECOMMENDED MODE';

  @override
  String get exerciseListDailySprintTitle => 'Daily Sprint';

  @override
  String get exerciseListDailySprintSubtitle => 'Practice all exercises at once and get instant AI coach feedback.';

  @override
  String get exerciseListDailySprintCta => 'Start all';

  @override
  String get exerciseOpenError => 'Cannot open exercise. Please try again.';

  @override
  String get vocabKnown => 'Got it';

  @override
  String get vocabReview => 'Review';

  @override
  String get vocabFlip => 'Tap to see answer';

  @override
  String get vocabDone => 'Noted!';

  @override
  String get vocabMatchInstruction => 'Match each term to its definition';

  @override
  String get vocabFillInstruction => 'Fill in the blank';

  @override
  String get vocabChoiceInstruction => 'Choose the correct word';

  @override
  String get vocabExplanation => 'Explanation';

  @override
  String get exerciseTypeFlashcard => 'Flashcard';

  @override
  String get exerciseTypeMatching => 'Matching';

  @override
  String get exerciseTypeFillBlank => 'Fill in';

  @override
  String get exerciseTypeChoiceWord => 'Choose word';

  @override
  String get typeGroupSubtitle => 'Choose exercise type to study';

  @override
  String get deckStartAll => 'Start all';

  @override
  String get deckOrStudyOne => 'Or study one at a time';

  @override
  String get deckSessionComplete => 'Session complete!';

  @override
  String deckKnownOf(int known, int total) {
    return '$known / $total known';
  }

  @override
  String deckRetryRemaining(int count) {
    return 'Review $count remaining';
  }

  @override
  String get deckDone => 'Done — back to list';

  @override
  String get deckCorrect => 'Correct!';

  @override
  String get deckWrong => 'Not quite';

  @override
  String get deckNext => 'Next';

  @override
  String get deckConfirmExit => 'Exit deck session?';

  @override
  String get deckConfirmExitBody => 'Progress will not be saved.';

  @override
  String get deckKnownLabel => 'Known';

  @override
  String get deckRetryLabel => 'Review';

  @override
  String get emptyExerciseList => 'No exercises yet';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';
}
