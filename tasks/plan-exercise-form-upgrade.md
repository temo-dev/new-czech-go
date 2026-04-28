# Plan: Exercise Form Upgrade

## Vấn đề hiện tại (baseline)

`exercise-dashboard.tsx` — 2327 dòng, 1 mega-file:

| Vấn đề | Biểu hiện |
|--------|-----------|
| **Modal cramped** | Poslech 1: 5 items × 5 fields = 25 inputs trong fixed-height modal — nested scroll |
| **Mất data khi đóng** | Dismiss modal = mất hết content đang nhập, không confirm, không autosave |
| `---` / `\|` textarea syntax | Admin nhớ `"A \| Label"`, `"Item 1\n---\nItem 2"` → typo → crash submit |
| Không structured item rows | 25+ fields gộp trong 3 textarea |
| Answer key `6=A\n7=B` | Không align với câu hỏi, dễ lệch chỉ số |
| 1 flat `ExerciseFormState` 30+ fields | Tất cả types share state → undefined fields khắp nơi |
| Không inline validation | Lỗi format chỉ hiện khi submit (parse exception) |
| Mega-file 2327 dòng | Hard to review, refactor, add type |

## Goal

Admin nhập content exercise dễ hơn: slide-over panel không cramped, autosave, structured rows thay textarea syntax, inline validation, file nhỏ dễ sửa.

## Assumptions

1. **Không đổi backend API** — payload JSON giữ nguyên
2. **Không đổi DB schema** — CMS UI-only change
3. **Backward compat** — edit mode vẫn đọc được exercise data cũ từ backend
4. **Scope**: container UX + structured inputs + validation — không live preview, không drag-to-reorder
5. **Không 1 form per type** — shared scaffold + type-specific sections, vẫn trong 1 component
6. **State migration strategy — Option C (confirmed)**: mỗi `*Fields` component nhận `initialData` từ `exercise.detail`, tự quản typed state nội bộ, expose `onChange(payload)` lên form cha. Form cha chỉ cần `payload` để submit — không biết internal structure. `ExerciseFormState` giữ common fields (title/skill/status/pool) + `typePayload: unknown` per type.
7. **V6 types in scope** — `quizcard_basic`, `matching`, `fill_blank`, `choice_word` cũng được split vào `VocabGrammarFields.tsx` ở EF-D
8. **autosave version key** — draft key là `ef-draft-v2` để invalidate draft cũ từ trước EF-B
9. **Cteni 1 image upload** — giữ nguyên asset upload flow hiện tại (upload button + asset ID display), chỉ thay textarea bằng per-slot inputs
10. **Poslech audio generation** — audio source radio + generate button nằm trong `PoslechFields` (per type, không common)

## Dependency Graph

```
EF-0 (slide-over panel + autosave + dismiss confirm)
  ‖ (song song)
EF-A (ItemRepeater + OptionRow + AnswerSelect)
  │
  ├──→ EF-B (Poslech 1-5 structured editors)
  ├──→ EF-C (Čtení 1-5 structured editors)
  └──→ EF-D (Speaking 1-4 + Writing 1-2 structured inputs)
                    │
                    ↓
             EF-E (file split + inline validation)
```

`EF-0` và `EF-A` song song.
`EF-B`, `EF-C`, `EF-D` song song sau `EF-A`.
`EF-E` sau cùng khi tất cả fields ổn định.

---

## Slice EF-0 — Slide-over panel + autosave + dismiss confirm

**UX problem solved:**
- Modal fixed-height + 25 inputs = nested scroll = tệ (UX rule: `scroll-behavior`)
- Dismiss = mất data (UX rule: `form-autosave`, `sheet-dismiss-confirm`)

**Design — slide-over panel (không phải modal):**
```
┌────────────────────────────────────────────────────┐
│ Exercise List           │ [← Đóng]  Poslech 1      │
│                         │  ─────────────────────   │
│  [Poslech 1]  edit ──┐  │  COMMON FIELDS           │
│  [Cteni 2]    edit   │  │  Title: [_____________]  │
│  ...                 └─▶│  Skill: [▾ Nghe]         │
│                         │  Status: [▾ draft]        │
│                         │  ─────────────────────   │
│                         │  TYPE-SPECIFIC FIELDS     │
│                         │  Đoạn 1: [____________]  │
│                         │  Đáp án: [▾ B]           │
│                         │  ...25 inputs scroll OK  │
│                         │                          │
│                         │  [Lưu nháp]  [Lưu & đóng]│
└────────────────────────────────────────────────────┘
```

**Files thay đổi:**
- `cms/components/exercise-dashboard.tsx` — thay `position:fixed` modal div bằng slide-over `aside`

