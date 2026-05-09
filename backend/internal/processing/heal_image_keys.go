package processing

import (
	"encoding/json"
	"log"

	"github.com/danieldev/czech-go-system/backend/internal/contracts"
)

// HealImageKeysRepo is the subset of store ops the heal migration needs.
// MemoryStore + postgresExerciseStore both satisfy it.
type HealImageKeysRepo interface {
	ListExercises(pool string) []contracts.Exercise
	UpdateExercise(id string, update contracts.Exercise) (contracts.Exercise, bool)
}

// HealPoslechImageKeys swaps any poslech_1 Items[i].Options[k].ImageAssetID
// that still holds a registered asset.id (pre-V30 wire) for that asset's
// storage_key. Without this, Flutter mediaUri queries `?key=<asset.id>`
// which the server resolves as a path and 404s — surfacing as letter
// placeholders in the 2x2 image grid.
//
// Idempotent. Storage_keys do not collide with asset.ids on a second run
// because asset.ids are short hex strings while storage_keys carry a
// directory-shaped prefix (e.g. `exercises/...` or `ai-generated/...`).
//
// Returns the number of exercises that were updated.
func HealPoslechImageKeys(repo HealImageKeysRepo) int {
	count := 0
	for _, ex := range repo.ListExercises("") {
		if ex.ExerciseType != "poslech_1" {
			continue
		}
		healed, changed := healPoslech1Exercise(ex)
		if !changed {
			continue
		}
		if _, ok := repo.UpdateExercise(ex.ID, contracts.Exercise{Detail: healed.Detail}); ok {
			count++
			log.Printf("v30 heal: poslech_1 exercise %s image_asset_ids healed", ex.ID)
		}
	}
	return count
}

// healPoslech1Exercise returns (healed, changed). When the exercise has any
// option whose image_asset_id matches a registered asset.id, the field is
// rewritten to that asset's storage_key and changed=true. All other
// values (storage_keys already correct, empty fields) pass through untouched.
func healPoslech1Exercise(ex contracts.Exercise) (contracts.Exercise, bool) {
	if len(ex.Assets) == 0 {
		return ex, false
	}
	lookup := make(map[string]string, len(ex.Assets))
	for _, a := range ex.Assets {
		if a.ID != "" && a.StorageKey != "" && a.ID != a.StorageKey {
			lookup[a.ID] = a.StorageKey
		}
	}
	if len(lookup) == 0 {
		return ex, false
	}

	var detail contracts.Poslech1Detail
	b, err := json.Marshal(ex.Detail)
	if err != nil {
		return ex, false
	}
	if err := json.Unmarshal(b, &detail); err != nil {
		return ex, false
	}

	changed := false
	for i := range detail.Items {
		for k := range detail.Items[i].Options {
			current := detail.Items[i].Options[k].ImageAssetID
			if current == "" {
				continue
			}
			if storage, ok := lookup[current]; ok {
				detail.Items[i].Options[k].ImageAssetID = storage
				changed = true
			}
		}
	}
	if !changed {
		return ex, false
	}
	ex.Detail = detail
	return ex, true
}
