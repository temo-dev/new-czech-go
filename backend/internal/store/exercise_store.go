package store

import (
	"fmt"
	"sync"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

type ExerciseStore interface {
	ExercisesByModule(moduleID string) []contracts.Exercise
	// ListExercises returns all exercises. pool="" means no filter; "course" or "exam" filters by pool.
	ListExercises(pool string) []contracts.Exercise
	Exercise(id string) (contracts.Exercise, bool)
	CreateExercise(exercise contracts.Exercise) contracts.Exercise
	UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool)
	DeleteExercise(id string) bool
}

type memoryExerciseStore struct {
	mu           sync.RWMutex
	exercises    map[string]contracts.Exercise
	nextExercise int
}

func newMemoryExerciseStore(seed []contracts.Exercise) *memoryExerciseStore {
	items := make(map[string]contracts.Exercise, len(seed))
	for _, exercise := range seed {
		items[exercise.ID] = cloneExercise(exercise)
	}
	return &memoryExerciseStore{
		exercises:    items,
		nextExercise: len(seed) + 1,
	}
}

func (s *memoryExerciseStore) ExercisesByModule(moduleID string) []contracts.Exercise {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]contracts.Exercise, 0)
	for _, exercise := range s.exercises {
		if exercise.ModuleID == moduleID && exercise.Status == "published" {
			items = append(items, cloneExercise(exercise))
		}
	}
	return items
}

func (s *memoryExerciseStore) ListExercises(pool string) []contracts.Exercise {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]contracts.Exercise, 0, len(s.exercises))
	for _, exercise := range s.exercises {
		if pool != "" && exercise.Pool != pool {
			continue
		}
		items = append(items, cloneExercise(exercise))
	}
	return items
}

func (s *memoryExerciseStore) Exercise(id string) (contracts.Exercise, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	exercise, ok := s.exercises[id]
	if !ok {
		return contracts.Exercise{}, false
	}
	return cloneExercise(exercise), true
}

func (s *memoryExerciseStore) CreateExercise(exercise contracts.Exercise) contracts.Exercise {
	s.mu.Lock()
	defer s.mu.Unlock()

	exercise.ID = fmt.Sprintf("exercise-%d", s.nextExercise)
	s.nextExercise++
	if exercise.Status == "" {
		exercise.Status = "draft"
	}
	cloned := cloneExercise(exercise)
	s.exercises[exercise.ID] = cloned
	return cloneExercise(cloned)
}

func (s *memoryExerciseStore) UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	current, ok := s.exercises[id]
	if !ok {
		return contracts.Exercise{}, false
	}
	merged := mergeExerciseUpdate(current, update)
	s.exercises[id] = merged
	return cloneExercise(merged), true
}

func (s *memoryExerciseStore) DeleteExercise(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.exercises[id]; !ok {
		return false
	}
	delete(s.exercises, id)
	return true
}

