package processing

import (
	"os"
	"strings"
)

// VoiceInfo describes a single TTS voice available for learner selection.
type VoiceInfo struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Gender   string `json:"gender"`   // "female" | "male"
	Provider string `json:"provider"` // "aws_polly" | "elevenlabs"
}

// VoiceRegistry maps voice slugs to TTSProvider instances.
// Built once at startup from env vars. For("") and For("unknown") always
// return the default provider — never nil.
type VoiceRegistry struct {
	entries  []VoiceInfo
	providers map[string]TTSProvider
	defaultP TTSProvider
}

// NewVoiceRegistry builds the registry from the environment.
// defaultTTS is used for the "jitka" slot and as the fallback for unknown slugs.
// Pass nil in dev mode; it will fall back to DevTTSProvider.
func NewVoiceRegistry(defaultTTS TTSProvider) *VoiceRegistry {
	if defaultTTS == nil {
		defaultTTS = DevTTSProvider{}
	}
	r := &VoiceRegistry{
		providers: make(map[string]TTSProvider),
		defaultP:  defaultTTS,
	}

	// Slot 1: Jitka — always present, backed by the primary TTS provider.
	r.register(VoiceInfo{ID: "jitka", Name: "Jitka", Gender: "female", Provider: "aws_polly"}, defaultTTS)

	// Slot 2: Tomáš — ElevenLabs primary voice (ELEVENLABS_VOICE_ID).
	if tomas := newElevenLabsForVoiceEnvVar("ELEVENLABS_VOICE_ID"); tomas != nil {
		r.register(VoiceInfo{ID: "tomas", Name: "Tomáš", Gender: "male", Provider: "elevenlabs"}, tomas)
	}

	// Slot 3: optional second EL female (ELEVENLABS_VOICE_ID_C).
	if elC := newElevenLabsForVoiceEnvVar("ELEVENLABS_VOICE_ID_C"); elC != nil {
		name := envOrDefault("VOICE_C_NAME", "Jana")
		r.register(VoiceInfo{ID: "el_female_2", Name: name, Gender: "female", Provider: "elevenlabs"}, elC)
	}

	// Slot 4: optional second EL male (ELEVENLABS_VOICE_ID_D).
	if elD := newElevenLabsForVoiceEnvVar("ELEVENLABS_VOICE_ID_D"); elD != nil {
		name := envOrDefault("VOICE_D_NAME", "Marek")
		r.register(VoiceInfo{ID: "el_male_2", Name: name, Gender: "male", Provider: "elevenlabs"}, elD)
	}

	return r
}

func (r *VoiceRegistry) register(info VoiceInfo, p TTSProvider) {
	r.entries = append(r.entries, info)
	r.providers[info.ID] = p
}

// For returns the TTSProvider for voiceID.
// Returns the default provider for empty or unrecognised slugs.
func (r *VoiceRegistry) For(voiceID string) TTSProvider {
	if p, ok := r.providers[voiceID]; ok {
		return p
	}
	return r.defaultP
}

// Voices returns the list of configured voice entries (copy, safe to read).
func (r *VoiceRegistry) Voices() []VoiceInfo {
	out := make([]VoiceInfo, len(r.entries))
	copy(out, r.entries)
	return out
}

// newElevenLabsForVoiceEnvVar builds an EL provider using ELEVENLABS_API_KEY
// and the env var named by voiceIDVar. Returns nil if either is unset.
func newElevenLabsForVoiceEnvVar(voiceIDVar string) TTSProvider {
	apiKey := strings.TrimSpace(os.Getenv("ELEVENLABS_API_KEY"))
	voiceID := strings.TrimSpace(os.Getenv(voiceIDVar))
	if apiKey == "" || voiceID == "" {
		return nil
	}
	return newElevenLabsProvider(apiKey, voiceID)
}
