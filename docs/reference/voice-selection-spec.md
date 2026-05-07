# Spec: V8 — Voice Selection

Idea: `docs/ideas/voice-selection.md`
Plan: `tasks/plan.md` → section V8
Created: 2026-04-30

---

## 1. Objective

Learner chọn 1 trong 4 giọng Czech trên màn Profile. Preference lưu client-side (`SharedPreferences`). Mỗi khi backend generate model answer TTS (speaking review + writing review), nó dùng giọng learner đã chọn thay vì giọng mặc định từ env var.

**Target users:** Learner app (Flutter iOS).

**Success criteria:**
- Tap chọn Tomáš trên Profile → làm bài writing → result screen phát audio bằng giọng Tomáš.
- App restart giữ preference.
- Nếu backend chỉ có 2 voices configured → Profile chỉ hiện 2 card, không crash.

**Out of scope:**
- Poslech pre-generated audio — không thay đổi (đã baked MP3).
- Sub voice picker (confusing, không khả thi với pre-gen audio).
- DB storage cho preference (cross-device sync defer).
- Personalize per exercise type.

---

## 2. Architecture

### Voice slots

| Slug | Display name | Gender | Provider | Env config |
|---|---|---|---|---|
| `jitka` | `Jitka` | female | AWS Polly | `POLLY_VOICE_ID` (hiện có, default `"Jitka"`) |
| `tomas` | `Tomáš` | male | ElevenLabs | `ELEVENLABS_VOICE_ID` (hiện có) |
| `el_female_2` | `$VOICE_C_NAME` (default `"Jana"`) | female | ElevenLabs | `ELEVENLABS_VOICE_ID_C` (**mới**) |
| `el_male_2` | `$VOICE_D_NAME` (default `"Marek"`) | male | ElevenLabs | `ELEVENLABS_VOICE_ID_D` (**mới**) |

Voice C và D chỉ xuất hiện trong `GET /v1/voices` nếu env var tương ứng được set.
Jitka và Tomas luôn có (nếu TTS configured).

### Data flow

```
Flutter Profile: tap voice card
  → VoicePreferenceService.save("tomas")   [SharedPreferences]

Flutter Exercise: submit attempt
  → api_client.submitText(id, text: ..., preferredVoiceId: "tomas")
    body: { "text": "...", "preferred_voice_id": "tomas" }

  → api_client.uploadComplete(id, preferredVoiceId: "tomas")
    body: { "preferred_voice_id": "tomas" }

Backend:
  handleSubmitText → ProcessWritingAttempt(id, sub)
    sub.PreferredVoiceID = "tomas"
    → voiceRegistry.For("tomas").Generate(id, modelAnswerText)

  handleUploadComplete → goroutine ProcessAttempt(id, locale, "tomas")
    → voiceRegistry.For("tomas").Generate(id, modelAnswerText)
```

### VoiceRegistry (new file: `backend/internal/processing/voice_registry.go`)

```go
type VoiceInfo struct {
    ID       string `json:"id"`
    Name     string `json:"name"`
    Gender   string `json:"gender"`    // "female" | "male"
    Provider string `json:"provider"`  // "aws_polly" | "elevenlabs"
}

type VoiceRegistry struct {
    entries  []VoiceInfo
    providers map[string]TTSProvider
    defaultP  TTSProvider
}

// NewVoiceRegistry builds registry from env + existing configured providers.
// defaultTTS = processor's existing p.ttsProvider (backward compat).
func NewVoiceRegistry(defaultTTS TTSProvider, pollyVoice TTSProvider, elA, elC, elD TTSProvider) *VoiceRegistry

// For returns provider for voiceID, or defaultP if unknown/empty.
func (r *VoiceRegistry) For(voiceID string) TTSProvider

// Voices returns only configured voice entries (used by GET /v1/voices).
func (r *VoiceRegistry) Voices() []VoiceInfo
```

**Fallback guarantee:** `For("")`, `For("unknown")`, `For("")` → `defaultP` (never nil).

---

## 3. API Contracts

### GET /v1/voices

No auth required. Returns configured voice list.

```
GET /v1/voices

200 OK
{
  "data": [
    { "id": "jitka",       "name": "Jitka",  "gender": "female", "provider": "aws_polly"   },
    { "id": "tomas",       "name": "Tomáš",  "gender": "male",   "provider": "elevenlabs"  },
    { "id": "el_female_2", "name": "Jana",   "gender": "female", "provider": "elevenlabs"  },
    { "id": "el_male_2",   "name": "Marek",  "gender": "male",   "provider": "elevenlabs"  }
  ],
  "meta": {}
}
```

