import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class SkillScore {
  const SkillScore({required this.skill, required this.score});
  final String
      skill; // reading, listening, writing, speaking, vocabulary, grammar
  final double score; // 0.0–100.0
}

class ExamHistoryItem {
  const ExamHistoryItem({
    required this.attemptId,
    required this.totalScore,
    required this.passThreshold,
    required this.passed,
    required this.aiGradingPending,
    required this.createdAt,
  });
  final String attemptId;
  final int totalScore;
  final int passThreshold;
  final bool passed;
  final bool aiGradingPending;
  final DateTime createdAt;
}

/// A set of dates (normalised to midnight) on which user had activity.
typedef ActivityCalendar = Set<DateTime>;

class ProgressData {
  const ProgressData({
    required this.skillScores,
    required this.examHistory,
    required this.activityDates,
    required this.currentStreak,
    required this.totalXp,
    required this.completedLessons,
  });

  final List<SkillScore> skillScores;
  final List<ExamHistoryItem> examHistory;
  final ActivityCalendar activityDates;
  final int currentStreak;
  final int totalXp;
  final int completedLessons;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final progressProvider = FutureProvider.autoDispose<ProgressData>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) throw Exception('Not authenticated');

  // Profile (streak + xp)
  final profileRaw = await supabase
      .from('profiles')
      .select('current_streak_days, total_xp')
      .eq('id', userId)
      .maybeSingle();

  final profile = profileRaw != null
      ? Map<String, dynamic>.from(profileRaw as Map)
      : <String, dynamic>{};

  final currentStreak = profile['current_streak_days'] as int? ?? 0;
  final totalXp = profile['total_xp'] as int? ?? 0;

  // Exam history (last 20 results)
  final resultsRaw = await supabase
      .from('exam_results')
      .select(
          'attempt_id, total_score, pass_threshold, passed, ai_grading_pending, created_at')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(20);

  final examHistory = (resultsRaw as List)
      .map((r) {
        final rm = Map<String, dynamic>.from(r as Map);
        return ExamHistoryItem(
          attemptId: rm['attempt_id'] as String? ?? '',
          totalScore: rm['total_score'] as int? ?? 0,
          passThreshold: rm['pass_threshold'] as int? ?? 60,
          passed: rm['passed'] as bool? ??
              ((rm['total_score'] as int? ?? 0) >=
                  (rm['pass_threshold'] as int? ?? 60)),
          aiGradingPending: rm['ai_grading_pending'] as bool? ?? false,
          createdAt: DateTime.tryParse(rm['created_at'] as String? ?? '') ??
              DateTime.now(),
        );
      })
      .where((item) => !item.aiGradingPending)
      .toList();

  // Skill scores: average from section_scores across all results
  final Map<String, List<double>> skillAccum = {};
  for (final item in examHistory) {
    try {
      final full = await supabase
          .from('exam_results')
          .select('section_scores')
          .eq('attempt_id', item.attemptId)
          .maybeSingle();
      if (full == null) continue;
      final sections = (full as Map)['section_scores'] as Map<String, dynamic>?;
      if (sections == null) continue;
      for (final entry in sections.entries) {
        final sm = Map<String, dynamic>.from(entry.value as Map);
        final score = (sm['score'] as num?)?.toDouble() ?? 0;
        final total = (sm['total'] as num?)?.toDouble() ?? 100;
        final pct = total > 0 ? (score / total) * 100 : 0.0;
        skillAccum.putIfAbsent(entry.key, () => []).add(pct);
      }
    } catch (_) {}
  }

  final skillScores = skillAccum.entries.map((e) {
    final avg = e.value.fold(0.0, (a, b) => a + b) / e.value.length;
    return SkillScore(skill: e.key, score: avg);
  }).toList();

  // Ensure all 4 main skills present (default 0 if no data)
  for (final skill in ['reading', 'listening', 'writing', 'speaking']) {
    if (!skillScores.any((s) => s.skill == skill)) {
      skillScores.add(SkillScore(skill: skill, score: 0));
    }
  }

  // Activity calendar: dates user completed lesson blocks
  final activityRaw = await supabase
      .from('user_progress')
      .select('completed_at')
      .eq('user_id', userId)
      .order('completed_at', ascending: false)
      .limit(365);

  final activityDates = <DateTime>{};
  for (final row in (activityRaw as List)) {
    final rm = Map<String, dynamic>.from(row as Map);
    final ts = rm['completed_at'] as String?;
    if (ts == null) continue;
    final dt = DateTime.tryParse(ts);
    if (dt == null) continue;
    activityDates.add(DateTime(dt.year, dt.month, dt.day));
  }

  // Completed lessons count
  final completedLessons = await _countCompletedLessons(userId);

  return ProgressData(
    skillScores: skillScores,
    examHistory: examHistory,
    activityDates: activityDates,
    currentStreak: currentStreak,
    totalXp: totalXp,
    completedLessons: completedLessons,
  );
});

Future<int> _countCompletedLessons(String userId) async {
  try {
    // A lesson is "complete" when the user has ≥ 6 block progress rows
    final progressRaw = await supabase
        .from('user_progress')
        .select('lesson_id')
        .eq('user_id', userId);

    final Map<String, int> blockCount = {};
    for (final row in (progressRaw as List)) {
      final rm = Map<String, dynamic>.from(row as Map);
      final lid = rm['lesson_id'] as String? ?? '';
      blockCount[lid] = (blockCount[lid] ?? 0) + 1;
    }
    return blockCount.values.where((c) => c >= 6).length;
  } catch (_) {
    return 0;
  }
}
