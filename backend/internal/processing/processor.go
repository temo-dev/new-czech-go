package processing

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type attemptRepository interface {
	Attempt(id string) (*contracts.Attempt, bool)
	Exercise(id string) (contracts.Exercise, bool)
	SetAttemptStatus(id, status string)
	CompleteAttempt(id string, transcript contracts.Transcript, feedback contracts.AttemptFeedback)
	UpsertReviewArtifact(id string, artifact contracts.AttemptReviewArtifact) (*contracts.AttemptReviewArtifact, bool)
	FailAttempt(id, failureCode string)
}

type Processor struct {
	repo           attemptRepository
	transcriber    Transcriber
	ttsProvider    TTSProvider
	llmProvider    LLMFeedbackProvider
	reviewProvider LLMReviewProvider
}

func NewProcessor(repo attemptRepository, transcriber Transcriber, ttsProvider TTSProvider, llmProvider LLMFeedbackProvider, reviewProvider LLMReviewProvider) *Processor {
	if transcriber == nil {
		transcriber = DevTranscriber{}
	}
	if ttsProvider == nil {
		ttsProvider = DevTTSProvider{}
	}
	if llmProvider == nil {
		llmProvider = DevLLMFeedbackProvider{}
	}
	if reviewProvider == nil {
		reviewProvider = DevLLMReviewProvider{}
	}
	return &Processor{repo: repo, transcriber: transcriber, ttsProvider: ttsProvider, llmProvider: llmProvider, reviewProvider: reviewProvider}
}

func (p *Processor) ProcessAttempt(attemptID string) error {
	attempt, ok := p.repo.Attempt(attemptID)
	if !ok {
		return fmt.Errorf("attempt %s not found", attemptID)
	}
	if attempt.Audio == nil || attempt.Audio.StorageKey == "" || attempt.Audio.DurationMs <= 0 {
		p.repo.FailAttempt(attemptID, "audio_invalid")
		return nil
	}

	exercise, ok := p.repo.Exercise(attempt.ExerciseID)
	if !ok {
		p.repo.FailAttempt(attemptID, "scoring_failed")
		return nil
	}

	p.repo.SetAttemptStatus(attemptID, "transcribing")

	transcript, reliability, usable, err := p.transcriber.Transcribe(exercise, *attempt.Audio)
	if err != nil {
		log.Printf("attempt %s transcription failed: storage_key=%q mime_type=%q duration_ms=%d error=%v", attemptID, attempt.Audio.StorageKey, attempt.Audio.MimeType, attempt.Audio.DurationMs, err)
		p.repo.FailAttempt(attemptID, "transcription_failed")
		return nil
	}
	if !usable {
		log.Printf("attempt %s transcription unusable: storage_key=%q mime_type=%q duration_ms=%d reliability=%s", attemptID, attempt.Audio.StorageKey, attempt.Audio.MimeType, attempt.Audio.DurationMs, reliability)
		p.repo.FailAttempt(attemptID, "transcription_failed")
		return nil
	}

	p.repo.SetAttemptStatus(attemptID, "scoring")

	locale := attempt.Locale
	if locale == "" {
		locale = contracts.DefaultLocale
	}
	feedback, ok := p.buildFeedbackWithLLM(attemptID, exercise, transcript, reliability, locale)
	if !ok {
		log.Printf("attempt %s scoring failed: transcript was not usable for feedback generation", attemptID)
		p.repo.FailAttempt(attemptID, "scoring_failed")
		return nil
	}

	p.repo.CompleteAttempt(attemptID, transcript, feedback)
	artifact, artifactOk := buildReviewArtifact(exercise, transcript, feedback)
	if !artifactOk {
		artifact = contracts.AttemptReviewArtifact{
			AttemptID: attemptID,
			Status:    "not_applicable",
		}
	} else {
		artifact.GeneratedAt = time.Now().UTC().Format(time.RFC3339)
		p.applyLLMReviewOverride(attemptID, exercise, transcript, feedback, &artifact, locale)
		if artifact.ModelAnswerText != "" {
			audio, err := p.ttsProvider.Generate(attemptID, artifact.ModelAnswerText)
			if err != nil {
				log.Printf("attempt %s review artifact tts generation failed: error=%v", attemptID, err)
			} else {
				artifact.TTSAudio = audio
			}
		}
	}
	if _, stored := p.repo.UpsertReviewArtifact(attemptID, artifact); !stored {
		log.Printf("attempt %s review artifact persistence failed after completion", attemptID)
	}
	return nil
}

func (p *Processor) applyLLMReviewOverride(attemptID string, exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback, artifact *contracts.AttemptReviewArtifact, locale string) {
	if p.reviewProvider == nil {
		return
	}
	rv, err := p.reviewProvider.GenerateReview(exercise, transcript, feedback, locale)
	if err != nil {
		log.Printf("attempt %s llm review unavailable, keeping rule-based: %v", attemptID, err)
		return
	}
	artifact.CorrectedTranscriptText = rv.CorrectedTranscript
	artifact.ModelAnswerText = rv.ModelAnswer
	artifact.DiffChunks = buildReadableDiffChunks(
		normalizeTranscript(artifact.SourceTranscriptText),
		normalizeTranscript(rv.CorrectedTranscript),
	)
	artifact.RepairProvider = "llm_review_claude_v1"
	log.Printf("attempt %s llm review applied", attemptID)
}

type transcriptReliability string

const (
	reliabilityUsable             transcriptReliability = "usable"
	reliabilityUsableWithWarnings transcriptReliability = "usable_with_warnings"
	reliabilityUnusable           transcriptReliability = "unusable"
)

func (p *Processor) buildFeedbackWithLLM(attemptID string, exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, bool) {
	baseline, ruleOk := buildFeedbackLocalized(exercise, transcript, reliability, locale)
	if !ruleOk {
		return contracts.AttemptFeedback{}, false
	}
	if p.llmProvider == nil {
		return baseline, true
	}
	llmFb, err := p.llmProvider.GenerateFeedback(exercise, transcript, reliability, locale)
	if err != nil {
		log.Printf("attempt %s llm feedback unavailable, using rule-based: %v", attemptID, err)
		return baseline, true
	}
	merged := baseline
	if llmFb.ReadinessLevel != "" {
		merged.ReadinessLevel = llmFb.ReadinessLevel
	}
	if llmFb.OverallSummary != "" {
		merged.OverallSummary = llmFb.OverallSummary
	}
	if len(llmFb.Strengths) > 0 {
		merged.Strengths = llmFb.Strengths
	}
	if len(llmFb.Improvements) > 0 {
		merged.Improvements = llmFb.Improvements
	}
	if len(llmFb.RetryAdvice) > 0 {
		merged.RetryAdvice = llmFb.RetryAdvice
	}
	if llmFb.SampleAnswer != "" {
		merged.SampleAnswer = llmFb.SampleAnswer
	}
	log.Printf("attempt %s llm feedback applied", attemptID)
	return merged, true
}

func buildFeedbackLocalized(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability, locale string) (contracts.AttemptFeedback, bool) {
	fb, ok := buildFeedback(exercise, transcript, reliability)
	if !ok {
		return fb, false
	}
	if locale == contracts.LocaleEN {
		fb = localizeFeedbackToEnglish(fb)
	}
	return fb, true
}

func localizeFeedbackToEnglish(fb contracts.AttemptFeedback) contracts.AttemptFeedback {
	fb.OverallSummary = "Your attempt was recorded. Detailed English coaching will appear when AI feedback is available."
	fb.Strengths = []string{"You produced a clear spoken response."}
	fb.Improvements = []string{"Try speaking more slowly and add one concrete detail."}
	fb.RetryAdvice = []string{"Record again and aim for 20-30 seconds."}
	return fb
}

