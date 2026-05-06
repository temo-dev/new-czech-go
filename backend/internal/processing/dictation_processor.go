package processing

// dictation_processor.go — V18 ProcessDictationAttempt orchestrator.
//
// The HTTP layer parses + validates the submission, then spawns this method
// in a goroutine. Deterministic scoring (V18-A2) runs synchronously here;
// LLM annotation (V18-A3) runs after but never blocks the score — failure
// just leaves error_tags / feedback_vi empty and the result UI falls back
// to the deterministic-only diff.

import (
	"log"
	"sort"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// ProcessDictationAttempt scores a psani_3_dictation submission. Steps:
//  1. Load the attempt + exercise.
//  2. Extract DictationDetail from the exercise body.
//  3. Compute the deterministic per-sentence + overall score.
//  4. Best-effort LLM annotation (error_tags, feedback_vi/en, diff_chunks);
//     fallback strings filled from dictationFallbackFeedback on LLM failure.
//  5. Persist DictationFeedback embedded inside AttemptFeedback and mark
//     the attempt completed.
//
// Panics inside this method are recovered and the attempt is marked failed.
func (p *Processor) ProcessDictationAttempt(attemptID string, sub contracts.DictationSubmission) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("dictation attempt %s: panic recovered: %v", attemptID, r)
			p.repo.FailAttempt(attemptID, "scoring_failed")
		}
	}()

	attempt, ok := p.repo.Attempt(attemptID)
	if !ok {
		log.Printf("dictation attempt %s not found", attemptID)
		return
	}
	exercise, ok := p.repo.Exercise(attempt.ExerciseID)
	if !ok {
		log.Printf("dictation attempt %s: exercise %s not found", attemptID, attempt.ExerciseID)
		p.repo.FailAttempt(attemptID, "scoring_failed")
		return
	}

	detail, ok := ExtractDictationDetail(exercise.Detail)
	if !ok {
		log.Printf("dictation attempt %s: could not parse detail for exercise %s", attemptID, attempt.ExerciseID)
		p.repo.FailAttempt(attemptID, "scoring_failed")
		return
	}

	refs := make([]string, len(detail.Sentences))
	for i, s := range detail.Sentences {
		refs[i] = s.Text
	}
	learners := alignDictationLearners(detail.Sentences, sub.Sentences)

	maxPoints := detail.MaxPoints
	if maxPoints <= 0 {
		maxPoints = 10
	}
	threshold := detail.PassThresholdPercent
	if threshold <= 0 {
		threshold = 60
	}

	feedback := ComputeDictationScore(refs, learners, maxPoints, threshold)
	// Fill audio_asset_id per sentence so the result UI can replay each row.
	for i := range feedback.Sentences {
		if i < len(detail.Sentences) {
			feedback.Sentences[i].AudioAssetID = detail.Sentences[i].AudioAssetID
		}
	}

	// Best-effort LLM annotation. Skip when the provider is unset or returns
	// an error — deterministic score + fallback feedback still ship.
	annotateWithLLM(p.dictationProvider, feedback.Sentences)

	// Persist via AttemptFeedback so downstream machinery (CompleteAttempt,
	// repo writes, observers) keeps its existing shape.
	wrapped := contracts.AttemptFeedback{
		ReadinessLevel:  readinessFromDictationScore(feedback),
		OverallSummary:  dictationOverallSummary(feedback),
		Strengths:       []string{},
		Improvements:    []string{},
		RetryAdvice:     []string{},
		TaskCompletion:  contracts.TaskCompletion{ScoreBand: dictationScoreBand(feedback)},
		GrammarFeedback: contracts.GrammarFeedback{ScoreBand: dictationScoreBand(feedback)},
		DictationResult: &feedback,
	}

	transcript := contracts.Transcript{
		FullText:    joinDictationLearnerText(feedback.Sentences),
		Locale:      "cs",
		Confidence:  1.0,
		Provider:    "learner_text",
		IsSynthetic: true,
	}
	p.completeAttempt(attemptID, exercise, transcript, wrapped)

	log.Printf("dictation attempt %s completed (score=%d/%d passed=%v)", attemptID, feedback.OverallScore, feedback.MaxPoints, feedback.Passed)
}

