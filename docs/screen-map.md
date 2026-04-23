# Screen Map

Per-screen contracts: file path, provider(s), UI states, and key interactions.

---

## Landing & Auth

### `LandingScreen`
**File**: `lib/features/landing/screens/landing_screen.dart`
**Provider**: none
**States**: static
**Actions**: → `/auth/login`, → `/mock-test/intro?examId=<defaultId>`

---

### `LoginScreen`
**File**: `lib/features/auth/screens/login_screen.dart`
**Provider**: `authNotifierProvider`
**States**: `idle`, `loading`, `error(message)`
**Actions**: `signIn(email, password)` → success: redirect to `?from=` or `/app/dashboard`; → `/auth/signup`, → `/auth/forgot-password`

---

### `SignupScreen`
**File**: `lib/features/auth/screens/signup_screen.dart`
**Provider**: `authNotifierProvider`
**States**: `idle`, `loading`, `error(message)`
**Actions**: `signUp(email, password, displayName)` → success: anonymous session linking → `/app/dashboard`

---

### `ForgotPasswordScreen`
**File**: `lib/features/auth/screens/forgot_password_screen.dart`
**Provider**: `authNotifierProvider`
**States**: `idle`, `loading`, `sent`, `error`
**Actions**: `sendPasswordReset(email)`

---

---

## Mock Test (Public)

### `MockTestIntroScreen`
**File**: `lib/features/mock_test/screens/mock_test_intro_screen.dart`
**Provider**: `mockExamMetaProvider`
**States**: `loading` (shimmer), `success`, `error`
**Data**: exam title, section breakdown (count + skill + duration)
**Actions**: "Bắt đầu thi" → creates `exam_attempts` row → `/mock-test/question/:attemptId`

---

### `MockTestQuestionScreen`
**File**: `lib/features/mock_test/screens/mock_test_question_screen.dart`
**Provider**: `examSessionNotifier`, `examQuestionsProvider`
**States**: `loading`, `active`, `sectionTransition`, `submitting`, `submitted`, `error`
**UI**: top bar (timer, section label, progress), question area, navigation panel, autosave indicator
**Actions**: answer → autosave to `exam_attempts.answers` theo `question_id`; "Nộp bài" → đảm bảo writing AI attempts được tạo, gọi `grade-exam`, chờ `exam_results` row rồi mới chuyển `/mock-test/result/:attemptId`
**Special**: timer ticks via `Ticker`; timer sync xuống DB theo checkpoint + lifecycle; section transition card shown between skills; nếu mọi section đều có `section_duration_minutes`, timer và điều hướng được khóa theo từng section thay vì một countdown global; listening prompts and listening fill-blank now play real remote audio through the inline exercise audio player instead of a mock UI state

---

### `MockTestResultScreen`
**File**: `lib/features/mock_test/screens/mock_test_result_screen.dart`
**Provider**: `examResultProvider`, `examAnalysisProvider`
**States**: `loading` (shimmer), `success`, `error`, `analysis_loading`
**UI**: total score hero, pass/fail badge, skill breakdown chart, weak skills list, `OverallInsightsCard`, preloaded `QuestionReviewList`, CTA (signup if guest, retry or review if auth)
**Actions**: "Xem lại đáp án" → review mode on same screen; "Thi lại" → new attempt; auth CTA → `/auth/signup`
**Special**: polling có kiểm soát cho tới khi `exam_results` row sẵn sàng; sau đó tiếp tục đọc `exam_analysis` làm source of truth duy nhất cho mock-test review. Objective summary đọc từ `question_feedbacks`; speaking/writing summary cũng đọc từ `question_feedbacks`, còn detail screen đọc từ `teacher_reviews_by_question`. Khi `exam_results.ai_grading_pending = true`, màn này chỉ hiển thị trạng thái “AI đang chấm toàn bộ bài thi” + rule official, chưa hiển thị tổng điểm cuối / pass-fail / breakdown kỹ năng như kết quả chính thức.