func buildFeedback(exercise contracts.Exercise, transcript contracts.Transcript, reliability transcriptReliability) (contracts.AttemptFeedback, bool) {
	normalized := normalizeTranscript(transcript.FullText)
	if normalized == "" {
		return contracts.AttemptFeedback{}, false
	}

	criteria, taskBand := evaluateTaskCompletion(exercise, normalized)
	grammar := evaluateGrammar(normalized, reliability)
	readiness := mapReadiness(taskBand, grammar.ScoreBand, reliability)
	summary := buildSummary(exercise, readiness, reliability, criteria)
	strengths := buildStrengths(criteria)
	improvements := buildImprovements(criteria, reliability)
	retryAdvice := buildRetryAdvice(exercise, criteria, reliability)
	sampleAnswer := sampleAnswerForExercise(exercise.ExerciseType)

	if len(strengths) == 0 {
		strengths = []string{"Ban da hoan thanh duoc mot cau tra loi ro rang."}
	}
	if len(improvements) == 0 {
		improvements = []string{"Thu noi lai cham hon va them mot chi tiet cu the."}
	}
	if len(retryAdvice) == 0 {
		retryAdvice = []string{"Thu ghi am lai va noi trong 20-30 giay."}
	}

	return contracts.AttemptFeedback{
		ReadinessLevel:  readiness,
		OverallSummary:  summary,
		Strengths:       strengths,
		Improvements:    improvements,
		TaskCompletion:  contracts.TaskCompletion{ScoreBand: taskBand, CriteriaResults: criteria},
		GrammarFeedback: grammar,
		RetryAdvice:     retryAdvice,
		SampleAnswer:    sampleAnswer,
	}, true
}

func buildReviewArtifact(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback) (contracts.AttemptReviewArtifact, bool) {
	switch exercise.ExerciseType {
	case "uloha_1_topic_answers":
		return buildUloha1ReviewArtifact(exercise, transcript, feedback)
	case "uloha_2_dialogue_questions":
		return buildUloha2ReviewArtifact(exercise, transcript, feedback)
	case "uloha_3_story_narration":
		return buildUloha3ReviewArtifact(exercise, transcript, feedback)
	case "uloha_4_choice_reasoning":
		return buildUloha4ReviewArtifact(exercise, transcript, feedback)
	default:
		return contracts.AttemptReviewArtifact{}, false
	}
}

func buildUloha1ReviewArtifact(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback) (contracts.AttemptReviewArtifact, bool) {
	normalized := normalizeTranscript(transcript.FullText)
	if normalized == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	corrected := correctedUloha1Transcript(normalized)
	model := uloha1ModelAnswer(exercise, corrected, feedback)
	if corrected == "" || model == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	diffChunks := buildReadableDiffChunks(normalized, corrected)
	speakingFocus := buildUloha1SpeakingFocus(exercise, normalized, corrected, feedback)

	return contracts.AttemptReviewArtifact{
		Status:                   "ready",
		SourceTranscriptText:     transcript.FullText,
		SourceTranscriptProvider: transcript.Provider,
		CorrectedTranscriptText:  corrected,
		ModelAnswerText:          model,
		SpeakingFocusItems:       speakingFocus,
		DiffChunks:               diffChunks,
		RepairProvider:           "task_aware_repair_v1",
	}, true
}

func buildUloha2ReviewArtifact(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback) (contracts.AttemptReviewArtifact, bool) {
	normalized := normalizeTranscript(transcript.FullText)
	if normalized == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	corrected := correctedUloha2Transcript(exercise, normalized, feedback)
	model := uloha2ModelAnswer(exercise, corrected, feedback)
	if corrected == "" || model == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	diffChunks := buildReadableDiffChunks(normalized, normalizeTranscript(corrected))
	speakingFocus := buildUloha2SpeakingFocus(exercise, normalized, corrected, feedback)

	return contracts.AttemptReviewArtifact{
		Status:                   "ready",
		SourceTranscriptText:     transcript.FullText,
		SourceTranscriptProvider: transcript.Provider,
		CorrectedTranscriptText:  corrected,
		ModelAnswerText:          model,
		SpeakingFocusItems:       speakingFocus,
		DiffChunks:               diffChunks,
		RepairProvider:           "task_aware_repair_v1",
	}, true
}

func buildUloha3ReviewArtifact(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback) (contracts.AttemptReviewArtifact, bool) {
	normalized := normalizeTranscript(transcript.FullText)
	if normalized == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	corrected := correctedNarrativeTranscript(normalized)
	model := uloha3ModelAnswer(exercise, feedback)
	if corrected == "" || model == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	diffChunks := buildReadableDiffChunks(normalized, normalizeTranscript(corrected))
	speakingFocus := buildUloha3SpeakingFocus(exercise, feedback)

	return contracts.AttemptReviewArtifact{
		Status:                   "ready",
		SourceTranscriptText:     transcript.FullText,
		SourceTranscriptProvider: transcript.Provider,
		CorrectedTranscriptText:  corrected,
		ModelAnswerText:          model,
		SpeakingFocusItems:       speakingFocus,
		DiffChunks:               diffChunks,
		RepairProvider:           "task_aware_repair_v1",
	}, true
}

func buildUloha4ReviewArtifact(exercise contracts.Exercise, transcript contracts.Transcript, feedback contracts.AttemptFeedback) (contracts.AttemptReviewArtifact, bool) {
	normalized := normalizeTranscript(transcript.FullText)
	if normalized == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	corrected := correctedNarrativeTranscript(normalized)
	model := uloha4ModelAnswer(exercise, normalized, feedback)
	if corrected == "" || model == "" {
		return contracts.AttemptReviewArtifact{}, false
	}

	diffChunks := buildReadableDiffChunks(normalized, normalizeTranscript(corrected))
	speakingFocus := buildUloha4SpeakingFocus(exercise, feedback)

	return contracts.AttemptReviewArtifact{
		Status:                   "ready",
		SourceTranscriptText:     transcript.FullText,
		SourceTranscriptProvider: transcript.Provider,
		CorrectedTranscriptText:  corrected,
		ModelAnswerText:          model,
		SpeakingFocusItems:       speakingFocus,
		DiffChunks:               diffChunks,
		RepairProvider:           "task_aware_repair_v1",
	}, true
}

func correctedNarrativeTranscript(normalized string) string {
	trimmed := strings.TrimSpace(normalized)
	if trimmed == "" {
		return ""
	}
	runes := []rune(trimmed)
	runes[0] = []rune(strings.ToUpper(string(runes[0])))[0]
	sentence := string(runes)
	if !strings.HasSuffix(sentence, ".") && !strings.HasSuffix(sentence, "!") && !strings.HasSuffix(sentence, "?") {
		sentence += "."
	}
	return sentence
}

func uloha3ModelAnswer(exercise contracts.Exercise, feedback contracts.AttemptFeedback) string {
	if authored := strings.TrimSpace(exercise.SampleAnswerText); authored != "" {
		return authored
	}
	if detail, ok := extractUloha3Detail(exercise.Detail); ok {
		if sample := buildUloha3SampleFromCheckpoints(detail.NarrativeCheckpoints); sample != "" {
			return sample
		}
	}
	if feedback.SampleAnswer != "" {
		return feedback.SampleAnswer
	}
	return sampleAnswerForExercise("uloha_3_story_narration")
}

func buildUloha3SampleFromCheckpoints(checkpoints []string) string {
	connectives := []string{"Nejdriv", "Potom", "Nakonec"}
	clean := make([]string, 0, len(checkpoints))
	for _, cp := range checkpoints {
		trimmed := strings.TrimSpace(cp)
		if trimmed == "" {
			continue
		}
		trimmed = strings.TrimRight(trimmed, ".!?")
		runes := []rune(trimmed)
		runes[0] = []rune(strings.ToLower(string(runes[0])))[0]
		clean = append(clean, string(runes))
	}
	if len(clean) == 0 {
		return ""
	}
	limit := len(clean)
	if limit > len(connectives) {
		limit = len(connectives)
	}
	parts := make([]string, 0, limit)
	for i := 0; i < limit; i++ {
		parts = append(parts, connectives[i]+" "+clean[i]+".")
	}
	return strings.Join(parts, " ")
}