// alignDictationLearners returns one learner-text string per detail sentence,
// filling missing entries with empty strings. Submissions are tolerated in
// any order: validators upstream guarantee the count matches and idx values
// are in [0, N), so we sort + index.
func alignDictationLearners(refs []contracts.DictationSentence, answers []contracts.DictationSentenceAnswer) []string {
	out := make([]string, len(refs))
	sorted := append([]contracts.DictationSentenceAnswer(nil), answers...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].Idx < sorted[j].Idx })
	for _, ans := range sorted {
		if ans.Idx >= 0 && ans.Idx < len(out) {
			out[ans.Idx] = ans.Text
		}
	}
	return out
}

// annotateWithLLM enriches each sentence score with error_tags + feedback
// when the LLM provider is configured. Failures are logged but never raise.
// When provider is nil OR returns an error, fallback feedback strings fill
// in based on per-sentence accuracy.
func annotateWithLLM(provider DictationFeedbackProvider, scores []contracts.DictationSentenceScore) {
	if len(scores) == 0 {
		return
	}
	if provider == nil {
		provider = DevDictationFeedbackProvider{}
	}
	inputs := make([]DictationLLMInput, 0, len(scores))
	for _, s := range scores {
		inputs = append(inputs, DictationLLMInput{
			Idx:              s.Idx,
			Reference:        s.Reference,
			Learner:          s.Learner,
			DistanceWeighted: s.DistanceWeighted,
		})
	}
	annotations, err := provider.Annotate(inputs)
	if err != nil {
		log.Printf("dictation LLM annotation failed: %v", err)
		fillDictationFallback(scores)
		return
	}
	if len(annotations) == 0 {
		// Dev provider returns nil; that's fine — use fallback strings.
		fillDictationFallback(scores)
		return
	}
	byIdx := make(map[int]DictationLLMAnnotation, len(annotations))
	for _, a := range annotations {
		byIdx[a.Idx] = a
	}
	for i := range scores {
		if a, ok := byIdx[scores[i].Idx]; ok {
			scores[i].ErrorTags = a.ErrorTags
			scores[i].FeedbackVI = a.FeedbackVI
			scores[i].FeedbackEN = a.FeedbackEN
			scores[i].DiffChunks = a.DiffChunks
		} else {
			scores[i].FeedbackVI = dictationFallbackFeedback(scores[i].Idx, scores[i].Accuracy)
		}
	}
}

func fillDictationFallback(scores []contracts.DictationSentenceScore) {
	for i := range scores {
		if scores[i].FeedbackVI == "" {
			scores[i].FeedbackVI = dictationFallbackFeedback(scores[i].Idx, scores[i].Accuracy)
		}
	}
}

// EnrichDictationDetail rewrites the exercise detail map to populate each
// sentence's `audio_asset_id` from the most recent rows in
// ExerciseSentenceAudioStore. This decouples audio generation (admin clicks
// "Tạo audio" → exercise_sentence_audio table) from exercise persistence
// (admin clicks Save → exercises.detail.sentences). Without this, learners
// see "audio_asset_id":"" on sentences whose audio was generated AFTER the
// last form save, even though the MP3 exists on disk.
//
// Returns the original detail unchanged when it is not a dictation map.
func EnrichDictationDetail(detail any, audios []contracts.ExerciseSentenceAudio) any {
	if len(audios) == 0 {
		return detail
	}
	byIdx := make(map[int]string, len(audios))
	for _, a := range audios {
		byIdx[a.SentenceIdx] = a.StorageKey
	}
	if d, ok := detail.(contracts.DictationDetail); ok {
		for i := range d.Sentences {
			idx := d.Sentences[i].Idx
			if key, ok := byIdx[idx]; ok && key != "" {
				d.Sentences[i].AudioAssetID = key
			}
		}
		return d
	}
	m, ok := detail.(map[string]any)
	if !ok {
		return detail
	}
	rawSentences, ok := m["sentences"].([]any)
	if !ok {
		return detail
	}
	for i, s := range rawSentences {
		sm, ok := s.(map[string]any)
		if !ok {
			continue
		}
		idx := i
		if v, ok := sm["idx"].(float64); ok {
			idx = int(v)
		}
		if key, ok := byIdx[idx]; ok && key != "" {
			sm["audio_asset_id"] = key
		}
	}
	return m
}