### `MockTestSubjectiveReviewScreen`
**File**: `lib/features/mock_test/screens/mock_test_subjective_review_screen.dart`
**Provider**: `examAnalysisProvider`
**States**: `loading` (skeleton), `processing`, `ready`, `error`
**UI**: read-only `AiTeacherDetailView` cho 1 câu speaking/writing trong mock test
**Actions**: back → `/mock-test/result/:attemptId`
**Special**: screen này chỉ dùng cho mock test; không submit hay poll `ai_teacher_reviews`, chỉ đọc payload đã materialize trong `exam_analysis.teacher_reviews_by_question`

---

## Dashboard

### `DashboardScreen`
**File**: `lib/features/dashboard/screens/dashboard_screen.dart`
**Provider**: `dashboardProvider`
**States**: `loading` (shimmer skeleton), `success`, `error` (with retry)
**UI cards**: greeting header, streak card, XP/points card, latest result card, recommended lesson card, course progress card, leaderboard preview card
**Actions**: tap recommended lesson → lesson player; tap leaderboard preview → `/app/leaderboard`

---

## Courses

### `CourseCatalogScreen`
**File**: `lib/features/course/screens/course_catalog_screen.dart`
**Provider**: `courseCatalogProvider`
**States**: `loading`, `success`, `empty`, `error`
**Actions**: tap course card → `/app/courses/:courseId`

---

### `CourseDetailScreen`
**File**: `lib/features/course/screens/course_detail_screen.dart`
**Provider**: `courseDetailProvider`
**States**: `loading`, `success`, `error`
**UI**: header banner (thumbnail, instructor, duration), module list with progress rings
**Actions**: tap module → `/app/courses/:courseId/modules/:moduleId`

---

### `ModuleDetailScreen`
**File**: `lib/features/course/screens/module_detail_screen.dart`
**Provider**: `moduleDetailProvider`
**States**: `loading`, `success`, `error`
**UI**: module header card, lesson list (status badges: locked/available/in-progress/completed), block progress counts, replay badge for completed lessons
**Actions**: tap available/in-progress/completed lesson → `/app/courses/.../lessons/:lessonId`

---

### `LessonPlayerScreen`
**File**: `lib/features/course/screens/lesson_player_screen.dart`
**Provider**: `lessonDetailProvider`, `exerciseSessionProvider`
**States**: `loading`, `active`, `blockComplete`, `allComplete`, `error`
**UI**: lesson header card, block cards (vocab/grammar/reading/listening/speaking/writing), exercise progress footer
**Special**: hides `AppShell` bottom nav. Every block flow can mark `user_progress`; completed lessons can be reset and replayed.
**Actions**: normal CTA → module detail, completed CTA `Học lại bài này` → reset lesson progress, "Mở bài thưởng" (if bonus available) → `/app/unlock-bonus/:lessonId`

---

### `UnlockBonusScreen`
**File**: `lib/features/course/screens/unlock_bonus_screen.dart`
**Provider**: `lessonDetailProvider`, `currentUserProvider`
**States**: `idle`, `loading`, `success`, `error (insufficient_xp)`
**Actions**: "Mở khóa" → calls `unlock_lesson_bonus` RPC → invalidates `lessonDetailProvider` + `currentUserProvider`

---

## Exam Catalog

### `ExamCatalogScreen`
**File**: `lib/features/mock_test/screens/exam_catalog_screen.dart`
**Provider**: `examListProvider`
**States**: `loading`, `success`, `empty`, `error`
**Actions**: tap exam → `/mock-test/intro?examId=<id>` (public) or `/app/simulator/intro` (full simulator)

---

## Practice (Exercise Flow)

### `PracticeScreen`
**File**: `lib/features/exercise/screens/practice_screen.dart`
**Provider**: `exerciseSessionProvider`
**States**: `loading`, `success`, `error`
**Actions**: initializes exercise session → `/app/practice/intro`

---

### `ExerciseIntroScreen`
**File**: `lib/features/exercise/screens/exercise_intro_screen.dart`
**Provider**: `exerciseSessionProvider`
**States**: static (shows exercise count + skill)
**Actions**: "Bắt đầu" → `/app/practice/question/0`

---