func buildUloha3SpeakingFocus(exercise contracts.Exercise, feedback contracts.AttemptFeedback) []contracts.SpeakingFocusItem {
	items := make([]contracts.SpeakingFocusItem, 0, 3)
	criteria := feedback.TaskCompletion.CriteriaResults

	if !criterionMetByKey(criteria, "covered_story_events") {
		target := ""
		if detail, ok := extractUloha3Detail(exercise.Detail); ok && len(detail.NarrativeCheckpoints) > 0 {
			target = strings.Join(detail.NarrativeCheckpoints, "; ")
		}
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "story_coverage",
			Label:          "Bao quat cac moc chinh",
			TargetFragment: target,
			IssueType:      "missing_detail",
			CommentVI:      "Hay nhac du cac moc chinh cua cau chuyen theo dung thu tu.",
		})
	}

	if !criterionMetByKey(criteria, "narrative_sequence_present") && len(items) < 3 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "sequence_markers",
			Label:          "Dung tu noi thu tu",
			TargetFragment: "Nejdriv..., potom..., nakonec...",
			IssueType:      "clarity_hint",
			CommentVI:      "Them tu noi thu tu (nejdriv, potom, nakonec) de nguoi nghe biet dau la moc dau va ket.",
		})
	}

	if !criterionMetByKey(criteria, "used_story_language") && len(items) < 3 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "past_tense",
			Label:          "Dung dong tu qua khu",
			TargetFragment: "byli, sli, koupili, odvezli",
			IssueType:      "word_form",
			CommentVI:      "Cau chuyen phai dung dong tu o qua khu (byl, sli, koupili, videli...).",
		})
	}

	if len(items) == 0 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:  "keep_story_flow",
			Label:     "Giu nhip ke nay",
			IssueType: "clarity_hint",
			CommentVI: "Ban da giu duoc mach ke chuyen; hay tiep tuc giu nhip tu nhien nay o buoc sau.",
		})
	}

	return items
}

func uloha4ModelAnswer(exercise contracts.Exercise, normalized string, feedback contracts.AttemptFeedback) string {
	if authored := strings.TrimSpace(exercise.SampleAnswerText); authored != "" {
		return authored
	}
	if detail, ok := extractUloha4Detail(exercise.Detail); ok && len(detail.Options) > 0 {
		chosen := detail.Options[0]
		for i := range detail.Options {
			if optionMentioned(normalized, detail.Options[i]) {
				chosen = detail.Options[i]
				break
			}
		}
		label := strings.TrimSpace(chosen.Label)
		if label != "" {
			axis := ""
			if len(detail.ExpectedReasoningAxes) > 0 {
				axis = strings.TrimSpace(detail.ExpectedReasoningAxes[0])
			}
			if axis != "" {
				return fmt.Sprintf("Vybiram %s, protoze %s.", label, axis)
			}
			return fmt.Sprintf("Vybiram %s, protoze je to pro me nejlepsi.", label)
		}
	}
	if feedback.SampleAnswer != "" {
		return feedback.SampleAnswer
	}
	return sampleAnswerForExercise("uloha_4_choice_reasoning")
}

func buildUloha4SpeakingFocus(exercise contracts.Exercise, feedback contracts.AttemptFeedback) []contracts.SpeakingFocusItem {
	items := make([]contracts.SpeakingFocusItem, 0, 3)
	criteria := feedback.TaskCompletion.CriteriaResults

	if !criterionMetByKey(criteria, "made_clear_choice") {
		target := "Vybiram..."
		if detail, ok := extractUloha4Detail(exercise.Detail); ok && len(detail.Options) > 0 {
			for _, o := range detail.Options {
				if o.Label != "" {
					target = "Vybiram " + o.Label
					break
				}
			}
		}
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "clear_choice",
			Label:          "Noi ro lua chon",
			TargetFragment: target,
			IssueType:      "missing_detail",
			CommentVI:      "Bat dau bang \"Vybiram...\" va neu ro phuong an ban chon.",
		})
	}

	if !criterionMetByKey(criteria, "gave_reason") && len(items) < 3 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "give_reason",
			Label:          "Them ly do",
			TargetFragment: "..., protoze ...",
			IssueType:      "missing_detail",
			CommentVI:      "Them it nhat mot ve sau tu \"protoze\" de giai thich vi sao ban chon phuong an nay.",
		})
	}

	if !criterionMetByKey(criteria, "reason_matches_choice") && len(items) < 3 {
		axis := ""
		if detail, ok := extractUloha4Detail(exercise.Detail); ok && len(detail.ExpectedReasoningAxes) > 0 {
			axis = detail.ExpectedReasoningAxes[0]
		}
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "reason_matches",
			Label:          "Ly do sat lua chon",
			TargetFragment: axis,
			IssueType:      "clarity_hint",
			CommentVI:      "Ly do nen gan truc tiep voi phuong an da chon, khong noi chung chung.",
		})
	}

	if len(items) == 0 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:  "keep_choice_clarity",
			Label:     "Giu cau tra loi ro nay",
			IssueType: "clarity_hint",
			CommentVI: "Ban dang dua ra lua chon va ly do kha tot; hay giu nguyen mau cau nay o lan sau.",
		})
	}

	return items
}

func correctedUloha1Transcript(normalized string) string {
	trimmed := strings.TrimSpace(normalized)
	if trimmed == "" {
		return ""
	}

	words := strings.Fields(trimmed)
	if len(words) > 0 && words[0] == "ja" {
		words = words[1:]
	}
	if len(words) == 0 {
		return ""
	}

	sentence := strings.Join(words, " ")
	sentence = strings.TrimSpace(sentence)
	if sentence == "" {
		return ""
	}

	first := []rune(sentence)
	first[0] = []rune(strings.ToUpper(string(first[0])))[0]
	sentence = string(first)
	if !strings.HasSuffix(sentence, ".") && !strings.HasSuffix(sentence, "!") && !strings.HasSuffix(sentence, "?") {
		sentence += "."
	}
	return sentence
}

func uloha1ModelAnswer(exercise contracts.Exercise, corrected string, feedback contracts.AttemptFeedback) string {
	if corrected == "" {
		return ""
	}
	if authored := strings.TrimSpace(exercise.SampleAnswerText); authored != "" {
		return authored
	}
	if criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "gave_supporting_detail") {
		return corrected
	}

	topic := strings.ToLower(strings.TrimSpace(firstNonEmpty(topicTokens(exercise)...)))
	switch topic {
	case "pocasi":
		return "Mam rad teple pocasi, protoze muzu byt dlouho venku s rodinou a chodit do parku."
	case "bydleni":
		return "Bydlim v byte s rodinou a libi se mi, ze je blizko centra i obchodu."
	default:
		base := strings.TrimSuffix(corrected, ".")
		return base + ", protoze je to pro me prijemne a prakticke."
	}
}

func buildUloha1SpeakingFocus(exercise contracts.Exercise, source, corrected string, feedback contracts.AttemptFeedback) []contracts.SpeakingFocusItem {
	items := make([]contracts.SpeakingFocusItem, 0, 3)
	topic := strings.TrimSpace(firstNonEmpty(topicTokens(exercise)...))

	if !criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "answered_question") {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:  "direct_answer",
			Label:     "Tra loi truc tiep hon",
			IssueType: "clarity_hint",
			CommentVI: "Mo dau bang mot cau tra loi truc tiep vao cau hoi chinh truoc khi them y phu.",
		})
	}
	if !criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "stayed_on_topic") && len(items) < 3 {
		comment := "Lap lai tu khoa cua chu de ngay o cau dau de bai noi dung trong tam hon."
		if topic != "" {
			comment = fmt.Sprintf("Lap lai tu khoa %s ngay o cau dau de bai noi dung trong tam hon.", topic)
		}
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:  "topic_anchor",
			Label:     "Bam sat chu de",
			IssueType: "clarity_hint",
			CommentVI: comment,
		})
	}
	if !criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "gave_supporting_detail") && len(items) < 3 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:  "supporting_detail",
			Label:     "Them ly do ngan",
			IssueType: "missing_detail",
			CommentVI: "Them mot ve sau tu protoze hoac mot chi tiet cu the de cau tra loi day hon.",
		})
	}

	if len(items) == 0 && strings.HasPrefix(strings.ToLower(source), "ja ") && len(items) < 3 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:        "trim_opening",
			Label:           "Rut gon mo dau",
			LearnerFragment: firstWordFragment(source, 2),
			TargetFragment:  firstWordFragment(corrected, 2),
			IssueType:       "word_form",
			CommentVI:       "Ban co the bo bot cum mo dau de cau nghe tu nhien hon.",
		})
	}

	if len(items) == 0 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:  "keep_clarity",
			Label:     "Giu nhip noi nay",
			IssueType: "clarity_hint",
			CommentVI: "Ban da noi kha ro; hay giu cach mo dau gon va them mot ly do tu nhien nhu hien tai.",
		})
	}

	return items
}