- Dev mode (TTS_PROVIDER unset): trả `[{id:"jitka",...}]` với DevTTSProvider stub.
- EL voice thiếu env: bị bỏ qua, không crash.

### GET /v1/voices/:id/preview

No auth required. Returns signed URL for short TTS sample.

```
GET /v1/voices/tomas/preview

200 OK
{ "data": { "url": "<signed url>", "mime_type": "audio/mpeg" }, "meta": {} }

404 Not Found   — voice ID không tồn tại trong registry
503 Service Unavailable — TTS generation failed (EL rate limit, AWS error, etc.)
  { "error": { "code": "tts_unavailable", "message": "..." } }
```

**Preview phrase:** `"Dobrý den, jsem připraven pomoci vám s učením češtiny."`

**Cache:** local file `$TMP/czech-go-system/voice-preview/<id>.mp3`
- Cache hit: skip TTS call, trả URL ngay.
- Cache miss: generate → write file → trả URL.
- Cache format: mp3 (EL default) hoặc wav (Polly) theo provider.
- Serve URL: same signed URL mechanism as existing review audio.

**EL error:** trả `503` — Flutter ẩn nút Preview hoặc show snackbar lỗi. Không fallback voice.

### POST /v1/attempts/:id/submit-text (thay đổi nhỏ)

Thêm optional field vào `WritingSubmission`:
```go
type WritingSubmission struct {
    Answers         []string `json:"answers,omitempty"`
    Text            string   `json:"text,omitempty"`
    PreferredVoiceID string  `json:"preferred_voice_id,omitempty"`  // NEW — empty = default
}
```
Backward compat: field omitted → empty string → default voice.

### POST /v1/attempts/:id/upload-complete (thay đổi nhỏ)

Hiện tại: có thể không parse body hoặc parse empty `{}`.
Sau: parse optional JSON:
```go
type uploadCompleteRequest struct {
    PreferredVoiceID string `json:"preferred_voice_id,omitempty"`
}
```
Backward compat: body empty/missing → `preferredVoiceID = ""` → default.

### ProcessAttempt signature change

```go
// Before:
func (p *Processor) ProcessAttempt(attemptID, locale string) error

// After:
func (p *Processor) ProcessAttempt(attemptID, locale, preferredVoiceID string) error
```

Internal: `p.ttsProvider.Generate(...)` → `p.voiceRegistry.For(preferredVoiceID).Generate(...)`

---

## 4. Flutter Spec

### VoicePreferenceService (`core/voice/voice_preference_service.dart`)

```dart
class VoicePreferenceService {
  static const _key = 'pref_voice_id';

  final SharedPreferences _prefs;
  const VoicePreferenceService._(this._prefs);

  static Future<VoicePreferenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return VoicePreferenceService._(prefs);
  }

  String get current => _prefs.getString(_key) ?? '';
  Future<void> save(String voiceId) => _prefs.setString(_key, voiceId);
}
```

Instantiated once in `main.dart`, injected vào ProfileScreen.

### VoiceOption model (`core/voice/voice_option.dart`)

```dart
class VoiceOption {
  final String id, name, gender, provider;
  const VoiceOption({required this.id, required this.name,
                     required this.gender, required this.provider});
  factory VoiceOption.fromJson(Map<String, dynamic> j) => VoiceOption(
    id: j['id'] as String, name: j['name'] as String,
    gender: j['gender'] as String, provider: j['provider'] as String,
  );
}
```

### api_client additions

```dart
Future<List<VoiceOption>> getVoices() async {
  final payload = await _authed('GET', '/v1/voices');
  return (payload['data'] as List).map((e) => VoiceOption.fromJson(e)).toList();
}

Future<String?> getVoicePreviewUrl(String voiceId) async {
  try {
    final payload = await _authed('GET', '/v1/voices/$voiceId/preview');
    return (payload['data'] as Map)['url'] as String?;
  } catch (_) { return null; }
}

Future<void> submitText(String attemptId, {
  List<String>? answers, String? text, String? preferredVoiceId,
}) async {
  final body = <String, dynamic>{};
  if (answers != null) body['answers'] = answers;
  if (text != null) body['text'] = text;
  if (preferredVoiceId != null && preferredVoiceId.isNotEmpty)
    body['preferred_voice_id'] = preferredVoiceId;
  await _authed('POST', '/v1/attempts/$attemptId/submit-text', body: body);
}
```

Speaking upload-complete: thêm `preferred_voice_id` vào body của call hiện tại.

### ProfileScreen — _VoicePickerSection

