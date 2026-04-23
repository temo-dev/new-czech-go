import 'package:app_czech/shared/models/user_model.dart';
import 'package:app_czech/features/mock_test/models/mock_test_result.dart';

/// A single row in the weekly leaderboard.
class LeaderboardRow {
  const LeaderboardRow({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.weeklyXp,
    required this.rank,
    this.isCurrentUser = false,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int weeklyXp;
  final int rank;
  final bool isCurrentUser;
}

/// Static recommendation for MVP — first lesson of the user's weakest skill.
class RecommendedLesson {
  const RecommendedLesson({
    required this.lessonId,
    required this.lessonTitle,
    required this.moduleTitle,
    required this.skill,
    required this.courseId,
    required this.moduleId,
    required this.courseSlug,
  });

  final String lessonId;
  final String lessonTitle;
  final String moduleTitle;
  final String skill;
  final String courseId;
  final String moduleId;
  final String courseSlug;
}

/// Stub course progress — wired properly on Day 9.
class CourseProgress {
  const CourseProgress({
    required this.courseId,
    required this.courseSlug,
    required this.courseTitle,
    required this.skill,
    required this.completedLessons,
    required this.totalLessons,
  });

  final String courseId;
  final String courseSlug;
  final String courseTitle;
  final String skill;
  final int completedLessons;
  final int totalLessons;

  double get progressFraction =>
      totalLessons > 0 ? completedLessons / totalLessons : 0;
}

/// Composed dashboard payload returned by [dashboardProvider].
class DashboardData {
  const DashboardData({
    required this.user,
    this.latestResult,
    this.recommendation,
    this.leaderboardPreview = const [],
    this.ownRank,
    this.activeCourse,
  });

  final AppUser user;
  final MockTestResult? latestResult;
  final RecommendedLesson? recommendation;
  final List<LeaderboardRow> leaderboardPreview;
  final int? ownRank;
  final CourseProgress? activeCourse;

  bool get hasResult => latestResult != null;
}
