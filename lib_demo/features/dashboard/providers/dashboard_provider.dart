import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';
import 'package:app_czech/features/mock_test/models/mock_test_result.dart';
import 'package:app_czech/features/dashboard/models/dashboard_models.dart';

/// Composes user profile + latest result + leaderboard preview into one payload.
/// Uses FutureProvider.autoDispose (no codegen required).
final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) throw Exception('Not authenticated');

  // ── Run all three data groups in parallel ─────────────────────────────────
  final results = await Future.wait([
    _fetchLatestResult(user.id),
    _fetchLeaderboard(user.id),
    _fetchCourseData(user.id),
  ]);

  final latestResult = results[0] as MockTestResult?;
  final leaderboardResult = results[1] as _LeaderboardResult;
  final courseData = results[2] as _CourseData;
  final finalizedLatestResult =
      latestResult?.hasOfficialResult == true ? latestResult : null;

  // ── Build recommendation from weakest skill (or active course skill) ──────
  final weakSkill = finalizedLatestResult?.weakSkills.isNotEmpty == true
      ? finalizedLatestResult!.weakSkills.first
      : courseData.activeCourse?.skill;

  RecommendedLesson? recommendation;
  if (weakSkill != null && courseData.courses.isNotEmpty) {
    recommendation = _buildRecommendation(
      courseData.courses,
      weakSkill,
      courseData.completedBlockIds,
    );
  }

  return DashboardData(
    user: user,
    latestResult: latestResult,
    recommendation: recommendation,
    leaderboardPreview: leaderboardResult.rows,
    ownRank: leaderboardResult.ownRank,
    activeCourse: courseData.activeCourse,
  );
});

// ── Private fetch helpers ──────────────────────────────────────────────────