func correctedUloha2Transcript(exercise contracts.Exercise, normalized string, feedback contracts.AttemptFeedback) string {
	questions := matchedRequiredSlotQuestions(exercise, normalized)
	if len(questions) == 0 {
		if criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "used_question_form") {
			return normalizedToQuestion(normalized)
		}
		required := uloha2RequiredQuestions(exercise)
		if len(required) == 0 {
			return ""
		}
		return required[0]
	}
	return strings.Join(questions, " ")
}

func uloha2ModelAnswer(exercise contracts.Exercise, corrected string, feedback contracts.AttemptFeedback) string {
	if corrected == "" {
		return ""
	}
	if authored := strings.TrimSpace(exercise.SampleAnswerText); authored != "" {
		return authored
	}
	if criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "covered_required_slots") &&
		criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "used_question_form") &&
		criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "included_custom_question") {
		return corrected
	}

	questions := append([]string{}, uloha2RequiredQuestions(exercise)...)
	if extra := uloha2ExtraQuestion(exercise); extra != "" {
		questions = append(questions, extra)
	}
	questions = uniqueNonEmptyStrings(questions)
	if len(questions) == 0 {
		return corrected
	}
	return strings.Join(questions, " ")
}

func buildUloha2SpeakingFocus(exercise contracts.Exercise, source, corrected string, feedback contracts.AttemptFeedback) []contracts.SpeakingFocusItem {
	items := make([]contracts.SpeakingFocusItem, 0, 3)
	requiredQuestions := uloha2RequiredQuestions(exercise)

	if !criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "used_question_form") {
		target := corrected
		if len(requiredQuestions) > 0 {
			target = requiredQuestions[0]
		}
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:        "question_form",
			Label:           "Dung dang cau hoi",
			LearnerFragment: firstWordFragment(source, 4),
			TargetFragment:  target,
			IssueType:       "question_form",
			CommentVI:       "Hay doi tu khoa roi thanh mot cau hoi day du de nguoi nghe thay ro ban dang hoi thong tin gi.",
		})
	}

	if !criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "covered_required_slots") && len(items) < 3 {
		missing := missingRequiredSlotQuestions(exercise, source)
		target := strings.Join(missing, " ")
		if target == "" && len(requiredQuestions) > 0 {
			target = strings.Join(requiredQuestions, " ")
		}
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "required_slots",
			Label:          "Hoi du thong tin chinh",
			TargetFragment: target,
			IssueType:      "missing_detail",
			CommentVI:      "Hay hoi du cac thong tin bat buoc cua tinh huong, vi thieu mot slot quan trong se lam bai noi giong chua xong nhiem vu.",
		})
	}

	if !criterionMetByKey(feedback.TaskCompletion.CriteriaResults, "included_custom_question") && len(items) < 3 {
		target := uloha2ExtraQuestion(exercise)
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:       "extra_question",
			Label:          "Them cau hoi bo sung",
			TargetFragment: target,
			IssueType:      "missing_detail",
			CommentVI:      "Sau khi hoi du thong tin chinh, them mot cau hoi bo sung tu nhien de bai noi giong tinh huong thi that hon.",
		})
	}

	if len(items) == 0 {
		items = append(items, contracts.SpeakingFocusItem{
			FocusKey:  "keep_question_flow",
			Label:     "Giu nhip hoi nay",
			IssueType: "clarity_hint",
			CommentVI: "Ban dang dat cau hoi kha ro; hay giu nhip hoi tung y ngan gon nhu hien tai.",
		})
	}

	return items
}

func buildReadableDiffChunks(source, target string) []contracts.DiffChunk {
	sourceWords := strings.Fields(strings.TrimSpace(source))
	targetWords := strings.Fields(strings.TrimSpace(target))

	if len(sourceWords) == 0 && len(targetWords) == 0 {
		return nil
	}

	prefix := 0
	for prefix < len(sourceWords) && prefix < len(targetWords) && sourceWords[prefix] == targetWords[prefix] {
		prefix++
	}

	suffix := 0
	for suffix < len(sourceWords)-prefix && suffix < len(targetWords)-prefix &&
		sourceWords[len(sourceWords)-1-suffix] == targetWords[len(targetWords)-1-suffix] {
		suffix++
	}

	chunks := make([]contracts.DiffChunk, 0, 3)
	if prefix > 0 {
		chunks = append(chunks, contracts.DiffChunk{
			Kind:       "unchanged",
			SourceText: strings.Join(sourceWords[:prefix], " "),
			TargetText: strings.Join(targetWords[:prefix], " "),
		})
	}

	sourceMiddle := strings.Join(sourceWords[prefix:len(sourceWords)-suffix], " ")
	targetMiddle := strings.Join(targetWords[prefix:len(targetWords)-suffix], " ")
	switch {
	case sourceMiddle == "" && targetMiddle == "":
		if len(chunks) == 0 {
			chunks = append(chunks, contracts.DiffChunk{
				Kind:       "unchanged",
				SourceText: strings.Join(sourceWords, " "),
				TargetText: strings.Join(targetWords, " "),
			})
		}
	case sourceMiddle == "":
		chunks = append(chunks, contracts.DiffChunk{
			Kind:       "inserted",
			TargetText: targetMiddle,
		})
	case targetMiddle == "":
		chunks = append(chunks, contracts.DiffChunk{
			Kind:       "deleted",
			SourceText: sourceMiddle,
		})
	default:
		chunks = append(chunks, contracts.DiffChunk{
			Kind:       "replaced",
			SourceText: sourceMiddle,
			TargetText: targetMiddle,
		})
	}

	if suffix > 0 {
		chunks = append(chunks, contracts.DiffChunk{
			Kind:       "unchanged",
			SourceText: strings.Join(sourceWords[len(sourceWords)-suffix:], " "),
			TargetText: strings.Join(targetWords[len(targetWords)-suffix:], " "),
		})
	}

	return chunks
}

func normalizedToQuestion(normalized string) string {
	trimmed := strings.TrimSpace(normalized)
	if trimmed == "" {
		return ""
	}

	first := []rune(trimmed)
	first[0] = []rune(strings.ToUpper(string(first[0])))[0]
	question := string(first)
	question = strings.TrimRight(question, ".!?")
	return question + "?"
}

func firstWordFragment(text string, count int) string {
	words := strings.Fields(strings.TrimSpace(text))
	if len(words) == 0 {
		return ""
	}
	if count > len(words) {
		count = len(words)
	}
	return strings.Join(words[:count], " ")
}

func evaluateTaskCompletion(exercise contracts.Exercise, transcript string) ([]contracts.CriterionCheck, string) {
	switch exercise.ExerciseType {
	case "uloha_3_story_narration":
		return evaluateStoryNarration(exercise, transcript)
	case "uloha_4_choice_reasoning":
		return evaluateChoiceReasoning(exercise, transcript)
	case "uloha_2_dialogue_questions":
		return evaluateDialogueQuestions(transcript)
	default:
		return evaluateUloha1(exercise, transcript)
	}
}

func evaluateUloha1(exercise contracts.Exercise, transcript string) ([]contracts.CriterionCheck, string) {
	topic := normalizeTranscript(strings.Join(topicTokens(exercise), " "))
	answered := wordCount(transcript) >= 3
	stayedOnTopic := topic == "" || containsAny(transcript, strings.Fields(topic))
	gaveDetail := wordCount(transcript) >= 7 || strings.Contains(transcript, "protoze")

	criteria := []contracts.CriterionCheck{
		{
			CriterionKey: "answered_question",
			Label:        "Tra loi dung cau hoi",
			Met:          answered,
			Comment:      boolComment(answered, "Ban da dua ra mot cau tra loi hoan chinh.", "Cau tra loi hien tai qua ngan de hien ro y chinh."),
		},
		{
			CriterionKey: "stayed_on_topic",
			Label:        "Giu dung chu de",
			Met:          stayedOnTopic,
			Comment:      boolComment(stayedOnTopic, "Noi dung van nam trong chu de bai tap.", "Cau tra loi chua bam sat chu de cua bai tap."),
		},
		{
			CriterionKey: "gave_supporting_detail",
			Label:        "Them chi tiet ho tro",
			Met:          gaveDetail,
			Comment:      boolComment(gaveDetail, "Ban da them ly do hoac chi tiet cu the.", "Hay them mot ly do ngan hoac mot chi tiet cu the hon."),
		},
	}

	return criteria, bandFromCriteria(criteria)
}

