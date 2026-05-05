package contracts

import (
	"encoding/json"
	"testing"
)

func TestDictationDetail_JSONRoundTrip(t *testing.T) {
	want := DictationDetail{
		Topic:               "Trong quán cafe",
		ContextImageAssetID: "img-123",
		Sentences: []DictationSentence{
			{Idx: 0, Text: "Pavel jde do kavárny.", AudioAssetID: "a-0"},
			{Idx: 1, Text: "Chce si dát čaj a koláč.", AudioAssetID: "a-1"},
		},
		MaxReplaysPerSentence: 3,
		VoiceID:               "Tomas",
		MaxPoints:             10,
		PassThresholdPercent:  60,
	}

	raw, err := json.Marshal(want)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var got DictationDetail
	if err := json.Unmarshal(raw, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if got.Topic != want.Topic {
		t.Errorf("topic: want %q got %q", want.Topic, got.Topic)
	}
	if len(got.Sentences) != len(want.Sentences) {
		t.Fatalf("sentences len: want %d got %d", len(want.Sentences), len(got.Sentences))
	}
	if got.Sentences[1].Text != want.Sentences[1].Text {
		t.Errorf("sentence[1] text round-trip failed: %q", got.Sentences[1].Text)
	}
	if got.MaxReplaysPerSentence != 3 || got.PassThresholdPercent != 60 {
		t.Errorf("scalar fields lost: %+v", got)
	}
}

func TestDictationDetail_OmitEmpty(t *testing.T) {
	d := DictationDetail{
		Topic: "x",
		Sentences: []DictationSentence{
			{Idx: 0, Text: "Ahoj."},
		},
	}
	raw, err := json.Marshal(d)
	if err != nil {
		t.Fatal(err)
	}
	s := string(raw)
	if containsField(s, "context_image_asset_id") {
		t.Errorf("empty context_image_asset_id should be omitted: %s", s)
	}
	if containsField(s, "audio_asset_id") {
		t.Errorf("empty audio_asset_id should be omitted: %s", s)
	}
}

func TestDictationSubmission_JSONRoundTrip(t *testing.T) {
	want := DictationSubmission{
		Sentences: []DictationSentenceAnswer{
			{Idx: 0, Text: "Pavel jde do kavárny.", ReplayCount: 1},
			{Idx: 1, Text: "Chce si dát čaj.", ReplayCount: 3},
		},
	}
	raw, _ := json.Marshal(want)
	var got DictationSubmission
	if err := json.Unmarshal(raw, &got); err != nil {
		t.Fatal(err)
	}
	if len(got.Sentences) != 2 {
		t.Fatalf("len: %d", len(got.Sentences))
	}
	if got.Sentences[1].ReplayCount != 3 {
		t.Errorf("replay_count lost: %d", got.Sentences[1].ReplayCount)
	}
}

func TestDictationFeedback_JSONShape(t *testing.T) {
	fb := DictationFeedback{
		OverallScore:     7,
		MaxPoints:        10,
		Passed:           true,
		PassThresholdPct: 60,
		Sentences: []DictationSentenceScore{
			{
				Idx:              0,
				Reference:        "Pavel jde do kavárny.",
				Learner:          "Pavel jde do kavarny.",
				Accuracy:         0.91,
				DistanceWeighted: 1.0,
				ErrorTags:        []string{"missing_diacritic"},
				FeedbackVI:       "Bạn quên dấu trên 'a'.",
				DiffChunks: []DiffChunk{
					{Kind: "replaced", SourceText: "kavárny", TargetText: "kavarny"},
				},
			},
		},
	}
	raw, err := json.Marshal(fb)
	if err != nil {
		t.Fatal(err)
	}
	if !containsField(string(raw), "pass_threshold_percent") {
		t.Errorf("pass_threshold_percent json tag missing: %s", string(raw))
	}
	if !containsField(string(raw), "distance_weighted") {
		t.Errorf("distance_weighted json tag missing: %s", string(raw))
	}
}

func containsField(s, field string) bool {
	return len(s) > 0 && (containsSub(s, "\""+field+"\":"))
}

func containsSub(s, sub string) bool {
	return len(s) >= len(sub) && (indexOf(s, sub) >= 0)
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
