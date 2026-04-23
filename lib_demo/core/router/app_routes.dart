/// All named route paths in one place.
/// Use these constants in push/replace calls — never raw strings.
abstract final class AppRoutes {
  // ── Bootstrap ──────────────────────────────────────────────────────────────
  static const splash = '/';
  static const landing = '/landing';

  // ── Auth ───────────────────────────────────────────────────────────────────
  static const login = '/auth/login';
  static const signup = '/auth/signup';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password'; // deep link: ?token=

  // ── Free mock test (guest-accessible) ─────────────────────────────────────
  static const mockTestIntro = '/mock-test/intro';
  static const mockTestQuestion = '/mock-test/question/:attemptId';
  static const mockTestReview = '/mock-test/review';
  static const mockTestResult = '/mock-test/result/:attemptId';
  static const mockTestSubjectiveReview =
      '/mock-test/result/:attemptId/review/:questionId';

  // ── App shell root (authenticated) ─────────────────────────────────────────
  static const dashboard = '/app/dashboard';
  static const courses = '/app/courses';
  static const courseDetail = '/app/courses/:courseId';
  static const moduleDetail = '/app/courses/:courseId/modules/:moduleId';
  static const lessonPlayer =
      '/app/courses/:courseId/modules/:moduleId/lessons/:lessonId';

  static const practiceExercise = '/app/practice/exercise/:exerciseId';
  static const practiceIntro = '/app/practice/intro';
  static const practiceQuestion = '/app/practice/question/:index';
  static const practiceExplanation = '/app/practice/explanation';

  static const simulatorIntro = '/app/simulator/intro';
  static const simulatorTransition = '/app/simulator/transition/:section';
  static const simulatorQuestion = '/app/simulator/question/:index';
  static const simulatorResult = '/app/simulator/result';
  static const simulatorReview = '/app/simulator/result/review';

  static const speakingPrompt = '/app/speaking/prompt';
  static const speakingRecording = '/app/speaking/recording';
  static const speakingFeedback = '/app/speaking/feedback';

  static const writingPrompt = '/app/writing/prompt';
  static const writingFeedback = '/app/writing/feedback';

  static const examCatalog = '/app/exams';

  static const leaderboard = '/app/leaderboard';
  static const progress = '/app/progress';
  static const notifications = '/app/notifications';

  static const teacherInbox = '/app/teacher/inbox';
  static const teacherThread = '/app/teacher/thread/:threadId';

  // ── Chat / DM ──────────────────────────────────────────────────────────────
  static const inbox = '/app/chat';
  static const chatRoom = '/app/chat/:roomId';

  static const profile = '/app/profile';
  static const settings = '/app/profile/settings';
  static const unlockBonus = '/app/unlock-bonus/:lessonId';

  // ── Error ──────────────────────────────────────────────────────────────────
  static const error = '/error';

  // ── Path helpers ───────────────────────────────────────────────────────────
  static String courseDetailPath(String courseId) => '/app/courses/$courseId';
  static String moduleDetailPath(String courseId, String moduleId) =>
      '/app/courses/$courseId/modules/$moduleId';
  static String lessonPlayerPath(
          String courseId, String moduleId, String lessonId) =>
      '/app/courses/$courseId/modules/$moduleId/lessons/$lessonId';
  static String mockTestQuestionPath(String attemptId) =>
      '/mock-test/question/$attemptId';
  static String mockTestResultPath(String attemptId) =>
      '/mock-test/result/$attemptId';
  static String mockTestSubjectiveReviewPath(
    String attemptId,
    String questionId,
  ) =>
      '/mock-test/result/$attemptId/review/$questionId';
  static String practiceExercisePath(String exerciseId) =>
      '/app/practice/exercise/$exerciseId';
  static String practiceQuestionPath(int index) =>
      '/app/practice/question/$index';
  static String simulatorQuestionPath(int index) =>
      '/app/simulator/question/$index';
  static String simulatorTransitionPath(String section) =>
      '/app/simulator/transition/$section';
  static String teacherThreadPath(String threadId) =>
      '/app/teacher/thread/$threadId';
  static String chatRoomPath(String roomId) => '/app/chat/$roomId';
  static String unlockBonusPath(String lessonId) =>
      '/app/unlock-bonus/$lessonId';
  static String grammarPracticePath(String exerciseId) =>
      '/app/practice/exercise/$exerciseId';
  static String listeningPracticePath(String exerciseId) =>
      '/app/practice/exercise/$exerciseId';
  static String speakingPracticePath(String exerciseId) =>
      '/app/practice/exercise/$exerciseId';
  static String readingPracticePath(String exerciseId) =>
      '/app/practice/exercise/$exerciseId';
  static String writingPracticePath(String exerciseId) =>
      '/app/practice/exercise/$exerciseId';
  static String flashcardPracticePath(String exerciseId) =>
      '/app/practice/exercise/$exerciseId';
}
