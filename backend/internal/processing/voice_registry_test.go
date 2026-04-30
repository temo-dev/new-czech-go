package processing

import (
	"testing"
)

func TestVoiceRegistryFallbackOnEmpty(t *testing.T) {
	reg := NewVoiceRegistry(nil)
	got := reg.For("")
	if got == nil {
		t.Fatal("For('') returned nil, want DevTTSProvider fallback")
	}
}

func TestVoiceRegistryFallbackOnUnknownSlug(t *testing.T) {
	reg := NewVoiceRegistry(nil)
	got := reg.For("unknown_voice_xyz")
	if got == nil {
		t.Fatal("For('unknown') returned nil, want default fallback")
	}
}

func TestVoiceRegistryAlwaysHasJitka(t *testing.T) {
	reg := NewVoiceRegistry(nil)
	voices := reg.Voices()
	var found bool
	for _, v := range voices {
		if v.ID == "jitka" {
			found = true
			if v.Gender != "female" {
				t.Errorf("jitka gender = %q, want female", v.Gender)
			}
			if v.Provider != "aws_polly" {
				t.Errorf("jitka provider = %q, want aws_polly", v.Provider)
			}
		}
	}
	if !found {
		t.Fatal("jitka missing from voice registry")
	}
}

func TestVoiceRegistryExcludesUnconfiguredELVoices(t *testing.T) {
	// No ELEVENLABS_* env vars set in test — only jitka should appear.
	reg := NewVoiceRegistry(nil)
	for _, v := range reg.Voices() {
		if v.Provider == "elevenlabs" {
			t.Errorf("unexpected elevenlabs voice %q without env vars configured", v.ID)
		}
	}
}

func TestVoiceRegistryForJitkaReturnsSameAsDefault(t *testing.T) {
	def := mockTTSProvider{}
	reg := NewVoiceRegistry(def)
	if reg.For("jitka") != def {
		t.Error("For('jitka') should return the default TTS when no separate Polly provider is wired")
	}
	if reg.For("") != def {
		t.Error("For('') should return default")
	}
}

func TestVoiceRegistryVoicesReturnsCopy(t *testing.T) {
	reg := NewVoiceRegistry(nil)
	v1 := reg.Voices()
	v2 := reg.Voices()
	if len(v1) != len(v2) {
		t.Error("Voices() returned different lengths on successive calls")
	}
	// Mutating the returned slice must not affect the registry.
	if len(v1) > 0 {
		v1[0].Name = "MUTATED"
		if reg.Voices()[0].Name == "MUTATED" {
			t.Error("Voices() returned a shared slice, not a copy")
		}
	}
}