StatefulWidget. State: `List<VoiceOption> _voices`, `String _selectedId`, `String? _playingId`.

```
initState:
  1. VoicePreferenceService.current → _selectedId
  2. api_client.getVoices() → _voices (on error: _voices = [])

UI:
  if (_voices.isEmpty) → SizedBox.shrink()
  else:
    Section header: l.profileVoiceSection
    ListView of _VoiceCard per voice

_VoiceCard:
  Tap → VoicePreferenceService.save(voice.id) + setState(_selectedId)
  Selected: orange border + check icon
  "Nghe thử" button:
    → getVoicePreviewUrl(voice.id) → AudioPlayer().setUrl(url) → play()
    → on error: ScaffoldMessenger.showSnackBar(...)
    → setState(_playingId) for loading indicator
```

**i18n keys** (thêm vào `app_vi.arb` + `app_en.arb`):

| Key | VI | EN |
|---|---|---|
| `profileVoiceSection` | `"Giọng đọc mẫu"` | `"Model answer voice"` |
| `profileVoicePreview` | `"Nghe thử"` | `"Preview"` |
| `profileVoiceFemale` | `"Nữ"` | `"Female"` |
| `profileVoiceMale` | `"Nam"` | `"Male"` |
| `profileVoiceProviderPolly` | `"AWS Polly"` | `"AWS Polly"` |
| `profileVoiceProviderElevenLabs` | `"ElevenLabs"` | `"ElevenLabs"` |
| `profileVoicePreviewError` | `"Không thể phát thử giọng này"` | `"Could not preview this voice"` |

---

## 5. Environment Variables

### Mới (backend)

| Var | Default | Mô tả |
|---|---|---|
| `ELEVENLABS_VOICE_ID_C` | _(unset)_ | EL voice ID cho Czech nữ thứ 2. Unset → voice C không xuất hiện. |
| `ELEVENLABS_VOICE_ID_D` | _(unset)_ | EL voice ID cho Czech nam thứ 2. Unset → voice D không xuất hiện. |
| `VOICE_C_NAME` | `"Jana"` | Display name cho voice C |
| `VOICE_D_NAME` | `"Marek"` | Display name cho voice D |

### Giữ nguyên (đã có)

- `POLLY_VOICE_ID` → Jitka (slot 1)
- `ELEVENLABS_VOICE_ID` → Tomas (slot 2)
- `ELEVENLABS_API_KEY` → required cho EL voices

---

## 6. Testing Strategy

### Backend unit tests (`make backend-test`)

- `VoiceRegistry.For("")` → returns defaultP
- `VoiceRegistry.For("unknown_slug")` → returns defaultP
- `VoiceRegistry.For("tomas")` → returns EL provider
- `VoiceRegistry.Voices()` → excludes unconfigured EL voices
- `GET /v1/voices` — dev mode: 200 + at least jitka
- `GET /v1/voices/unknown/preview` → 404
- `ProcessAttempt` with `preferredVoiceID="tomas"` uses correct provider (mock registry)
- `ProcessWritingAttempt` with `sub.PreferredVoiceID="jitka"` uses correct provider
- `handleUploadComplete` backward compat: empty body → `preferredVoiceID=""`

### Flutter tests (`make flutter-test`)

- `VoiceOption.fromJson` parses correctly
- `VoicePreferenceService.save/current` round-trip
- `api_client.submitText` includes `preferred_voice_id` only when non-empty

### Manual verification

1. Dev mode: `GET /v1/voices` → `[{id:"jitka",...}]`
2. With EL env vars: `GET /v1/voices` → 2–4 entries
3. `GET /v1/voices/jitka/preview` → URL; gọi lại → same URL (cache)
4. Profile → tap Tomáš → Tomáš selected → làm bài viết → review audio = Tomáš
5. Kill + restart app → Tomáš vẫn selected

---

## 7. Boundaries

**Always do:**
- `VoiceRegistry.For()` phải never return nil — luôn fallback default
- `preferred_voice_id` absent/empty → giữ nguyên behavior hiện tại (backward compat)
- Preview cache: skip TTS nếu file đã tồn tại local
- Flutter: ẩn voice section nếu `GET /v1/voices` fail (feature is non-critical)

**Ask first about:**
- Thêm voice thứ 5+ (ngoài scope V8)
- Per-exercise-type voice preference
- Sync preference lên server (DB migration)

**Never do:**
- Tạo migration DB cho voice preference (SharedPreferences đủ dùng V1)
- Affect послech pre-generated audio
- Block app startup nếu `GET /v1/voices` chậm
- Hardcode EL voice IDs trong code — luôn dùng env vars