### `ExerciseQuestionScreen`
**File**: `lib/features/exercise/screens/exercise_question_screen.dart`
**Provider**: `exerciseSessionProvider`
**States**: `question`, `submitting`
**UI**: `QuestionShell` + appropriate exercise widget (MCQ, fill-blank, listening, reading, speaking recorder, writing input)
**Actions**: submit answer → `exerciseSession.submitAnswer()` → `awardXp()` if correct → `/app/practice/explanation`
**Special**: listening exercises and listening fill-blank questions use the inline audio player backed by `just_audio`, so exercise flows consume the same remote `audio_url` assets as mock tests

---

### `ExerciseExplanationScreen`
**File**: `lib/features/exercise/screens/exercise_explanation_screen.dart`
**Provider**: `exerciseSessionProvider`
**States**: `explanation`
**UI**: result badge (correct/incorrect), `ExplanationPanel` (correct answer + explanation), "Tiếp theo" button
**Actions**: "Tiếp theo" → next question or `completed` state → back to lesson

---

## Full Simulator

### `SimulatorIntroScreen`
**File**: `lib/features/simulator/screens/simulator_intro_screen.dart`
**Provider**: `mockExamMetaProvider`, `isPremiumProvider`
**States**: `loading`, `success`, `locked` (non-premium)
**Actions**: "Bắt đầu" → creates attempt → `/app/simulator/question/0`

---

### `SimulatorQuestionScreen`
**File**: `lib/features/simulator/screens/simulator_question_screen.dart`
**Provider**: `examSessionNotifier`
**States**: same as `MockTestQuestionScreen`
**Special**: uses same `examSessionNotifier` — only difference is route prefix and auth requirement.

---

### `SimulatorResultScreen`
**File**: `lib/features/simulator/screens/simulator_result_screen.dart`
**Provider**: `examResultProvider`
**States**: `loading`, `success`, `error`
**UI**: same as `MockTestResultScreen` but always authenticated.

---

## Speaking AI

### `SpeakingPromptScreen`
**File**: `lib/features/speaking_ai/screens/speaking_prompt_screen.dart`
**Provider**: `exerciseSessionProvider` or direct exercise arg, `isPremiumProvider`
**States**: `loading`, `success`, `locked`
**UI**: question prompt + recording tips
**Actions**: "Bắt đầu thu âm" → `/app/speaking/recording`

---

### `SpeakingRecordingScreen`
**File**: `lib/features/speaking_ai/screens/speaking_recording_screen.dart`
**Provider**: `speakingProvider`
**States**: `idle`, `recording`, `uploading`, `processing`, `error`
**UI**: waveform visualizer, recording timer, stop button
**Actions**: stop → `speakingProvider.stopAndUpload()` → polls → `/app/speaking/feedback`

---

### `SpeakingFeedbackScreen`
**File**: `lib/features/speaking_ai/screens/speaking_feedback_screen.dart`
**Provider**: `speakingFeedbackProvider(attemptId)`
**States**: `loading` (shimmer), `processing` (polling indicator), `ready`, `error` (with retry)
**UI**: total score ring, metric breakdown cards (Phát âm/Lưu loát/Từ vựng/Ngữ pháp), annotated transcript (highlighted issues), short tips, corrected answer
**Actions**: "Thử lại" → back to recording; "Xem đánh giá giáo viên" → `/app/teacher/inbox`
**Special**: dùng cho lesson/practice/exercise path; mock test dùng `MockTestSubjectiveReviewScreen` thay vì route này

---

## Writing AI

### `WritingPromptScreen`
**File**: `lib/features/writing_ai/screens/writing_prompt_screen.dart`
**Provider**: `exerciseSessionProvider`, `isPremiumProvider`
**States**: `loading`, `success`, `locked`
**UI**: question prompt, text input area (1–500 chars), character counter
**Actions**: "Nộp bài" → `writingProvider.submit()` → first `pending` state pushes exactly once to `/app/writing/feedback`; lesson flow passes `exercise_id`, mock test passes `question_id + exam_attempt_id`

---

### `WritingFeedbackScreen`
**File**: `lib/features/writing_ai/screens/writing_feedback_screen.dart`
**Provider**: `writingProvider`
**States**: `loading` (shimmer), `processing`, `ready`, `error` (with retry)
**UI**: total score ring, metric breakdown cards (Ngữ pháp/Từ vựng/Mạch lạc/Nội dung), annotated text (highlighted grammar/vocab spans), corrected essay, short tips
**Actions**: "Thử lại" → back to prompt; "Xem đánh giá giáo viên" → `/app/teacher/inbox`
**Special**: dùng cho lesson/practice/exercise path; mock test dùng `MockTestSubjectiveReviewScreen` thay vì route này

