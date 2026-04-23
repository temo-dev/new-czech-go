import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.xp,
    this.isCurrentUser = false,
  });

  final int rank;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int xp;
  final bool isCurrentUser;
}

class LeaderboardData {
  const LeaderboardData({
    required this.weekly,
    required this.allTime,
    this.ownWeeklyRank,
    this.ownAllTimeRank,
  });

  final List<LeaderboardEntry> weekly;
  final List<LeaderboardEntry> allTime;
  final int? ownWeeklyRank;
  final int? ownAllTimeRank;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardData>((ref) async {
  final userId = supabase.auth.currentUser?.id;

  // Weekly leaderboard (current week only)
  final weeklyRaw = await supabase
      .from('leaderboard_weekly')
      .select()
      .eq('week_start', _currentWeekStart())
      .order('weekly_xp', ascending: false)
      .limit(50);

  // All-time: rank by total_xp from profiles
  final allTimeRaw = await supabase
      .from('profiles')
      .select('id, display_name, avatar_url, total_xp')
      .order('total_xp', ascending: false)
      .limit(50);

  int? ownWeeklyRank;
  int? ownAllTimeRank;

  final weekly = (weeklyRaw as List).asMap().entries.map((e) {
    final m = Map<String, dynamic>.from(e.value as Map);
    final uid = m['user_id'] as String? ?? m['id'] as String? ?? '';
    final rank = e.key + 1;
    if (uid == userId) ownWeeklyRank = rank;
    return LeaderboardEntry(
      rank: rank,
      userId: uid,
      displayName: m['display_name'] as String? ?? 'Học viên',
      avatarUrl: m['avatar_url'] as String?,
      xp: m['weekly_xp'] as int? ?? 0,
      isCurrentUser: uid == userId,
    );
  }).toList();

  final allTime = (allTimeRaw as List).asMap().entries.map((e) {
    final m = Map<String, dynamic>.from(e.value as Map);
    final uid = m['id'] as String? ?? '';
    final rank = e.key + 1;
    if (uid == userId) ownAllTimeRank = rank;
    return LeaderboardEntry(
      rank: rank,
      userId: uid,
      displayName: m['display_name'] as String? ?? 'Học viên',
      avatarUrl: m['avatar_url'] as String?,
      xp: m['total_xp'] as int? ?? 0,
      isCurrentUser: uid == userId,
    );
  }).toList();

  return LeaderboardData(
    weekly: weekly,
    allTime: allTime,
    ownWeeklyRank: ownWeeklyRank,
    ownAllTimeRank: ownAllTimeRank,
  );
});

String _currentWeekStart() {
  final now = DateTime.now().toUtc();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}
