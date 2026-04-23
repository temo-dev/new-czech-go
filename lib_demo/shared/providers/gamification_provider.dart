import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';

// ── XP Notifier ───────────────────────────────────────────────────────────────

/// Optimistically adds XP to the local user profile and persists to Supabase.
/// Invalidates [currentUserProvider] so PointsCard and Dashboard refresh.
Future<void> awardXp(WidgetRef ref, int xpAmount) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null || xpAmount <= 0) return;

  // Optimistic update
  final userAsync = ref.read(currentUserProvider);
  final current = userAsync.valueOrNull;
  if (current != null) {
    ref
        .read(currentUserProvider.notifier)
        .updateProfile(current.copyWith(totalXp: current.totalXp + xpAmount));
  }

  // Persist via RPC (atomic increment) or raw upsert
  try {
    await supabase.rpc('increment_xp', params: {
      'p_user_id': userId,
      'p_amount': xpAmount,
    });
  } catch (_) {
    // Fallback: fetch current XP and add (must update weekly_xp too so the
    // leaderboard trigger fires)
    try {
      final row = await supabase
          .from('profiles')
          .select('total_xp, weekly_xp')
          .eq('id', userId)
          .single();
      final m = row as Map;
      final existingTotal = m['total_xp'] as int? ?? 0;
      final existingWeekly = m['weekly_xp'] as int? ?? 0;
      await supabase.from('profiles').update({
        'total_xp': existingTotal + xpAmount,
        'weekly_xp': existingWeekly + xpAmount,
      }).eq('id', userId);
    } catch (_) {
      // Silently ignore — the optimistic update already reflected locally
    }
  }

  ref.invalidate(currentUserProvider);
}

// ── Streak update ─────────────────────────────────────────────────────────────

/// Updates the user's activity streak.
/// - If last_activity_date is yesterday → increment streak by 1
/// - If last_activity_date is today → no change
/// - Otherwise → reset streak to 1
/// Invalidates [currentUserProvider] so StreakCard refreshes.
Future<void> updateActivityStreak(WidgetRef ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  try {
    final row = await supabase
        .from('profiles')
        .select('current_streak_days, last_activity_date')
        .eq('id', userId)
        .single();

    final profile = Map<String, dynamic>.from(row as Map);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final lastActivityStr = profile['last_activity_date'] as String?;
    DateTime? lastActivity;
    if (lastActivityStr != null) {
      lastActivity = DateTime.tryParse(lastActivityStr);
      if (lastActivity != null) {
        lastActivity =
            DateTime(lastActivity.year, lastActivity.month, lastActivity.day);
      }
    }

    int newStreak = 1;
    if (lastActivity != null) {
      final diff = todayDate.difference(lastActivity).inDays;
      if (diff == 0) {
        // Already recorded today — nothing to update
        return;
      } else if (diff == 1) {
        final currentStreak = profile['current_streak_days'] as int? ?? 0;
        newStreak = currentStreak + 1;
      }
      // diff > 1 → streak resets to 1
    }

    await supabase.from('profiles').update({
      'current_streak_days': newStreak,
      'last_activity_date': todayDate.toIso8601String(),
    }).eq('id', userId);

    ref.invalidate(currentUserProvider);
  } catch (_) {
    // Non-fatal — don't block exercise completion
  }
}