func evaluateDialogueQuestions(transcript string) ([]contracts.CriterionCheck, string) {
	hasQuestionForm := strings.Contains(transcript, "?") || containsAny(transcript, []string{"kolik", "kdy", "kde", "jak", "muzu"})
	coveredSlots := countMatches(transcript, []string{"kolik", "kdy", "v kolik", "kde"}) >= 2
	customQuestion := containsAny(transcript, []string{"online", "rezervovat", "telefon"})

	criteria := []contracts.CriterionCheck{
		{CriterionKey: "covered_required_slots", Label: "Hoi du thong tin can thiet", Met: coveredSlots, Comment: boolComment(coveredSlots, "Ban da hoi nhieu thong tin can thiet.", "Hay hoi them it nhat mot thong tin quan trong nua.")},
		{CriterionKey: "used_question_form", Label: "Dung dang cau hoi", Met: hasQuestionForm, Comment: boolComment(hasQuestionForm, "Cau hoi cua ban co y hoi ro rang.", "Hay dung mot mau cau hoi day du hon.")},
		{CriterionKey: "included_custom_question", Label: "Them cau hoi bo sung", Met: customQuestion, Comment: boolComment(customQuestion, "Ban da them mot cau hoi bo sung hop ly.", "Neu duoc, hay them mot cau hoi bo sung tu nhien hon.")},
	}

	return criteria, bandFromCriteria(criteria)
}

func evaluateStoryNarration(exercise contracts.Exercise, transcript string) ([]contracts.CriterionCheck, string) {
	sequenceMarkers := []string{"nejdriv", "pak", "nakonec", "potom"}
	pastVerbs := []string{"byli", "byla", "byl", "koupili", "odvezli", "jela", "vezli", "sli", "udelali", "videli", "rekli"}

	detail, detailOK := extractUloha3Detail(exercise.Detail)
	checkpoints := detail.NarrativeCheckpoints
	grammarFocus := detail.GrammarFocus

	coverageRatio := 0.0
	if detailOK && len(checkpoints) > 0 {
		coverageRatio = checkpointCoverage(transcript, checkpoints)
	}
	coveredEvents := coverageRatio >= 0.5 ||
		(len(checkpoints) == 0 && countMatches(transcript, sequenceMarkers) >= 2)

	markerHits := countMatches(transcript, sequenceMarkers)
	hasSequence := markerHits >= 2 ||
		(markerHits >= 1 && coverageRatio >= 0.5) ||
		(len(checkpoints) >= 2 && checkpointsInOrder(transcript, checkpoints))

	pastHits := countMatches(transcript, pastVerbs)
	grammarHit := len(grammarFocus) > 0 && containsAny(transcript, tokenizeAll(grammarFocus))
	hasStoryLanguage := pastHits >= 2 || (pastHits >= 1 && grammarHit)

	coveredComment := boolComment(coveredEvents,
		"Ban da nhac den nhieu moc chinh cua cau chuyen.",
		"Hay nhac them cac buoc quan trong cua cau chuyen.")
	if !coveredEvents && len(checkpoints) > 0 {
		missing := missingCheckpoints(transcript, checkpoints, 2)
		if len(missing) > 0 {
			coveredComment = "Hay nhac den: " + strings.Join(missing, "; ") + "."
		}
	}

	criteria := []contracts.CriterionCheck{
		{CriterionKey: "covered_story_events", Label: "Bao quat cac su kien chinh", Met: coveredEvents, Comment: coveredComment},
		{CriterionKey: "narrative_sequence_present", Label: "Co trinh tu ke chuyen", Met: hasSequence, Comment: boolComment(hasSequence, "Ban da ke theo mot trinh tu de theo doi.", "Hay them tu noi thu tu nhu nejdriv, pak, nakonec.")},
		{CriterionKey: "used_story_language", Label: "Dung ngon ngu ke chuyen", Met: hasStoryLanguage, Comment: boolComment(hasStoryLanguage, "Ban da dung cach noi phu hop de ke chuyen.", "Hay dung them dong tu o qua khu (byl, sli, videli...).")},
	}

	return criteria, bandFromCriteria(criteria)
}

func evaluateChoiceReasoning(exercise contracts.Exercise, transcript string) ([]contracts.CriterionCheck, string) {
	detail, detailOK := extractUloha4Detail(exercise.Detail)
	choiceVerbs := []string{"vybiram", "volim", "chci", "beru", "vyberu", "vybral", "vybrala"}

	var identifiedOption *contracts.ChoiceOption
	if detailOK {
		for i := range detail.Options {
			opt := detail.Options[i]
			if optionMentioned(transcript, opt) {
				identifiedOption = &detail.Options[i]
				break
			}
		}
	}

	madeChoice := identifiedOption != nil || containsAny(transcript, choiceVerbs)

	axisHit := false
	matchedAxis := ""
	if detailOK {
		for _, axis := range detail.ExpectedReasoningAxes {
			tokens := contentTokens(axis)
			if len(tokens) > 0 && containsAny(transcript, tokens) {
				axisHit = true
				matchedAxis = axis
				break
			}
		}
	}
	gaveReason := strings.Contains(transcript, "protoze") || axisHit

	reasonMatchesChoice := identifiedOption != nil && gaveReason
	if reasonMatchesChoice && detailOK && identifiedOption != nil && matchedAxis != "" {
		reasonMatchesChoice = tokensCoOccur(transcript, contentTokens(identifiedOption.Label), contentTokens(matchedAxis), 12)
	}

	choiceComment := boolComment(madeChoice,
		"Ban da noi ro minh chon phuong an nao.",
		"Hay noi ro ban chon phuong an nao truoc.")
	if !madeChoice && detailOK && len(detail.Options) > 0 {
		names := make([]string, 0, len(detail.Options))
		for _, o := range detail.Options {
			if o.Label != "" {
				names = append(names, o.Label)
			}
		}
		if len(names) > 0 {
			choiceComment = "Hay bat dau bang cau \"Vybiram...\" voi mot trong: " + strings.Join(names, ", ") + "."
		}
	}

	criteria := []contracts.CriterionCheck{
		{CriterionKey: "made_clear_choice", Label: "Dua ra lua chon ro rang", Met: madeChoice, Comment: choiceComment},
		{CriterionKey: "gave_reason", Label: "Dua ra ly do", Met: gaveReason, Comment: boolComment(gaveReason, "Ban da giai thich vi sao minh chon nhu vay.", "Hay them it nhat mot ly do voi tu \"protoze\".")},
		{CriterionKey: "reason_matches_choice", Label: "Ly do khop voi lua chon", Met: reasonMatchesChoice, Comment: boolComment(reasonMatchesChoice, "Ly do cua ban phu hop voi lua chon.", "Hay noi ly do gan sat hon voi phuong an duoc chon.")},
	}

	return criteria, bandFromCriteria(criteria)
}

func checkpointCoverage(transcript string, checkpoints []string) float64 {
	if len(checkpoints) == 0 {
		return 0
	}
	hit := 0
	for _, cp := range checkpoints {
		tokens := contentTokens(cp)
		if len(tokens) == 0 {
			continue
		}
		if containsAny(transcript, tokens) {
			hit++
		}
	}
	return float64(hit) / float64(len(checkpoints))
}

func checkpointsInOrder(transcript string, checkpoints []string) bool {
	pos := 0
	for _, cp := range checkpoints {
		tokens := contentTokens(cp)
		if len(tokens) == 0 {
			continue
		}
		nextPos := -1
		for _, t := range tokens {
			idx := strings.Index(transcript[pos:], t)
			if idx >= 0 && (nextPos < 0 || idx < nextPos) {
				nextPos = idx
			}
		}
		if nextPos < 0 {
			return false
		}
		pos += nextPos + 1
	}
	return true
}