Future<MockTestResult?> _fetchLatestResult(String userId) async {
  try {
    final data = await supabase
        .from('exam_results')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    final raw = Map<String, dynamic>.from(data as Map);
    final rawSections = (raw['section_scores'] as Map<String, dynamic>?) ?? {};
    final sectionScores = rawSections.map(
      (k, v) => MapEntry(
        k,
        SectionResult.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
    final rawWeak = raw['weak_skills'];
    final weakSkills =
        rawWeak is List ? List<String>.from(rawWeak) : <String>[];
    return MockTestResult(
      id: raw['id'] as String,
      attemptId: raw['attempt_id'] as String,
      userId: raw['user_id'] as String?,
      totalScore: raw['total_score'] as int? ?? 0,
      passThreshold: raw['pass_threshold'] as int? ?? 60,
      sectionScores: sectionScores,
      weakSkills: weakSkills,
      passed: raw['passed'] as bool? ??
          ((raw['total_score'] as int? ?? 0) >=
              (raw['pass_threshold'] as int? ?? 60)),
      writtenScore: raw['written_score'] as int? ?? 0,
      writtenTotal: raw['written_total'] as int? ?? 70,
      writtenPassThreshold: raw['written_pass_threshold'] as int? ?? 42,
      speakingScore: raw['speaking_score'] as int? ?? 0,
      speakingTotal: raw['speaking_total'] as int? ?? 40,
      speakingPassThreshold: raw['speaking_pass_threshold'] as int? ?? 24,
      aiGradingPending: raw['ai_grading_pending'] as bool? ?? false,
      createdAt: DateTime.parse(raw['created_at'] as String),
    );
  } catch (_) {
    return null;
  }
}

class _LeaderboardResult {
  const _LeaderboardResult({required this.rows, this.ownRank});
  final List<LeaderboardRow> rows;
  final int? ownRank;
}

Future<_LeaderboardResult> _fetchLeaderboard(String userId) async {
  try {
    final weekStart = _currentWeekStart();

    // Top 3 for preview card
    final rows = await supabase
        .from('leaderboard_weekly')
        .select()
        .eq('week_start', weekStart)
        .order('weekly_xp', ascending: false)
        .limit(3);

    final leaderboardRows = (rows as List).asMap().entries.map((e) {
      final row = Map<String, dynamic>.from(e.value as Map);
      return LeaderboardRow(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? 'Người dùng',
        avatarUrl: row['avatar_url'] as String?,
        weeklyXp: row['weekly_xp'] as int? ?? 0,
        rank: e.key + 1,
        isCurrentUser: row['user_id'] == userId,
      );
    }).toList();

    // Own rank: fetch own XP then count users ranked above
    final ownRow = await supabase
        .from('leaderboard_weekly')
        .select('weekly_xp')
        .eq('week_start', weekStart)
        .eq('user_id', userId)
        .maybeSingle();

    int? ownRank;
    if (ownRow != null) {
      final ownXp = (ownRow as Map)['weekly_xp'] as int? ?? 0;
      final above = await supabase
          .from('leaderboard_weekly')
          .select('user_id')
          .eq('week_start', weekStart)
          .gt('weekly_xp', ownXp);
      ownRank = (above as List).length + 1;
    }

    return _LeaderboardResult(rows: leaderboardRows, ownRank: ownRank);
  } catch (_) {
    return const _LeaderboardResult(rows: []);
  }
}

String _currentWeekStart() {
  final now = DateTime.now().toUtc();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}

class _CourseData {
  const _CourseData({
    required this.courses,
    required this.completedBlockIds,
    this.activeCourse,
  });
  final List<Map<String, dynamic>> courses;
  final Set<String> completedBlockIds;
  final CourseProgress? activeCourse;
}

Future<_CourseData> _fetchCourseData(String userId) async {
  try {
    // Fetch progress and course structure in parallel
    final fetches = await Future.wait([
      supabase
          .from('user_progress')
          .select('lesson_id, lesson_block_id, completed_at')
          .eq('user_id', userId),
      supabase.from('courses').select(
          'id, slug, title, skill, modules(id, title, order_index, lessons(id, title, order_index, lesson_blocks(id)))'),
    ]);

    // Build lookup structures from user_progress
    final completedBlockIds = <String>{};
    final lessonLastActive = <String, DateTime>{};

    for (final row in (fetches[0] as List)) {
      final r = Map<String, dynamic>.from(row as Map);
      completedBlockIds.add(r['lesson_block_id'] as String);
      final lessonId = r['lesson_id'] as String;
      final completedAt = DateTime.parse(r['completed_at'] as String);
      final existing = lessonLastActive[lessonId];
      if (existing == null || completedAt.isAfter(existing)) {
        lessonLastActive[lessonId] = completedAt;
      }
    }

    final courses = (fetches[1] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (courses.isEmpty) {
      return const _CourseData(courses: [], completedBlockIds: {});
    }

    // Find the most recently active course
    CourseProgress? activeCourse;
    DateTime? bestActivity;

    for (final course in courses) {
      final modules = _sortedModules(course);
      int totalLessons = 0;
      int completedLessons = 0;
      DateTime? courseLastActive;

      for (final module in modules) {
        for (final lesson in _sortedLessons(module)) {
          totalLessons++;
          final lessonId = lesson['id'] as String;
          final blockIds = _blockIds(lesson);
          if (blockIds.isNotEmpty &&
              blockIds.every(completedBlockIds.contains)) {
            completedLessons++;
          }
          final lastActive = lessonLastActive[lessonId];
          if (lastActive != null &&
              (courseLastActive == null ||
                  lastActive.isAfter(courseLastActive))) {
            courseLastActive = lastActive;
          }
        }
      }

      final candidate = CourseProgress(
        courseId: course['id'] as String,
        courseSlug: course['slug'] as String,
        courseTitle: course['title'] as String,
        skill: course['skill'] as String,
        completedLessons: completedLessons,
        totalLessons: totalLessons,
      );

      if (activeCourse == null) {
        // First course is the default fallback
        activeCourse = candidate;
        bestActivity = courseLastActive;
      } else if (courseLastActive != null &&
          (bestActivity == null || courseLastActive.isAfter(bestActivity))) {
        activeCourse = candidate;
        bestActivity = courseLastActive;
      }
    }

    return _CourseData(
      courses: courses,
      completedBlockIds: completedBlockIds,
      activeCourse: activeCourse,
    );
  } catch (_) {
    return const _CourseData(courses: [], completedBlockIds: {});
  }
}

/// Returns the first incomplete lesson for [skill] as a [RecommendedLesson].
/// Returns null if all lessons are complete or the skill has no course.
RecommendedLesson? _buildRecommendation(
  List<Map<String, dynamic>> courses,
  String skill,
  Set<String> completedBlockIds,
) {
  Map<String, dynamic>? course;
  for (final c in courses) {
    if (c['skill'] == skill) {
      course = c;
      break;
    }
  }
  if (course == null) return null;

  for (final module in _sortedModules(course)) {
    for (final lesson in _sortedLessons(module)) {
      final blockIds = _blockIds(lesson);
      final allDone =
          blockIds.isNotEmpty && blockIds.every(completedBlockIds.contains);
      if (!allDone) {
        return RecommendedLesson(
          lessonId: lesson['id'] as String,
          lessonTitle: lesson['title'] as String,
          moduleTitle: module['title'] as String,
          skill: skill,
          courseId: course['id'] as String,
          moduleId: module['id'] as String,
          courseSlug: course['slug'] as String,
        );
      }
    }
  }
  return null; // All lessons completed for this skill
}

// ── Tiny helpers ──────────────────────────────────────────────────────────

List<Map<String, dynamic>> _sortedModules(Map<String, dynamic> course) {
  final list = ((course['modules'] as List?) ?? [])
      .map((m) => Map<String, dynamic>.from(m as Map))
      .toList();
  list.sort(
      (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
  return list;
}

List<Map<String, dynamic>> _sortedLessons(Map<String, dynamic> module) {
  final list = ((module['lessons'] as List?) ?? [])
      .map((l) => Map<String, dynamic>.from(l as Map))
      .toList();
  list.sort(
      (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
  return list;
}

List<String> _blockIds(Map<String, dynamic> lesson) {
  return ((lesson['lesson_blocks'] as List?) ?? [])
      .map((b) => (Map<String, dynamic>.from(b as Map))['id'] as String)
      .toList();
}
