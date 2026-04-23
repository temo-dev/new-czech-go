package processing

import (
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func TestAmazonTranscriberBuildsMediaURIFromBucketAndStorageKey(t *testing.T) {
	transcriber := &AmazonTranscriber{audioBucket: "demo-audio-bucket"}

	uri, err := transcriber.mediaURI(contracts.AttemptAudio{
		StorageKey: "attempt-audio/attempt-1/audio.m4a",
	})
	if err != nil {
		t.Fatalf("mediaURI returned error: %v", err)
	}
	if uri != "s3://demo-audio-bucket/attempt-audio/attempt-1/audio.m4a" {
		t.Fatalf("unexpected media URI %q", uri)
	}
}

func TestReliabilityFromTranscriptWarnsForShortTranscriptAgainstLongAudio(t *testing.T) {
	reliability := reliabilityFromTranscript("ano ano ano", 0.91, 12000)
	if reliability != reliabilityUsableWithWarnings {
		t.Fatalf("expected usable_with_warnings, got %s", reliability)
	}
}

func TestTranscriptOutputKeyUsesPrefixAndJSONFilename(t *testing.T) {
	key := transcriptOutputKey("transcribe-output/dev", "attempt-123")
	if key != "transcribe-output/dev/attempt-123.json" {
		t.Fatalf("unexpected transcript output key %q", key)
	}
}

func TestParseS3URI(t *testing.T) {
	bucket, key, err := parseS3URI("s3://demo-bucket/transcribe-output/attempt-123.json")
	if err != nil {
		t.Fatalf("parseS3URI returned error: %v", err)
	}
	if bucket != "demo-bucket" || key != "transcribe-output/attempt-123.json" {
		t.Fatalf("unexpected parsed values bucket=%q key=%q", bucket, key)
	}
}

func TestMediaFormatForMimeSupportsCommonRecorderAliases(t *testing.T) {
	cases := map[string]string{
		"audio/mp4a-latm": "m4a",
		"audio/x-m4a":     "m4a",
		"audio/x-wav":     "wav",
		"audio/wave":      "wav",
	}

	for mimeType, expected := range cases {
		if actual := mediaFormatForMime(mimeType); actual != expected {
			t.Fatalf("expected media format %q for %q, got %q", expected, mimeType, actual)
		}
	}
}

func TestBuildStartTranscriptionJobInputOmitsClientReportedSampleRate(t *testing.T) {
	transcriber := &AmazonTranscriber{
		languageCode: "cs-CZ",
		outputBucket: "demo-output-bucket",
		outputPrefix: "transcribe-output",
	}

	input := transcriber.buildStartTranscriptionJobInput(
		"attempt-123",
		"s3://demo-audio-bucket/attempt-audio/attempt-123/audio.m4a",
		contracts.AttemptAudio{
			MimeType:     "audio/m4a",
			SampleRateHz: 44100,
		},
	)

	if input.MediaSampleRateHertz != nil {
		t.Fatalf("expected MediaSampleRateHertz to be omitted, got %d", aws.ToInt32(input.MediaSampleRateHertz))
	}
	if got := string(input.MediaFormat); got != "m4a" {
		t.Fatalf("expected media format m4a, got %q", got)
	}
	if got := aws.ToString(input.OutputBucketName); got != "demo-output-bucket" {
		t.Fatalf("expected output bucket demo-output-bucket, got %q", got)
	}
	if got := aws.ToString(input.OutputKey); got != "transcribe-output/attempt-123.json" {
		t.Fatalf("expected output key transcribe-output/attempt-123.json, got %q", got)
	}
}

func TestTranscriptResultURIUsesConfiguredOutputBucketWhenPresent(t *testing.T) {
	transcriber := &AmazonTranscriber{
		outputBucket: "demo-output-bucket",
		outputPrefix: "transcribe-output",
	}

	uri := transcriber.transcriptResultURI("attempt-123", "https://transcribe.example.invalid/transcript.json")
	if uri != "s3://demo-output-bucket/transcribe-output/attempt-123.json" {
		t.Fatalf("unexpected transcript result uri %q", uri)
	}
}

func TestTranscriptResultURIFallsBackToJobTranscriptURI(t *testing.T) {
	transcriber := &AmazonTranscriber{}

	uri := transcriber.transcriptResultURI("attempt-123", "https://transcribe.example.invalid/transcript.json")
	if uri != "https://transcribe.example.invalid/transcript.json" {
		t.Fatalf("unexpected transcript result uri %q", uri)
	}
}

func TestParseTranscriptPayloadMarksTranscriptAsReal(t *testing.T) {
	transcriber := &AmazonTranscriber{languageCode: "cs-CZ"}

	transcript, reliability, usable, err := transcriber.parseTranscriptPayload([]byte(`{
		"results": {
			"transcripts": [{"transcript": "Dobry den, ja jsem Daniel."}],
			"items": [{"type": "pronunciation", "alternatives": [{"confidence": "0.93"}]}]
		}
	}`), contracts.AttemptAudio{DurationMs: 8000})
	if err != nil {
		t.Fatalf("parseTranscriptPayload returned error: %v", err)
	}
	if !usable {
		t.Fatal("expected transcript to be usable")
	}
	if reliability == reliabilityUnusable {
		t.Fatalf("expected usable reliability, got %s", reliability)
	}
	if transcript.Provider != transcriptProviderAmazonTranscribe {
		t.Fatalf("expected provider %q, got %q", transcriptProviderAmazonTranscribe, transcript.Provider)
	}
	if transcript.IsSynthetic {
		t.Fatal("expected Amazon transcript to be marked as real")
	}
}