func missingCheckpoints(transcript string, checkpoints []string, maxCount int) []string {
	missing := make([]string, 0, maxCount)
	for _, cp := range checkpoints {
		tokens := contentTokens(cp)
		if len(tokens) == 0 {
			continue
		}
		if !containsAny(transcript, tokens) {
			missing = append(missing, cp)
			if len(missing) >= maxCount {
				break
			}
		}
	}
	return missing
}

func optionMentioned(transcript string, opt contracts.ChoiceOption) bool {
	candidates := make([]string, 0, 4)
	candidates = append(candidates, contentTokens(opt.Label)...)
	candidates = append(candidates, contentTokens(opt.Description)...)
	if opt.OptionKey != "" {
		candidates = append(candidates, strings.ToLower(opt.OptionKey))
	}
	return containsAny(transcript, candidates)
}

var stopwordsCzech = map[string]struct{}{
	"a": {}, "i": {}, "v": {}, "s": {}, "k": {}, "o": {}, "u": {}, "z": {},
	"do": {}, "na": {}, "se": {}, "si": {}, "je": {}, "to": {}, "ten": {}, "ta": {},
	"mi": {}, "my": {}, "ja": {}, "on": {}, "ona": {}, "ho": {}, "by": {},
	"co": {}, "ze": {}, "az": {}, "za": {}, "po": {}, "pro": {},
}

func contentTokens(text string) []string {
	if text == "" {
		return nil
	}
	normalized := normalizeTranscript(text)
	words := strings.Fields(normalized)
	tokens := make([]string, 0, len(words))
	for _, w := range words {
		if len(w) < 3 {
			continue
		}
		if _, stop := stopwordsCzech[w]; stop {
			continue
		}
		tokens = append(tokens, w)
	}
	return tokens
}

func tokenizeAll(items []string) []string {
	out := make([]string, 0, len(items)*2)
	for _, item := range items {
		out = append(out, contentTokens(item)...)
	}
	return out
}

func tokensCoOccur(transcript string, a, b []string, window int) bool {
	if len(a) == 0 || len(b) == 0 {
		return false
	}
	words := strings.Fields(transcript)
	aIdx := firstIndex(words, a)
	bIdx := firstIndex(words, b)
	if aIdx < 0 || bIdx < 0 {
		return false
	}
	diff := aIdx - bIdx
	if diff < 0 {
		diff = -diff
	}
	return diff <= window
}

func firstIndex(words []string, needles []string) int {
	for i, w := range words {
		for _, n := range needles {
			if strings.Contains(w, n) {
				return i
			}
		}
	}
	return -1
}

func evaluateGrammar(transcript string, reliability transcriptReliability) contracts.GrammarFeedback {
	issues := make([]contracts.GrammarIssue, 0, 2)
	scoreBand := "strong"

	if wordCount(transcript) < 5 {
		scoreBand = "weak"
		issues = append(issues, contracts.GrammarIssue{
			IssueKey:   "answer_too_short",
			Label:      "Cau tra loi con ngan",
			Comment:    "Phan noi hien tai hoi ngan nen chua the hien du y.",
			ExampleFix: "Mam rad teple pocasi, protoze muzu byt dlouho venku s rodinou.",
		})
	} else if wordCount(transcript) < 10 {
		scoreBand = "ok"
		issues = append(issues, contracts.GrammarIssue{
			IssueKey:   "detail_depth",
			Label:      "Can them do cu the",
			Comment:    "Cau tra loi de hieu nhung van co the tu nhien hon neu them chi tiet.",
			ExampleFix: "Mam rad teple pocasi, protoze muzu byt dlouho venku s rodinou a chodit do parku.",
		})
	}

	if reliability == reliabilityUsableWithWarnings {
		scoreBand = "weak"
		issues = append(issues, contracts.GrammarIssue{
			IssueKey:   "transcript_reliability",
			Label:      "Do ro cua ban ghi am",
			Comment:    "Ban ghi am hoi ngan nen he thong chi dua ra nhan xet an toan.",
			ExampleFix: "Thu noi ro hon va giu am luong deu trong toan bo cau tra loi.",
		})
	}

	if len(issues) == 0 {
		issues = append(issues, contracts.GrammarIssue{
			IssueKey:   "clarity",
			Label:      "Do ro va tu nhien",
			Comment:    "Cau tra loi kha ro, ban co the tiep tuc giu nhip noi nay.",
			ExampleFix: transcript,
		})
	}

	return contracts.GrammarFeedback{
		ScoreBand:        scoreBand,
		Issues:           issues,
		RewrittenExample: transcript,
	}
}

func mapReadiness(taskBand, grammarBand string, reliability transcriptReliability) string {
	switch {
	case taskBand == "weak":
		return "not_ready"
	case taskBand == "ok" && grammarBand == "weak":
		return "needs_work"
	case taskBand == "strong" && (grammarBand == "ok" || grammarBand == "strong"):
		if reliability == reliabilityUsableWithWarnings {
			return "almost_ready"
		}
		return "ready_for_mock"
	default:
		return "almost_ready"
	}
}

func buildSummary(exercise contracts.Exercise, readiness string, reliability transcriptReliability, criteria []contracts.CriterionCheck) string {
	switch exercise.ExerciseType {
	case "uloha_1_topic_answers":
		return buildUloha1Summary(exercise, readiness, reliability, criteria)
	case "uloha_2_dialogue_questions":
		return buildUloha2Summary(exercise, readiness, reliability, criteria)
	}

	base := map[string]string{
		"not_ready":      "Ban da bat dau dung huong, nhung can lam ro yeu cau bai noi hon truoc khi vao mock exam.",
		"needs_work":     "Ban tra loi dung y chinh, nhung can noi dai hon va ro hon de giong bai thi that.",
		"almost_ready":   "Ban dang o gan muc on, chi can them vai chi tiet cu the de bai noi thuyet phuc hon.",
		"ready_for_mock": "Ban hoan thanh bai noi kha chac chan va co the chuyen sang buoc luyen mock.",
	}

	summary := base[readiness]
	if summary == "" {
		summary = base["needs_work"]
	}
	if reliability == reliabilityUsableWithWarnings {
		summary += " Ban ghi am nay hoi ngan, vi vay nen hay thu noi ro hon o lan tiep theo."
	}
	if exercise.ExerciseType == "uloha_3_story_narration" && readiness != "not_ready" {
		summary = "Ban da giu duoc mach ke chuyen co ban, bay gio hay lam noi bat hon trinh tu va chi tiet cua tung tranh."
	}
	return summary
}

func buildStrengths(criteria []contracts.CriterionCheck) []string {
	var strengths []string
	for _, criterion := range criteria {
		if criterion.Met {
			strengths = append(strengths, criterionStrength(criterion.CriterionKey))
		}
		if len(strengths) == 3 {
			break
		}
	}
	return strengths
}

func buildImprovements(criteria []contracts.CriterionCheck, reliability transcriptReliability) []string {
	var improvements []string
	for _, criterion := range criteria {
		if !criterion.Met {
			improvements = append(improvements, criterionImprovement(criterion.CriterionKey))
		}
		if len(improvements) == 3 {
			break
		}
	}
	if reliability == reliabilityUsableWithWarnings && len(improvements) < 3 {
		improvements = append(improvements, "Thu ghi am ro hon va noi them 1-2 cau de he thong danh gia on dinh hon.")
	}
	return improvements
}

func buildRetryAdvice(exercise contracts.Exercise, criteria []contracts.CriterionCheck, reliability transcriptReliability) []string {
	switch exercise.ExerciseType {
	case "uloha_1_topic_answers":
		return buildUloha1RetryAdvice(exercise, criteria, reliability)
	case "uloha_2_dialogue_questions":
		return buildUloha2RetryAdvice(exercise, criteria, reliability)
	}

	advice := []string{
		"Thu lam lai va giu phan tra loi trong khoang 20-30 giay.",
	}
	switch exercise.ExerciseType {
	case "uloha_3_story_narration":
		advice = append(advice, "Hay nhac den tung buc tranh theo thu tu nejdriv, pak, nakonec.")
	case "uloha_4_choice_reasoning":
		advice = append(advice, "Noi ro ban chon phuong an nao truoc, roi them it nhat mot ly do.")
	case "uloha_2_dialogue_questions":
		advice = append(advice, "Hay dat 2-3 cau hoi day du thay vi chi noi tu khoa.")
	default:
		advice = append(advice, "Them mot ly do ngan voi protoze de cau tra loi thuyet phuc hon.")
	}
	if reliability == reliabilityUsableWithWarnings {
		advice = append(advice, "Thu noi cham hon va giu am luong deu tu dau den cuoi.")
	}
	return advice
}