**Spec:**
- Panel: `position: fixed; top: 0; right: 0; height: 100vh; width: min(80vw, 960px)`
- Panel `overflow-y: auto` — scroll toàn bộ panel (không nested)
- List bên trái vẫn visible, dimmed overlay
- Animation: `transform: translateX(100%)` → `translateX(0)`, `250ms ease-out`
- List không scroll khi panel mở (lock body scroll phần dưới overlay)

**localStorage autosave:**
- Mỗi 10s (hoặc khi type-specific field thay đổi) → `localStorage.setItem('ef-draft', JSON.stringify(form))`
- Khi mở form mới: check `ef-draft` → nếu có → toast "Khôi phục bản nháp?" [Có] [Không]
- Khi submit thành công → `localStorage.removeItem('ef-draft')`

**Dismiss confirm:**
- Khi click close/overlay với `isDirty === true` → confirm dialog:
  ```
  "Bạn có thay đổi chưa lưu. Đóng không?"
  [Đóng không lưu]  [Tiếp tục chỉnh sửa]
  ```
- `isDirty` = form state khác initial state khi mở

**Acceptance Criteria:**
- Panel mở từ phải, animation 250ms
- Scroll không bị cramped: 25+ inputs scroll toàn bộ panel
- List bên trái vẫn nhìn thấy (dimmed)
- Autosave toast hiện khi có draft cũ
- Dismiss có draft → confirm dialog
- `make cms-lint && make cms-build`

---

## Slice EF-A — Shared components: ItemRepeater + OptionRow + AnswerSelect

**Files mới:**
- `cms/components/exercise-form/ItemRepeater.tsx`
- `cms/components/exercise-form/OptionRow.tsx`
- `cms/components/exercise-form/AnswerSelect.tsx`

**Design:**

`ItemRepeater` — danh sách rows có thể add/remove:
```
┌─ Label ──────────────────────────────┐
│ [Item 1 text...              ] [↑][↓][×] │
│ [Item 2 text...              ] [↑][↓][×] │
│ [+ Thêm item]                            │
└──────────────────────────────────────┘
```
Props: `items: string[]`, `onChange(items: string[])`, `placeholder`, `label`, `maxItems?`, `minItems?`
- Up/Down buttons reorder (không cần drag)
- Disabled ×  khi `items.length === minItems`
- Disabled + khi `items.length === maxItems`

`OptionRow` — 1 row cho 1 option (key + label):
```
[A │ Label text...      ] [×]   ← key fixed, label editable
```
Props: `optionKey: string`, `label: string`, `onChange(label)`, `onRemove?`
- `optionKey` hiện như badge, không edit (A/B/C/D auto-generated)

`AnswerSelect` — dropdown aligned với item/question:
```
Câu 3 đáp án: [▾ B  ]   ← options = keys từ OptionRow list
```
Props: `label: string`, `options: {key: string; label: string}[]`, `value: string`, `onChange(key)`

**Acceptance Criteria:**
- `ItemRepeater`: Add thêm row; × xóa; ↑↓ reorder; disabled ở min/max
- `AnswerSelect`: dropdown chỉ hiện options được pass vào, không hardcode
- Pure controlled — không local state
- `make cms-lint`

---

## Slice EF-B — Poslech 1-5: structured item editors

**Files mới:**
- `cms/components/exercise-form/PoslechFields.tsx`

**State shape** (thay flat string):
```typescript
type PoslechItem = {
  text: string;           // transcript/dialog text
  correctAnswer: string;  // option key (A-D hoặc A-G)
};
type PoslechOption = { key: string; label: string };
type Poslech5Slot = { slotKey: string; label: string; correctAnswer: string };
```

**UX per type:**

**Poslech 1 / 2** (5 passages → A-D, 5 fixed options):
```
┌── Đoạn 1 ─────────────────────────────────────┐
│ Transcript: [_________________________________] │
│ A: [Cesta na nádraží]  B: [Na poště]           │
│ C: [V restauraci    ]  D: [V obchodě]           │
│ Đáp án: [▾ B]                                  │
└────────────────────────────────────────────────┘
[+ Thêm đoạn] (max 5)
```
- Options A-D là free text inputs (OptionRow × 4)
- AnswerSelect aligned với options

**Poslech 3** (5 passages → match A-G):
- `ItemRepeater` cho transcript rows
- `OptionRow` × 7 cho A-G (shared pool)
- `AnswerSelect` per passage từ pool A-G

**Poslech 4** (5 dialogs → choose image A-F):
- `ItemRepeater` cho dialog rows
- `OptionRow` × 6 cho A-F (image asset IDs)
- `AnswerSelect` per dialog