// ExtractDictationDetail unmarshals a generic exercise.Detail into a typed
// DictationDetail. Mirrors extractPsani1Detail in llm_user_prompts.go.
// Exported because the HTTP submit-text handler calls it during validation.
func ExtractDictationDetail(v any) (contracts.DictationDetail, bool) {
	if d, ok := v.(contracts.DictationDetail); ok {
		return d, true
	}
	m, ok := v.(map[string]any)
	if !ok {
		return contracts.DictationDetail{}, false
	}
	d := contracts.DictationDetail{}
	if s, ok := m["topic"].(string); ok {
		d.Topic = s
	}
	if s, ok := m["context_image_asset_id"].(string); ok {
		d.ContextImageAssetID = s
	}
	if s, ok := m["voice_id"].(string); ok {
		d.VoiceID = s
	}
	if n, ok := m["max_replays_per_sentence"].(float64); ok {
		d.MaxReplaysPerSentence = int(n)
	}
	if n, ok := m["max_points"].(float64); ok {
		d.MaxPoints = int(n)
	}
	if n, ok := m["pass_threshold_percent"].(float64); ok {
		d.PassThresholdPercent = int(n)
	}
	if s, ok := m["submission_mode"].(string); ok {
		d.SubmissionMode = s
	}
	if arr, ok := m["sentences"].([]any); ok {
		for _, item := range arr {
			sm, ok := item.(map[string]any)
			if !ok {
				continue
			}
			s := contracts.DictationSentence{}
			if v, ok := sm["idx"].(float64); ok {
				s.Idx = int(v)
			}
			if v, ok := sm["text"].(string); ok {
				s.Text = v
			}
			if v, ok := sm["audio_asset_id"].(string); ok {
				s.AudioAssetID = v
			}
			d.Sentences = append(d.Sentences, s)
		}
	}
	return d, true
}

// readinessFromDictationScore maps the dictation Levenshtein-derived percentage
// to the canonical 4-band readiness vocab. `Passed` short-circuits to
// ready_for_mock so the deterministic threshold stays the source of truth.
func readinessFromDictationScore(fb contracts.DictationFeedback) string {
	if fb.Passed {
		return "ready_for_mock"
	}
	if fb.MaxPoints == 0 {
		return "not_ready"
	}
	pct := float64(fb.OverallScore) / float64(fb.MaxPoints)
	switch {
	case pct >= 0.60:
		return "almost_ready"
	case pct >= 0.30:
		return "needs_work"
	default:
		return "not_ready"
	}
}

func dictationScoreBand(fb contracts.DictationFeedback) string {
	if fb.Passed {
		return "ok"
	}
	return "needs_practice"
}

func dictationOverallSummary(fb contracts.DictationFeedback) string {
	if fb.Passed {
		return "Đã đạt ngưỡng. Hãy luyện thêm để chuẩn dấu phụ và viết hoa."
	}
	return "Chưa đạt ngưỡng. Hãy nghe lại từng câu và chú ý dấu phụ trong tiếng Czech."
}

func joinDictationLearnerText(scores []contracts.DictationSentenceScore) string {
	var out string
	for i, s := range scores {
		if i > 0 {
			out += "\n"
		}
		out += s.Learner
	}
	return out
}