func seedExercises() []contracts.Exercise {
	return []contracts.Exercise{
		{
			ID:                    "exercise-uloha1-weather",
			SkillID:               "skill-dev-noi",
			ExerciseType:          "uloha_1_topic_answers",
			Title:                 "Pocasi 1",
			ShortInstruction:      "Tra loi ngan gon theo chu de thoi tiet.",
			LearnerInstruction:    "Ban se tra loi 4 cau hoi ngan ve chu de thoi tiet.",
			EstimatedDurationSec:  90,
			PrepTimeSec:           10,
			RecordingTimeLimitSec: 45,
			SampleAnswerEnabled:   true,
			Status:                "published",
			SequenceNo:            1,
			Prompt: contracts.Uloha1Prompt{
				TopicLabel: "Pocasi",
				QuestionPrompts: []string{
					"Ve kterem mesici v Cesku casto snezi a mrzne?",
					"Jake pocasi mate rad/a a proc?",
					"Kdy naposledy prselo?",
					"Jake pocasi bude zitra?",
				},
			},
			ScoringTemplatePreview: &contracts.ScoringPreview{
				RubricVersion: "v1",
				FeedbackStyle: "supportive_direct_vi",
			},
		},
		{
			ID:                    "exercise-uloha3-tv",
			SkillID:               "skill-dev-noi",
			ExerciseType:          "uloha_3_story_narration",
			Title:                 "Nakup televize",
			ShortInstruction:      "Ke lai pribeh theo 4 tranh.",
			LearnerInstruction:    "Ban hay noi lai cau chuyen theo 4 tranh va dung qua khu.",
			EstimatedDurationSec:  120,
			PrepTimeSec:           15,
			RecordingTimeLimitSec: 60,
			SampleAnswerEnabled:   true,
			Status:                "published",
			SequenceNo:            1,
			Detail: contracts.Uloha3Detail{
				StoryTitle: "Nakup televize",
				ImageAssetIDs: []string{
					"asset-tv-1",
					"asset-tv-2",
					"asset-tv-3",
					"asset-tv-4",
				},
				NarrativeCheckpoints: []string{
					"Otec a syn sli do obchodu.",
					"Divali se na televize a porovnavali je.",
					"Vybrali jednu televizi a zaplatili ji.",
					"Odvezli televizi domu autem.",
				},
				GrammarFocus: []string{"past_tense"},
			},
			ScoringTemplatePreview: &contracts.ScoringPreview{
				RubricVersion: "v1",
				FeedbackStyle: "supportive_direct_vi",
			},
		},
		{
			ID:                    "exercise-uloha2-cinema",
			SkillID:               "skill-dev-noi",
			ExerciseType:          "uloha_2_dialogue_questions",
			Title:                 "Kino vecer",
			ShortInstruction:      "Zeptejte se na chybejici informace o navsteve kina.",
			LearnerInstruction:    "Predstavte si, ze chcete jit vecer do kina. Zeptejte se aspon na tri dulezite informace a pridejte jednu vlastni otazku navic.",
			EstimatedDurationSec:  90,
			PrepTimeSec:           10,
			RecordingTimeLimitSec: 45,
			SampleAnswerEnabled:   true,
			Status:                "published",
			SequenceNo:            2,
			Detail: contracts.Uloha2Detail{
				ScenarioTitle:  "Navsteva kina",
				ScenarioPrompt: "Chcete jit do kina na vecerni film. Potrebujete zjistit cas zacatku, cenu listku a jestli je mozne koupit listky online.",
				RequiredInfoSlots: []contracts.RequiredInfoSlot{
					{SlotKey: "start_time", Label: "Cas zacatku", SampleQuestion: "V kolik hodin film zacina?"},
					{SlotKey: "price", Label: "Cena listku", SampleQuestion: "Kolik stoji jeden listek?"},
					{SlotKey: "online_ticket", Label: "Nakup online", SampleQuestion: "Muzu si koupit listek online?"},
				},
				CustomQuestionHint: "Pridejte jeste jednu prirozenou doplnujici otazku, treba na titulky nebo sal.",
			},
			ScoringTemplatePreview: &contracts.ScoringPreview{
				RubricVersion: "v1",
				FeedbackStyle: "supportive_direct_vi",
			},
		},
		{
			ID:                    "exercise-uloha4-flat",
			SkillID:               "skill-dev-noi",
			ExerciseType:          "uloha_4_choice_reasoning",
			Title:                 "Bydleni v Praze",
			ShortInstruction:      "Vyberte jednu moznost a vysvetlete proc.",
			LearnerInstruction:    "Predstavte si, ze hledate bydleni v Praze. Vyberte jednu moznost a reknete, proc je pro vas nejlepsi.",
			EstimatedDurationSec:  90,
			PrepTimeSec:           10,
			RecordingTimeLimitSec: 45,
			SampleAnswerEnabled:   true,
			Status:                "published",
			SequenceNo:            2,
			Detail: contracts.Uloha4Detail{
				ScenarioPrompt: "Hledate bydleni v Praze. Ktery byt si vyberete a proc?",
				Options: []contracts.ChoiceOption{
					{OptionKey: "flat_a", Label: "Byt A", Description: "Levnejsi, ale daleko od centra."},
					{OptionKey: "flat_b", Label: "Byt B", Description: "Blizko centra, ale mensi."},
					{OptionKey: "flat_c", Label: "Byt C", Description: "Vetsi a klidny, ale drazsi."},
				},
				ExpectedReasoningAxes: []string{"price", "location", "space"},
			},
			ScoringTemplatePreview: &contracts.ScoringPreview{
				RubricVersion: "v1",
				FeedbackStyle: "supportive_direct_vi",
			},
		},
	}
}

func mergeExerciseUpdate(current, update contracts.Exercise) contracts.Exercise {
	if update.Title != "" {
		current.Title = update.Title
	}
	if update.ShortInstruction != "" {
		current.ShortInstruction = update.ShortInstruction
	}
	if update.LearnerInstruction != "" {
		current.LearnerInstruction = update.LearnerInstruction
	}
	if update.ExerciseType != "" {
		current.ExerciseType = update.ExerciseType
	}
	if update.SkillID != "" {
		current.SkillID = update.SkillID
	}
	if update.Pool != "" {
		current.Pool = update.Pool
	}
	if update.Status != "" {
		current.Status = update.Status
	}
	if update.EstimatedDurationSec != 0 {
		current.EstimatedDurationSec = update.EstimatedDurationSec
	}
	if update.PrepTimeSec != 0 {
		current.PrepTimeSec = update.PrepTimeSec
	}
	if update.RecordingTimeLimitSec != 0 {
		current.RecordingTimeLimitSec = update.RecordingTimeLimitSec
	}
	if update.SampleAnswerEnabled {
		current.SampleAnswerEnabled = true
	} else if update.DisableSampleAnswer {
		current.SampleAnswerEnabled = false
	}
	if update.SampleAnswerText != "" {
		current.SampleAnswerText = update.SampleAnswerText
	}
	if update.Detail != nil {
		current.Detail = update.Detail
	}
	if update.Prompt != nil {
		current.Prompt = update.Prompt
	}
	if len(update.Assets) > 0 {
		current.Assets = append([]contracts.PromptAsset(nil), update.Assets...)
	}
	if update.ScoringTemplatePreview != nil {
		preview := *update.ScoringTemplatePreview
		current.ScoringTemplatePreview = &preview
	}
	return current
}

func cloneExercise(src contracts.Exercise) contracts.Exercise {
	clone := src
	if src.Assets != nil {
		clone.Assets = append([]contracts.PromptAsset(nil), src.Assets...)
	}
	if src.ScoringTemplatePreview != nil {
		preview := *src.ScoringTemplatePreview
		clone.ScoringTemplatePreview = &preview
	}
	return clone
}