func buildUloha1Summary(exercise contracts.Exercise, readiness string, reliability transcriptReliability, criteria []contracts.CriterionCheck) string {
	topic := firstNonEmpty(topicTokens(exercise)...)
	if topic == "" {
		topic = "chu de nay"
	}

	switch {
	case !criterionMetByKey(criteria, "answered_question"):
		return fmt.Sprintf("Ban can tra loi truc tiep hon vao cau hoi ve %s truoc khi them y phu.", topic)
	case !criterionMetByKey(criteria, "stayed_on_topic"):
		return fmt.Sprintf("Ban da bat dau noi, nhung can bam sat hon vao chu de %s de bai noi dung trong tam hon.", topic)
	case !criterionMetByKey(criteria, "gave_supporting_detail"):
		summary := fmt.Sprintf("Ban dang bam dung chu de %s, nhung can them mot ly do hoac chi tiet cu the de cau tra loi day hon.", topic)
		if reliability == reliabilityUsableWithWarnings {
			summary += " Ban ghi am nay hoi ngan, nen hay noi ro hon o lan tiep theo."
		}
		return summary
	case readiness == "ready_for_mock":
		return fmt.Sprintf("Ban tra loi kha chac chan ve %s va da co ly do/chi tiet ho tro, nen co the chuyen sang muc tap kho hon.", topic)
	default:
		summary := fmt.Sprintf("Ban da tra loi dung chu de %s va dang di dung huong, bay gio hay giu cau tra loi ro rang va tu nhien hon nua.", topic)
		if reliability == reliabilityUsableWithWarnings {
			summary += " Ban ghi am nay hoi ngan, vi vay nen hay thu noi ro hon o lan tiep theo."
		}
		return summary
	}
}

func buildUloha2Summary(exercise contracts.Exercise, readiness string, reliability transcriptReliability, criteria []contracts.CriterionCheck) string {
	scenario := uloha2ScenarioTitle(exercise)
	if scenario == "" {
		scenario = "tinh huong nay"
	}

	switch {
	case !criterionMetByKey(criteria, "covered_required_slots"):
		return fmt.Sprintf("Trong %s, ban can hoi them nhung thong tin chinh de nguoi nghe thay ro muc tieu cua cuoc hoi.", scenario)
	case !criterionMetByKey(criteria, "used_question_form"):
		return fmt.Sprintf("Trong %s, y hoi cua ban da co huong dung, nhung can chuyen thanh cau hoi day du hon.", scenario)
	case !criterionMetByKey(criteria, "included_custom_question"):
		return fmt.Sprintf("Ban da hoi duoc phan chinh trong %s; buoc tiep theo la them mot cau hoi bo sung de bai noi giong tinh huong thi that hon.", scenario)
	case readiness == "ready_for_mock":
		return fmt.Sprintf("Ban da hoi thong tin kha tu nhien trong %s va dang o muc san sang de tap mock.", scenario)
	default:
		summary := fmt.Sprintf("Ban dang hoi thong tin dung huong trong %s; hay tiep tuc giu dang cau hoi ro rang va day du.", scenario)
		if reliability == reliabilityUsableWithWarnings {
			summary += " Ban ghi am nay hoi ngan, vi vay nen hay thu noi ro hon o lan tiep theo."
		}
		return summary
	}
}

func buildUloha1RetryAdvice(exercise contracts.Exercise, criteria []contracts.CriterionCheck, reliability transcriptReliability) []string {
	topic := firstNonEmpty(topicTokens(exercise)...)
	if topic == "" {
		topic = "chu de bai tap"
	}

	advice := []string{"Mo dau bang 1 cau tra loi truc tiep vao cau hoi chinh."}
	if !criterionMetByKey(criteria, "stayed_on_topic") {
		advice = append(advice, fmt.Sprintf("Lap lai tu khoa %s ngay o cau dau de giu bai noi dung chu de.", topic))
	}
	if !criterionMetByKey(criteria, "gave_supporting_detail") {
		advice = append(advice, "Them mot ve sau tu protoze hoac mot chi tiet cu the sau cau dau tien.")
	}
	if reliability == reliabilityUsableWithWarnings {
		advice = append(advice, "Thu noi cham hon va giu am luong deu tu dau den cuoi.")
	}
	return advice
}

func buildUloha2RetryAdvice(exercise contracts.Exercise, criteria []contracts.CriterionCheck, reliability transcriptReliability) []string {
	advice := []string{"Bat dau bang 1 cau hoi day du thay vi chi noi tu khoa."}
	if !criterionMetByKey(criteria, "covered_required_slots") {
		advice = append(advice, "Dat it nhat 2-3 cau hoi ve gia, thoi gian, dia diem hoac thong tin bat buoc cua tinh huong.")
	}
	if !criterionMetByKey(criteria, "used_question_form") {
		advice = append(advice, "Thu dung mau hoi ngan nhu V kolik hodin...?, Kolik to stoji?, Kde to je?")
	}
	if !criterionMetByKey(criteria, "included_custom_question") {
		advice = append(advice, "Ket thuc bang mot cau hoi bo sung tu nhien nhu online, rezervace hoac telefon.")
	}
	if reliability == reliabilityUsableWithWarnings {
		advice = append(advice, "Thu noi cham hon va giu am luong deu tu dau den cuoi.")
	}
	return advice
}

func sampleAnswerForExercise(exerciseType string) string {
	switch exerciseType {
	case "uloha_3_story_narration":
		return "Nejdriv prisli do obchodu, potom koupili televizi a nakonec ji odvezli domu."
	case "uloha_4_choice_reasoning":
		return "Vybiram park, protoze je klidny a muzeme tam byt dlouho venku."
	case "uloha_2_dialogue_questions":
		return "Dobry den, v kolik hodin to zacina, kolik to stoji a je nutna rezervace?"
	default:
		return "Mam rad teple pocasi, protoze muzu byt dlouho venku s rodinou a chodit do parku."
	}
}

func bandFromCriteria(criteria []contracts.CriterionCheck) string {
	metCount := 0
	for _, criterion := range criteria {
		if criterion.Met {
			metCount++
		}
	}
	switch {
	case metCount == len(criteria):
		return "strong"
	case metCount >= len(criteria)-1:
		return "ok"
	default:
		return "weak"
	}
}

func topicTokens(exercise contracts.Exercise) []string {
	switch prompt := exercise.Prompt.(type) {
	case contracts.Uloha1Prompt:
		return []string{prompt.TopicLabel}
	case *contracts.Uloha1Prompt:
		if prompt == nil {
			return nil
		}
		return []string{prompt.TopicLabel}
	case map[string]any:
		if topic, ok := prompt["topic_label"].(string); ok {
			return []string{topic}
		}
	}
	return []string{exercise.Title}
}

func uloha2ScenarioTitle(exercise contracts.Exercise) string {
	switch detail := exercise.Detail.(type) {
	case contracts.Uloha2Detail:
		return strings.TrimSpace(detail.ScenarioTitle)
	case *contracts.Uloha2Detail:
		if detail == nil {
			return ""
		}
		return strings.TrimSpace(detail.ScenarioTitle)
	case map[string]any:
		if title, ok := detail["scenario_title"].(string); ok {
			return strings.TrimSpace(title)
		}
	}
	return ""
}

