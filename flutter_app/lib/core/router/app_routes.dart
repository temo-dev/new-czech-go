abstract final class AppRoutes {
  static const home = '/';

  // Uloha flow: prompt → recording → feedback
  // :taskType = uloha1 | uloha2 | uloha3 | uloha4
  static const ulohaPrompt    = '/uloha/:taskType/prompt';
  static const ulohaRecording = '/uloha/:taskType/recording';
  static const ulohaFeedback  = '/uloha/:taskType/feedback/:attemptId';

  // Named helpers for context.go()
  static String promptPath(String taskType) =>
      '/uloha/$taskType/prompt';
  static String recordingPath(String taskType) =>
      '/uloha/$taskType/recording';
  static String feedbackPath(String taskType, String attemptId) =>
      '/uloha/$taskType/feedback/$attemptId';
}