**Poslech 5** (voicemail → fill info):
```
Voicemail text: [textarea free text]
┌── Slot 1 ──────────────────────────────────────┐
│ Slot key: [jmeno ] Label: [Jméno  ] Đáp án: [__] │
└────────────────────────────────────────────────┘
[+ Thêm slot] (max 5)
```

**Serialization:**
- `PoslechFields` serializes to exact same JSON as `buildPoslechPayload` expects
- No backend changes

**Acceptance Criteria:**
- Add/remove items (Poslech 1-4: max 5; Poslech 5: max 5 slots)
- AnswerSelect aligned với đúng item
- Edit mode: load từ exercise.detail → structured state → render đúng
- Submit gửi đúng payload

**Verification:** `make cms-lint && make cms-build`

---

## Slice EF-C — Čtení 1-5: structured item editors

**Files mới:**
- `cms/components/exercise-form/CteniFields.tsx`

**State shape:**
```typescript
type CteniQuestion = { text: string; options: string[]; correctAnswer: string };
type CteniItem = { text: string; correctAnswer: string };
```

**UX per type:**

**Čtení 1** (5 images → match A-H):
```
Options A-H: [OptionRow × 8]
Items:
┌── Obrázek 1 ─────────────────┐
│ Asset/text: [asset-id-here ] │
│ Đáp án: [▾ C]               │
└──────────────────────────────┘
× 5
```

**Čtení 2 / 4** (reading text → questions → A-D):
```
Đoạn văn: [textarea — full width, 10 rows]
─────────────────────────────────────────
Câu 6: [Question text...                ]
  A: [___] B: [___] C: [___] D: [___]
  Đáp án: [▾ A]
Câu 7: ...
[+ Thêm câu] (Čtení 2: max 5; Čtení 4: max 6)
```

**Čtení 3** (4 texts → match persons A-E):
```
Nhân vật A-E: [OptionRow × 5]
Đoạn 1: [textarea]  → [▾ B]
Đoạn 2: [textarea]  → [▾ A]
[+ Thêm đoạn] (max 4)
```

**Čtení 5** (fill-in 5 slots):
```
Đoạn văn: [textarea — 10 rows]
─────────────────────────────────────
Câu 1: [question text] Đáp án: [___]
Câu 2: ...
[+ Thêm câu] (max 5)
```

**Acceptance Criteria:**
- Tất cả 5 cteni types render structured fields
- Edit mode load data đúng
- Submit payload không thay đổi

**Verification:** `make cms-lint && make cms-build`

---

## Slice EF-D — Speaking (Uloha 1-4) + Writing (Psaní 1-2)

**Files mới:**
- `cms/components/exercise-form/SpeakingFields.tsx`
- `cms/components/exercise-form/WritingFields.tsx`

**Speaking — UX per type:**

**Uloha 1** — `question_prompts`:
```
Prompts (3-4):
[Prompt 1...] [↑][↓][×]
[Prompt 2...] [↑][↓][×]
[+ Thêm] (max 4)
```
→ `ItemRepeater` với maxItems=4, minItems=3

**Uloha 2** — `required_info_slots`:
```
┌── Slot 1 ──────────────────────────────────────────────────┐
│ Key: [jmeno    ] Label: [Jméno a příjmení] Sample: [Jak se jmenujete?] [×] │
└────────────────────────────────────────────────────────────┘
[+ Thêm slot]
```
3 inputs per slot (key, label, sample) → custom `InfoSlotRow` component (thay parse `slot_key | label | sample`)

**Uloha 3** — `narrative_checkpoints`:
```
Checkpoints:
[Checkpoint 1...] [↑][↓][×]
[+ Thêm] (max 4)
```
→ `ItemRepeater` với maxItems=4

**Uloha 4** — `choice_options`:
```
Option A: [Label text              ] [Description optional...] [×]
Option B: [Label text              ] [Description optional...] [×]
[+ Thêm] (max 4)
```
→ Custom `ChoiceOptionRow` với key auto-generated (A/B/C/D), label + description inputs

**Writing — UX per type:**

**Psaní 1** — `formularQuestions`:
```
Câu hỏi (đúng 3):
[Câu hỏi 1...] [↑][↓][×]
[Câu hỏi 2...] [↑][↓][×]
[Câu hỏi 3...] [↑][↓]     ← × disabled vì minItems=3
```
→ `ItemRepeater` với maxItems=3, minItems=3

**Psaní 2** — `emailTopics` (5 image prompt labels):
```
Topics (đúng 5 ảnh):
[Topic 1...] [↑][↓][×]
...
```
→ `ItemRepeater` với maxItems=5, minItems=5

