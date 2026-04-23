package processing

import "github.com/danieldev/czech-go-system/backend/internal/contracts"

const (
	transcriptProviderDevStub          = "dev_stub"
	transcriptProviderAmazonTranscribe = "amazon_transcribe"
)

type Transcriber interface {
	Transcribe(exercise contracts.Exercise, audio contracts.AttemptAudio) (contracts.Transcript, transcriptReliability, bool, error)
}

type DevTranscriber struct{}

func (DevTranscriber) Transcribe(exercise contracts.Exercise, audio contracts.AttemptAudio) (contracts.Transcript, transcriptReliability, bool, error) {
	text, reliability := devTranscriptText(exercise, audio.DurationMs)
	normalized := normalizeTranscript(text)
	if normalized == "" || reliability == reliabilityUnusable {
		return contracts.Transcript{}, reliability, false, nil
	}

	confidence := 0.92
	switch reliability {
	case reliabilityUsableWithWarnings:
		confidence = 0.68
	case reliabilityUnusable:
		confidence = 0.20
	}

	return contracts.Transcript{
		FullText:    normalized,
		Locale:      "cs-CZ",
		Confidence:  confidence,
		Provider:    transcriptProviderDevStub,
		IsSynthetic: true,
	}, reliability, true, nil
}

func devTranscriptText(exercise contracts.Exercise, durationMs int) (string, transcriptReliability) {
	if durationMs < 1500 {
		return "", reliabilityUnusable
	}

	switch exercise.ExerciseType {
	case "uloha_3_story_narration":
		if durationMs < 5000 {
			return "Rodina koupila televizi a jela domu.", reliabilityUsableWithWarnings
		}
		return "Nejdriv byli v obchode, pak koupili novou televizi a nakonec ji odvezli domu autem.", reliabilityUsable
	case "uloha_4_choice_reasoning":
		if durationMs < 5000 {
			return "Vybiram park, protoze je klidny.", reliabilityUsableWithWarnings
		}
		return "Vybiram park, protoze je klidny, levny a muzeme tam mluvit venku s kamarady.", reliabilityUsable
	case "uloha_2_dialogue_questions":
		if durationMs < 5000 {
			return "V kolik hodin to je a kolik to stoji?", reliabilityUsableWithWarnings
		}
		return "Dobry den, v kolik hodin to zacina, kolik to stoji a muzu si koupit listek online?", reliabilityUsable
	default:
		if durationMs < 4000 {
			return "Mam rad teple pocasi.", reliabilityUsableWithWarnings
		}
		if durationMs < 12000 {
			return "Mam rad teple pocasi, protoze muzu byt venku.", reliabilityUsable
		}
		return "Mam rad teple pocasi, protoze muzu byt dlouho venku s rodinou a chodit do parku.", reliabilityUsable
	}
}