---

## Social

### `LeaderboardScreen`
**File**: `lib/features/leaderboard/screens/leaderboard_screen.dart`
**Provider**: `leaderboardProvider`
**States**: `loading`, `success`, `error`
**UI**: weekly XP ranking list; own row highlighted; tap row → `LeaderboardUserSheet` (avatar, stats, add friend CTA)

---

### `InboxScreen`
**File**: `lib/features/chat/screens/inbox_screen.dart`
**Provider**: `conversationListProvider` (stream)
**States**: `loading`, `success (list)`, `empty`, `error`
**Actions**: tap conversation → `/app/chat/:roomId`; FAB → friend search for new DM

---

### `ChatRoomScreen`
**File**: `lib/features/chat/screens/chat_room_screen.dart`
**Provider**: `chatRoomProvider(roomId)` (stream), `sendMessageProvider`
**States**: `loading`, `active`, `error`
**UI**: message list (reverse scroll), `MessageInputBar` (text + attachment picker), `MessageBubble` (own/other), attachment previews
**Actions**: send text; pick file/image → upload to `chat-attachments` bucket → send file message

---

### `FriendsScreen`
**File**: `lib/features/chat/screens/friends_screen.dart`
**Provider**: `friendListProvider`, `friendRequestsProvider`, `userSearchProvider`
**States**: `loading`, `success`, `empty`
**Tabs**: Friends list, Pending requests, Search
**Actions**: accept/decline request; send request; "Nhắn tin" → `find_or_create_dm` RPC → `/app/chat/:roomId`

---

## Teacher Feedback

### `TeacherInboxScreen`
**File**: `lib/features/teacher_feedback/screens/teacher_inbox_screen.dart`
**Provider**: `teacherReviewListProvider`
**States**: `loading`, `success`, `empty`, `error`
**Actions**: tap thread → `/app/teacher/thread/:threadId`

---

### `TeacherThreadScreen`
**File**: `lib/features/teacher_feedback/screens/teacher_thread_screen.dart`
**Provider**: `teacherThreadProvider(reviewId)`
**States**: `loading`, `success`, `error`
**UI**: message thread (teacher comments interspersed with learner's original submission)
**Actions**: reply (learner); close thread

---

## Progress & Profile

### `ProgressScreen`
**File**: `lib/features/progress/screens/progress_screen.dart`
**Provider**: `progressProvider`
**States**: `loading`, `success`, `empty`, `error`
**UI**: skill accuracy bars, XP chart, streak history, completed lesson count

---

### `NotificationsScreen`
**File**: `lib/features/notifications/screens/notifications_screen.dart`
**Provider**: `notificationPrefsProvider`
**States**: `loading`, `success`
**UI**: toggle enabled/disabled, reminder hour picker, timezone selector

---

### `ProfileScreen`
**File**: `lib/features/profile/screens/profile_screen.dart`
**Provider**: `currentUserProvider`
**States**: `loading`, `success`, `error`
**UI**: avatar, display name, XP, streak, subscription badge, exam date countdown
**Actions**: → `/app/profile/settings`; → `/app/notifications`; → `/app/progress`

---

### `SettingsScreen`
**File**: `lib/features/profile/screens/settings_screen.dart`
**Provider**: `currentUserProvider`, `notificationPrefsProvider`
**States**: `loading`, `success`
**Actions**: edit display name/avatar/exam date/daily goal; change locale; sign out

---

## Shell

### `AppShell`
**File**: `lib/features/shell/app_shell.dart`
**Provider**: `connectivityProvider`, `currentUserProvider`
**Layout**:
- `< 900px`: `NavigationBar` at bottom (`BottomNavBar` widget)
- `≥ 900px`: `NavigationRail` on left (`SideRailNav` widget), content capped at `maxWidth: 1200`
**Special**: shows `OfflineBanner` when `connectivityProvider == offline`. Hides bottom nav on full-screen routes.
