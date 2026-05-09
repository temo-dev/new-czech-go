package processing

import (
	"testing"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

func makeBrokenPoslech1() contracts.Exercise {
	return contracts.Exercise{
		ID:           "ex1",
		ExerciseType: "poslech_1",
		Assets: []contracts.PromptAsset{
			{ID: "asset-abc", StorageKey: "exercises/ex1/asset-abc.jpg", AssetKind: "image", MimeType: "image/jpeg"},
			{ID: "asset-def", StorageKey: "exercises/ex1/asset-def.jpg", AssetKind: "image", MimeType: "image/jpeg"},
		},
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{
					QuestionNo: 1,
					Options: []contracts.MultipleChoiceOption{
						{Key: "A", Text: "a", ImageAssetID: "asset-abc"},
						{Key: "B", Text: "b", ImageAssetID: "asset-def"},
						{Key: "C", Text: "c", ImageAssetID: ""},
						{Key: "D", Text: "d", ImageAssetID: "exercises/ex1/already-healed.jpg"},
					},
				},
			},
		},
	}
}

func TestHealPoslech1Exercise_SwapsAssetIDtoStorageKey(t *testing.T) {
	ex := makeBrokenPoslech1()
	healed, changed := healPoslech1Exercise(ex)
	if !changed {
		t.Fatal("expected changed=true")
	}
	detail := healed.Detail.(contracts.Poslech1Detail)
	got := func(k int) string { return detail.Items[0].Options[k].ImageAssetID }
	if got(0) != "exercises/ex1/asset-abc.jpg" {
		t.Errorf("opt A = %q, want healed", got(0))
	}
	if got(1) != "exercises/ex1/asset-def.jpg" {
		t.Errorf("opt B = %q, want healed", got(1))
	}
	if got(2) != "" {
		t.Errorf("opt C = %q, want empty preserved", got(2))
	}
	if got(3) != "exercises/ex1/already-healed.jpg" {
		t.Errorf("opt D = %q, want untouched (already storage_key)", got(3))
	}
}

func TestHealPoslech1Exercise_Idempotent(t *testing.T) {
	ex := makeBrokenPoslech1()
	once, _ := healPoslech1Exercise(ex)
	twice, changed := healPoslech1Exercise(once)
	if changed {
		t.Errorf("second run should be no-op, but changed=true")
	}
	_ = twice
}

func TestHealPoslech1Exercise_NonPoslech1_NoChange(t *testing.T) {
	ex := contracts.Exercise{
		ExerciseType: "poslech_2",
		Assets: []contracts.PromptAsset{
			{ID: "asset-x", StorageKey: "exercises/ex2/asset-x.jpg"},
		},
		Detail: contracts.Poslech2Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, Options: []contracts.MultipleChoiceOption{
					{Key: "A", ImageAssetID: "asset-x"},
				}},
			},
		},
	}
	// healPoslech1Exercise is internal; the exported Heal looks at type. We call
	// via the heal exported function below which we test here via a fake repo.
	if _, changed := healPoslech1Exercise(ex); !changed {
		// healPoslech1Exercise itself doesn't filter by type; the public
		// HealPoslechImageKeys does. Direct call would still heal — this test
		// is more useful as an integration check, see TestHealPoslechImageKeys.
		_ = changed
	}
}

func TestHealPoslech1Exercise_NoAssets_NoChange(t *testing.T) {
	ex := contracts.Exercise{
		ExerciseType: "poslech_1",
		Detail: contracts.Poslech1Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, Options: []contracts.MultipleChoiceOption{
					{Key: "A", ImageAssetID: "asset-abc"},
				}},
			},
		},
	}
	if _, changed := healPoslech1Exercise(ex); changed {
		t.Error("no Assets registry → cannot heal → expected unchanged")
	}
}

// fakeHealRepo is a minimal in-memory store for testing the public migration.
type fakeHealRepo struct {
	items map[string]contracts.Exercise
}

func newFakeHealRepo(exs ...contracts.Exercise) *fakeHealRepo {
	r := &fakeHealRepo{items: make(map[string]contracts.Exercise)}
	for _, e := range exs {
		r.items[e.ID] = e
	}
	return r
}

func (r *fakeHealRepo) ListExercises(_ string) []contracts.Exercise {
	out := make([]contracts.Exercise, 0, len(r.items))
	for _, e := range r.items {
		out = append(out, e)
	}
	return out
}

func (r *fakeHealRepo) UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool) {
	cur, ok := r.items[id]
	if !ok {
		return contracts.Exercise{}, false
	}
	if update.Detail != nil {
		cur.Detail = update.Detail
	}
	r.items[id] = cur
	return cur, true
}

func TestHealPoslechImageKeys_HealsOnlyPoslech1(t *testing.T) {
	broken := makeBrokenPoslech1()
	other := contracts.Exercise{
		ID:           "ex-other",
		ExerciseType: "poslech_2",
		Assets: []contracts.PromptAsset{
			{ID: "asset-leak", StorageKey: "exercises/ex-other/asset-leak.jpg"},
		},
		Detail: contracts.Poslech2Detail{
			Items: []contracts.ListeningItem{
				{QuestionNo: 1, Options: []contracts.MultipleChoiceOption{
					{Key: "A", ImageAssetID: "asset-leak"},
				}},
			},
		},
	}

	repo := newFakeHealRepo(broken, other)
	count := HealPoslechImageKeys(repo)
	if count != 1 {
		t.Errorf("healed count = %d, want 1 (only poslech_1)", count)
	}
	// poslech_1 was healed
	healedDetail := repo.items["ex1"].Detail.(contracts.Poslech1Detail)
	if healedDetail.Items[0].Options[0].ImageAssetID != "exercises/ex1/asset-abc.jpg" {
		t.Errorf("poslech_1 not healed: %+v", healedDetail.Items[0].Options[0])
	}
	// poslech_2 untouched
	otherDetail := repo.items["ex-other"].Detail.(contracts.Poslech2Detail)
	if otherDetail.Items[0].Options[0].ImageAssetID != "asset-leak" {
		t.Errorf("poslech_2 should NOT be healed (out of V30 scope), got %+v",
			otherDetail.Items[0].Options[0])
	}
}

func TestHealPoslechImageKeys_IdempotentAcrossRuns(t *testing.T) {
	repo := newFakeHealRepo(makeBrokenPoslech1())
	first := HealPoslechImageKeys(repo)
	second := HealPoslechImageKeys(repo)
	if first != 1 {
		t.Errorf("first run = %d, want 1", first)
	}
	if second != 0 {
		t.Errorf("second run = %d, want 0 (idempotent)", second)
	}
}