func uloha2Detail(exercise contracts.Exercise) contracts.Uloha2Detail {
	switch detail := exercise.Detail.(type) {
	case contracts.Uloha2Detail:
		return detail
	case *contracts.Uloha2Detail:
		if detail != nil {
			return *detail
		}
	case map[string]any:
		out := contracts.Uloha2Detail{}
		if title, ok := detail["scenario_title"].(string); ok {
			out.ScenarioTitle = strings.TrimSpace(title)
		}
		if prompt, ok := detail["scenario_prompt"].(string); ok {
			out.ScenarioPrompt = strings.TrimSpace(prompt)
		}
		if hint, ok := detail["custom_question_hint"].(string); ok {
			out.CustomQuestionHint = strings.TrimSpace(hint)
		}
		if slots, ok := detail["required_info_slots"].([]any); ok {
			for _, raw := range slots {
				slotMap, ok := raw.(map[string]any)
				if !ok {
					continue
				}
				slot := contracts.RequiredInfoSlot{}
				if slotKey, ok := slotMap["slot_key"].(string); ok {
					slot.SlotKey = slotKey
				}
				if label, ok := slotMap["label"].(string); ok {
					slot.Label = label
				}
				if sample, ok := slotMap["sample_question"].(string); ok {
					slot.SampleQuestion = sample
				}
				out.RequiredInfoSlots = append(out.RequiredInfoSlots, slot)
			}
		}
		return out
	}
	return contracts.Uloha2Detail{}
}

func uloha2RequiredQuestions(exercise contracts.Exercise) []string {
	detail := uloha2Detail(exercise)
	questions := make([]string, 0, len(detail.RequiredInfoSlots))
	for _, slot := range detail.RequiredInfoSlots {
		question := strings.TrimSpace(slot.SampleQuestion)
		if question == "" {
			continue
		}
		questions = append(questions, ensureQuestionMark(question))
	}
	return uniqueNonEmptyStrings(questions)
}

func matchedRequiredSlotQuestions(exercise contracts.Exercise, transcript string) []string {
	detail := uloha2Detail(exercise)
	questions := make([]string, 0, len(detail.RequiredInfoSlots))
	for _, slot := range detail.RequiredInfoSlots {
		if !uloha2SlotCovered(slot, transcript) {
			continue
		}
		question := strings.TrimSpace(slot.SampleQuestion)
		if question == "" {
			continue
		}
		questions = append(questions, ensureQuestionMark(question))
	}
	return uniqueNonEmptyStrings(questions)
}

func missingRequiredSlotQuestions(exercise contracts.Exercise, transcript string) []string {
	detail := uloha2Detail(exercise)
	questions := make([]string, 0, len(detail.RequiredInfoSlots))
	for _, slot := range detail.RequiredInfoSlots {
		if uloha2SlotCovered(slot, transcript) {
			continue
		}
		question := strings.TrimSpace(slot.SampleQuestion)
		if question == "" {
			continue
		}
		questions = append(questions, ensureQuestionMark(question))
	}
	return uniqueNonEmptyStrings(questions)
}

func uloha2SlotCovered(slot contracts.RequiredInfoSlot, transcript string) bool {
	normalizedSlotKey := strings.ToLower(strings.TrimSpace(slot.SlotKey))
	switch {
	case strings.Contains(normalizedSlotKey, "start") || strings.Contains(normalizedSlotKey, "time"):
		return containsAny(transcript, []string{"v kolik", "kdy", "zacina", "zacatek"})
	case strings.Contains(normalizedSlotKey, "price"):
		return containsAny(transcript, []string{"kolik stoji", "stoji", "cena"})
	case strings.Contains(normalizedSlotKey, "online") || strings.Contains(normalizedSlotKey, "rezerv"):
		return containsAny(transcript, []string{"online", "rezerv", "internet"})
	default:
		return containsAny(transcript, uloha2SlotKeywords(slot))
	}
}

func uloha2SlotKeywords(slot contracts.RequiredInfoSlot) []string {
	keywords := []string{
		strings.ToLower(strings.TrimSpace(slot.Label)),
		strings.ToLower(strings.TrimSpace(slot.SampleQuestion)),
		strings.ToLower(strings.ReplaceAll(strings.TrimSpace(slot.SlotKey), "_", " ")),
	}
	return uniqueNonEmptyStrings(keywords)
}

func uloha2ExtraQuestion(exercise contracts.Exercise) string {
	hint := strings.ToLower(uloha2Detail(exercise).CustomQuestionHint)
	switch {
	case strings.Contains(hint, "titulky"):
		return "A jsou tam titulky?"
	case strings.Contains(hint, "sal"):
		return "A v jakem sale to je?"
	case strings.Contains(hint, "telefon"):
		return "A muzu tam zavolat?"
	case strings.Contains(hint, "online") || strings.Contains(hint, "rezerv"):
		return "A je nutna rezervace?"
	case hint != "":
		return "A muzu se jeste zeptat na dalsi detail?"
	default:
		return "A je nutna rezervace?"
	}
}

func ensureQuestionMark(text string) string {
	trimmed := strings.TrimSpace(text)
	if trimmed == "" {
		return ""
	}
	trimmed = strings.TrimRight(trimmed, ".!?")
	return trimmed + "?"
}

func uniqueNonEmptyStrings(values []string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		out = append(out, trimmed)
	}
	return out
}

func criterionMetByKey(criteria []contracts.CriterionCheck, key string) bool {
	for _, criterion := range criteria {
		if criterion.CriterionKey == key {
			return criterion.Met
		}
	}
	return false
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func normalizeTranscript(text string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
}

func containsAny(text string, terms []string) bool {
	normalizedText := strings.ToLower(text)
	for _, term := range terms {
		normalizedTerm := strings.ToLower(strings.TrimSpace(term))
		if normalizedTerm != "" && strings.Contains(normalizedText, normalizedTerm) {
			return true
		}
	}
	return false
}

func countMatches(text string, terms []string) int {
	matches := 0
	for _, term := range terms {
		if containsAny(text, []string{term}) {
			matches++
		}
	}
	return matches
}

func wordCount(text string) int {
	return len(strings.Fields(text))
}

func boolComment(condition bool, whenTrue, whenFalse string) string {
	if condition {
		return whenTrue
	}
	return whenFalse
}

func criterionStrength(key string) string {
	messages := map[string]string{
		"answered_question":          "Ban da tra loi dung cau hoi.",
		"stayed_on_topic":            "Ban giu noi dung dung chu de.",
		"gave_supporting_detail":     "Ban da them duoc ly do hoac chi tiet ho tro.",
		"covered_required_slots":     "Ban hoi duoc nhieu thong tin can thiet.",
		"used_question_form":         "Ban dat cau hoi theo cach de hieu.",
		"included_custom_question":   "Ban co them cau hoi bo sung hop ly.",
		"covered_story_events":       "Ban da bao quat duoc nhieu su kien trong cau chuyen.",
		"narrative_sequence_present": "Ban giu duoc trinh tu ke chuyen.",
		"used_story_language":        "Ban dung cach noi phu hop voi bai ke chuyen.",
		"made_clear_choice":          "Ban dua ra lua chon ro rang.",
		"gave_reason":                "Ban da noi ro ly do cho lua chon cua minh.",
		"reason_matches_choice":      "Ly do cua ban phu hop voi lua chon da dua ra.",
	}
	return messages[key]
}

func criterionImprovement(key string) string {
	messages := map[string]string{
		"answered_question":          "Hay tra loi truc tiep hon vao cau hoi chinh.",
		"stayed_on_topic":            "Hay bam sat hon vao chu de cua bai noi.",
		"gave_supporting_detail":     "Hay them mot ly do ngan hoac mot chi tiet cu the.",
		"covered_required_slots":     "Hay hoi them cac thong tin con thieu trong tinh huong.",
		"used_question_form":         "Hay dung dang cau hoi day du hon thay vi noi tu khoa.",
		"included_custom_question":   "Neu duoc, hay them mot cau hoi bo sung tu nhien hon.",
		"covered_story_events":       "Hay nhac den them cac su kien chinh cua cau chuyen.",
		"narrative_sequence_present": "Hay them tu noi thu tu de bai ke chuyen ro hon.",
		"used_story_language":        "Hay noi theo mach cau chuyen thay vi tach thanh cum tu ngan.",
		"made_clear_choice":          "Hay noi ro ngay tu dau ban chon phuong an nao.",
		"gave_reason":                "Hay them it nhat mot ly do cho lua chon cua ban.",
		"reason_matches_choice":      "Hay noi ly do gan sat hon voi phuong an da chon.",
	}
	if message := messages[key]; message != "" {
		return message
	}
	return "Hay noi ro hon va them mot chi tiet cu the."
}
