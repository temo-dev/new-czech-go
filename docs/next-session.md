# Next Session

## Resume Prompt
Use this in a new chat:

`Tiếp tục dự án ở /Users/daniel.dev/Desktop/czech-go-system. Đọc AGENTS.md và docs/README.md trước, rồi tiếp tục từ slice gần nhất.`

Or the more specific version:

`Tiếp tục dự án ở /Users/daniel.dev/Desktop/czech-go-system. Đọc AGENTS.md và docs/README.md trước. Chúng ta đã có Flutter ghi âm thật, upload binary lên backend dev, và attempt đã lưu audio metadata. Hãy tiếp tục bước kế tiếp.`

## Current State
- `Flutter` can record real local audio.
- `Flutter` uploads the recorded binary to the backend dev upload target.
- Backend stores the uploaded audio in local temp storage.
- `Attempt` now retains audio metadata.
- Result UI shows uploaded audio metadata, transcript, and feedback.
- `CMS` and `Flutter` both use bundled local `Playfair Display`.

## Recommended Reading Order
1. [AGENTS.md](/Users/daniel.dev/Desktop/czech-go-system/AGENTS.md)
2. [docs/README.md](/Users/daniel.dev/Desktop/czech-go-system/docs/README.md)
3. [api-contracts.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/api-contracts.md)
4. [uloha-1-practice.md](/Users/daniel.dev/Desktop/czech-go-system/docs/features/uloha-1-practice.md)
5. [flutter-exercise-practice.md](/Users/daniel.dev/Desktop/czech-go-system/docs/screens/flutter-exercise-practice.md)

## Best Next Step
Choose one:
- Add playback for the recorded audio in `Flutter`
- Replace mock transcript/scoring with a more real backend pipeline
- Start persistence work for uploaded audio metadata and attempts

## Last Verified
- `cms lint` pass
- `cms build` pass
- `go build ./...` pass
- `flutter analyze` pass
- `flutter test` pass
- `go test ./...` has no tests yet

## Important Constraints
- Always prefix shell commands with `rtk`
- Use root [AGENTS.md](/Users/daniel.dev/Desktop/czech-go-system/AGENTS.md)
- Do not reintroduce remote font fetching
- Keep the current upload contract stable while improving internals