**Files mới phụ:**
- `cms/components/exercise-form/InfoSlotRow.tsx` — 3-column slot row cho Uloha 2
- `cms/components/exercise-form/ChoiceOptionRow.tsx` — key+label+desc cho Uloha 4

**Acceptance Criteria:**
- `InfoSlotRow` render key/label/sample inputs theo hàng ngang
- `ChoiceOptionRow` render key badge + label + description
- `ItemRepeater` maxItems enforced
- Submit payload không thay đổi

**Verification:** `make cms-lint && make cms-build`

---

## Slice EF-E — File split + inline validation

**Mục tiêu:** 1 file 2327 dòng → nhiều file ≤ 500 dòng + validation trực tiếp.

**File structure sau split:**
```
cms/components/
  exercise-dashboard.tsx          ← list + filter + panel shell (~500 dòng)
  exercise-form/
    index.tsx                     ← ExerciseForm: state + submit + wizard step (~350 dòng)
    common-fields.tsx             ← Title, instruction, skill, status, pool, pool (~150 dòng)
    SpeakingFields.tsx            ← Uloha 1-4 (từ EF-D)
    WritingFields.tsx             ← Psaní 1-2 (từ EF-D)
    PoslechFields.tsx             ← Poslech 1-5 (từ EF-B)
    CteniFields.tsx               ← Cteni 1-5 (từ EF-C)
    ItemRepeater.tsx              ← shared (từ EF-A)
    OptionRow.tsx                 ← shared (từ EF-A)
    AnswerSelect.tsx              ← shared (từ EF-A)
    InfoSlotRow.tsx               ← từ EF-D
    ChoiceOptionRow.tsx           ← từ EF-D
    validation.ts                 ← per-type validation rules
```

**Inline validation — `validation.ts`:**
```typescript
type FieldError = { field: string; message: string };
function validateExercise(type: ExerciseType, data: TypedFormState): FieldError[]
```

Rules mẫu:
| Type | Rule |
|------|------|
| `poslech_1` | items.length === 5, mỗi item có text + correctAnswer |
| `cteni_2` | questions.length === 5, mỗi question có 4 options + answer |
| `psani_1_formular` | questions.length === 3 |
| `uloha_2_*` | required_info_slots.length ≥ 1, mỗi slot có key + label |

**Error display:**
- Field-level: `<span style={{ color: 'var(--error)', fontSize: 12 }}>lỗi ở đây</span>` ngay dưới input
- Submit button: disabled khi `errors.length > 0`
- Validate on blur (không phải keystroke)

**Acceptance Criteria:**
- `exercise-dashboard.tsx` < 600 dòng
- Không file nào > 500 dòng
- Inline validation hiện đúng field
- Submit disabled khi invalid
- `make cms-lint && make cms-build` sạch

---

## [CHECKPOINT EF] — Exercise Form Upgrade Complete

**Điều kiện pass:**
- [ ] **Panel**: form mở slide-over từ phải, không cramped, scroll toàn bộ
- [ ] **Autosave**: đóng + mở lại → toast "Khôi phục bản nháp?"
- [ ] **Dismiss confirm**: có unsaved changes → dialog confirm trước khi đóng
- [ ] **Poslech 1-5**: structured rows, không `---`/`|` syntax
- [ ] **Čtení 1-5**: structured rows, dropdown answers
- [ ] **Speaking + Writing**: structured inputs
- [ ] **Inline validation**: hiện lỗi trước submit, submit disabled khi invalid
- [ ] **File split**: không file nào > 500 dòng
- [ ] `make verify` green

---

## Thứ tự triển khai

```
EF-0 (slide-over + autosave)   ←─ song song ─→   EF-A (shared components)
         │                                                │
         └─────────────────────────────────────────────── ┘
                               │
              EF-B + EF-C + EF-D (song song)
                               │
                            EF-E (file split + validation)
```

Ước tính:
| Slice | Độ phức tạp | Ước tính |
|-------|-------------|----------|
| EF-0 | Medium | 1 ngày |
| EF-A | Low | 0.5 ngày |
| EF-B | Medium-High | 2 ngày |
| EF-C | Medium-High | 2 ngày |
| EF-D | Medium | 1.5 ngày |
| EF-E | Medium | 1 ngày |

## Không nằm trong scope

- Live preview của exercise khi nhập
- Drag-to-reorder (up/down buttons đủ cho V1)
- Import/export CSV/JSON
- Một form riêng per exercise type (20 routes) — không cần thiết
- Backend API changes
- Flutter changes
